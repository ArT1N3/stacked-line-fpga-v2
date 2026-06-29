--=============================================================================
-- countor_clk_flash - Flash时钟计数器（EN=0清零，DDR在q=9时co=1）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity countor_clk_flash is port(clk,en:in std_logic; co:out std_logic); end entity countor_clk_flash;
architecture rtl of countor_clk_flash is signal q:integer range 0 to 15:=0;
begin
  process(clk,en)
  begin
    if en='0' then q<=0;co<='0';
    else
      if rising_edge(clk) then if q<9 then q<=q+1; else q<=0; end if; end if;
      if falling_edge(clk) then if q=9 then co<='1'; else co<='0'; end if; end if;
    end if;
  end process;
end architecture rtl;
