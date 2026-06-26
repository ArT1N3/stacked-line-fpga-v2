--=============================================================================
-- delay_1 - 3级DDR移位寄存器延时线（约1.5个时钟周期）
--=============================================================================
-- 功能：使用双沿（DDR）提供约1.5时钟周期延时。
--   下降沿：d1<=in1(采样), d3<=d2(传递)
--   上升沿：d2<=d1(中间传递), dly_out<=d3(输出)
-- 用于com_rxd中UART接收器与帧组装流水线之间的信号对齐。
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity delay_1 is port(clk,in1:in std_logic;dly_out:out std_logic); end entity delay_1;
architecture rtl of delay_1 is signal d1,d2,d3:std_logic:='0';
begin
  process(clk)
  begin
    if falling_edge(clk) then d1<=in1; d3<=d2; end if;
    if rising_edge(clk) then d2<=d1; dly_out<=d3; end if;
  end process;
end architecture rtl;
