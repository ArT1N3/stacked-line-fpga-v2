--=============================================================================
-- dly_rd_rom - ROM读取延时器（EN=0清零，DDR在q=560时co=1，约600ms）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity dly_rd_rom is port(clk,en:in std_logic; co:out std_logic); end entity dly_rd_rom;
architecture rtl of dly_rd_rom is signal q:integer range 0 to 1023:=0;
begin
  process(clk,en)
  begin
    if en='0' then q<=0;co<='0';
    else
      if rising_edge(clk) then if q<600 then q<=q+1; end if; end if;
      if falling_edge(clk) then if q=560 then co<='1'; else co<='0'; end if; end if;
    end if;
  end process;
end architecture rtl;
