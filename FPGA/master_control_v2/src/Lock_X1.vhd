--=============================================================================
-- lock_x1 - 1位锁存器（上升沿触发，clr优先于rst）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity lock_x1 is port(clk,rst,clr:in std_logic; q:out std_logic); end entity lock_x1;
architecture rtl of lock_x1 is
begin process(clk)begin if rising_edge(clk) then if clr='1' then q<='0'; elsif rst='1' then q<='1'; end if; end if; end process;
end architecture rtl;
