--=============================================================================
-- level_edg - 边沿检测器（DDR，检测上升沿且电平为高）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity level_edg is port(level_in,clk:in std_logic; edg_out:out std_logic); end entity level_edg;
architecture rtl of level_edg is signal d1,d2,d3:std_logic;
begin
  process(clk)
  begin
    if falling_edge(clk) then d1<=level_in; d3<=d2; end if;
    if rising_edge(clk) then d2<=d1; edg_out<=(d1 xor d3)and level_in; end if;
  end process;
end architecture rtl;
