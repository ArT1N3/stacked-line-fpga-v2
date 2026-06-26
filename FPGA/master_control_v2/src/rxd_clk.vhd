--=============================================================================
-- rxd_clk - UART波特率时钟发生器
--=============================================================================
-- 功能：50MHz→~961.5kHz（50MHz/52），用于115200波特UART的8倍过采样。
-- 实际921.6kHz理想值，误差+4.3%，在UART±5%容限内可接受。
--=============================================================================

library ieee; use ieee.std_logic_1164.all;

entity rxd_clk is port(clk,rst:in std_logic; clk_115200:out std_logic); end entity rxd_clk;

architecture rtl of rxd_clk is
  signal clk_gen:std_logic:='0'; signal clk_count:integer range 0 to 51:=0;
begin
  process(clk,rst)
  begin
    if rst='0' then clk_count<=0; clk_gen<='0';
    elsif rising_edge(clk) then
      if clk_count=1 then clk_gen<='0'; clk_count<=clk_count+1;
      elsif clk_count=26 then clk_gen<='1'; clk_count<=clk_count+1;
      elsif clk_count=51 then clk_count<=0;
      else clk_count<=clk_count+1; end if;
    end if;
  end process;
  clk_115200<=clk_gen;
end architecture rtl;
