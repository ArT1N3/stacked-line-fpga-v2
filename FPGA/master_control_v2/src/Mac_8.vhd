--=============================================================================
-- mac_8 - 8级过采样毛刺滤波器（DDR，160ns滤波窗口@50MHz）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity mac_8 is port(in1,clk:in std_logic; o1:out std_logic); end entity mac_8;
architecture rtl of mac_8 is signal cnt:unsigned(2 downto 0):=(others=>'0'); signal sum:std_logic_vector(7 downto 0):=(others=>'0');
begin
  process(clk)
  begin
    if falling_edge(clk) then sum(to_integer(cnt))<=in1; end if;
    if rising_edge(clk) then cnt<=cnt+1; if sum=x"FF" then o1<='1'; elsif sum=x"00" then o1<='0'; end if; end if;
  end process;
end architecture rtl;
