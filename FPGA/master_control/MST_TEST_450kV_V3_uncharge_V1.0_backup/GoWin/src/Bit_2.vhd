--=============================================================================
-- bit_2 - 2位拼接器（D1,D0 → Bit2[1:0]）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity bit_2 is port(d1,d0:in std_logic; bit2:out std_logic_vector(1 downto 0)); end entity bit_2;
architecture rtl of bit_2 is begin bit2(1)<=d1; bit2(0)<=d0; end architecture rtl;
