--=============================================================================
-- clock_divider - LED时序时钟发生器
--=============================================================================
-- 功能：从波特率时钟产生两个低频时钟：clk_5ms(200Hz)用于LED闪烁、clk_500ms(2Hz)用于闪烁持续时间。
-- 级联分频：输入~961.5kHz→/576→200Hz→/100→2Hz。替代原有的5ms_clk+clk_500ms两个独立模块。
--=============================================================================

library ieee; use ieee.std_logic_1164.all;

entity clock_divider is port(clk_115200,rst:in std_logic; clk_5ms,clk_500ms:out std_logic); end entity clock_divider;

architecture rtl of clock_divider is
  constant D5:integer:=287; constant D500:integer:=49;
  signal c5:integer range 0 to D5:=0; signal c500:integer range 0 to D500:=0;
  signal clk5,clk500:std_logic:='0';
begin
  -- 第1级：~961.5kHz→200Hz（/576，翻转每288周期）
  process(clk_115200,rst)
  begin
    if rst='0' then c5<=0; clk5<='0';
    elsif rising_edge(clk_115200) then
      if c5=D5 then c5<=0; clk5<=not clk5; else c5<=c5+1; end if;
    end if;
  end process;
  -- 第2级：200Hz→2Hz（/100，翻转每50周期）
  process(clk5,rst)
  begin
    if rst='0' then c500<=0; clk500<='0';
    elsif rising_edge(clk5) then
      if c500=D500 then c500<=0; clk500<=not clk500; else c500<=c500+1; end if;
    end if;
  end process;
  clk_5ms<=clk5; clk_500ms<=clk500;
end architecture rtl;
