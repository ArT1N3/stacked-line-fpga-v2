 --=============================================================================
-- bit_byte - 8位拼接器（D7..D0 → Byte[7:0]）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity bit_byte is port(d7,d6,d5,d4,d3,d2,d1,d0:in std_logic; byte:out std_logic_vector(7 downto 0)); end entity bit_byte;
architecture rtl of bit_byte is begin byte<=d7&d6&d5&d4&d3&d2&d1&d0; end architecture rtl;
