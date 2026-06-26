--=============================================================================
-- single_m - 单脉冲发生器（CLR=1清零，Stp=0复位，~500ms M_ON脉冲）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity single_m is port(clk,clr,stp:in std_logic; m_on:out std_logic); end entity single_m;
architecture rtl of single_m is signal q1:unsigned(14 downto 0):=(others=>'0');
begin
  process(clk,clr)
  begin
    if clr='1' then q1<=(others=>'0');
    elsif rising_edge(clk) then
      if stp='0' then q1<=to_unsigned(31000,15); m_on<='0'; -- 预设值
      else if q1<=6000 then q1<=q1+1; end if;
        if q1<=5000 and q1>=10 then m_on<='1'; else m_on<='0'; end if;
      end if;
    end if;
  end process;
end architecture rtl;
