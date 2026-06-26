--=============================================================================
-- countor_addr_rx_cnt_pfc - PFC UART字节地址计数器（0→13, 13字节帧）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity countor_addr_rx_cnt_pfc is port(clk,clk2,en:in std_logic; qout:out std_logic_vector(4 downto 0); co:out std_logic); end entity countor_addr_rx_cnt_pfc;
architecture rtl of countor_addr_rx_cnt_pfc is signal q:unsigned(4 downto 0):=(others=>'0');
begin
  process(clk,en)begin if en='0' then q<=(others=>'0'); elsif rising_edge(clk) then if q<13 then q<=q+1; else q<=(others=>'0'); end if; end if; end process;
  process(en,clk2)begin if en='0' then co<='0'; elsif rising_edge(clk2) then if q>=13 then co<='1'; else co<='0'; end if; end if; end process;
  qout<=std_logic_vector(q);
end architecture rtl;
