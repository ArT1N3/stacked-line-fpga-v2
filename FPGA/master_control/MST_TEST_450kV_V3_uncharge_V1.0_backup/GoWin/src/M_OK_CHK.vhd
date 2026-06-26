--=============================================================================
-- m_ok_chk - 主控OK检测（CLR=0清零，~1.2s后M_OK=1）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity m_ok_chk is port(clk,clr:in std_logic; m_ok:out std_logic); end entity m_ok_chk;
architecture rtl of m_ok_chk is signal q1:unsigned(10 downto 0):=(others=>'0');
begin
  process(clk,clr)
  begin
    if clr='0' then q1<=(others=>'0'); m_ok<='0';
    elsif rising_edge(clk) then
      if q1<2010 then q1<=q1+1; end if;
      if q1>=1250 then m_ok<='1'; else m_ok<='0'; end if;
    end if;
  end process;
end architecture rtl;
