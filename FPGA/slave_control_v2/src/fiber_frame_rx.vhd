--=============================================================================
-- fiber_frame_rx - V2.0 光纤环网帧接收器
--=============================================================================
-- 功能：
--   从 com_rx (UART字节接收器) 接收字节流，组装成完整帧。
--   支持 HDLC 风格字节去填充、CRC-16-CCITT 校验。
--
-- 帧格式：
--   SOF(0x7E) FLAGS DST SRC CMD LEN PAYLOAD(0~240B) CRC16(2B,LE) EOF(0x7E)
--
-- 字节填充规则（去填充）：
--   0x7D 0x5E → 0x7E
--   0x7D 0x5D → 0x7D
--
-- 状态机：
--   IDLE → WAIT_SOF → HEADER(5B) → PAYLOAD(LEN字节) → CRC16(2B) → WAIT_EOF → DONE
--=============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fiber_frame_rx is
  port (
    -- 系统
    clk         : in  std_logic;   -- 50MHz 系统时钟
    rst         : in  std_logic;   -- 异步复位（低有效）

    -- UART 字节接口（来自 com_rx，在 clk_uart 域）
    rx_byte     : in  std_logic_vector(7 downto 0);
    rx_lk       : in  std_logic;   -- 字节锁存脉冲（单周期高有效）
    rx_busy     : in  std_logic;   -- UART 接收忙标志

    -- 帧缓冲读端口（处理器/TX 通过此接口读取帧数据）
    buf_rd_data : out std_logic_vector(7 downto 0);
    buf_rd_addr : in  std_logic_vector(7 downto 0);

    -- 帧缓冲写端口（cmd_processor 修改帧数据用）
    buf_wr_data : in  std_logic_vector(7 downto 0);
    buf_wr_addr : in  std_logic_vector(7 downto 0);
    buf_wr_en   : in  std_logic;   -- 写使能（单周期脉冲）

    -- 帧头部信息（处理器直接读取，无需访问缓冲）
    flags_out   : out std_logic_vector(7 downto 0);
    dst_out     : out std_logic_vector(7 downto 0);
    src_out     : out std_logic_vector(7 downto 0);
    cmd_out     : out std_logic_vector(7 downto 0);
    frame_len   : out std_logic_vector(7 downto 0);  -- 载荷长度

    -- 状态输出
    frame_valid : out std_logic;   -- 帧接收完成且 CRC 正确（单周期脉冲）
    frame_err   : out std_logic;   -- 帧错误（单周期脉冲）
    err_code    : out std_logic_vector(2 downto 0);
    crc_err_cnt : out std_logic_vector(15 downto 0)
  );
end entity fiber_frame_rx;

architecture rtl of fiber_frame_rx is

  --===========================================================================
  -- CRC-16-CCITT 常量
  --===========================================================================
  -- 多项式: x^16 + x^12 + x^5 + 1 = 0x1021
  -- 初始值: 0xFFFF
  -- 覆盖: FLAGS ~ PAYLOAD 末尾
  --===========================================================================

  -- CRC 计算函数：单字节更新
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
  -- 帧缓冲（256 字节）
  --===========================================================================
  -- 布局: [0]=FLAGS, [1]=DST, [2]=SRC, [3]=CMD, [4]=LEN
  --       [5..5+LEN-1]=PAYLOAD, [5+LEN..5+LEN+1]=CRC16{LSB,MSB}
  --===========================================================================
  type frame_buf_t is array (0 to 255) of std_logic_vector(7 downto 0);
  signal frame_buf    : frame_buf_t;

  --===========================================================================
  -- 状态机定义
  --===========================================================================
  type rx_state_t is (
    ST_IDLE,          -- 等待 SOF
    ST_HEADER,        -- 接收 FLAGS..LEN（5 字节）
    ST_PAYLOAD,       -- 接收 PAYLOAD（LEN 字节）
    ST_CRC,           -- 接收 CRC16（2 字节，LSB 先）
    ST_WAIT_EOF,      -- 等待 EOF (0x7E)
    ST_DONE,          -- 帧有效，输出脉冲
    ST_ERROR          -- 帧错误，输出脉冲
  );
  signal state        : rx_state_t;

  --===========================================================================
  -- 内部信号
  --===========================================================================
  signal buf_wr_ptr   : integer range 0 to 255;  -- 缓冲写指针（内部）
  signal byte_count   : integer range 0 to 255;  -- 当前阶段已接收字节计数
  signal exp_len      : integer range 0 to 255;  -- 期望的载荷长度（来自 LEN 字段）
  signal escape_flag  : std_logic;               -- 转义标志（收到 0x7D 后置位）
  signal crc_calc     : std_logic_vector(15 downto 0);  -- CRC 计算累加器
  signal crc_received : std_logic_vector(15 downto 0);  -- 接收到的 CRC 值
  signal crc_ok       : std_logic;               -- CRC 校验通过
  signal err_cnt      : unsigned(15 downto 0);   -- CRC 错误计数器
  signal rx_lk_d1     : std_logic;               -- rx_lk 延迟（边沿检测）

  -- 内部写通道（状态机→缓冲，避免多驱动）
  signal rx_wr_en     : std_logic;
  signal rx_wr_data   : std_logic_vector(7 downto 0);
  signal rx_wr_addr   : integer range 0 to 255;

  -- 接收阶段字节计数目标
  signal hdr_target   : integer range 0 to 5;    -- HEADER 阶段目标=5
  signal payload_target : integer range 0 to 255; -- PAYLOAD 阶段目标=exp_len
  signal crc_target   : integer range 0 to 2;    -- CRC 阶段目标=2

begin

  --===========================================================================
  -- 主接收状态机
  --===========================================================================
  p_rx_fsm : process(clk, rst)
    variable eff_byte : std_logic_vector(7 downto 0);
  begin
    if rst = '0' then
      state           <= ST_IDLE;
      buf_wr_ptr      <= 0;
      byte_count      <= 0;
      exp_len         <= 0;
      escape_flag     <= '0';
      crc_calc        <= (others => '0');
      crc_received    <= (others => '0');
      crc_ok          <= '0';
      err_cnt         <= (others => '0');
      rx_lk_d1        <= '0';
      flags_out       <= (others => '0');
      dst_out         <= (others => '0');
      src_out         <= (others => '0');
      cmd_out         <= (others => '0');
      frame_len       <= (others => '0');
      frame_valid     <= '0';
      frame_err       <= '0';
      err_code        <= (others => '0');

    elsif rising_edge(clk) then
      -- 默认值
      rx_lk_d1    <= rx_lk;
      rx_wr_en    <= '0';

      case state is

        --=================================================================
        -- ST_IDLE: 等待 SOF (0x7E)
        --=================================================================
        when ST_IDLE =>
          buf_wr_ptr  <= 0;
          byte_count  <= 0;
          exp_len     <= 0;
          escape_flag <= '0';
          crc_calc    <= x"FFFF";  -- CRC 初始值
          crc_ok      <= '0';
          err_code    <= (others => '0');
          -- frame_valid/frame_err 保持上一个值，在新帧开始时不立即清零

          if rx_lk = '1' and rx_lk_d1 = '0' then
            report "DBG: lk edge in IDLE, rx_byte=" & integer'image(to_integer(unsigned(rx_byte)));
            if rx_byte = x"7E" then
              report "DBG: SOF detected -> HEADER";
              -- 检测到新帧开始，清除上一帧的标志
              frame_valid <= '0';
              frame_err   <= '0';
              state <= ST_HEADER;
              hdr_target <= 5;
            end if;
          end if;

        --=================================================================
        -- ST_HEADER: 接收 FLAGS, DST, SRC, CMD, LEN（5 字节）
        --=================================================================
        when ST_HEADER =>
          if rx_lk = '1' and rx_lk_d1 = '0' then
            report "DBG HDR: byte=" & integer'image(to_integer(unsigned(rx_byte))) & " cnt=" & integer'image(byte_count);
            -- 提前 EOF？（帧太短）
            if rx_byte = x"7E" then
              report "DBG HDR: premature EOF";
              state    <= ST_ERROR;
              err_code <= "001";
            -- 转义字节
            elsif rx_byte = x"7D" then
              if escape_flag = '1' then
                -- 连续转义字节：无效序列
                state    <= ST_ERROR;
                err_code <= "100";
              else
                escape_flag <= '1';
              end if;
            else
              -- 去填充 → 计算有效字节
              if escape_flag = '1' then
                if rx_byte = x"5E" then
                  eff_byte := x"7E";
                elsif rx_byte = x"5D" then
                  eff_byte := x"7D";
                else
                  state    <= ST_ERROR;
                  err_code <= "100";  -- 无效转义序列
                  eff_byte := x"00";
                end if;
              else
                eff_byte := rx_byte;
              end if;

              -- 写缓冲并更新 CRC
              rx_wr_data <= eff_byte;
              rx_wr_addr <= buf_wr_ptr;
              rx_wr_en   <= '1';
              crc_calc    <= crc16_update(crc_calc, eff_byte);
              buf_wr_ptr  <= buf_wr_ptr + 1;
              byte_count  <= byte_count + 1;
              escape_flag <= '0';

              -- 收到 LEN 后确定载荷长度（byte_count 刚递增，LEN 是第5字节=索引4）
              if byte_count = 4 then
                exp_len <= to_integer(unsigned(eff_byte));
                report "DBG HDR: LEN byte, val=" & integer'image(to_integer(unsigned(eff_byte)));
                if to_integer(unsigned(eff_byte)) > 240 then
                  state    <= ST_ERROR;
                  err_code <= "010";
                elsif to_integer(unsigned(eff_byte)) = 0 then
                  report "DBG HDR: LEN=0 -> ST_CRC";
                  state      <= ST_CRC;
                  byte_count <= 0;
                  crc_target <= 2;
                else
                  report "DBG HDR: LEN>0 -> ST_PAYLOAD";
                  state      <= ST_PAYLOAD;
                  byte_count <= 0;
                  payload_target <= to_integer(unsigned(eff_byte));
                end if;
              end if;
            end if;
          end if;

        --=================================================================
        -- ST_PAYLOAD: 接收 PAYLOAD（LEN 字节）
        --=================================================================
        when ST_PAYLOAD =>
          if rx_lk = '1' and rx_lk_d1 = '0' then
            -- EOF 仅在 payload 收完后才是合法的
            if rx_byte = x"7E" then
              if byte_count = payload_target then
                -- 正常转到 CRC（但 CRC 长度为0？不可能，至少2字节CRC+EOF）
                -- 实际不应在这里收到 EOF，报错
                state    <= ST_ERROR;
                err_code <= "001";
              else
                state    <= ST_ERROR;
                err_code <= "011";  -- 载荷不足就收到 EOF
              end if;
            elsif rx_byte = x"7D" then
              if escape_flag = '1' then
                -- 连续转义字节：无效序列
                state    <= ST_ERROR;
                err_code <= "100";
              else
                escape_flag <= '1';
              end if;
            else
              -- 去填充处理
              if escape_flag = '1' then
                if rx_byte = x"5E" then
                  rx_wr_data <= x"7E";
                  rx_wr_addr <= buf_wr_ptr;
                  rx_wr_en   <= '1';
                  crc_calc <= crc16_update(crc_calc, x"7E");
                elsif rx_byte = x"5D" then
                  rx_wr_data <= x"7D";
                  rx_wr_addr <= buf_wr_ptr;
                  rx_wr_en   <= '1';
                  crc_calc <= crc16_update(crc_calc, x"7D");
                else
                  state    <= ST_ERROR;
                  err_code <= "100";  -- 无效转义序列
                end if;
              else
                rx_wr_data <= rx_byte;
                rx_wr_addr <= buf_wr_ptr;
                rx_wr_en   <= '1';
                crc_calc <= crc16_update(crc_calc, rx_byte);
              end if;

              buf_wr_ptr <= buf_wr_ptr + 1;
              byte_count  <= byte_count + 1;
              escape_flag <= '0';

              -- 载荷收完，进入 CRC 阶段
              if byte_count = payload_target - 1 then
                -- payload_target bytes received (byte_count was incremented)
                state      <= ST_CRC;
                byte_count <= 0;
                crc_target <= 2;
              end if;
            end if;
          end if;

        --=================================================================
        -- ST_CRC: 接收 CRC16（2 字节，LSB 先）
        --=================================================================
        when ST_CRC =>
          if rx_lk = '1' and rx_lk_d1 = '0' then
            report "DBG CRC: byte=" & integer'image(to_integer(unsigned(rx_byte))) & " cnt=" & integer'image(byte_count);
            if rx_byte = x"7E" then
              report "DBG CRC: premature EOF!";
              state    <= ST_ERROR;
              err_code <= "001";
            elsif rx_byte = x"7D" then
              if escape_flag = '1' then
                -- 连续转义字节：无效序列
                state    <= ST_ERROR;
                err_code <= "100";
              else
                escape_flag <= '1';
              end if;
            else
              -- 存储 CRC 字节（先去填充）
              if escape_flag = '1' then
                if rx_byte = x"5E" then
                  crc_received(7 + byte_count*8 downto byte_count*8) <= x"7E";
                elsif rx_byte = x"5D" then
                  crc_received(7 + byte_count*8 downto byte_count*8) <= x"7D";
                else
                  state    <= ST_ERROR;
                  err_code <= "100";  -- 无效转义序列
                end if;
              else
                crc_received(7 + byte_count*8 downto byte_count*8) <= rx_byte;
              end if;
              byte_count  <= byte_count + 1;
              escape_flag <= '0';

              if byte_count = 1 then
                report "DBG CRC: both bytes received -> WAIT_EOF";
                state <= ST_WAIT_EOF;
              end if;
            end if;
          end if;

        --=================================================================
        -- ST_WAIT_EOF: 等待 EOF (0x7E)，允许转义
        --=================================================================
        when ST_WAIT_EOF =>
          if rx_lk = '1' and rx_lk_d1 = '0' then
            report "DBG WAIT_EOF: byte=" & integer'image(to_integer(unsigned(rx_byte)));
            if rx_byte = x"7E" then
              report "DBG WAIT_EOF: EOF -> check CRC";
              if crc_calc = crc_received then
                report "DBG WAIT_EOF: CRC OK -> DONE";
                crc_ok <= '1';
                state  <= ST_DONE;
              else
                report "DBG WAIT_EOF: CRC mismatch -> ERROR"
                  & " calc=" & integer'image(to_integer(unsigned(crc_calc(15 downto 8))))
                  & integer'image(to_integer(unsigned(crc_calc(7 downto 0))))
                  & " recv=" & integer'image(to_integer(unsigned(crc_received(15 downto 8))))
                  & integer'image(to_integer(unsigned(crc_received(7 downto 0))));
                crc_ok   <= '0';
                err_cnt  <= err_cnt + 1;
                state    <= ST_ERROR;
                err_code <= "101";
              end if;
            elsif rx_byte = x"7D" then
              if escape_flag = '1' then
                -- 连续转义字节：无效序列
                state    <= ST_ERROR;
                err_code <= "100";
              else
                escape_flag <= '1';
              end if;
            else
              -- 收到非 0x7E 非 0x7D 的字节
              if escape_flag = '1' then
                -- 转义后也不是 0x7E（EOF），可能是噪声
                if rx_byte = x"5E" then
                  -- 0x7D 0x5E → 0x7E → 等同于 EOF
                  report "DBG WAIT_EOF: escaped EOF -> check CRC";
                  if crc_calc = crc_received then
                    crc_ok <= '1';
                    state  <= ST_DONE;
                  else
                    crc_ok   <= '0';
                    err_cnt  <= err_cnt + 1;
                    state    <= ST_ERROR;
                    err_code <= "101";
                  end if;
                else
                  -- 无效转义序列
                  state    <= ST_ERROR;
                  err_code <= "100";
                end if;
                escape_flag <= '0';
              end if;
              -- 非转义模式下的普通字节：继续等待 EOF（不报错）
            end if;
          end if;

        --=================================================================
        -- ST_DONE: 帧接收成功
        --=================================================================
        when ST_DONE =>
          -- 锁存头部信息
          flags_out <= frame_buf(0);
          dst_out   <= frame_buf(1);
          src_out   <= frame_buf(2);
          cmd_out   <= frame_buf(3);
          frame_len <= std_logic_vector(to_unsigned(exp_len, 8));
          frame_valid <= '1';
          state     <= ST_IDLE;

        --=================================================================
        -- ST_ERROR: 帧接收错误
        --=================================================================
        when ST_ERROR =>
          frame_err <= '1';
          state     <= ST_IDLE;

        when others =>
          state <= ST_IDLE;

      end case;
    end if;
  end process p_rx_fsm;

  --===========================================================================
  -- 帧缓冲异步读端口（处理器/TX 读取帧数据用）
  --===========================================================================
  buf_rd_data <= frame_buf(to_integer(unsigned(buf_rd_addr)));

  --===========================================================================
  -- 帧缓冲统一写进程（单点写入，避免多驱动）
  -- 优先级：外部写（cmd_processor）> 内部写（状态机接收）
  --===========================================================================
  p_buf_write : process(clk)
  begin
    if rising_edge(clk) then
      if buf_wr_en = '1' then
        frame_buf(to_integer(unsigned(buf_wr_addr))) <= buf_wr_data;
      elsif rx_wr_en = '1' then
        frame_buf(rx_wr_addr) <= rx_wr_data;
      end if;
    end if;
  end process p_buf_write;

  --===========================================================================
  -- 输出计数器
  --===========================================================================
  crc_err_cnt <= std_logic_vector(err_cnt);

end architecture rtl;
