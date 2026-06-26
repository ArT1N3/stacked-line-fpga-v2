--=============================================================================
-- countor_addr_rx_cnt - UART字节地址计数器（0→20）
--=============================================================================
-- 功能：com_rxd帧组装流水线中计数接收到的UART字节。
-- clk域：rx_lk脉冲递增,q<20→+1, q>=20→回0。clk2域：q>=20时co='1'（帧完成）。
-- 5位宽：32>20，支持扩展。
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity countor_addr_rx_cnt is port(clk,clk2,en:in std_logic;qout:out std_logic_vector(4 downto 0);co:out std_logic); end entity countor_addr_rx_cnt;
architecture rtl of countor_addr_rx_cnt is signal q:unsigned(4 downto 0):=(others=>'0');
begin
  process(clk,en)begin if en='0' then q<=(others=>'0'); elsif rising_edge(clk) then if q<20 then q<=q+1; else q<=(others=>'0'); end if; end if; end process;
  process(en,clk2)begin if en='0' then co<='0'; elsif rising_edge(clk2) then if q>=20 then co<='1'; else co<='0'; end if; end if; end process;
  qout<=std_logic_vector(q);
end architecture rtl;
