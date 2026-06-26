--=============================================================================
-- ad_trig - ADC触发脉冲发生器（每100周期输出trig脉冲）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity ad_trig is port(clk_1m:in std_logic; trig:out std_logic); end entity ad_trig;
architecture rtl of ad_trig is signal q:integer range 0 to 510:=0;
begin process(clk_1m)begin if rising_edge(clk_1m) then if q<100 then q<=q+1;trig<='0';else q<=0;trig<='1';end if;end if;end process;end architecture rtl;
