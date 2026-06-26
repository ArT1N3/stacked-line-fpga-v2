--=============================================================================
-- trig_out - 触发输出（Trig=1清零，DDR在q=1~8间输出约0.5us脉冲）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity trig_out is port(clk,trig:in std_logic; s_out:out std_logic); end entity trig_out;
architecture rtl of trig_out is signal q1:unsigned(5 downto 0):=(others=>'0');
begin
  process(clk,trig)
  begin
    if trig='1' then q1<=(others=>'0'); s_out<='0';
    else
      if rising_edge(clk) then if q1<="110010" then q1<=q1+1; end if; end if;
      if falling_edge(clk) then if q1>=1 and q1<9 then s_out<='1'; else s_out<='0'; end if; end if;
    end if;
  end process;
end architecture rtl;
