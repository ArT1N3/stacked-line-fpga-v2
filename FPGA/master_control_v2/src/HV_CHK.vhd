--=============================================================================
-- hv_chk - 高压检测（CLR=1清零，DDR输出~140us低脉冲）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity hv_chk is port(clk,clr:in std_logic; trig_l:out std_logic); end entity hv_chk;
architecture rtl of hv_chk is signal q1:unsigned(7 downto 0):=(others=>'0');
begin
  process(clk,clr)
  begin
    if clr='1' then q1<=(others=>'0'); trig_l<='0';
    else
      if rising_edge(clk) then if q1<="10010110" then q1<=q1+1; end if; end if;
      if falling_edge(clk) then if q1>=1 and q1<="10001100" then trig_l<='1'; else trig_l<='0'; end if; end if;
    end if;
  end process;
end architecture rtl;
