--=============================================================================
-- countor_addr22 - 3位地址计数器（0→4，DDR在q>=4时co=1）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity countor_addr22 is port(clk,en:in std_logic; qout:out std_logic_vector(2 downto 0); co:out std_logic); end entity countor_addr22;
architecture rtl of countor_addr22 is signal q:unsigned(2 downto 0):=(others=>'0');
begin
  process(clk,en)begin if en='0' then q<=(others=>'0'); elsif rising_edge(clk) then if q<4 then q<=q+1; end if; end if; end process;
  process(q,clk,en)begin if en='0' then co<='0'; elsif falling_edge(clk) then if q>=4 then co<='1'; else co<='0'; end if; end if; end process;
  qout<=std_logic_vector(q);
end architecture rtl;
