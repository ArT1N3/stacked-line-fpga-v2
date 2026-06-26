--=============================================================================
-- coms - 11位并行加载移位寄存器（UART发送串行器）
--   STLD=0: 加载d10..d0; STLD=1: 移位, SER串入, QH串出
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity coms is port(ser,stld,clk,clkih:in std_logic; d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,d10:in std_logic; qhn,qh:out std_logic); end entity coms;
architecture rtl of coms is signal sr:std_logic_vector(10 downto 0);
begin
  process(clk)begin if rising_edge(clk) then if stld='0' then sr<=d10&d9&d8&d7&d6&d5&d4&d3&d2&d1&d0; elsif clkih='0' then sr<=ser&sr(10 downto 1); end if; end if; end process;
  qh<=sr(0); qhn<=not sr(0);
end architecture rtl;
