--=============================================================================
-- trig_aux - 辅助触发脉冲发生器（每22周期输出trig脉冲，~60us周期）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity trig_aux is port(clk:in std_logic; trig:out std_logic); end entity trig_aux;
architecture rtl of trig_aux is signal q:integer range 0 to 120:=0;
begin process(clk)begin if rising_edge(clk) then if q<21 then q<=q+1;trig<='0';else q<=0;trig<='1';end if;end if;end process;end architecture rtl;
