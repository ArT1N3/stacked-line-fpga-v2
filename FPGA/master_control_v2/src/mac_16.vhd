--=============================================================================
-- mac_16 - 16级过采样毛刺滤波器（DDR双沿采样）
--=============================================================================
-- 功能：在top.vhd中用于对RXD输入消抖后再送入slave_ctrl。
--   50MHz DDR采样：320ns滤波窗口，抑制<320ns的毛刺。
--   320ns足够短，不影响UART时序（1位=8.68us @115200波特）。
--=============================================================================

library ieee;
use ieee.std_logic_1164.all; use ieee.numeric_std.all;

entity mac_16 is port(in1,clk:in std_logic; o1:out std_logic); end entity mac_16;

architecture rtl of mac_16 is
  signal cnt:unsigned(3 downto 0):=(others=>'0'); signal sum:std_logic_vector(15 downto 0):=(others=>'0');
begin
  process(clk)
  begin
    if falling_edge(clk) then sum(to_integer(cnt))<=in1; end if; -- 下降沿采样存入环形缓冲区
    if rising_edge(clk) then cnt<=cnt+1; -- 上升沿评估
      if sum=x"FFFF" then o1<='1'; elsif sum=x"0000" then o1<='0'; end if; -- 混合→保持（迟滞）
    end if;
  end process;
end architecture rtl;
