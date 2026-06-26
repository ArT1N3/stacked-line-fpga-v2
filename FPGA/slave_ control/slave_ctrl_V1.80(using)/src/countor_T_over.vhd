--=============================================================================
-- countor_t_over - UART帧超时计数器（400周期约416us）
--=============================================================================
-- 功能：clr='0'→保持为0（UART忙），clr='1'→计数至400后co脉冲（超时→中止帧）
-- 5字节时间=足够检测帧传输中断
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity countor_t_over is port(clk,clr:in std_logic;co:out std_logic); end entity countor_t_over;
architecture rtl of countor_t_over is signal q:integer range 0 to 1023:=0;
begin
  process(clk,clr)begin if clr='0' then q<=0;co<='0'; elsif rising_edge(clk) then if q<400 then q<=q+1;co<='0'; else q<=0;co<='1'; end if; end if; end process;
end architecture rtl;
