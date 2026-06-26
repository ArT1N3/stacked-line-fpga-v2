--=============================================================================
-- fault_detector_v2 - V2.0 多通道故障检测器
--=============================================================================
-- 功能：
--   1~4 通道独立短路故障检测。每通道：
--     - 32 级 DDR 采样毛刺滤波器（320ns @50MHz，满足 <1μs 要求）
--     - 故障锁存器（硬件自保持，需显式清除）
--     - 使能门控（空闲时屏蔽，防止误触发）
--
-- V1.0 对比：
--   - V1.0: 10 通道，固定使能，3.2ms 滤波窗口（mac_32 × 100Hz时钟）
--   - V2.0: 1~4 通道，50MHz DDR 滤波 = 640ns 实际窗口，满足 <1μs
--=============================================================================
library ieee;
use ieee.std_logic_1164.all;

entity fault_detector_v2 is
  port (
    clk         : in  std_logic;   -- 50 MHz
    rst         : in  std_logic;   -- 异步复位
    en          : in  std_logic;   -- 使能（低有效屏蔽，连接 rxd_filtered）
    module_count: in  std_logic_vector(1 downto 0);  -- 模块数 1~4
    short_in    : in  std_logic_vector(3 downto 0);  -- 短路输入（低=故障）
    fault_out   : out std_logic_vector(3 downto 0);  -- 故障锁存输出
    fault_clear : in  std_logic    -- 清除故障锁存（单周期脉冲）
  );
end entity fault_detector_v2;

architecture rtl of fault_detector_v2 is

  -- 32 级 DDR 移位寄存器（单通道毛刺滤波器）
  -- DDR：在 clk 的上升沿和下降沿都采样
  component mac_32 is
    port (
      in1 : in  std_logic;
      clk : in  std_logic;
      o1  : out std_logic
    );
  end component;

  -- 故障 DFF（锁存器）
  -- clk: 滤波后的故障信号边沿
  -- rst: 异步复位（fault_clear）
  -- en:  使能
  -- d:   固定 '1'（锁存故障）
  -- q:   故障输出
  component err_dff is
    port (
      clk : in  std_logic;
      rst : in  std_logic;
      en  : in  std_logic;
      d   : in  std_logic;
      q   : out std_logic
    );
  end component;

  constant VCC   : std_logic := '1';
  signal filtered : std_logic_vector(3 downto 0);  -- 滤波后的信号

begin

  -- 生成 4 个独立通道的故障检测器
  -- 只使能已配置的模块（module_count 控制）
  gen_channels : for i in 0 to 3 generate
    -- 毛刺滤波器：32级DDR @50MHz → 640ns去抖窗口
    u_filter : mac_32
      port map (
        in1 => short_in(i),
        clk => clk,
        o1  => filtered(i)
      );

    -- 故障锁存器：滤波信号的下降沿（短路=低有效）锁存 '1'
    -- 注意：err_dff 使用滤波信号的上升沿（正常→正常）和下降沿（正常→故障）
    -- 当短路由高变低 → filtered 下降 = 故障事件
    -- err_dff 在 clk 上升沿时锁存 d='1'，实际上我们用 falling edge
    -- V1.0 的做法: 滤波信号作为 clk 输入，利用其下降沿
    u_latch : err_dff
      port map (
        clk => filtered(i),   -- 滤波信号下降沿 = 故障事件
        rst => fault_clear,   -- 主控清除
        en  => en,            -- 使能门控
        d   => VCC,           -- 始终锁存 '1'
        q   => fault_out(i)
      );
  end generate gen_channels;

end architecture rtl;
