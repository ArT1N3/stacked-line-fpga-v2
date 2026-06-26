--=============================================================================
-- master_v2_top - V2.0 总控板 FPGA 顶层 (GW1N-UV9QN88C6/I5, QFN88)
--=============================================================================
-- V2.0新增：光纤环网接口 (fiber_rx, fiber_tx) + ring_master
-- V1.0保留：PC UART, 充电机RS-485, I2C, ADC, 继电器, LED
--=============================================================================
library ieee;
use ieee.std_logic_1164.all;

entity master_v2_top is
  port (
    -- 系统
    clk_50M     : in  std_logic;   -- 50MHz 晶振

    -- 上位机 UART（V1.0不变）
    PC_RXD      : in  std_logic;
    PC_TXD      : out std_logic;

    -- 充电机 RS-485（V1.0不变）
    CHG_TX      : out std_logic;
    CHG_RX      : in  std_logic;
    CHG_EN      : out std_logic;
    CHG_RO      : in  std_logic;
    CHG_DI      : out std_logic;

    -- 光纤环网（V2.0新增）
    fiber_rx    : in  std_logic;
    fiber_tx    : out std_logic;

    -- PFC 通信
    PFC_TX      : out std_logic;
    PFC_RX      : in  std_logic;

    -- ADC (MCP3202)
    AD_CS       : out std_logic;
    AD_CLK      : out std_logic;
    AD_DI       : out std_logic;
    AD_DO       : in  std_logic;

    -- I2C (LM75B / EEPROM)
    SCL         : out std_logic;
    SDA         : inout std_logic;
    SCL_LM75    : out std_logic;
    SDA_LM75    : inout std_logic;

    -- 继电器控制
    CTR_RLY1    : out std_logic;
    CTR_RLY2    : out std_logic;
    CTR_RLY3    : out std_logic;
    CTR_RLY4    : out std_logic;
    CTR_RLY5    : out std_logic;
    CTR_RLY6    : out std_logic;

    -- 脉冲触发输出（V1.0保留，V2.0升级为高精度可调）
    TRIG_OUT    : out std_logic;

    -- 测试/调试
    LED1        : out std_logic;
    LED2        : out std_logic;
    LED3        : out std_logic;
    LED4        : out std_logic;

    -- 485 收发控制
    RO_485      : in  std_logic;
    DI_485      : out std_logic
  );
end entity master_v2_top;

architecture rtl of master_v2_top is

  --=========================================================================
  -- ring_master 组件
  --=========================================================================
  component ring_master is
    port (
      clk, rst : in std_logic;
      cmd_req : in std_logic;
      cmd_code, cmd_dst : in std_logic_vector(7 downto 0);
      cmd_mod : in std_logic_vector(1 downto 0);
      cmd_is_bcast : in std_logic;
      cmd_data : in std_logic_vector(7 downto 0);
      cmd_data_len : in std_logic_vector(7 downto 0);
      cmd_wr_en : in std_logic;
      cmd_wr_addr : in std_logic_vector(7 downto 0);
      master_busy : out std_logic;
      rsp_valid, rsp_err : out std_logic;
      rsp_src, rsp_cmd : out std_logic_vector(7 downto 0);
      rsp_data : out std_logic_vector(7 downto 0);
      rsp_data_len : out std_logic_vector(7 downto 0);
      rx_byte : in std_logic_vector(7 downto 0);
      rx_lk, rx_busy : in std_logic;
      tx_byte : out std_logic_vector(7 downto 0);
      tx_load : out std_logic;
      tx_busy : in std_logic;
      timeout_ms : in std_logic_vector(7 downto 0);
      topo_tbl_addr : in std_logic_vector(7 downto 0);
      topo_tbl_data : out std_logic_vector(7 downto 0);
      topo_count : out std_logic_vector(7 downto 0);
      ring_ok : out std_logic;
      crc_err_cnt : out std_logic_vector(15 downto 0)
    );
  end component;

  -- V1.0 复用组件
  component mac_16 is
    port (in1, clk : in std_logic; o1 : out std_logic);
  end component;
  component rxd_clk is
    port (clk : in std_logic; clk_out : out std_logic);
  end component;
  component com_rx is
    port (clk, din : in std_logic;
          dat : out std_logic_vector(7 downto 0);
          busy, lk : out std_logic);
  end component;
  component com_tx is
    port (clk, ld : in std_logic;
          dat : in std_logic_vector(7 downto 0);
          dout, busy : out std_logic);
  end component;

  -- 环网信号
  signal fiber_rx_filt  : std_logic;
  signal clk_uart       : std_logic;
  signal rx_byte        : std_logic_vector(7 downto 0);
  signal rx_lk, rx_busy : std_logic;
  signal tx_byte        : std_logic_vector(7 downto 0);
  signal tx_load, tx_busy : std_logic;
  signal tx_serial      : std_logic;
  signal ring_ok        : std_logic;

  -- 命令接口（从 PC 命令解析模块接入）
  signal cmd_req        : std_logic := '0';
  signal cmd_code       : std_logic_vector(7 downto 0) := (others => '0');
  signal cmd_dst        : std_logic_vector(7 downto 0) := (others => '0');
  signal cmd_mod        : std_logic_vector(1 downto 0) := (others => '0');
  signal cmd_is_bcast   : std_logic := '0';
  signal cmd_data       : std_logic_vector(7 downto 0) := (others => '0');
  signal cmd_data_len   : std_logic_vector(7 downto 0) := (others => '0');
  signal master_busy    : std_logic;

begin

  --=======================================================================
  -- 光纤环网：RXD滤波 → UART RX → ring_master → UART TX → TXD
  --=======================================================================
  u_rx_filter : mac_16
    port map (in1 => fiber_rx, clk => clk_50M, o1 => fiber_rx_filt);

  u_clk_uart : rxd_clk
    port map (clk => clk_50M, clk_out => clk_uart);

  u_com_rx_fiber : com_rx
    port map (clk => clk_uart, din => fiber_rx_filt,
              dat => rx_byte, busy => rx_busy, lk => rx_lk);

  u_ring : ring_master
    port map (
      clk => clk_50M, rst => '1',
      cmd_req => cmd_req, cmd_code => cmd_code, cmd_dst => cmd_dst,
      cmd_mod => cmd_mod, cmd_is_bcast => cmd_is_bcast,
      cmd_data => cmd_data, cmd_data_len => cmd_data_len,
      cmd_wr_en => '0', cmd_wr_addr => x"00",
      master_busy => master_busy,
      rsp_valid => open, rsp_err => open,
      rsp_src => open, rsp_cmd => open,
      rsp_data => open, rsp_data_len => open,
      rx_byte => rx_byte, rx_lk => rx_lk, rx_busy => rx_busy,
      tx_byte => tx_byte, tx_load => tx_load, tx_busy => tx_busy,
      timeout_ms => x"64",
      topo_tbl_addr => x"00", topo_tbl_data => open,
      topo_count => open,
      ring_ok => ring_ok, crc_err_cnt => open
    );

  u_com_tx_fiber : com_tx
    port map (clk => clk_uart, ld => tx_load,
              dat => tx_byte, dout => tx_serial, busy => tx_busy);

  fiber_tx <= tx_serial;

  --=======================================================================
  -- 状态指示
  --=======================================================================
  LED1 <= ring_ok;  -- 环网正常=亮
  LED2 <= '0';
  LED3 <= '0';
  LED4 <= '0';

  --=======================================================================
  -- 以下为 V1.0 保留模块的占位连接
  -- 实际集成时需要接入：
  --   - PC UART (com_rx + com_tx + rcv_from_pc + fpga_to_pc)
  --   - 充电机通信 (com_rx_charger + mast_to_charger)
  --   - 命令处理 (cmd_deal_m → ring_master cmd_* 接口)
  --   - ADC / I2C / 继电器 / 脉冲输出
  --=======================================================================
  PC_TXD   <= '1';   -- 占位
  CHG_TX   <= '1';
  CHG_EN   <= '0';
  CHG_DI   <= '0';
  PFC_TX   <= '1';
  AD_CS    <= '1';
  AD_CLK   <= '0';
  AD_DI    <= '0';
  SCL      <= '1';
  SDA      <= 'Z';
  SCL_LM75 <= '1';
  SDA_LM75 <= 'Z';
  CTR_RLY1 <= '0';
  CTR_RLY2 <= '0';
  CTR_RLY3 <= '0';
  CTR_RLY4 <= '0';
  CTR_RLY5 <= '0';
  CTR_RLY6 <= '0';
  TRIG_OUT <= '0';
  DI_485   <= '0';

end architecture rtl;
