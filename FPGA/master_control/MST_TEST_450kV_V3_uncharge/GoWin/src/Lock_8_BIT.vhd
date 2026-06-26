--=============================================================================
-- lock_8_bit - 8位数据锁存器（LOCK上升沿锁存DAT_I→DAT_O）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity lock_8_bit is port(lock:in std_logic; dat_i:in std_logic_vector(7 downto 0); dat_o:out std_logic_vector(7 downto 0)); end entity lock_8_bit;
architecture rtl of lock_8_bit is begin process(lock)begin if rising_edge(lock) then dat_o<=dat_i; end if; end process; end architecture rtl;
