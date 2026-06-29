--=============================================================================
-- dly_rw_sel - 读写选择延时器（EN=0清零，~500周期后co=1）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity dly_rw_sel is port(clk,en:in std_logic; co:out std_logic); end entity dly_rw_sel;
architecture rtl of dly_rw_sel is signal q:integer range 0 to 511:=0;
begin
  process(clk)
  begin
    if en='0' then q<=0;co<='0';
    elsif rising_edge(clk) then if q<500 then q<=q+1;co<='0'; else co<='1'; end if; end if;
  end process;
end architecture rtl;
