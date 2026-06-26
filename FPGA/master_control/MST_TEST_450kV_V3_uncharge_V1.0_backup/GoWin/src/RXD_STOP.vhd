--=============================================================================
-- rxd_stop - RXD停止检测（RXD='1'清零，DDR输出，~20周期后ERR=1）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity rxd_stop is port(rxd,clk_10us:in std_logic; err:out std_logic); end entity rxd_stop;
architecture rtl of rxd_stop is signal q:unsigned(4 downto 0):=(others=>'0');
begin
  process(clk_10us,rxd)
  begin
    if rxd='1' then q<=(others=>'0'); err<='0';
    else
      if rising_edge(clk_10us) then if q<30 then q<=q+1; end if; end if;
      if falling_edge(clk_10us) then if q>20 then err<='1'; else err<='0'; end if; end if;
    end if;
  end process;
end architecture rtl;
