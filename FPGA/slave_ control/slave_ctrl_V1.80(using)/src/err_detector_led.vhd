--=============================================================================
-- err_detector_led - 故障检测与LED输出（顶层封装）
--=============================================================================
-- 功能：故障检测流水线的顶层封装。
--   包含短路检测（err_detector_block_top）、故障合并（err_charge_or_short）、
--   和LED驱动（err_led）。
--
-- 信号流：
--   short_in[10:1]（外部，低有效：正常=1,故障=0）
--     ↓ err_detector_block_top（10×毛刺滤波+故障锁存）
--     ↓ err_short[10:1]（滤波后的短路故障）
--     +
--   charge_in[10:1]（外部，高有效：正常=0,故障=1）= err_charge[10:1]（直通）
--     ↓ err_charge_or_short（逐通道OR：任一故障则LED亮）
--     ↓ err_total[10:1] → err_led（同步输出寄存器）→ red_led[10:1]
--
-- 极性说明：
--   short_in: 低有效 → OR级中取反
--   charge_in: 高有效 → 直通
--   red_led: 高有效（故障时LED亮）
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity err_detector_led is
  port (
    clk,rst,en_charge:in std_logic;
    short_in,charge_in:in std_logic_vector(10 downto 1);
    charge_out_state,short_out_state,red_led:out std_logic_vector(10 downto 1)
  );
end entity err_detector_led;

architecture rtl of err_detector_led is
  component err_detector_block_top is port(clk,rst,en:in std_logic;short_err_in:in std_logic_vector(10 downto 1);short_err_out:out std_logic_vector(10 downto 1)); end component;
  component err_charge_or_short is port(clk:in std_logic;short_in,charge_in:in std_logic_vector(10 downto 1);err_out:out std_logic_vector(10 downto 1)); end component;
  component err_led is port(rst,clk:in std_logic;err_in:in std_logic_vector(10 downto 1);red_led:out std_logic_vector(10 downto 1)); end component;
  signal err_short,err_charge,err_total:std_logic_vector(10 downto 1);
begin
  err_charge<=charge_in; -- 供电故障直通（比较器电路自带迟滞，无需额外滤波）
  u1:err_detector_block_top port map(clk=>clk,rst=>rst,en=>en_charge,short_err_in=>short_in,short_err_out=>err_short);
  u2:err_charge_or_short port map(clk=>clk,short_in=>err_short,charge_in=>err_charge,err_out=>err_total);
  u3:err_led port map(clk=>clk,rst=>rst,err_in=>err_total,red_led=>red_led);
  charge_out_state<=err_charge; short_out_state<=err_short; -- 输出状态信号供移位寄存器上传
end architecture rtl;
