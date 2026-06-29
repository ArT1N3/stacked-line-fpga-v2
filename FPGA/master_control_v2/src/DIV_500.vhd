--=============================================================================
-- div_500 - 时钟分频器（50%占空比），/500，q>250时clk2='1'
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity div_500 is port(clk:in std_logic; clk2:out std_logic); end entity div_500;
architecture rtl of div_500 is signal q:integer range 0 to 2047:=0;
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if q<499 then q<=q+1; else q<=0; end if;
      if q>250 then clk2<='1'; else clk2<='0'; end if;
    end if;
  end process;
end architecture rtl;
