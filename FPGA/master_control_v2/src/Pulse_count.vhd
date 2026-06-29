--=============================================================================
-- pulse_count - 24位脉冲计数器（clr=1清零，pulse上升沿递增）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity pulse_count is port(clr,pulse:in std_logic; num:out std_logic_vector(23 downto 0)); end entity pulse_count;
architecture rtl of pulse_count is signal q1:unsigned(23 downto 0):=(others=>'0');
begin
  process(pulse,clr)begin if clr='1' then q1<=(others=>'0'); elsif rising_edge(pulse) then q1<=q1+1; end if; end process;
  num<=std_logic_vector(q1);
end architecture rtl;
