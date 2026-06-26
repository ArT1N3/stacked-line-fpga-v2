--=============================================================================
-- hc74374 - 8位D触发器（带三态输出，OEN=0使能输出，CLK上升沿锁存）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity hc74374 is port(oen,clk,d1,d2,d3,d4,d5,d6,d7,d8:in std_logic; q1,q2,q3,q4,q5,q6,q7,q8:out std_logic); end entity hc74374;
architecture rtl of hc74374 is
  signal dff:std_logic_vector(8 downto 1);
begin
  process(clk)begin if rising_edge(clk) then dff<=d8&d7&d6&d5&d4&d3&d2&d1; end if; end process;
  q1<=dff(1)when oen='0'else'Z';q2<=dff(2)when oen='0'else'Z';q3<=dff(3)when oen='0'else'Z';q4<=dff(4)when oen='0'else'Z';
  q5<=dff(5)when oen='0'else'Z';q6<=dff(6)when oen='0'else'Z';q7<=dff(7)when oen='0'else'Z';q8<=dff(8)when oen='0'else'Z';
end architecture rtl;
