--=============================================================================
-- cmd_processor - V2.0 光纤环网命令处理器
--=============================================================================
-- 功能：
--   解析接收到的帧命令，执行对应操作，构建响应或广播收集数据。
--
-- 广播收集机制：
--   CMD=0x02 (STAT_COLLECT) 或 CMD=0x06 (TOPO_DISCOVER) 时，
--   检查本机地址是否在 GROUP 范围 [group_start, group_start+group_count-1] 内。
--   若在范围内，向载荷末尾追加数据，更新 LEN，后续由 fiber_frame_tx 发送。
--
-- 地址匹配：
--   - 单播: DST == my_address
--   - 广播: BCAST == '1' 或 DST == 0xFF
--=============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cmd_processor is
  port (
    -- 系统
    clk           : in  std_logic;
    rst           : in  std_logic;

    -- 本机配置
    my_address    : in  std_logic_vector(7 downto 0);  -- 本机地址 (1~254)
    module_count  : in  std_logic_vector(1 downto 0);  -- 模块数 (1~4: 00=1,01=2,10=3,11=4)

    -- 帧头部（来自 fiber_frame_rx）
    proc_start    : in  std_logic;   -- 启动处理（单周期脉冲）
    flags_in      : in  std_logic_vector(7 downto 0);
    dst_in        : in  std_logic_vector(7 downto 0);
    src_in        : in  std_logic_vector(7 downto 0);
    cmd_in        : in  std_logic_vector(7 downto 0);
    frame_len_in  : in  std_logic_vector(7 downto 0);

    -- 帧缓冲读写接口（修改帧数据、更新 LEN 等）
    buf_wr_data   : out std_logic_vector(7 downto 0);
    buf_wr_addr   : out std_logic_vector(7 downto 0);
    buf_wr_en     : out std_logic;    -- 写使能
    buf_rd_data   : in  std_logic_vector(7 downto 0);
    buf_rd_addr   : out std_logic_vector(7 downto 0);

    -- 本机状态输入（供响应使用）
    fault_in      : in  std_logic_vector(7 downto 0);   -- bit[N]=模块N故障
    relay_in      : in  std_logic_vector(7 downto 0);   -- bit[N]=模块N继电器状态
    module_present: in  std_logic_vector(3 downto 0);   -- 已安装模块位掩码
    temp_in       : in  std_logic_vector(15 downto 0);  -- 温度 ADC
    vcc_in        : in  std_logic_vector(15 downto 0);  -- 电压监控
    slave_status  : in  std_logic_vector(2 downto 0);   -- [故障锁存, 通信错误, 配置错误]
    hop_count     : in  std_logic_vector(15 downto 0);  -- 跳数（来自帧载荷或累加）

    -- 控制输出
    relay_ctrl    : out std_logic_vector(7 downto 0);   -- 继电器控制值
    relay_mask    : out std_logic_vector(7 downto 0);   -- 继电器写掩码
    relay_update  : out std_logic;   -- 继电器更新脉冲
    fault_clear   : out std_logic;   -- 清除故障锁存
    soft_reset    : out std_logic;   -- 软复位
    config_write  : out std_logic;   -- 配置写入脉冲
    config_id     : out std_logic_vector(7 downto 0);
    config_data   : out std_logic_vector(7 downto 0);
    addr_assign   : out std_logic;   -- 地址分配脉冲
    new_address   : out std_logic_vector(7 downto 0);
    write_flash   : out std_logic;   -- 写入 Flash 标志

    -- 状态输出
    frame_matched : out std_logic;   -- 帧地址匹配（本机需处理）
    frame_modified: out std_logic;   -- 帧被修改（需重算 CRC）
    proc_done     : out std_logic    -- 处理完成脉冲
  );
end entity cmd_processor;

architecture rtl of cmd_processor is

  -- 命令常量
  constant CMD_STAT_QUERY     : std_logic_vector(7 downto 0) := x"01";
  constant CMD_STAT_COLLECT   : std_logic_vector(7 downto 0) := x"02";
  constant CMD_RLY_CTRL       : std_logic_vector(7 downto 0) := x"03";
  constant CMD_CFG_WRITE      : std_logic_vector(7 downto 0) := x"04";
  constant CMD_CFG_READ       : std_logic_vector(7 downto 0) := x"05";
  constant CMD_TOPO_DISCOVER  : std_logic_vector(7 downto 0) := x"06";
  constant CMD_FAULT_CLEAR    : std_logic_vector(7 downto 0) := x"08";
  constant CMD_RESET_SLAVE    : std_logic_vector(7 downto 0) := x"09";
  constant CMD_IDENTIFY       : std_logic_vector(7 downto 0) := x"0A";
  constant CMD_ADDR_ASSIGN    : std_logic_vector(7 downto 0) := x"0B";
  constant CMD_BROADCAST_RLY  : std_logic_vector(7 downto 0) := x"0D";
  constant CMD_BROADCAST_CFG  : std_logic_vector(7 downto 0) := x"0E";

  -- 处理状态机
  type proc_state_t is (
    ST_IDLE,
    ST_CHECK_ADDR,    -- 检查地址匹配
    ST_DECODE,        -- 解码命令
    ST_BUILD_RESP,    -- 构建响应（单播查询类）
    ST_APPEND_DATA,   -- 追加数据（广播收集类）
    ST_EXECUTE,       -- 执行控制命令
    ST_DONE
  );
  signal state      : proc_state_t;

  -- 内部信号
  signal is_bcast   : std_logic;
  signal is_collect : std_logic;
  signal addr_match : std_logic;
  signal mod_addr   : std_logic_vector(1 downto 0);  -- 目标模块
  signal num_modules: integer range 1 to 4;
  signal payload_len: integer range 0 to 255;
  signal append_offset : integer range 0 to 255;     -- 追加数据起始偏移
  signal collect_idx   : integer range 0 to 7;       -- 当前追加字节索引
  signal resp_byte_cnt : integer range 0 to 15;      -- 响应字节计数

begin

  --===========================================================================
  -- 地址匹配逻辑（组合）
  --===========================================================================
  is_bcast   <= flags_in(6);  -- BCAST 标志位
  mod_addr   <= flags_in(4 downto 3);  -- 目标模块号
  num_modules <= 1 when module_count = "00" else
                 2 when module_count = "01" else
                 3 when module_count = "10" else 4;

  -- 地址匹配：广播 or 单播命中
  addr_match <= '1' when (is_bcast = '1' or dst_in = x"FF" or dst_in = my_address) else '0';

  -- 是否为广播收集类命令
  is_collect <= '1' when (cmd_in = CMD_STAT_COLLECT or cmd_in = CMD_TOPO_DISCOVER)
                      and is_bcast = '1' else '0';

  -- 载荷长度
  payload_len <= to_integer(unsigned(frame_len_in));

  --===========================================================================
  -- 命令处理状态机
  --===========================================================================
  p_proc : process(clk, rst)
  begin
    if rst = '0' then
      state          <= ST_IDLE;
      buf_wr_data    <= (others => '0');
      buf_wr_addr    <= (others => '0');
      buf_wr_en      <= '0';
      buf_rd_addr    <= (others => '0');
      relay_ctrl     <= (others => '0');
      relay_mask     <= (others => '0');
      relay_update   <= '0';
      fault_clear    <= '0';
      soft_reset     <= '0';
      config_write   <= '0';
      config_id      <= (others => '0');
      config_data    <= (others => '0');
      addr_assign    <= '0';
      new_address    <= (others => '0');
      write_flash    <= '0';
      frame_matched  <= '0';
      frame_modified <= '0';
      proc_done      <= '0';
      append_offset  <= 0;
      collect_idx    <= 0;
      resp_byte_cnt  <= 0;

    elsif rising_edge(clk) then
      -- 默认值
      buf_wr_en      <= '0';
      relay_update   <= '0';
      fault_clear    <= '0';
      soft_reset     <= '0';
      config_write   <= '0';
      addr_assign    <= '0';
      proc_done      <= '0';

      case state is

        --=================================================================
        -- ST_IDLE: 等待帧处理请求
        --=================================================================
        when ST_IDLE =>
          frame_matched  <= '0';
          frame_modified <= '0';
          if proc_start = '1' then
            state <= ST_CHECK_ADDR;
          end if;

        --=================================================================
        -- ST_CHECK_ADDR: 检查地址匹配
        --=================================================================
        when ST_CHECK_ADDR =>
          if addr_match = '0' then
            -- 不匹配，直接完成（原样转发）
            frame_matched <= '0';
            proc_done     <= '1';
            state         <= ST_IDLE;
          else
            frame_matched <= '1';
            state         <= ST_DECODE;
          end if;

        --=================================================================
        -- ST_DECODE: 解码命令，分支处理
        --=================================================================
        when ST_DECODE =>
          case cmd_in is

            -- 单播状态查询: 构建12字节响应
            when CMD_STAT_QUERY =>
              state <= ST_BUILD_RESP;
              resp_byte_cnt <= 0;

            -- 广播收集状态: 追加4字节
            when CMD_STAT_COLLECT =>
              state <= ST_APPEND_DATA;
              append_offset <= 5 + payload_len;  -- 载荷末尾
              collect_idx   <= 0;

            -- 拓扑发现: 追加5字节
            when CMD_TOPO_DISCOVER =>
              state <= ST_APPEND_DATA;
              append_offset <= 5 + payload_len;
              collect_idx   <= 0;

            -- 继电器控制
            when x"03" =>  -- CMD_RLY_CTRL
              state <= ST_EXECUTE;
            when x"0D" =>  -- CMD_BROADCAST_RLY
              state <= ST_EXECUTE;

            -- 配置写入
            when x"04" =>  -- CMD_CFG_WRITE
              state <= ST_EXECUTE;
            when x"0E" =>  -- CMD_BROADCAST_CFG
              state <= ST_EXECUTE;

            -- 故障清除
            when CMD_FAULT_CLEAR =>
              state <= ST_EXECUTE;

            -- 软复位
            when CMD_RESET_SLAVE =>
              state <= ST_EXECUTE;

            -- 身份识别: 构建8字节响应
            when CMD_IDENTIFY =>
              state <= ST_BUILD_RESP;
              resp_byte_cnt <= 0;

            -- 地址分配
            when CMD_ADDR_ASSIGN =>
              state <= ST_EXECUTE;

            -- 配置读取: 构建响应
            when CMD_CFG_READ =>
              state <= ST_BUILD_RESP;
              resp_byte_cnt <= 0;

            -- 未知命令: 直接完成
            when others =>
              proc_done <= '1';
              state     <= ST_IDLE;

          end case;

        --=================================================================
        -- ST_BUILD_RESP: 构建响应载荷（单播查询命令）
        -- 响应写入 buf[5..5+resp_len-1]，覆盖原载荷
        -- 同时更新 LEN (buf[4]) 为响应载荷长度
        --=================================================================
        when ST_BUILD_RESP =>
          case cmd_in is

            when CMD_STAT_QUERY =>
              case resp_byte_cnt is
                when 0 =>
                  buf_wr_addr <= std_logic_vector(to_unsigned(5, 8));
                  buf_wr_data <= fault_in;
                  buf_wr_en   <= '1';
                when 1 =>
                  buf_wr_addr <= std_logic_vector(to_unsigned(6, 8));
                  buf_wr_data <= (others => '0');  -- fault 高字节 = 0
                  buf_wr_en   <= '1';
                when 2 =>
                  buf_wr_addr <= std_logic_vector(to_unsigned(7, 8));
                  buf_wr_data <= relay_in;
                  buf_wr_en   <= '1';
                when 3 =>
                  buf_wr_addr <= std_logic_vector(to_unsigned(8, 8));
                  buf_wr_data <= (others => '0');  -- relay 高字节 = 0
                  buf_wr_en   <= '1';
                when 4 =>
                  buf_wr_addr <= std_logic_vector(to_unsigned(9, 8));
                  buf_wr_data <= "0000" & module_present;
                  buf_wr_en   <= '1';
                when 5 =>
                  buf_wr_addr <= std_logic_vector(to_unsigned(10, 8));
                  buf_wr_data <= "000000" & module_count;
                  buf_wr_en   <= '1';
                when 6 =>
                  buf_wr_addr <= std_logic_vector(to_unsigned(11, 8));
                  buf_wr_data <= temp_in(7 downto 0);
                  buf_wr_en   <= '1';
                when 7 =>
                  buf_wr_addr <= std_logic_vector(to_unsigned(12, 8));
                  buf_wr_data <= temp_in(15 downto 8);
                  buf_wr_en   <= '1';
                when 8 =>
                  buf_wr_addr <= std_logic_vector(to_unsigned(13, 8));
                  buf_wr_data <= vcc_in(7 downto 0);
                  buf_wr_en   <= '1';
                when 9 =>
                  buf_wr_addr <= std_logic_vector(to_unsigned(14, 8));
                  buf_wr_data <= vcc_in(15 downto 8);
                  buf_wr_en   <= '1';
                when 10 =>
                  buf_wr_addr <= std_logic_vector(to_unsigned(15, 8));
                  buf_wr_data <= "00000" & slave_status;
                  buf_wr_en   <= '1';
                when 11 =>
                  buf_wr_addr <= std_logic_vector(to_unsigned(16, 8));
                  buf_wr_data <= (others => '0');  -- reserved
                  buf_wr_en   <= '1';
                when 12 =>
                  -- 更新 LEN = 12
                  buf_wr_addr <= std_logic_vector(to_unsigned(4, 8));
                  buf_wr_data <= x"0C";
                  buf_wr_en   <= '1';
                when 13 =>
                  -- 更新 FLAGS: RESP=1
                  buf_wr_addr <= std_logic_vector(to_unsigned(0, 8));
                  buf_wr_data <= flags_in or x"80";  -- set RESP bit
                  buf_wr_en   <= '1';
                when 14 =>
                  -- 交换 DST/SRC
                  buf_wr_addr <= std_logic_vector(to_unsigned(1, 8));
                  buf_wr_data <= src_in;  -- 响应目标 = 原发送方
                  buf_wr_en   <= '1';
                when 15 =>
                  buf_wr_addr <= std_logic_vector(to_unsigned(2, 8));
                  buf_wr_data <= my_address;  -- 响应源 = 本机
                  buf_wr_en   <= '1';
                  frame_modified <= '1';
                  proc_done <= '1';
                  state     <= ST_IDLE;
                when others => null;
              end case;
              if resp_byte_cnt < 15 then
                resp_byte_cnt <= resp_byte_cnt + 1;
              end if;

            when CMD_IDENTIFY =>
              -- 8字节身份响应
              case resp_byte_cnt is
                when 0 =>
                  buf_wr_addr <= std_logic_vector(to_unsigned(5, 8));
                  buf_wr_data <= x"01";  -- device_type[0]: 分控板V2
                  buf_wr_en   <= '1';
                when 1 =>
                  buf_wr_addr <= std_logic_vector(to_unsigned(6, 8));
                  buf_wr_data <= x"00";  -- device_type[1]
                  buf_wr_en   <= '1';
                when 2 =>
                  buf_wr_addr <= std_logic_vector(to_unsigned(7, 8));
                  buf_wr_data <= x"00";  -- fw_version[0]
                  buf_wr_en   <= '1';
                when 3 =>
                  buf_wr_addr <= std_logic_vector(to_unsigned(8, 8));
                  buf_wr_data <= x"01";  -- fw_version[1] = V1.00
                  buf_wr_en   <= '1';
                when 4 =>
                  buf_wr_addr <= std_logic_vector(to_unsigned(9, 8));
                  buf_wr_data <= x"00";  -- serial[0]
                  buf_wr_en   <= '1';
                when 5 =>
                  buf_wr_addr <= std_logic_vector(to_unsigned(10, 8));
                  buf_wr_data <= x"00";  -- serial[1]
                  buf_wr_en   <= '1';
                when 6 =>
                  buf_wr_addr <= std_logic_vector(to_unsigned(11, 8));
                  buf_wr_data <= "000000" & module_count;
                  buf_wr_en   <= '1';
                when 7 =>
                  buf_wr_addr <= std_logic_vector(to_unsigned(12, 8));
                  buf_wr_data <= x"01";  -- hw_revision
                  buf_wr_en   <= '1';
                when 8 =>
                  buf_wr_addr <= std_logic_vector(to_unsigned(4, 8));
                  buf_wr_data <= x"08";  -- LEN=8
                  buf_wr_en   <= '1';
                when 9 =>
                  buf_wr_addr <= std_logic_vector(to_unsigned(0, 8));
                  buf_wr_data <= flags_in or x"80";  -- RESP=1
                  buf_wr_en   <= '1';
                when 10 =>
                  buf_wr_addr <= std_logic_vector(to_unsigned(1, 8));
                  buf_wr_data <= src_in;
                  buf_wr_en   <= '1';
                when 11 =>
                  buf_wr_addr <= std_logic_vector(to_unsigned(2, 8));
                  buf_wr_data <= my_address;
                  buf_wr_en   <= '1';
                  frame_modified <= '1';
                  proc_done <= '1';
                  state     <= ST_IDLE;
                when others => null;
              end case;
              if resp_byte_cnt < 11 then
                resp_byte_cnt <= resp_byte_cnt + 1;
              end if;

            when others =>
              proc_done <= '1';
              state     <= ST_IDLE;

          end case;

        --=================================================================
        -- ST_APPEND_DATA: 向载荷末尾追加数据（广播收集命令）
        -- STAT_COLLECT: 追加4字节 [fault+relay(2B)] [address(1B)] [status(1B)]
        -- TOPO_DISCOVER: 追加5字节 [hop_count(2B)] [address(1B)] [module_count(1B)] [status(1B)]
        --=================================================================
        when ST_APPEND_DATA =>
          if cmd_in = CMD_STAT_COLLECT then
            case collect_idx is
              when 0 =>
                buf_wr_addr <= std_logic_vector(to_unsigned(append_offset, 8));
                buf_wr_data <= fault_in;  -- fault bits
                buf_wr_en   <= '1';
              when 1 =>
                buf_wr_addr <= std_logic_vector(to_unsigned(append_offset + 1, 8));
                buf_wr_data <= relay_in;  -- relay bits
                buf_wr_en   <= '1';
              when 2 =>
                buf_wr_addr <= std_logic_vector(to_unsigned(append_offset + 2, 8));
                buf_wr_data <= my_address;
                buf_wr_en   <= '1';
              when 3 =>
                buf_wr_addr <= std_logic_vector(to_unsigned(append_offset + 3, 8));
                buf_wr_data <= "00000" & slave_status;
                buf_wr_en   <= '1';
              when 4 =>
                -- 更新 LEN = 原LEN + 4
                buf_wr_addr <= std_logic_vector(to_unsigned(4, 8));
                buf_wr_data <= std_logic_vector(to_unsigned(payload_len + 4, 8));
                buf_wr_en   <= '1';
              when 5 =>
                -- 更新 FLAGS: RESP=1
                buf_wr_addr <= std_logic_vector(to_unsigned(0, 8));
                buf_wr_data <= flags_in or x"80";
                buf_wr_en   <= '1';
                frame_modified <= '1';
                proc_done <= '1';
                state     <= ST_IDLE;
              when others => null;
            end case;
            if collect_idx < 5 then
              collect_idx <= collect_idx + 1;
            end if;

          elsif cmd_in = CMD_TOPO_DISCOVER then
            case collect_idx is
              when 0 =>
                buf_wr_addr <= std_logic_vector(to_unsigned(append_offset, 8));
                buf_wr_data <= hop_count(7 downto 0);   -- hop_count LSB
                buf_wr_en   <= '1';
              when 1 =>
                buf_wr_addr <= std_logic_vector(to_unsigned(append_offset + 1, 8));
                buf_wr_data <= hop_count(15 downto 8);  -- hop_count MSB
                buf_wr_en   <= '1';
              when 2 =>
                buf_wr_addr <= std_logic_vector(to_unsigned(append_offset + 2, 8));
                buf_wr_data <= my_address;
                buf_wr_en   <= '1';
              when 3 =>
                buf_wr_addr <= std_logic_vector(to_unsigned(append_offset + 3, 8));
                buf_wr_data <= "000000" & module_count;
                buf_wr_en   <= '1';
              when 4 =>
                buf_wr_addr <= std_logic_vector(to_unsigned(append_offset + 4, 8));
                buf_wr_data <= "00000" & slave_status;
                buf_wr_en   <= '1';
              when 5 =>
                -- 更新 LEN = 原LEN + 5
                buf_wr_addr <= std_logic_vector(to_unsigned(4, 8));
                buf_wr_data <= std_logic_vector(to_unsigned(payload_len + 5, 8));
                buf_wr_en   <= '1';
              when 6 =>
                -- 更新 FLAGS: RESP=1
                buf_wr_addr <= std_logic_vector(to_unsigned(0, 8));
                buf_wr_data <= flags_in or x"80";
                buf_wr_en   <= '1';
                frame_modified <= '1';
                proc_done <= '1';
                state     <= ST_IDLE;
              when others => null;
            end case;
            if collect_idx < 6 then
              collect_idx <= collect_idx + 1;
            end if;
          end if;

        --=================================================================
        -- ST_EXECUTE: 执行控制命令
        --=================================================================
        when ST_EXECUTE =>
          case cmd_in is
            when x"03" =>  -- CMD_RLY_CTRL
              relay_update <= '1';
              proc_done    <= '1';
              state        <= ST_IDLE;
            when x"0D" =>  -- CMD_BROADCAST_RLY
              relay_update <= '1';
              proc_done    <= '1';
              state        <= ST_IDLE;

            when CMD_FAULT_CLEAR =>
              fault_clear <= '1';
              proc_done   <= '1';
              state       <= ST_IDLE;

            when CMD_RESET_SLAVE =>
              soft_reset <= '1';
              proc_done  <= '1';
              state      <= ST_IDLE;

            when CMD_ADDR_ASSIGN =>
              -- 读取 PAYLOAD[0]=new_addr, PAYLOAD[1]=write_flash_flag
              addr_assign <= '1';
              proc_done   <= '1';
              state       <= ST_IDLE;

            when others =>
              proc_done <= '1';
              state     <= ST_IDLE;
          end case;

        --=================================================================
        -- ST_DONE: 处理完成
        --=================================================================
        when ST_DONE =>
          proc_done <= '1';
          state     <= ST_IDLE;

        when others =>
          state <= ST_IDLE;

      end case;
    end if;
  end process p_proc;

end architecture rtl;
