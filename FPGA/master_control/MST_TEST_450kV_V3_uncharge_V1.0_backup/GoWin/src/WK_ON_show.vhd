--=============================================================================
-- wk_on_show - 工作状态显示（Wk=0清零，~0.5s后St=0，~1s后计数器重置）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity wk_on_show is port(clk,wk:in std_logic; st:out std_logic); end entity wk_on_show;
architecture rtl of wk_on_show is signal q1:unsigned(9 downto 0):=(others=>'0');
begin
  process(clk,wk)
  begin
    if rising_edge(clk) then
      if wk='0' then q1<=(others=>'0'); st<='1';
      else
        if q1<="1111101000" then q1<=q1+1; else q1<=(others=>'0'); end if;
        if q1<="0111110100" then st<='0'; else st<='1'; end if;
      end if;
    end if;
  end process;
end architecture rtl;
