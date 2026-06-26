--=============================================================================
-- mux21a - 2选1选择器（含输出取反，2022.11.13修改）
--=============================================================================
-- sel='0'→y=NOT(a), sel='1'→y=NOT(b)。取反配合外部RS-232驱动器再次翻转得正确极性。
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity mux21a is port(a,b,sel:in std_logic;y:out std_logic); end entity mux21a;
architecture rtl of mux21a is
begin process(sel,a,b)begin if sel='0' then y<=not a; else y<=not b; end if; end process;
end architecture rtl;
