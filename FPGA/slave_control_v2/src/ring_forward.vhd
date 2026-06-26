--=============================================================================
-- ring_forward - V2.0 光纤环网转发控制器（从机端）
--=============================================================================
-- 功能：
--   协调 fiber_frame_rx、cmd_processor、fiber_frame_tx 三个子模块，
--   实现存储转发环网通信。
--
-- 缓冲架构：
--   fiber_frame_rx 内部维护帧缓冲（256B），提供读写端口。
--   cmd_processor 通过 buf_wr_* 端口修改缓冲。
--   fiber_frame_tx 通过 buf_rd_* 端口读取缓冲发送。
--
-- 状态机：
--   IDLE → 等待 frame_valid
--        → 若地址匹配/广播: cmd_processor 处理
--        → fiber_frame_tx 转发到下一节点
--        → 等待 tx_done
--        → IDLE
--=============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ring_forward is
  port (
    -- 系统
    clk           : in  std_logic;
    rst           : in  std_logic;

    -- 本机配置
    my_address    : in  std_logic_vector(7 downto 0);
    module_count  : in  std_logic_vector(1 downto 0);

    -- 本机状态
    fault_in      : in  std_logic_vector(7 downto 0);
    relay_in      : in  std_logic_vector(7 downto 0);
    module_present: in  std_logic_vector(3 downto 0);
    temp_in       : in  std_logic_vector(15 downto 0);
    vcc_in        : in  std_logic_vector(15 downto 0);
    slave_status  : in  std_logic_vector(2 downto 0);

    -- UART 字节接收（来自 com_rx）
    rx_byte       : in  std_logic_vector(7 downto 0);
    rx_lk         : in  std_logic;
    rx_busy       : in  std_logic;

    -- UART 字节发送（连接 com_tx）
    tx_byte       : out std_logic_vector(7 downto 0);
    tx_load       : out std_logic;
    tx_busy       : in  std_logic;

    -- 控制输出
    relay_ctrl    : out std_logic_vector(7 downto 0);
    relay_mask    : out std_logic_vector(7 downto 0);
    relay_update  : out std_logic;
    fault_clear   : out std_logic;
    soft_reset    : out std_logic;
    config_write  : out std_logic;
    config_id     : out std_logic_vector(7 downto 0);
    config_data   : out std_logic_vector(7 downto 0);
    addr_assign   : out std_logic;
    new_address   : out std_logic_vector(7 downto 0);
    write_flash   : out std_logic;

    -- 状态
    frame_active  : out std_logic;
    crc_err_cnt   : out std_logic_vector(15 downto 0)
  );
end entity ring_forward;

architecture rtl of ring_forward is

  -- fiber_frame_rx 信号
  signal rx_frame_valid : std_logic;
  signal rx_frame_err   : std_logic;
  signal rx_err_code    : std_logic_vector(2 downto 0);
  signal rx_flags       : std_logic_vector(7 downto 0);
  signal rx_dst         : std_logic_vector(7 downto 0);
  signal rx_src         : std_logic_vector(7 downto 0);
  signal rx_cmd         : std_logic_vector(7 downto 0);
  signal rx_len         : std_logic_vector(7 downto 0);
  signal rx_buf_rd_data : std_logic_vector(7 downto 0);

  -- fiber_frame_tx 信号
  signal tx_start    : std_logic;
  signal tx_done     : std_logic;
  signal tx_busy_out : std_logic;
  signal tx_rd_data  : std_logic_vector(7 downto 0);

  -- cmd_processor 信号
  signal proc_start    : std_logic;
  signal proc_done     : std_logic;
  signal proc_matched  : std_logic;
  signal proc_modified : std_logic;
  signal proc_wr_data  : std_logic_vector(7 downto 0);
  signal proc_wr_addr  : std_logic_vector(7 downto 0);
  signal proc_wr_en    : std_logic;
  signal proc_rd_addr  : std_logic_vector(7 downto 0);
  signal proc_rd_data  : std_logic_vector(7 downto 0);

  -- 缓冲读写地址（TX/Proc 共享读端口，通过 MUX 切换）
  signal buf_rd_addr   : std_logic_vector(7 downto 0);
  signal buf_rd_data   : std_logic_vector(7 downto 0);

  -- 状态机
  type fwd_state_t is (
    ST_IDLE,
    ST_CHECK,
    ST_PROC_WAIT,
    ST_FORWARD_PREP,
    ST_FORWARD,
    ST_TX_WAIT,
    ST_DONE
  );
  signal fwd_state   : fwd_state_t;

  -- 地址匹配
  signal is_bcast    : std_logic;
  signal need_process: std_logic;

  -- 跳数
  signal hop_counter : unsigned(15 downto 0);

begin

  --=========================================================================
  -- fiber_frame_rx 实例
  --=========================================================================
  u_rx : entity work.fiber_frame_rx
    port map (
      clk         => clk,
      rst         => rst,
      rx_byte     => rx_byte,
      rx_lk       => rx_lk,
      rx_busy     => rx_busy,
      buf_rd_data => rx_buf_rd_data,
      buf_rd_addr => buf_rd_addr,
      buf_wr_data => proc_wr_data,
      buf_wr_addr => proc_wr_addr,
      buf_wr_en   => proc_wr_en,
      flags_out   => rx_flags,
      dst_out     => rx_dst,
      src_out     => rx_src,
      cmd_out     => rx_cmd,
      frame_len   => rx_len,
      frame_valid => rx_frame_valid,
      frame_err   => rx_frame_err,
      err_code    => rx_err_code,
      crc_err_cnt => crc_err_cnt
    );

  --=========================================================================
  -- fiber_frame_tx 实例
  --=========================================================================
  u_tx : entity work.fiber_frame_tx
    port map (
      clk         => clk,
      rst         => rst,
      buf_rd_data => tx_rd_data,
      buf_rd_addr => buf_rd_addr,
      frame_len   => rx_len,
      tx_start    => tx_start,
      tx_done     => tx_done,
      tx_busy_out => tx_busy_out,
      tx_byte     => tx_byte,
      tx_load     => tx_load,
      uart_busy   => tx_busy
    );

  --=========================================================================
  -- cmd_processor 实例
  --=========================================================================
  u_proc : entity work.cmd_processor
    port map (
      clk           => clk,
      rst           => rst,
      my_address    => my_address,
      module_count  => module_count,
      proc_start    => proc_start,
      flags_in      => rx_flags,
      dst_in        => rx_dst,
      src_in        => rx_src,
      cmd_in        => rx_cmd,
      frame_len_in  => rx_len,
      buf_wr_data   => proc_wr_data,
      buf_wr_addr   => proc_wr_addr,
      buf_wr_en     => proc_wr_en,
      buf_rd_data   => proc_rd_data,
      buf_rd_addr   => proc_rd_addr,
      fault_in      => fault_in,
      relay_in      => relay_in,
      module_present=> module_present,
      temp_in       => temp_in,
      vcc_in        => vcc_in,
      slave_status  => slave_status,
      hop_count     => std_logic_vector(hop_counter),
      relay_ctrl    => relay_ctrl,
      relay_mask    => relay_mask,
      relay_update  => relay_update,
      fault_clear   => fault_clear,
      soft_reset    => soft_reset,
      config_write  => config_write,
      config_id     => config_id,
      config_data   => config_data,
      addr_assign   => addr_assign,
      new_address   => new_address,
      write_flash   => write_flash,
      frame_matched => proc_matched,
      frame_modified=> proc_modified,
      proc_done     => proc_done
    );

  --=========================================================================
  -- 缓冲读端口 MUX: fiber_frame_tx 和 cmd_processor 分时共享读地址
  -- 读数据同时输出到两者，由使用方自行采样
  --=========================================================================
  tx_rd_data   <= rx_buf_rd_data;  -- TX 读来自 RX 缓冲
  proc_rd_data <= rx_buf_rd_data;  -- Proc 读也来自 RX 缓冲

  -- 读地址 MUX: TX 发送时由 fiber_frame_tx 控制，处理时由 cmd_processor 控制
  -- 简化处理：使用 proc_rd_addr 作为默认，TX 期间 fiber_frame_tx 自行驱动
  -- fiber_frame_tx 的 buf_rd_addr 直接驱动 buf_rd_addr（见下方）

  --=========================================================================
  -- 地址匹配
  --=========================================================================
  is_bcast     <= rx_flags(6);
  need_process <= '1' when (is_bcast = '1' or rx_dst = my_address) else '0';

  --=========================================================================
  -- 顶层转发状态机
  --=========================================================================
  p_fwd : process(clk, rst)
  begin
    if rst = '0' then
      fwd_state    <= ST_IDLE;
      tx_start     <= '0';
      proc_start   <= '0';
      hop_counter  <= (others => '0');
      frame_active <= '0';
      buf_rd_addr  <= (others => '0');

    elsif rising_edge(clk) then
      tx_start   <= '0';
      proc_start <= '0';

      case fwd_state is

        when ST_IDLE =>
          frame_active <= '0';
          if rx_frame_valid = '1' then
            frame_active <= '1';
            fwd_state    <= ST_CHECK;
          end if;

        when ST_CHECK =>
          if need_process = '1' then
            if rx_cmd = x"06" then
              hop_counter <= hop_counter + 1;
            end if;
            proc_start <= '1';
            fwd_state  <= ST_PROC_WAIT;
          else
            fwd_state <= ST_FORWARD_PREP;
          end if;

        when ST_PROC_WAIT =>
          if proc_done = '1' then
            fwd_state <= ST_FORWARD_PREP;
          end if;

        when ST_FORWARD_PREP =>
          -- 错误帧置 ERR 标志
          if rx_frame_err = '1' then
            proc_wr_data <= rx_flags or x"20";
            proc_wr_addr <= x"00";
            proc_wr_en   <= '1';
          end if;
          fwd_state <= ST_FORWARD;

        when ST_FORWARD =>
          -- 由 fiber_frame_tx 接管 buf_rd_addr
          tx_start    <= '1';
          fwd_state   <= ST_TX_WAIT;

        when ST_TX_WAIT =>
          if tx_done = '1' then
            fwd_state <= ST_DONE;
          end if;

        when ST_DONE =>
          frame_active <= '0';
          fwd_state    <= ST_IDLE;

        when others =>
          fwd_state <= ST_IDLE;

      end case;
    end if;
  end process p_fwd;

end architecture rtl;
