--=============================================================================
-- read_flash - Flash读取数据锁存（4路lock_8: shift_clk锁存dat→DAT1..DAT4）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity read_flash is port(shift_clk:in std_logic; dat:in std_logic_vector(7 downto 0); dat1,dat2,dat3,dat4:out std_logic_vector(7 downto 0)); end entity read_flash;
architecture rtl of read_flash is
  component lock_8 is port(din:in std_logic_vector(7 downto 0); lk:in std_logic; q:out std_logic_vector(7 downto 0)); end component;
  signal addr:std_logic_vector(2 downto 0):=(others=>'0'); signal d1,d2,d3,d4:std_logic_vector(7 downto 0);
begin
  -- shift_clk作为地址计数器和锁存时钟
  process(shift_clk)begin if rising_edge(shift_clk) then if unsigned(addr)<4 then addr<=std_logic_vector(unsigned(addr)+1); end if; end if; end process;
  u1:lock_8 port map(din=>dat,lk=>shift_clk,q=>d1); u2:lock_8 port map(din=>dat,lk=>shift_clk,q=>d2);
  u3:lock_8 port map(din=>dat,lk=>shift_clk,q=>d3); u4:lock_8 port map(din=>dat,lk=>shift_clk,q=>d4);
  -- 实际是移位读取，按addr选择输出
  dat1<=d1 when addr="001" else(others=>'0'); dat2<=d2 when addr="010" else(others=>'0');
  dat3<=d3 when addr="011" else(others=>'0'); dat4<=d4 when addr="100" else(others=>'0');
end architecture rtl;
