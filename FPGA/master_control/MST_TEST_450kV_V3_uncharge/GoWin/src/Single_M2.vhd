--=============================================================================
-- single_m2 - 单脉冲发生器2（CLR=0清零，~20ms后M_ON=1，~2s计数器饱和）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity single_m2 is port(clk,clr:in std_logic; m_on:out std_logic); end entity single_m2;
architecture rtl of single_m2 is signal q1:unsigned(10 downto 0):=(others=>'0');
begin
  process(clk,clr)
  begin
    if clr='0' then q1<=(others=>'0'); m_on<='0';
    elsif rising_edge(clk) then
      if q1<=1000 then q1<=q1+1; end if;
      if q1>30 then m_on<='1'; else m_on<='0'; end if;
    end if;
  end process;
end architecture rtl;
