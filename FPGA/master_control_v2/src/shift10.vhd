--=============================================================================
-- shift10 - 8位移位寄存器（CLRN=0清零，CLK上升沿移位: din→d0→d1→...→d7）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity shift10 is port(clrn,clk,din:in std_logic; d0,d1,d2,d3,d4,d5,d6,d7:out std_logic); end entity shift10;
architecture rtl of shift10 is
  signal dff:std_logic_vector(3 to 11);
begin
  d0<=dff(4);d1<=dff(5);d2<=dff(6);d3<=dff(7);d4<=dff(8);d5<=dff(9);d6<=dff(10);d7<=dff(11);
  process(clk,clrn)begin if clrn='0' then dff<=(others=>'0'); elsif rising_edge(clk) then dff<=dff(4 to 11)&dff(3); dff(3)<=din; end if; end process;
end architecture rtl;
