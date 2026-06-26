--=============================================================================
-- err_led - 故障LED输出寄存器（同步寄存+异步复位）
--=============================================================================
-- 功能：寄存故障状态，防止组合逻辑毛刺导致LED可见闪烁。
-- rst='0'→全灭, rising_edge(clk)→锁存err_in
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity err_led is port(rst,clk:in std_logic;err_in:in std_logic_vector(10 downto 1);red_led:out std_logic_vector(10 downto 1)); end entity err_led;
architecture rtl of err_led is
begin
  process(rst,clk)begin if rst='0' then red_led<=(others=>'0'); elsif rising_edge(clk) then red_led<=err_in; end if; end process;
end architecture rtl;
