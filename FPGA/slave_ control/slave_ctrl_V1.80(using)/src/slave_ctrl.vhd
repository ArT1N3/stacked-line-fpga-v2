--=============================================================================
-- slave_ctrl - 分控板顶层控制模块
--=============================================================================
-- 功能：
--   10通道故障检测、LED指示、通过RS-232与主控进行双协议通信。
--
-- 架构概述：
--   设计中有两条独立的通信路径，共享同一个RXD引脚：
--
--   路径1 - 脉宽协议 (order_shift + err_detector_led)：
--     主控在RXD线上发送低电平脉宽调制指令。
--     不同宽度的脉冲编码不同的指令：
--       180-220 us → 查询在线状态（供电故障）
--       380-420 us → 查询使能状态
--       480-520 us → 触发充电（过流检测）
--     分控收到指令后在TXD上移位输出状态数据作为响应。
--     此路径使用系统时钟速度（50 MHz）。
--
--   路径2 - UART协议 (com_rxd + uart_cmd_deal)：
--     主控以约115200波特率发送标准UART帧。
--     每帧包含8个16位数据字，可配置80+个通道。
--     此路径使用rxd_clk产生的约961.5 kHz时钟进行UART计时。
--
-- LED行为：
--   复位后，LED显示约2秒的地址闪烁模式（上电指示）。
--   然后切换到显示实时故障状态：
--     LED亮 = 检测到故障（短路 或 供电故障）
--
-- 时钟域：
--   clk（50MHz系统）  → 主逻辑、状态机、故障检测
--   clk_115200（~961.5k）→ UART字节接收时序
--   clk_5ms（200Hz）     → LED闪烁模式时序
--   clk_500ms（2Hz）     → LED闪烁持续时间时序
--
-- 复位：
--   rst = '0' → 异步复位（低有效）
--   rst_err    → 故障检测器复位（由UART指令控制）
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity slave_ctrl is
  port (
    clk        : in  std_logic;    -- 50MHz系统时钟
    rst        : in  std_logic;    -- 异步复位（低有效）
    rxd        : in  std_logic;    -- RS-232接收（脉宽+UART共享）
    address    : in  std_logic_vector(3 downto 0);  -- 板卡地址（1-9），用于多节点总线
    charge_in  : in  std_logic_vector(10 downto 1); -- 供电故障输入（高有效）
    short_in   : in  std_logic_vector(10 downto 1); -- 短路故障输入（低有效）
    en_work    : out std_logic_vector(10 downto 1); -- 通道使能输出
    en_trig    : out std_logic_vector(10 downto 1); -- 触发输出（使能取反）
    red_led    : out std_logic_vector(10 downto 1); -- 故障LED输出
    txd        : out std_logic     -- RS-232发送（状态上传）
  );
end entity slave_ctrl;

architecture rtl of slave_ctrl is

  -- ========================================================================
  -- 子模块声明
  -- ========================================================================

  component err_detector_led
    port (
      clk               : in  std_logic;
      rst               : in  std_logic;
      en_charge         : in  std_logic;
      short_in          : in  std_logic_vector(10 downto 1);
      charge_in         : in  std_logic_vector(10 downto 1);
      charge_out_state  : out std_logic_vector(10 downto 1);
      short_out_state   : out std_logic_vector(10 downto 1);
      red_led           : out std_logic_vector(10 downto 1)
    );
  end component;

  component order_shift
    port (
      clk         : in  std_logic;
      rst         : in  std_logic;
      rs_232      : in  std_logic;
      address     : in  std_logic_vector(3 downto 0);
      err_total   : in  std_logic_vector(10 downto 1);
      err_charge  : in  std_logic_vector(10 downto 1);
      en_charge   : out std_logic;
      en_state    : in  std_logic_vector(10 downto 1);
      txd_out     : out std_logic
    );
  end component;

  component com_rxd
    port (
      din    : in  std_logic;
      clk    : in  std_logic;
      rst    : in  std_logic;
      confm  : out std_logic;
      cmd    : out std_logic_vector(7 downto 0);
      dat1   : out std_logic_vector(15 downto 0);
      dat3   : out std_logic_vector(15 downto 0);
      dat5   : out std_logic_vector(15 downto 0);
      dat7   : out std_logic_vector(15 downto 0);
      dat9   : out std_logic_vector(15 downto 0);
      dat11  : out std_logic_vector(15 downto 0);
      dat13  : out std_logic_vector(15 downto 0);
      dat15  : out std_logic_vector(15 downto 0)
    );
  end component;

  component uart_cmd_deal
    port (
      clk      : in  std_logic;
      rst      : in  std_logic;
      confm    : in  std_logic;
      cmd      : in  std_logic_vector(7 downto 0);
      data1    : in  std_logic_vector(15 downto 0);
      data3    : in  std_logic_vector(15 downto 0);
      data5    : in  std_logic_vector(15 downto 0);
      data7    : in  std_logic_vector(15 downto 0);
      data9    : in  std_logic_vector(15 downto 0);
      data11   : in  std_logic_vector(15 downto 0);
      data13   : in  std_logic_vector(15 downto 0);
      data15   : in  std_logic_vector(15 downto 0);
      address  : in  std_logic_vector(3 downto 0);
      rst_err  : out std_logic;
      en_work  : out std_logic_vector(10 downto 1);
      en_trig  : out std_logic_vector(10 downto 1);
      en_state : out std_logic_vector(10 downto 1)
    );
  end component;

  component rxd_clk
    port (
      clk        : in  std_logic;
      rst        : in  std_logic;
      clk_115200 : out std_logic
    );
  end component;

  component clock_divider
    port (
      clk_115200 : in  std_logic;
      rst        : in  std_logic;
      clk_5ms    : out std_logic;
      clk_500ms  : out std_logic
    );
  end component;

  component led_flicker
    port (
      clk_5ms      : in  std_logic;
      clk_500ms    : in  std_logic;
      addr_in      : in  std_logic_vector(3 downto 0);
      flicker_out  : out std_logic_vector(10 downto 1);
      err_en       : out std_logic
    );
  end component;

  component led_driver
    port (
      red_led_in   : in  std_logic_vector(10 downto 1);
      flicker_out  : in  std_logic_vector(10 downto 1);
      err_en       : in  std_logic;
      red_led_out  : out std_logic_vector(10 downto 1)
    );
  end component;

  -- ========================================================================
  -- 内部互连信号
  -- ========================================================================
  signal rst_err       : std_logic;    -- 故障检测器复位（来自UART指令）
  signal en_charge     : std_logic;    -- 充电检测使能（来自脉宽协议）
  signal red_led_total : std_logic_vector(10 downto 1); -- 原始故障状态
  signal red_led_out   : std_logic_vector(10 downto 1); -- 最终LED输出
  signal err_charge    : std_logic_vector(10 downto 1); -- 每通道供电故障
  signal err_short     : std_logic_vector(10 downto 1); -- 每通道短路故障
  signal en_state      : std_logic_vector(10 downto 1); -- 通道使能状态
  signal confm         : std_logic;    -- UART帧确认脉冲
  signal cmd_byte      : std_logic_vector(7 downto 0);  -- UART指令字节
  signal data1, data3, data5, data7   : std_logic_vector(15 downto 0);
  signal data9, data11, data13, data15 : std_logic_vector(15 downto 0);
  signal clk_115200    : std_logic;    -- 约961.5kHz UART波特率时钟
  signal clk_5ms       : std_logic;    -- 200Hz LED闪烁时钟
  signal clk_500ms     : std_logic;    -- 2Hz LED闪烁持续时间时钟
  signal err_en        : std_logic;    -- '0'=闪烁模式, '1'=故障显示模式
  signal flicker_out   : std_logic_vector(10 downto 1); -- 闪烁模式输出

begin

  -- LED总线直接输出
  red_led <= red_led_out;

  -- ========================================================================
  -- u1: 故障检测与LED状态
  -- 接收10路外部charge_in和short_in信号。
  -- 输出滤波后的故障状态和直通的状态信号。
  -- 由rst_err（UART指令）复位，主控可通过此信号清除故障锁存。
  -- ========================================================================
  u1: err_detector_led
    port map (
      clk              => clk,
      rst              => rst_err,
      en_charge        => en_charge,
      short_in         => short_in,
      charge_in        => charge_in,
      charge_out_state => err_charge,
      short_out_state  => err_short,
      red_led          => red_led_total
    );

  -- ========================================================================
  -- u2: 脉宽指令检测与状态上传
  -- 监控RXD上的低电平脉宽指令。
  -- 控制en_charge（充电检测窗口），并使用定时多节点协议
  -- 在TXD上移位输出故障/使能状态。
  -- ========================================================================
  u2: order_shift
    port map (
      clk        => clk,
      rst        => rst,
      rs_232     => rxd,
      address    => address,
      err_total  => red_led_total,
      err_charge => err_charge,
      en_charge  => en_charge,
      en_state   => en_state,
      txd_out    => txd
    );

  -- ========================================================================
  -- u3: UART多帧接收器
  -- 从RXD接收UART字节流，组装20字节帧，校验（HEAD=0xEB, END=0xAA），
  -- 输出解析后的CMD和数据字。
  -- 使用clk_115200进行UART时序控制（约921.6kHz，8倍过采样）。
  -- ========================================================================
  u3: com_rxd
    port map (
      din   => rxd,
      clk   => clk_115200,
      rst   => rst,
      confm => confm,
      cmd   => cmd_byte,
      dat1  => data1,
      dat3  => data3,
      dat5  => data5,
      dat7  => data7,
      dat9  => data9,
      dat11 => data11,
      dat13 => data13,
      dat15 => data15
    );

  -- ========================================================================
  -- u4: UART指令解析执行
  -- CMD x"01": 复位rst_err（清除故障锁存）
  -- CMD x"55": 锁存使能配置数据
  -- 根据板卡地址将128位数据中的10位片段分配到
  -- en_work/en_trig/en_state输出（多节点寻址）。
  -- ========================================================================
  u4: uart_cmd_deal
    port map (
      clk      => clk,
      rst      => rst,
      confm    => confm,
      cmd      => cmd_byte,
      data1    => data1,
      data3    => data3,
      data5    => data5,
      data7    => data7,
      data9    => data9,
      data11   => data11,
      data13   => data13,
      data15   => data15,
      address  => address,
      rst_err  => rst_err,
      en_work  => en_work,
      en_trig  => en_trig,
      en_state => en_state
    );

  -- ========================================================================
  -- u5: 波特率时钟发生器
  -- 50MHz / 52 ≈ 961.5kHz，用于115200波特率UART的8倍过采样。
  -- 约4%的时序误差在UART容限内（通常容忍<5%）。
  -- ========================================================================
  u5: rxd_clk
    port map (
      clk        => clk,
      rst        => rst,
      clk_115200 => clk_115200
    );

  -- ========================================================================
  -- u6: LED闪烁模式发生器
  -- 复位后输出约2秒基于地址的闪烁模式。
  -- err_en在闪烁阶段保持'0'，之后变为'1'。
  -- ========================================================================
  u6: led_flicker
    port map (
      clk_5ms     => clk_5ms,
      clk_500ms   => clk_500ms,
      addr_in     => address,
      flicker_out => flicker_out,
      err_en      => err_en
    );

  -- ========================================================================
  -- u7: LED时钟分频器
  -- 将961.5kHz波特率时钟分频 → 200Hz (5ms) → 2Hz (500ms)。
  -- ========================================================================
  u7: clock_divider
    port map (
      clk_115200 => clk_115200,
      rst        => rst,
      clk_5ms    => clk_5ms,
      clk_500ms  => clk_500ms
    );

  -- ========================================================================
  -- u8: LED输出选择器
  -- err_en='0' → flicker_out（上电闪烁模式）
  -- err_en='1' → red_led_total（实时故障状态）
  -- ========================================================================
  u8: led_driver
    port map (
      red_led_in  => red_led_total,
      flicker_out => flicker_out,
      err_en      => err_en,
      red_led_out => red_led_out
    );

end architecture rtl;
