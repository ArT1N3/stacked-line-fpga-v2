--=============================================================================
-- com_dly_en - 通信延时使能（trig=0清零，约1000周期后EN=1）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity com_dly_en is port(clk,trig:in std_logic; en:out std_logic); end entity com_dly_en;
architecture rtl of com_dly_en is signal q:unsigned(10 downto 0):=(others=>'0');
begin
  process(clk,trig)
  begin
    if trig='0' then q<=(others=>'0'); en<='0';
    elsif rising_edge(clk) then if q<2000 then q<=q+1; end if; if q>1000 then en<='1'; else en<='0'; end if; end if;
  end process;
end architecture rtl;
