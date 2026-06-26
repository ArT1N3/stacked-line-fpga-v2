--=============================================================================
-- trig_100 - 100周期触发脉冲发生器（每100周期输出一个trig脉冲）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity trig_100 is port(clk:in std_logic; trig:out std_logic); end entity trig_100;
architecture rtl of trig_100 is signal q:integer range 0 to 120:=0;
begin
  process(clk)begin if rising_edge(clk) then if q<100 then q<=q+1;trig<='0';else q<=0;trig<='1';end if;end if;end process;
end architecture rtl;
