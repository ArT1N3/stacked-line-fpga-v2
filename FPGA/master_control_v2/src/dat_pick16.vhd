--=============================================================================
-- dat_pick16 - 4选1数据选择器（Lock下降沿锁存4路输入，addr选择输出）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity dat_pick16 is port(dat1,dat2,dat3,dat4:in std_logic_vector(7 downto 0); addr:in std_logic_vector(2 downto 0); lock:in std_logic; dat,adr:out std_logic_vector(7 downto 0)); end entity dat_pick16;
architecture rtl of dat_pick16 is signal da1,da2,da3,da4:std_logic_vector(7 downto 0);
begin
  process(lock)begin if falling_edge(lock) then da1<=dat1;da2<=dat2;da3<=dat3;da4<=dat4; end if; end process;
  adr(2 downto 0)<=addr; adr(7 downto 3)<=(others=>'0');
  with addr select dat<=da1 when "001",da2 when "010",da3 when "011",da4 when "100",(others=>'0') when others;
end architecture rtl;
