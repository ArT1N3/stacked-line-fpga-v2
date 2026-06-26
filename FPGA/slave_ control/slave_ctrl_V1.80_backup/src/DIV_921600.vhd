--=============================================================================
-- div_921600 - 50MHz→~925.9kHz时钟分频器（/54）
--=============================================================================
-- 误差+0.47%，优于rxd_clk（+4.3%）。DDR输出。注意：当前工程未使用（不在.gprj中）。
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity div_921600 is port(clk:in std_logic;clk2:out std_logic); end entity div_921600;
architecture rtl of div_921600 is signal q:integer range 0 to 63:=0;
begin
  process(clk)
  begin
    if rising_edge(clk) then if q<53 then q<=q+1; else q<=0; end if; end if;
    if falling_edge(clk) then if q>26 then clk2<='1'; else clk2<='0'; end if; end if;
  end process;
end architecture rtl;
