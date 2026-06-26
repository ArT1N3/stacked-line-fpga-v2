--=============================================================================
-- chk_tx - 检测发送（trig=1清零，DDR输出，q在1~200间TX=1，q=200时chk=1）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity chk_tx is port(clk_1m,trig:in std_logic; tx,chk:out std_logic); end entity chk_tx;
architecture rtl of chk_tx is signal q:unsigned(7 downto 0):=(others=>'0');
begin
  process(clk_1m,trig)
  begin
    if trig='1' then q<=(others=>'0');tx<='0';chk<='0';
    else
      if rising_edge(clk_1m) then if q<250 then q<=q+1; end if; end if;
      if falling_edge(clk_1m) then if q>=1 and q<200 then tx<='1'; else tx<='0'; end if; if q=200 then chk<='1'; else chk<='0'; end if; end if;
    end if;
  end process;
end architecture rtl;
