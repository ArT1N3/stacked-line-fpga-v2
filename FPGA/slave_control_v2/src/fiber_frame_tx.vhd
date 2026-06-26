--=============================================================================
-- fiber_frame_tx - V2.0 光纤环网帧发送器
--=============================================================================
-- 功能：
--   从帧缓冲读取数据，组装完整帧并通过 com_tx (UART字节发送器) 串行发送。
--   支持 HDLC 风格字节填充和 CRC-16-CCITT 生成。
--
-- 帧格式：
--   SOF(0x7E) FLAGS DST SRC CMD LEN PAYLOAD(0~240B) CRC16(2B,LE) EOF(0x7E)
--
-- 字节填充规则（发送端）：
--   0x7E → 0x7D 0x5E
--   0x7D → 0x7D 0x5D
--   SOF/EOF 的 0x7E 不进行填充（它们是定界符本身）
--
-- 时序：
--   每字节发送时间 ≈ 87μs (10bit × 8.68μs @115200bps)
--   最大帧 (249B) ≈ 21.6ms
--=============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fiber_frame_tx is
  port (
    -- 系统
    clk         : in  std_logic;   -- 50MHz 系统时钟
    rst         : in  std_logic;   -- 异步复位（低有效）

    -- 帧缓冲读端口
    buf_rd_data : in  std_logic_vector(7 downto 0);
    buf_rd_addr : out std_logic_vector(7 downto 0);

    -- 帧信息
    frame_len   : in  std_logic_vector(7 downto 0);  -- 载荷长度 (0~240)

    -- 控制
    tx_start    : in  std_logic;   -- 启动发送（单周期脉冲，高有效）
    tx_done     : out std_logic;   -- 发送完成（单周期脉冲）
    tx_busy_out : out std_logic;   -- 帧发送进行中

    -- UART TX 字节接口（连接 com_tx）
    tx_byte     : out std_logic_vector(7 downto 0);  -- 待发送字节
    tx_load     : out std_logic;   -- 加载信号（低有效，连接 com_tx 的 ld）
    uart_busy   : in  std_logic    -- com_tx 忙标志（高=发送中）
  );
end entity fiber_frame_tx;

architecture rtl of fiber_frame_tx is

  --===========================================================================
  -- CRC-16-CCITT（与 fiber_frame_rx 中的函数相同）
  --===========================================================================
  function crc16_update(crc : std_logic_vector(15 downto 0);
                        data : std_logic_vector(7 downto 0))
                        return std_logic_vector is
    variable crc_v : std_logic_vector(15 downto 0);
    variable d     : std_logic;
  begin
    crc_v := crc;
    for i in 7 downto 0 loop
      d      := data(i) xor crc_v(15);
      crc_v(15 downto 13) := crc_v(14 downto 12);
      crc_v(12)           := d xor crc_v(11);
      crc_v(11 downto 6)  := crc_v(10 downto 5);
      crc_v(5)            := d xor crc_v(4);
      crc_v(4 downto 1)   := crc_v(3 downto 0);
      crc_v(0)            := d;
    end loop;
    return crc_v;
  end function crc16_update;

  --===========================================================================
  -- 发送状态机
  --===========================================================================
  type tx_state_t is (
    ST_IDLE,          -- 等待 tx_start
    ST_SOF,           -- 发送 SOF (0x7E)
    ST_HEADER,        -- 发送 FLAGS..LEN（5 字节，计算 CRC）
    ST_PAYLOAD,       -- 发送 PAYLOAD（LEN 字节，计算 CRC）
    ST_CRC,           -- 发送 CRC16（2 字节，LSB 先）
    ST_EOF,           -- 发送 EOF (0x7E)
    ST_DONE           -- 完成，输出 tx_done 脉冲
  );
  signal state        : tx_state_t;

  -- 字节填充子状态
  type stuff_state_t is (
    SS_NORMAL,        -- 正常发送
    SS_ESCAPE         -- 发送转义序列的第二个字节
  );
  signal stuff_st     : stuff_state_t;

  --===========================================================================
  -- 内部信号
  --===========================================================================
  signal byte_idx     : integer range 0 to 255;  -- 当前阶段字节索引
  signal exp_len      : integer range 0 to 255;  -- 载荷长度
  signal buf_addr     : unsigned(7 downto 0);    -- 缓冲读地址
  signal current_byte : std_logic_vector(7 downto 0);  -- 当前处理的原始字节
  signal crc_calc     : std_logic_vector(15 downto 0); -- CRC 累加器
  signal crc_gen      : std_logic_vector(15 downto 0); -- 生成完毕的 CRC 值
  signal uart_busy_d1 : std_logic;               -- busy 延迟（边沿检测）
  signal uart_done    : std_logic;               -- UART 字节发送完成脉冲
  signal load_reg     : std_logic;               -- tx_load 寄存器

begin

  --===========================================================================
  -- UART busy 下降沿检测（字节发送完成）
  --===========================================================================
  process(clk, rst)
  begin
    if rst = '0' then
      uart_busy_d1 <= '0';
    elsif rising_edge(clk) then
      uart_busy_d1 <= uart_busy;
    end if;
  end process;
  uart_done <= '1' when uart_busy_d1 = '1' and uart_busy = '0' else '0';

  --===========================================================================
  -- 主发送状态机
  --===========================================================================
  p_tx_fsm : process(clk, rst)
    -- 需要填充的字节判断
    impure function needs_stuffing(b : std_logic_vector(7 downto 0)) return boolean is
    begin
      return b = x"7E" or b = x"7D";
    end function;
  begin
    if rst = '0' then
      state        <= ST_IDLE;
      stuff_st     <= SS_NORMAL;
      byte_idx     <= 0;
      exp_len      <= 0;
      buf_addr     <= (others => '0');
      current_byte <= (others => '0');
      crc_calc     <= (others => '0');
      crc_gen      <= (others => '0');
      tx_byte      <= (others => '1');  -- 空闲高
      load_reg     <= '1';              -- 不加载
      tx_done      <= '0';
      tx_busy_out  <= '0';

    elsif rising_edge(clk) then
      -- 默认值
      tx_done <= '0';

      case state is

        --=================================================================
        -- ST_IDLE: 等待 tx_start
        --=================================================================
        when ST_IDLE =>
          tx_busy_out <= '0';
          load_reg    <= '1';
          if tx_start = '1' then
            exp_len   <= to_integer(unsigned(frame_len));
            crc_calc  <= x"FFFF";  -- CRC 初始值
            buf_addr  <= (others => '0');
            byte_idx  <= 0;
            tx_busy_out <= '1';
            state     <= ST_SOF;
          end if;

        --=================================================================
        -- ST_SOF: 发送 SOF (0x7E)，不填充
        --=================================================================
        when ST_SOF =>
          if uart_busy = '0' and load_reg = '1' then
            tx_byte  <= x"7E";
            load_reg <= '0';  -- 触发 com_tx 加载
          elsif uart_done = '1' then
            load_reg <= '1';
            byte_idx <= 0;
            buf_addr <= to_unsigned(0, 8);  -- 指向 FLAGS
            state    <= ST_HEADER;
          end if;

        --=================================================================
        -- ST_HEADER: 发送 FLAGS..LEN（缓冲地址 0..4），计算 CRC
        --=================================================================
        when ST_HEADER =>
          if byte_idx < 5 then
            if uart_busy = '0' and load_reg = '1' then
              current_byte <= buf_rd_data;
              crc_calc <= crc16_update(crc_calc, buf_rd_data);

              if needs_stuffing(buf_rd_data) then
                -- 发送转义前缀 0x7D
                tx_byte  <= x"7D";
                load_reg <= '0';
                stuff_st <= SS_ESCAPE;
              else
                -- 直接发送
                tx_byte  <= buf_rd_data;
                load_reg <= '0';
                stuff_st <= SS_NORMAL;
              end if;
            elsif uart_done = '1' then
              load_reg <= '1';
              if stuff_st = SS_ESCAPE then
                -- 发送转义后的字节
                if current_byte = x"7E" then
                  tx_byte <= x"5E";
                else
                  tx_byte <= x"5D";
                end if;
                load_reg <= '0';
                stuff_st <= SS_NORMAL;
              else
                -- 正常字节发送完毕，前进到下一字节
                byte_idx <= byte_idx + 1;
                buf_addr <= buf_addr + 1;
              end if;
            end if;
          else
            -- HEADER 发送完毕（5字节），进入 PAYLOAD
            if uart_busy = '0' and load_reg = '1' then
              byte_idx <= 0;
              buf_addr <= to_unsigned(5, 8);  -- 指向 PAYLOAD[0]
              if exp_len = 0 then
                -- 无载荷，直接进入 CRC
                crc_gen <= crc16_update(crc_calc, x"00");  -- dummy, already done
                -- CRC 需要基于已经计算的 crc_calc
                byte_idx <= 0;
                state <= ST_CRC;
              else
                state <= ST_PAYLOAD;
              end if;
            end if;
          end if;

        --=================================================================
        -- ST_PAYLOAD: 发送 PAYLOAD，计算 CRC
        --=================================================================
        when ST_PAYLOAD =>
          if byte_idx < exp_len then
            if uart_busy = '0' and load_reg = '1' then
              current_byte <= buf_rd_data;
              crc_calc <= crc16_update(crc_calc, buf_rd_data);

              if needs_stuffing(buf_rd_data) then
                tx_byte  <= x"7D";
                load_reg <= '0';
                stuff_st <= SS_ESCAPE;
              else
                tx_byte  <= buf_rd_data;
                load_reg <= '0';
                stuff_st <= SS_NORMAL;
              end if;
            elsif uart_done = '1' then
              load_reg <= '1';
              if stuff_st = SS_ESCAPE then
                if current_byte = x"7E" then
                  tx_byte <= x"5E";
                else
                  tx_byte <= x"5D";
                end if;
                load_reg <= '0';
                stuff_st <= SS_NORMAL;
              else
                byte_idx <= byte_idx + 1;
                buf_addr <= buf_addr + 1;
              end if;
            end if;
          else
            -- PAYLOAD 发送完毕，保存 CRC 结果，进入 CRC 阶段
            if uart_busy = '0' and load_reg = '1' then
              crc_gen  <= crc_calc;  -- 锁存最终 CRC 值
              byte_idx <= 0;
              state    <= ST_CRC;
            end if;
          end if;

        --=================================================================
        -- ST_CRC: 发送 CRC16（2 字节，LSB 先）
        -- CRC 字节也需要填充
        --=================================================================
        when ST_CRC =>
          if byte_idx < 2 then
            if uart_busy = '0' and load_reg = '1' then
              if byte_idx = 0 then
                current_byte <= crc_gen(7 downto 0);   -- LSB
              else
                current_byte <= crc_gen(15 downto 8);  -- MSB
              end if;

              if needs_stuffing(current_byte) then
                tx_byte  <= x"7D";
                load_reg <= '0';
                stuff_st <= SS_ESCAPE;
              else
                tx_byte  <= current_byte;
                load_reg <= '0';
                stuff_st <= SS_NORMAL;
              end if;
            elsif uart_done = '1' then
              load_reg <= '1';
              if stuff_st = SS_ESCAPE then
                if current_byte = x"7E" then
                  tx_byte <= x"5E";
                else
                  tx_byte <= x"5D";
                end if;
                load_reg <= '0';
                stuff_st <= SS_NORMAL;
              else
                byte_idx <= byte_idx + 1;
              end if;
            end if;
          else
            -- CRC 发送完毕，发送 EOF
            if uart_busy = '0' and load_reg = '1' then
              state <= ST_EOF;
            end if;
          end if;

        --=================================================================
        -- ST_EOF: 发送 EOF (0x7E)，不填充
        --=================================================================
        when ST_EOF =>
          if uart_busy = '0' and load_reg = '1' then
            tx_byte  <= x"7E";
            load_reg <= '0';
          elsif uart_done = '1' then
            load_reg <= '1';
            state    <= ST_DONE;
          end if;

        --=================================================================
        -- ST_DONE: 完成
        --=================================================================
        when ST_DONE =>
          tx_busy_out <= '0';
          tx_done     <= '1';
          state       <= ST_IDLE;

        when others =>
          state <= ST_IDLE;

      end case;
    end if;
  end process p_tx_fsm;

  --===========================================================================
  -- 输出
  --===========================================================================
  tx_load     <= load_reg;
  buf_rd_addr <= std_logic_vector(buf_addr);

end architecture rtl;
