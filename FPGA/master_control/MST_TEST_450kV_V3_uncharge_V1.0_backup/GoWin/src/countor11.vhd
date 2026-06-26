--=============================================================================
-- countor11 - 4位计数器（0→11, 12进制），q=11时co='1'
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity countor11 is port(clk,en:in std_logic; qout:out std_logic_vector(3 downto 0); co:out std_logic); end entity countor11;
architecture rtl of countor11 is signal q:unsigned(3 downto 0):=(others=>'0');
begin
  process(clk,en)begin if en='0' then q<=(others=>'0'); elsif rising_edge(clk) then if q>=11 then q<=(others=>'0'); else q<=q+1; end if; end if; end process;
  qout<=std_logic_vector(q); co<='1' when q=11 else '0';
end architecture rtl;
