--=============================================================================
-- clk_div_500 - 时钟分频器（/501，DDR输出），q=200时上升沿
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity clk_div_500 is port(clk_in:in std_logic; div_out:out std_logic); end entity clk_div_500;
architecture rtl of clk_div_500 is signal q1:integer range 0 to 511:=0;
begin
  process(clk_in)
  begin
    if rising_edge(clk_in) then if q1<=500 then q1<=q1+1; else q1<=0; end if; end if;
    if falling_edge(clk_in) then if q1=200 then div_out<='1'; else div_out<='0'; end if; end if;
  end process;
end architecture rtl;
