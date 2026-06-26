--=============================================================================
-- clk_x2 - 2倍频器（clk XOR反馈产生2倍频时钟）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity clk_x2 is port(clk:in std_logic; clk_2:out std_logic); end entity clk_x2;
architecture rtl of clk_x2 is signal clk_tmp,dout,dout_n:std_logic;
begin
  clk_tmp<=clk xor dout; dout_n<=not dout; clk_2<=clk_tmp;
  process(clk_tmp)begin if rising_edge(clk_tmp) then dout<=dout_n; end if; end process;
end architecture rtl;
