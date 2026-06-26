--=============================================================================
-- com_dly_rst - 通信延时复位（trig=1清零，约400周期后RST=0）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity com_dly_rst is port(clk,trig:in std_logic; rst:out std_logic); end entity com_dly_rst;
architecture rtl of com_dly_rst is signal q:unsigned(9 downto 0):=(others=>'0');
begin
  process(clk,trig)
  begin
    if trig='1' then q<=(others=>'0'); rst<='1';
    elsif rising_edge(clk) then if q<500 then q<=q+1; else q<=(others=>'0'); end if; if q=400 then rst<='0'; else rst<='1'; end if; end if;
  end process;
end architecture rtl;
