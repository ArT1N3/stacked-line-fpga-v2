--=============================================================================
-- const_3 - 参数化3位常量发生器（编译时常量）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity const_3 is generic(const:integer:=1); port(result:out std_logic_vector(2 downto 0)); end entity const_3;
architecture rtl of const_3 is begin result<=std_logic_vector(to_unsigned(const,3)); end architecture rtl;
