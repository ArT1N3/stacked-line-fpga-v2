--=============================================================================
-- chk_tx2 - 检测发送2（trig=1清零，DDR输出，q在1~400间TX=1，q=400时chk=1）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity chk_tx2 is port(clk_1m,trig:in std_logic; tx,chk:out std_logic); end entity chk_tx2;
architecture rtl of chk_tx2 is signal q:unsigned(8 downto 0):=(others=>'0');
begin
  process(clk_1m,trig)
  begin
    if trig='1' then q<=(others=>'0');tx<='0';chk<='0';
    else
      if rising_edge(clk_1m) then if q<450 then q<=q+1; end if; end if;
      if falling_edge(clk_1m) then if q>=1 and q<400 then tx<='1'; else tx<='0'; end if; if q=400 then chk<='1'; else chk<='0'; end if; end if;
    end if;
  end process;
end architecture rtl;
