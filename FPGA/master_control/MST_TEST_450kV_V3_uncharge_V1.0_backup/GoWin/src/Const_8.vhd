--=============================================================================
-- const_8 - 参数化8位常量发生器（编译时常量）
--=============================================================================
-- 注意：当前工程未使用（不在.gprj中），保留作为工具模块。
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity const_8 is generic(const:integer:=102); port(result:out std_logic_vector(7 downto 0)); end entity const_8;
architecture rtl of const_8 is begin result<=std_logic_vector(to_unsigned(const,8)); end architecture rtl;
