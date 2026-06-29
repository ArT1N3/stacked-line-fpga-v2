--=============================================================================
-- dat_confm_rx_pfc - PFC帧校验（HEAD=0xEB, END2=0xAA, 10个字段校验和vs CHK[7:0]）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity dat_confm_rx_pfc is port(head,adr,st,end2:in std_logic_vector(7 downto 0); bus_u,set_u,u_p,u_n:in std_logic_vector(15 downto 0); chk:in std_logic_vector(7 downto 0); equal:out std_logic); end entity dat_confm_rx_pfc;
architecture rtl of dat_confm_rx_pfc is
  signal sum:unsigned(11 downto 0);
begin
  sum<=resize(unsigned(adr),12)+resize(unsigned(st),12)+resize(unsigned(bus_u(15 downto 8)),12)+resize(unsigned(bus_u(7 downto 0)),12)+resize(unsigned(set_u(15 downto 8)),12)+resize(unsigned(set_u(7 downto 0)),12)+resize(unsigned(u_p(15 downto 8)),12)+resize(unsigned(u_p(7 downto 0)),12)+resize(unsigned(u_n(15 downto 8)),12)+resize(unsigned(u_n(7 downto 0)),12);
  equal<='1' when head=x"EB" and end2=x"AA" and sum(7 downto 0)=unsigned(chk) else '0';
end architecture rtl;
