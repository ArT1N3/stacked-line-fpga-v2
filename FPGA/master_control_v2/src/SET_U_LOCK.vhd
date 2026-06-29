--=============================================================================
-- set_u_lock - 数据锁存器（LOCK上升沿锁存DAT_I→DAT_O）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity set_u_lock is port(lock:in std_logic; dat_i:in std_logic_vector(15 downto 0); dat_o:out std_logic_vector(15 downto 0)); end entity set_u_lock;
architecture rtl of set_u_lock is
begin process(lock)begin if rising_edge(lock) then dat_o<=dat_i; end if; end process;
end architecture rtl;
