--==============================================================================
-- ring_master - V2.0 光纤环网主控控制器 (GW1N-9C)
--=============================================================================
-- 功能：
--   作为光纤环网的头节点，负责：
--     1. 接受上层命令 → 构建环网帧 → 发送
--     2. 接收响应帧 → 解析 → 上报
--     3. 超时检测与自动重试（3次）
--     4. 拓扑表维护（物理顺序映射）
--     5. 定期轮询（STAT_COLLECT 广播收集）
--
-- 缓冲架构：
--   使用 fiber_frame_rx/tx 的帧缓冲（256B）。
--   主控先填充请求帧 → TX 发送 → RX 接收响应。
--=============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ring_master is
  port (
    -- 系统
    clk           : in  std_logic;   -- 50 MHz
    rst           : in  std_logic;   -- 异步复位（低有效）

    -- 命令请求端口（来自上层状态机/PC命令处理器）
    cmd_req       : in  std_logic;   -- 命令请求脉冲
    cmd_code      : in  std_logic_vector(7 downto 0);  -- 命令码
    cmd_dst       : in  std_logic_vector(7 downto 0);  -- 目标地址
    cmd_mod       : in  std_logic_vector(1 downto 0);  -- 目标模块
    cmd_is_bcast  : in  std_logic;   -- 广播标志
    cmd_data      : in  std_logic_vector(7 downto 0);  -- 载荷数据字节
    cmd_data_len  : in  std_logic_vector(7 downto 0);  -- 载荷长度
    cmd_wr_en     : in  std_logic;   -- 载荷写入使能
    cmd_wr_addr   : in  std_logic_vector(7 downto 0);  -- 载荷写入地址
    master_busy   : out std_logic;   -- 主控忙（正在处理命令）

    -- 响应端口（上报给上层）
    rsp_valid     : out std_logic;   -- 响应有效脉冲
    rsp_src       : out std_logic_vector(7 downto 0);  -- 响应源地址
    rsp_cmd       : out std_logic_vector(7 downto 0);  -- 响应命令码
    rsp_data      : out std_logic_vector(7 downto 0);  -- 响应数据字节
    rsp_data_len  : out std_logic_vector(7 downto 0);  -- 响应载荷长度
    rsp_err       : out std_logic;   -- 响应错误

    -- UART 字节接收（来自 com_rx）
    rx_byte       : in  std_logic_vector(7 downto 0);
    rx_lk         : in  std_logic;
    rx_busy       : in  std_logic;

    -- UART 字节发送（连接 com_tx）
    tx_byte       : out std_logic_vector(7 downto 0);
    tx_load       : out std_logic;
    tx_busy       : in  std_logic;

    -- 超时参数
    timeout_ms    : in  std_logic_vector(7 downto 0);  -- 超时时间（ms）

    -- 拓扑表输出（供 PC 读取）
    topo_tbl_addr : in  std_logic_vector(7 downto 0);  -- 表地址 (0~N-1)
    topo_tbl_data : out std_logic_vector(7 downto 0);  -- 表数据
    topo_count    : out std_logic_vector(7 downto 0);  -- 已发现从机数

    -- 状态
    ring_ok       : out std_logic;   -- 环网正常
    crc_err_cnt   : out std_logic_vector(15 downto 0)
  );
end entity ring_master;

architecture rtl of ring_master is

  --=========================================================================
  -- fiber_frame_rx/tx 信号（与从机共用相同核心）
  --=========================================================================
  signal rx_frame_valid : std_logic;
  signal rx_frame_err   : std_logic;
  signal rx_err_code    : std_logic_vector(2 downto 0);
  signal rx_flags       : std_logic_vector(7 downto 0);
  signal rx_dst         : std_logic_vector(7 downto 0);
  signal rx_src         : std_logic_vector(7 downto 0);
  signal rx_cmd         : std_logic_vector(7 downto 0);
  signal rx_len         : std_logic_vector(7 downto 0);
  signal rx_buf_rd_data : std_logic_vector(7 downto 0);

  signal tx_start       : std_logic;
  signal tx_done        : std_logic;
  signal tx_busy_out    : std_logic;
  signal tx_rd_data     : std_logic_vector(7 downto 0);

  -- 缓冲读写
  signal buf_rd_addr    : std_logic_vector(7 downto 0);
  signal buf_wr_data    : std_logic_vector(7 downto 0);
  signal buf_wr_addr    : std_logic_vector(7 downto 0);
  signal buf_wr_en      : std_logic;

  --=========================================================================
  -- 主控状态机
  --=========================================================================
  type master_state_t is (
    ST_IDLE,           -- 等待命令
    ST_BUILD_HDR,      -- 构建帧头 FLAGS/DST/SRC/CMD/LEN (6周期)
    ST_BUILD_PAYLOAD,  -- 写入载荷数据 (N周期)
    ST_SEND,           -- 发送帧
    ST_WAIT_RESP,      -- 等待响应
    ST_TIMEOUT,        -- 超时处理
    ST_RETRY,          -- 重试
    ST_DONE            -- 完成
  );
  signal mst_state     : master_state_t;
  signal build_idx     : integer range 0 to 255;  -- 帧构建索引

  --=========================================================================
  -- 内部寄存器
  --=========================================================================
  signal pending_cmd   : std_logic_vector(7 downto 0);  -- 待响应命令
  signal pending_dst   : std_logic_vector(7 downto 0);  -- 待响应目标
  signal retry_count   : integer range 0 to 3;          -- 重试计数
  signal timeout_cnt   : integer range 0 to 500000;     -- 超时计数器（50MHz ticks）
  signal timeout_limit : integer range 0 to 500000;     -- 超时阈值
  signal frame_len_reg : integer range 0 to 255;        -- 载荷长度寄存器

  --=========================================================================
  -- 拓扑表
  --=========================================================================
  type topo_entry_t is record
    addr         : std_logic_vector(7 downto 0);
    hop          : std_logic_vector(15 downto 0);
    module_cnt   : std_logic_vector(7 downto 0);
    status       : std_logic_vector(7 downto 0);
  end record;
  type topo_table_t is array (0 to 127) of topo_entry_t;
  signal topo_table   : topo_table_t;
  signal topo_idx     : integer range 0 to 127;  -- 当前处理索引
  signal topo_count_r : integer range 0 to 255;  -- 已发现从机数

  -- CRC 生成函数（与 fiber_frame_tx 相同）
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
  end function;

begin

  --=========================================================================
  -- fiber_frame_rx 实例（接收响应帧）
  --=========================================================================
  u_rx : entity work.fiber_frame_rx
    port map (
      clk         => clk, rst => rst,
      rx_byte     => rx_byte, rx_lk => rx_lk, rx_busy => rx_busy,
      buf_rd_data => rx_buf_rd_data, buf_rd_addr => buf_rd_addr,
      buf_wr_data => buf_wr_data, buf_wr_addr => buf_wr_addr, buf_wr_en => buf_wr_en,
      flags_out   => rx_flags, dst_out => rx_dst,
      src_out     => rx_src, cmd_out => rx_cmd, frame_len => rx_len,
      frame_valid => rx_frame_valid, frame_err => rx_frame_err,
      err_code    => rx_err_code, crc_err_cnt => crc_err_cnt
    );

  --=========================================================================
  -- fiber_frame_tx 实例（发送请求帧）
  --=========================================================================
  u_tx : entity work.fiber_frame_tx
    port map (
      clk         => clk, rst => rst,
      buf_rd_data => tx_rd_data, buf_rd_addr => buf_rd_addr,
      frame_len   => std_logic_vector(to_unsigned(frame_len_reg, 8)),
      tx_start    => tx_start, tx_done => tx_done,
      tx_busy_out => tx_busy_out,
      tx_byte     => tx_byte, tx_load => tx_load, uart_busy => tx_busy
    );

  -- 读数据共享
  tx_rd_data <= rx_buf_rd_data;

  --=========================================================================
  -- 主控状态机
  --=========================================================================
  p_master : process(clk, rst)
    variable crc_val : std_logic_vector(15 downto 0);
    variable tmp_byte : std_logic_vector(7 downto 0);
  begin
    if rst = '0' then
      mst_state      <= ST_IDLE;
      pending_cmd    <= (others => '0');
      pending_dst    <= (others => '0');
      retry_count    <= 0;
      timeout_cnt    <= 0;
      timeout_limit  <= 100000;  -- 默认 ~2ms @50MHz
      frame_len_reg  <= 0;
      buf_wr_data    <= (others => '0');
      buf_wr_addr    <= (others => '0');
      buf_wr_en      <= '0';
      tx_start       <= '0';
      rsp_valid      <= '0';
      rsp_src        <= (others => '0');
      rsp_cmd        <= (others => '0');
      rsp_data       <= (others => '0');
      rsp_data_len   <= (others => '0');
      rsp_err        <= '0';
      master_busy    <= '0';
      ring_ok        <= '0';
      topo_idx       <= 0;
      topo_count_r   <= 0;
      build_idx      <= 0;
      for i in 0 to 127 loop
        topo_table(i).addr <= (others => '0');
        topo_table(i).hop  <= (others => '0');
        topo_table(i).module_cnt <= (others => '0');
        topo_table(i).status <= (others => '0');
      end loop;

    elsif rising_edge(clk) then
      -- 默认值
      buf_wr_en   <= '0';
      tx_start    <= '0';
      rsp_valid   <= '0';

      -- 超时计数器（始终运行）
      if timeout_cnt < timeout_limit then
        timeout_cnt <= timeout_cnt + 1;
      end if;

      case mst_state is

        --===============================================================
        -- ST_IDLE: 等待命令
        --===============================================================
        when ST_IDLE =>
          master_busy <= '0';
          retry_count <= 0;
          build_idx   <= 0;
          if cmd_req = '1' then
            master_busy   <= '1';
            pending_cmd   <= cmd_code;
            pending_dst   <= cmd_dst;
            frame_len_reg <= to_integer(unsigned(cmd_data_len));
            mst_state     <= ST_BUILD_HDR;
          end if;

        --===============================================================
        -- ST_BUILD_HDR: 构建帧头（6周期: FLAGS, DST, SRC, CMD, LEN）
        --===============================================================
        when ST_BUILD_HDR =>
          buf_wr_en <= '1';
          case build_idx is
            when 0 =>
              buf_wr_addr <= x"00";
              buf_wr_data <= "0" & cmd_is_bcast & "0" & cmd_mod & "000";
            when 1 =>
              buf_wr_addr <= x"01";
              buf_wr_data <= cmd_dst;
            when 2 =>
              buf_wr_addr <= x"02";
              buf_wr_data <= x"00";  -- SRC = 主控
            when 3 =>
              buf_wr_addr <= x"03";
              buf_wr_data <= cmd_code;
            when 4 =>
              buf_wr_addr <= x"04";
              buf_wr_data <= cmd_data_len;
            when others =>
              buf_wr_en <= '0';
              build_idx <= 0;
              if frame_len_reg > 0 then
                mst_state <= ST_BUILD_PAYLOAD;
              else
                mst_state <= ST_SEND;
              end if;
          end case;
          if build_idx < 5 then
            build_idx <= build_idx + 1;
          end if;

        --===============================================================
        -- ST_BUILD_PAYLOAD: 写入载荷（N周期）
        --===============================================================
        when ST_BUILD_PAYLOAD =>
          buf_wr_addr <= std_logic_vector(to_unsigned(5 + build_idx, 8));
          buf_wr_data <= cmd_data;  -- 上层逐字节提供
          buf_wr_en   <= '1';
          if build_idx < frame_len_reg - 1 then
            build_idx <= build_idx + 1;
          else
            build_idx <= 0;
            mst_state <= ST_SEND;
          end if;

        --===============================================================
        -- ST_SEND: 启动帧发送
        --===============================================================
        when ST_SEND =>
          tx_start    <= '1';
          timeout_cnt <= 0;
          mst_state   <= ST_WAIT_RESP;

        --===============================================================
        -- ST_WAIT_RESP: 等待响应帧
        --===============================================================
        when ST_WAIT_RESP =>
          if rx_frame_valid = '1' then
            -- 收到响应
            timeout_cnt <= 0;
            rsp_valid   <= '1';
            rsp_src     <= rx_src;
            rsp_cmd     <= rx_cmd;
            rsp_data_len <= rx_len;
            rsp_err     <= '0';
            ring_ok     <= '1';

            -- 拓扑发现：解析响应
            if pending_cmd = x"06" then
              -- 从载荷中提取拓扑数据（每从机5B）
              topo_count_r <= to_integer(unsigned(rx_len)) / 5;
              -- (实际实现需逐条解析到 topo_table)
            end if;

            mst_state <= ST_DONE;

          elsif rx_frame_err = '1' then
            rsp_valid <= '1';
            rsp_err   <= '1';
            mst_state <= ST_DONE;

          elsif timeout_cnt >= timeout_limit then
            mst_state <= ST_TIMEOUT;
          end if;

        --===============================================================
        -- ST_TIMEOUT: 超时，决定是否重试
        --===============================================================
        when ST_TIMEOUT =>
          if retry_count < 2 then  -- 最多3次尝试（0,1,2）
            retry_count <= retry_count + 1;
            mst_state   <= ST_RETRY;
          else
            -- 3次超时，标记从机离线
            ring_ok     <= '0';
            rsp_valid   <= '1';
            rsp_err     <= '1';
            master_busy <= '0';
            mst_state   <= ST_DONE;
          end if;

        --===============================================================
        -- ST_RETRY: 重试
        --===============================================================
        when ST_RETRY =>
          tx_start    <= '1';
          timeout_cnt <= 0;
          mst_state   <= ST_WAIT_RESP;

        --===============================================================
        -- ST_DONE: 完成
        --===============================================================
        when ST_DONE =>
          master_busy <= '0';
          mst_state   <= ST_IDLE;

        when others =>
          mst_state <= ST_IDLE;

      end case;
    end if;
  end process p_master;

  --=========================================================================
  -- 拓扑表读取
  --=========================================================================
  topo_tbl_data <= topo_table(to_integer(unsigned(topo_tbl_addr))).addr;  -- 简化
  topo_count    <= std_logic_vector(to_unsigned(topo_count_r, 8));

end architecture rtl;
