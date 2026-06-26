--=============================================================================
-- err_dff - 带异步复位的故障锁存器
--=============================================================================
-- 功能：粘滞故障锁存——一旦检测到故障（mac_32滤波输出上升沿），锁存永久'1'，
--   直到显式复位。即使故障消失，LED仍保持亮，直到主控通过UART指令x"01"复位。
--
-- 原始BUG修复：旧版使用if(clk='0')then q1<='0'; elsif(rst'event and rst='1')...
--   这是非标准的：clk上的电平敏感清零+rst上的边沿触发置位，综合结果不确定。
--   新版使用标准异步复位+上升沿clk+使能，所有FPGA工具均可正确综合。
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity err_dff is port(clk,rst,en,d:in std_logic; q:out std_logic); end entity err_dff;

architecture rtl of err_dff is
  signal q1:std_logic:='0';
begin
  process(clk,rst)
  begin
    if rst='0' then q1<='0'; -- 异步清零
    elsif rising_edge(clk) then if en='1' then q1<=d; end if; end if;
  end process;
  q<=q1;
end architecture rtl;
