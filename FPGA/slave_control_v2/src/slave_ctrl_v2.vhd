--=============================================================================
-- slave_ctrl_v2 - V2.0 分控板顶层模块 (GW1N-1C, QFN48)
--=============================================================================
-- 功能：
--   光纤环网从机节点。接收光纤串行数据，通过环网转发协议处理命令，
--   控制 1~4 个高压模块的继电器和故障检测。
--
-- 架构：
--   fiber_rx_pin → mac_16(滤波) → rxd_clk(波特率) → com_rx(UART字节)
--       → ring_forward(环网转发+命令处理) → com_tx(UART字节) → fiber_tx_pin
--   short_in_pins → en_err_chk(门控) → fault_detector_v2(滤波+锁存)
--       → ring_forward(状态读取)
--
-- V1.0 迁移：
--   - 移除：err_order, err_ctrl, err_shift_test, mux21a, order_shift
--     (脉宽协议不再需要)
--   - 移除：uart_cmd_deal (由 V2.0 cmd_processor 替代)
--   - 移除：LED_FLICKER, led_driver (简化 LED 输出)
--   - 保留：com_rx, com_tx, rxd_clk, mac_16, en_err_chk, mac_32, err_dff
--   - 新增：ring_forward, fault_detector_v2
--=============================================================================
library ieee;
use ieee.std_logic_1164.all;

entity slave_ctrl_v2 is
  port (
    -- 系统
    clk_50M     : in  std_logic;   -- 50 MHz 晶振
    rst_n       : in  std_logic;   -- 复位（低有效）

    -- 光纤接口
    fiber_rx    : in  std_logic;   -- 光纤接收（来自光模块 RX）
    fiber_tx    : out std_logic;   -- 光纤发送（去往光模块 TX）

    -- 地址配置
    address     : in  std_logic_vector(7 downto 0);  -- 8位拨码地址

    -- 模块接口（4通道）
    short_in    : in  std_logic_vector(3 downto 0);  -- 短路检测（低=故障）
    relay_out   : out std_logic_vector(3 downto 0);  -- 继电器控制（高=闭合）

    -- LED 指示
    fault_led   : out std_logic_vector(3 downto 0);  -- 故障灯（红）
    status_led  : out std_logic    -- 状态灯（绿: 通信正常闪烁）
  );
end entity slave_ctrl_v2;

architecture rtl of slave_ctrl_v2 is

  --=========================================================================
  -- V1.0 复用组件声明
  --=========================================================================
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

  component en_err_chk is
    port (en : in std_logic;
          in1 : in std_logic_vector(10 downto 1);
          out1 : out std_logic_vector(10 downto 1));
  end component;

  --=========================================================================
  -- V2.0 组件声明
  --==========================================================================
  component ring_forward is
    port (
      clk, rst : in std_logic;
      my_address, fault_in, relay_in : in std_logic_vector(7 downto 0);
      module_present : in std_logic_vector(3 downto 0);
      module_count : in std_logic_vector(1 downto 0);
      temp_in, vcc_in : in std_logic_vector(15 downto 0);
      slave_status : in std_logic_vector(2 downto 0);
      rx_byte : in std_logic_vector(7 downto 0);
      rx_lk, rx_busy : in std_logic;
      tx_byte : out std_logic_vector(7 downto 0);
      tx_load : out std_logic;
      tx_busy : in std_logic;
      relay_ctrl, relay_mask : out std_logic_vector(7 downto 0);
      relay_update, fault_clear, soft_reset : out std_logic;
      config_write, config_id : out std_logic_vector(7 downto 0);
      config_data : out std_logic_vector(7 downto 0);
      addr_assign, write_flash : out std_logic;
      new_address : out std_logic_vector(7 downto 0);
      frame_active : out std_logic;
      crc_err_cnt : out std_logic_vector(15 downto 0)
    );
  end component;

  component fault_detector_v2 is
    port (
      clk, rst, en : in std_logic;
      module_count : in std_logic_vector(1 downto 0);
      short_in : in std_logic_vector(3 downto 0);
      fault_out : out std_logic_vector(3 downto 0);
      fault_clear : in std_logic
    );
  end component;

  --=========================================================================
  -- 内部信号
  --=========================================================================
  -- 时钟
  signal clk_uart      : std_logic;  -- ~961.5 kHz UART 时钟

  -- RXD 信号链
  signal rxd_filtered  : std_logic;  -- mac_16 滤波后的 RXD
  signal rx_byte       : std_logic_vector(7 downto 0);
  signal rx_lk         : std_logic;
  signal rx_busy       : std_logic;

  -- TXD 信号链
  signal tx_byte       : std_logic_vector(7 downto 0);
  signal tx_load       : std_logic;
  signal tx_busy       : std_logic;
  signal tx_serial     : std_logic;

  -- 故障检测
  signal short_masked  : std_logic_vector(9 downto 0);  -- en_err_chk 输出（10位）
  signal short_4ch     : std_logic_vector(3 downto 0);  -- 低4位=实际输入
  signal fault_latched : std_logic_vector(3 downto 0);
  signal fault_clear   : std_logic;

  -- ring_forward 互联
  signal relay_ctrl    : std_logic_vector(7 downto 0);
  signal relay_mask    : std_logic_vector(7 downto 0);
  signal relay_update  : std_logic;
  signal frame_active  : std_logic;

  -- 常量
  constant MODULE_CNT  : std_logic_vector(1 downto 0) := "11";  -- 默认4模块
  constant VCC          : std_logic := '1';
  constant GND          : std_logic := '0';

begin

  --=======================================================================
  -- 1. RXD 毛刺滤波（mac_16: 16级DDR @50MHz → 320ns去抖）
  --=======================================================================
  u_rx_filter : mac_16
    port map (in1 => fiber_rx, clk => clk_50M, o1 => rxd_filtered);

  --=======================================================================
  -- 2. 波特率时钟生成（50MHz / 52 ≈ 961.5kHz）
  --=======================================================================
  u_clk_gen : rxd_clk
    port map (clk => clk_50M, clk_out => clk_uart);

  --=======================================================================
  -- 3. UART 字节接收器
  --=======================================================================
  u_com_rx : com_rx
    port map (clk => clk_uart, din => rxd_filtered,
              dat => rx_byte, busy => rx_busy, lk => rx_lk);

  --=======================================================================
  -- 4. 短路输入门控（RXD 空闲高时屏蔽，防止误触发）
  --=======================================================================
  -- en_err_chk 是 10bit 版本，我们只用低 4bit
  u_en_chk : en_err_chk
    port map (
      en   => rxd_filtered,
      in1(10 downto 5) => (others => '1'),  -- 未用通道接高
      in1(4)  => short_in(3),
      in1(3)  => short_in(2),
      in1(2)  => short_in(1),
      in1(1)  => short_in(0),
      out1 => short_masked
    );
  short_4ch <= short_masked(3 downto 0);  -- 提取低4位

  --=======================================================================
  -- 5. 故障检测器（4通道，32级DDR滤波+锁存）
  --=======================================================================
  u_fault_det : fault_detector_v2
    port map (
      clk          => clk_50M,
      rst          => rst_n,
      en           => rxd_filtered,
      module_count => MODULE_CNT,
      short_in     => short_4ch,
      fault_out    => fault_latched,
      fault_clear  => fault_clear
    );

  --=======================================================================
  -- 6. 环网转发控制器（核心）
  --=======================================================================
  u_ring : ring_forward
    port map (
      clk            => clk_50M,
      rst            => rst_n,
      my_address     => address,
      module_count   => MODULE_CNT,
      fault_in(3 downto 0)  => fault_latched,
      fault_in(7 downto 4)  => (others => '0'),
      relay_in(3 downto 0)  => relay_out,
      relay_in(7 downto 4)  => (others => '0'),
      module_present => "1111",  -- 假设4模块全在线
      temp_in        => (others => '0'),  -- 无温度传感器（GW1N-1C不接LM75B）
      vcc_in         => (others => '0'),  -- 无电压监控
      slave_status   => "000",
      rx_byte        => rx_byte,
      rx_lk          => rx_lk,
      rx_busy        => rx_busy,
      tx_byte        => tx_byte,
      tx_load        => tx_load,
      tx_busy        => tx_busy,
      relay_ctrl     => relay_ctrl,
      relay_mask     => relay_mask,
      relay_update   => relay_update,
      fault_clear    => fault_clear,
      soft_reset     => open,
      config_write   => open,
      config_id      => open,
      config_data    => open,
      addr_assign    => open,
      new_address    => open,
      write_flash    => open,
      frame_active   => frame_active,
      crc_err_cnt    => open
    );

  --=======================================================================
  -- 7. UART 字节发送器
  --=======================================================================
  u_com_tx : com_tx
    port map (clk => clk_uart, ld => tx_load,
              dat => tx_byte, dout => tx_serial, busy => tx_busy);

  --=======================================================================
  -- 输出连接
  --=======================================================================
  fiber_tx   <= tx_serial;

  -- 继电器输出（由 relay_update 脉冲锁存新值）
  p_relay : process(clk_50M, rst_n)
  begin
    if rst_n = '0' then
      relay_out <= (others => '0');
    elsif rising_edge(clk_50M) then
      if relay_update = '1' then
        for i in 0 to 3 loop
          if relay_mask(i) = '1' then
            relay_out(i) <= relay_ctrl(i);
          end if;
        end loop;
      end if;
    end if;
  end process p_relay;

  -- 故障 LED（直连故障锁存输出）
  fault_led  <= fault_latched;

  -- 状态 LED（frame_active 闪烁 = 通信正常）
  status_led <= frame_active;

end architecture rtl;
