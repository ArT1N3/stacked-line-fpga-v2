--=============================================================================
-- chk_trig - 检测触发（trig或CLR=1清零，DDR在q=100/130/160时依次输出TX1/2/3脉冲）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity chk_trig is port(clk_100us,trig,clr:in std_logic; tx1,tx2,tx3:out std_logic); end entity chk_trig;
architecture rtl of chk_trig is signal q:unsigned(9 downto 0):=(others=>'0');
begin
  process(clk_100us,trig,clr)
  begin
    if trig='1' or clr='1' then q<=(others=>'0');tx1<='0';tx2<='0';tx3<='0';
    else
      if rising_edge(clk_100us) then if q<1000 then q<=q+1; else q<=(others=>'0'); end if; end if;
      if falling_edge(clk_100us) then if q=100 then tx1<='1'; else tx1<='0'; end if; if q=130 then tx2<='1'; else tx2<='0'; end if; if q=160 then tx3<='1'; else tx3<='0'; end if; end if;
    end if;
  end process;
end architecture rtl;
