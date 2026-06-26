--=============================================================================
-- wk_st_delay - 工作状态延时器（DDR），WK='1'清零计数器，~1000ms后St变低
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity wk_st_delay is port(clk,wk:in std_logic; st:out std_logic); end entity wk_st_delay;
architecture rtl of wk_st_delay is signal q1:unsigned(9 downto 0):=(others=>'0');
begin
  process(clk,wk)
  begin
    if rising_edge(clk) then if wk='1' then q1<=(others=>'0'); elsif q1<="1111111100" then q1<=q1+1; end if; end if;
    if falling_edge(clk) then if q1>="1111101000" then st<='0'; else st<='1'; end if; end if;
  end process;
end architecture rtl;
