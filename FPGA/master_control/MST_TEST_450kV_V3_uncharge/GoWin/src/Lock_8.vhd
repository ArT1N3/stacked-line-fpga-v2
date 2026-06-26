--=============================================================================
-- lock_8 - 8位数据锁存器（LK上升沿锁存DIN→Q）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity lock_8 is port(din:in std_logic_vector(7 downto 0); lk:in std_logic; q:out std_logic_vector(7 downto 0)); end entity lock_8;
architecture rtl of lock_8 is begin process(lk)begin if rising_edge(lk) then q<=din; end if; end process; end architecture rtl;
