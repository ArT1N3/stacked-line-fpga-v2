--=============================================================================
-- led_test2 - LED测试（50MHz计数器，DDR翻转LED[3:0]模式"0110"<->"1001"）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity led_test2 is port(clk,rst:in std_logic; led:out std_logic_vector(3 downto 0)); end entity led_test2;
architecture rtl of led_test2 is signal q:integer range 0 to 50000010:=0;
begin
  process(clk)
  begin
    if rising_edge(clk) then if q<50000000 then q<=q+1; else q<=0; end if; end if;
    if falling_edge(clk) then if q<25000000 then led<="0110"; else led<="1001"; end if; end if;
  end process;
end architecture rtl;
