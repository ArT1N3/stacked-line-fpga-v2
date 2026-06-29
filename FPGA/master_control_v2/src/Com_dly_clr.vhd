--=============================================================================
-- com_dly_clr - 通信延时清除（trig=1清零，~1000周期后CLR=0，之后ERR=1）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity com_dly_clr is port(clk,trig:in std_logic; clr,err:out std_logic); end entity com_dly_clr;
architecture rtl of com_dly_clr is signal q:unsigned(9 downto 0):=(others=>'0');
begin
  process(clk,trig)
  begin
    if trig='1' then q<=(others=>'0'); clr<='1'; err<='0';
    elsif rising_edge(clk) then
      if q<1010 then q<=q+1; end if;
      if q=1000 then clr<='0'; else clr<='1'; end if;
      if q<1000 then err<='0'; else err<='1'; end if;
    end if;
  end process;
end architecture rtl;
