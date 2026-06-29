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

    -- ADC (MCP3202)
    AD_CS       : out std_logic;
    AD_CLK      : out std_logic;
    AD_DI       : out std_logic;
    AD_DO       : in  std_logic;

    -- I2C (LM75B / EEPROM) — I/O 不足暂用占位
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
    LED2        : out std_logic
  );
end entity master_v2_top;

architecture rtl of master_v2_top is

  --=========================================================================
  -- V2.0 组件声明
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

  --=========================================================================
  -- V1.0 复用组件声明
  --=========================================================================
  component mac_16 is
    port (in1, clk : in std_logic; o1 : out std_logic);
  end component;
  component rxd_clk is
    port (clk, rst : in std_logic; clk_115200 : out std_logic);
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

  -- PC UART 组件（V1.0）
  component rcv_from_pc is
    port (rxd, rst, clk : in std_logic;
          ok : out std_logic;
          aux, cmd, grp : out std_logic_vector(7 downto 0);
          dat1, dat3, dat5, dat7, dat9 : out std_logic_vector(15 downto 0));
  end component;
  component fpga_to_pc is
    port (cmd, grp, aux : in std_logic_vector(7 downto 0);
          dat1, dat3, dat5, dat7, dat9, dat11, dat13 : in std_logic_vector(15 downto 0);
          dat15 : in std_logic_vector(7 downto 0);
          clk, clr_n : in std_logic;
          dat : out std_logic_vector(7 downto 0);
          ld : out std_logic);
  end component;
  component cmd_deal_m is
    port (cmd : in std_logic_vector(7 downto 0);
          en : in std_logic;
          cmd01, cmd02, cmd03, cmd04, cmd05, cmd06, cmd07, cmd08,
          cmd09, cmd0a, cmd0b, cmd0c, cmd0d, cmd0e, cmd0f,
          cmd10, cmd11, cmd12, cmd13 : out std_logic);
  end component;

  -- 充电机通信组件
  component com_rx_charger is
    port (din, clk, rst, rst_o : in std_logic;
          confm : out std_logic;
          adr, rsv, st, st2, tm1, tm2, tm3 : out std_logic_vector(7 downto 0);
          bus_u, set_u, u_n, u_p : out std_logic_vector(15 downto 0));
  end component;
  component mast_to_charger is
    port (cmd : in std_logic_vector(7 downto 0);
          dat_u : in std_logic_vector(15 downto 0);
          ask, clk, clr_n : in std_logic;
          dat : out std_logic_vector(7 downto 0);
          ld : out std_logic);
  end component;

  -- 继电器控制
  component rly_ctr_8 is
    port (cmd_r, rst : in std_logic;
          dat : in std_logic_vector(7 downto 0);
          r1, r2, r3, r4, r5, r6, r7, r8 : out std_logic;
          rly_st : out std_logic_vector(4 downto 0));
  end component;


  --=========================================================================
  -- 光纤环网信号
  --=========================================================================
  signal fiber_rx_filt  : std_logic;
  signal clk_uart       : std_logic;
  signal rx_byte        : std_logic_vector(7 downto 0);
  signal rx_lk, rx_busy : std_logic;
  signal tx_byte        : std_logic_vector(7 downto 0);
  signal tx_load, tx_busy : std_logic;
  signal tx_serial      : std_logic;
  signal ring_ok        : std_logic;

  -- ring_master 命令接口
  signal cmd_req        : std_logic := '0';
  signal cmd_code       : std_logic_vector(7 downto 0) := (others => '0');
  signal cmd_dst        : std_logic_vector(7 downto 0) := (others => '0');
  signal cmd_mod        : std_logic_vector(1 downto 0) := (others => '0');
  signal cmd_is_bcast   : std_logic := '0';
  signal cmd_data       : std_logic_vector(7 downto 0) := (others => '0');
  signal cmd_data_len   : std_logic_vector(7 downto 0) := (others => '0');
  signal master_busy    : std_logic;

  -- ring_master 响应接口
  signal rsp_valid      : std_logic;
  signal rsp_err        : std_logic;
  signal rsp_src        : std_logic_vector(7 downto 0);
  signal rsp_cmd        : std_logic_vector(7 downto 0);
  signal rsp_data       : std_logic_vector(7 downto 0);
  signal rsp_data_len   : std_logic_vector(7 downto 0);

  --=========================================================================
  -- PC UART 信号
  --=========================================================================
  signal pc_cmd_valid   : std_logic;  -- rcv_from_pc.ok → 帧接收完成
  signal pc_cmd         : std_logic_vector(7 downto 0);
  signal pc_aux         : std_logic_vector(7 downto 0);
  signal pc_grp         : std_logic_vector(7 downto 0);
  signal pc_dat1        : std_logic_vector(15 downto 0);
  signal pc_dat3        : std_logic_vector(15 downto 0);
  signal pc_dat5        : std_logic_vector(15 downto 0);
  signal pc_dat7        : std_logic_vector(15 downto 0);
  signal pc_dat9        : std_logic_vector(15 downto 0);

  -- PC TX 信号
  signal pc_tx_dat      : std_logic_vector(7 downto 0);
  signal pc_tx_ld       : std_logic;
  signal pc_tx_busy     : std_logic;
  signal pc_tx_serial   : std_logic;

  -- 命令解码信号
  signal cmd01, cmd02, cmd03, cmd04, cmd05, cmd06, cmd07, cmd08 : std_logic;
  signal cmd09, cmd0a, cmd0b, cmd0c, cmd0d, cmd0e, cmd0f : std_logic;
  signal cmd10, cmd11, cmd12, cmd13 : std_logic;

  -- 充电机通信信号
  signal chg_rx_filt    : std_logic;
  signal chg_confm      : std_logic;
  signal chg_adr        : std_logic_vector(7 downto 0);
  signal chg_rsv        : std_logic_vector(7 downto 0);
  signal chg_st         : std_logic_vector(7 downto 0);
  signal chg_st2        : std_logic_vector(7 downto 0);
  signal chg_tm1        : std_logic_vector(7 downto 0);
  signal chg_tm2        : std_logic_vector(7 downto 0);
  signal chg_tm3        : std_logic_vector(7 downto 0);
  signal chg_bus_u      : std_logic_vector(15 downto 0);
  signal chg_set_u      : std_logic_vector(15 downto 0);
  signal chg_u_n        : std_logic_vector(15 downto 0);
  signal chg_u_p        : std_logic_vector(15 downto 0);
  signal chg_tx_dat     : std_logic_vector(7 downto 0);
  signal chg_tx_ld      : std_logic;
  signal chg_tx_busy    : std_logic;
  signal chg_tx_serial  : std_logic;

  -- 响应数据锁存（FPGA_TO_PC 在 clr_n 下降沿锁存，用 clr_n 脉冲触发）
  signal pc_clr_n       : std_logic := '1';
  signal pc_rsp_cmd     : std_logic_vector(7 downto 0) := (others => '0');
  signal pc_rsp_grp     : std_logic_vector(7 downto 0) := (others => '0');
  signal pc_rsp_aux     : std_logic_vector(7 downto 0) := (others => '0');
  signal pc_rsp_dat1    : std_logic_vector(15 downto 0) := (others => '0');
  signal pc_rsp_dat3    : std_logic_vector(15 downto 0) := (others => '0');

begin

  --=======================================================================
  -- 1. 光纤环网：RXD滤波 → UART RX → ring_master → UART TX → TXD
  --=======================================================================
  u_rx_filter : mac_16
    port map (in1 => fiber_rx, clk => clk_50M, o1 => fiber_rx_filt);

  u_clk_uart : rxd_clk
    port map (clk => clk_50M, rst => '1', clk_115200 => clk_uart);

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
      rsp_valid => rsp_valid, rsp_err => rsp_err,
      rsp_src => rsp_src, rsp_cmd => rsp_cmd,
      rsp_data => rsp_data, rsp_data_len => rsp_data_len,
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
  -- 2. PC UART RX：PC_RXD → rcv_from_pc（内置 comuse UART）→ 命令解析
  --=======================================================================
  u_rcv_pc : rcv_from_pc
    port map (
      rxd  => PC_RXD,
      rst  => '1',     -- 不复位，持续接收
      clk  => clk_50M,
      ok   => pc_cmd_valid,
      aux  => pc_aux,
      cmd  => pc_cmd,
      grp  => pc_grp,
      dat1 => pc_dat1,
      dat3 => pc_dat3,
      dat5 => pc_dat5,
      dat7 => pc_dat7,
      dat9 => pc_dat9
    );

  -- 命令解码：pc_cmd → 19个 one-hot 输出
  u_cmd_deal : cmd_deal_m
    port map (
      cmd   => pc_cmd,
      en    => pc_cmd_valid,
      cmd01 => cmd01, cmd02 => cmd02, cmd03 => cmd03, cmd04 => cmd04,
      cmd05 => cmd05, cmd06 => cmd06, cmd07 => cmd07, cmd08 => cmd08,
      cmd09 => cmd09, cmd0a => cmd0a, cmd0b => cmd0b, cmd0c => cmd0c,
      cmd0d => cmd0d, cmd0e => cmd0e, cmd0f => cmd0f,
      cmd10 => cmd10, cmd11 => cmd11, cmd12 => cmd12, cmd13 => cmd13
    );

  --=======================================================================
  -- 3. PC → ring_master 命令桥接
  --    pc_cmd_valid 脉冲时，将 PC 命令翻译为环网命令
  --    TODO: 完整的命令映射（当前为基本框架）
  --=======================================================================
  p_cmd_bridge : process(clk_50M)
  begin
    if rising_edge(clk_50M) then
      -- 默认：不发起命令
      cmd_req <= '0';

      if pc_cmd_valid = '1' and master_busy = '0' then
        -- PC 发来新命令且环网主控空闲时，发起环网命令
        -- TODO: 根据 pc_cmd / pc_grp 映射 DST / MOD / BCAST
        cmd_req      <= '1';
        cmd_code     <= pc_cmd;           -- 直接传递命令码
        cmd_dst      <= pc_grp;           -- V1.0 Grp 字段 = 目标地址
        cmd_mod      <= pc_aux(1 downto 0); -- AUX 低 2 位 = 模块选择
        cmd_is_bcast <= '0';              -- TODO: 广播命令判断
        cmd_data_len <= x"00";            -- TODO: 从 pc_dat* 提取载荷
      end if;
    end if;
  end process p_cmd_bridge;

  --=======================================================================
  -- 4. ring_master 响应 → PC UART TX
  --    rsp_valid 脉冲时锁存响应数据 → fpga_to_pc → com_tx → PC_TXD
  --=======================================================================
  p_rsp_latch : process(clk_50M)
  begin
    if rising_edge(clk_50M) then
      if rsp_valid = '1' then
        pc_rsp_cmd  <= rsp_cmd;
        pc_rsp_grp  <= rsp_src;           -- 响应源 = 从机地址
        pc_rsp_aux  <= (others => '0');
        pc_rsp_dat1 <= x"00" & rsp_data;   -- 响应数据放入 dat1 低字节
        pc_rsp_dat3 <= (others => '0');
      end if;
    end if;
  end process p_rsp_latch;

  -- clr_n 脉冲生成：rsp_valid 触发一个低脉冲让 fpga_to_pc 锁存数据
  p_clr_pulse : process(clk_50M)
    variable cnt : integer range 0 to 7 := 0;
  begin
    if rising_edge(clk_50M) then
      if rsp_valid = '1' then
        cnt := 0;
        pc_clr_n <= '0';
      elsif cnt < 3 then
        cnt := cnt + 1;
        pc_clr_n <= '0';
      else
        pc_clr_n <= '1';
      end if;
    end if;
  end process p_clr_pulse;

  u_fpga_to_pc : fpga_to_pc
    port map (
      cmd   => pc_rsp_cmd,
      grp   => pc_rsp_grp,
      aux   => pc_rsp_aux,
      dat1  => pc_rsp_dat1,
      dat3  => pc_rsp_dat3,
      dat5  => x"0000",
      dat7  => x"0000",
      dat9  => x"0000",
      dat11 => x"0000",
      dat13 => x"0000",
      dat15 => x"00",
      clk   => clk_50M,
      clr_n => pc_clr_n,
      dat   => pc_tx_dat,
      ld    => pc_tx_ld
    );

  u_com_tx_pc : com_tx
    port map (clk => clk_uart, ld => pc_tx_ld,
              dat => pc_tx_dat, dout => pc_tx_serial, busy => pc_tx_busy);

  PC_TXD <= pc_tx_serial;

  --=======================================================================
  -- 5. 充电机 RS-485：CHG_RX → 滤波 → com_rx_charger，Mast_TO_Charger → com_tx → CHG_TX
  --=======================================================================
  u_chg_filter : mac_16
    port map (in1 => CHG_RX, clk => clk_50M, o1 => chg_rx_filt);

  u_chg_rx : com_rx_charger
    port map (
      din   => chg_rx_filt,
      clk   => clk_uart,   -- UART 采样时钟 (921.6kHz)
      rst   => '1',
      rst_o => '1',
      confm => chg_confm,
      adr   => chg_adr, rsv => chg_rsv, st => chg_st, st2 => chg_st2,
      tm1   => chg_tm1, tm2 => chg_tm2, tm3 => chg_tm3,
      bus_u => chg_bus_u, set_u => chg_set_u, u_n => chg_u_n, u_p => chg_u_p
    );

  u_chg_tx_builder : mast_to_charger
    port map (
      cmd   => chg_st,        -- 充电机命令码（默认=ST查询）
      dat_u => chg_set_u,     -- 电压设定值
      ask   => '0',
      clk   => clk_50M,
      clr_n => chg_confm,     -- 收到充电机帧后触发响应
      dat   => chg_tx_dat,
      ld    => chg_tx_ld
    );

  u_com_tx_chg : com_tx
    port map (clk => clk_uart, ld => chg_tx_ld,
              dat => chg_tx_dat, dout => chg_tx_serial, busy => chg_tx_busy);

  CHG_TX <= chg_tx_serial;
  CHG_EN <= chg_tx_ld;   -- RS-485 TX enable: 发送时拉低使能
  CHG_DI <= chg_tx_serial;

  --=======================================================================
  -- 6. 继电器控制（8路，只用前6路）
  --=======================================================================
  u_rly : rly_ctr_8
    port map (
      cmd_r => cmd03 or cmd0d,  -- RLY_CTRL or BROADCAST_RLY
      rst   => '1',
      dat   => pc_dat1(7 downto 0),
      r1    => CTR_RLY1, r2 => CTR_RLY2, r3 => CTR_RLY3,
      r4    => CTR_RLY4, r5 => CTR_RLY5, r6 => CTR_RLY6,
      r7    => open, r8 => open,
      rly_st => open
    );

  --=======================================================================
  -- 7. 状态指示
  --=======================================================================
  LED1 <= ring_ok;          -- 环网正常=亮
  LED2 <= rsp_valid;        -- 环网响应=闪

  --=======================================================================
  -- 8. ADC (MCP3202)：I/O 不足暂用占位
  --=======================================================================
  AD_CS  <= '1';
  AD_CLK <= '0';
  AD_DI  <= '0';

  --=======================================================================
  -- 9. I2C：温度传感器 + EEPROM（I/O 不足，暂用占位）
  --    TODO: 升级到 GW1N-9C QFN100 或启用双用途引脚后启用
  --=======================================================================
  SCL      <= '1';
  SDA      <= 'Z';
  SCL_LM75 <= '1';
  SDA_LM75 <= 'Z';

  --=======================================================================
  -- 10. 脉冲触发输出（暂用占位，V2.0 升级为高精度可调）
  --=======================================================================
  TRIG_OUT <= '0';

  --=======================================================================
  -- 11. 全部外设已集成
  --=======================================================================

end architecture rtl;
