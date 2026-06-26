--=============================================================================
-- mac_32 - 32级过采样毛刺滤波器（内置10kHz采样时钟）
--=============================================================================
-- 功能：短路故障检测用毛刺滤波器。在内置约10kHz时钟的32个连续边沿上
--   采样故障输入。仅当32个采样全部一致时才改变输出（全'1'或全'0'）。
--
-- 为何32级+慢时钟？ 短路故障信号噪声大，需3.2ms稳定窗口。
--   内部时钟：50MHz/10000→5kHz翻转→10kHz输出，周期=100us
--   滤波行为：全1→O1='1'（故障）、全0→O1='0'（正常）、混合→保持（迟滞）
--   截止频率≈1/(2π×3.2ms)≈50Hz，抑制>300Hz的噪声
--=============================================================================

library ieee;
use ieee.std_logic_1164.all; use ieee.numeric_std.all;

entity mac_32 is port(in1,clk:in std_logic; o1:out std_logic); end entity mac_32;

architecture rtl of mac_32 is
  constant DIV_MAX:integer:=9999;
  signal clk_div_count:integer range 0 to DIV_MAX:=0; signal clk_sample:std_logic:='0';
  signal cnt:unsigned(4 downto 0):=(others=>'0'); signal sum:std_logic_vector(31 downto 0):=(others=>'0');
begin
  -- ~10kHz采样时钟：50MHz/10000，50%占空比
  process(clk)
  begin
    if rising_edge(clk) then
      if clk_div_count<DIV_MAX then clk_div_count<=clk_div_count+1; else clk_div_count<=0; end if;
      if clk_div_count<(DIV_MAX/2) then clk_sample<='0'; else clk_sample<='1'; end if;
    end if;
  end process;
  -- 32级DDR过采样滤波：上升沿评估多数表决，下降沿采样
  process(clk_sample)
  begin
    if rising_edge(clk_sample) then cnt<=cnt+1;
      if sum=x"FFFFFFFF" then o1<='1'; elsif sum=x"00000000" then o1<='0'; end if; -- 否则保持（迟滞）
    end if;
    if falling_edge(clk_sample) then sum(to_integer(cnt))<=in1; end if; -- 存入环形缓冲区
  end process;
end architecture rtl;
