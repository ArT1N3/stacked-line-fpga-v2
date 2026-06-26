--=============================================================================
-- dat_confm_rx_ch - 充电机帧校验（HEAD=0xEB, END2=0xAA, 15字节校验和vs CHK[7:0]）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity dat_confm_rx_ch is port(head,adr,st,st2,rsv,end2:in std_logic_vector(7 downto 0); bus_u,set_u,u_p,u_n:in std_logic_vector(15 downto 0); temp1,temp2,temp3,chk:in std_logic_vector(7 downto 0); equal:out std_logic); end entity dat_confm_rx_ch;
architecture rtl of dat_confm_rx_ch is
  signal sum:unsigned(12 downto 0);
begin
  sum<=resize(unsigned(adr),13)+resize(unsigned(st),13)+resize(unsigned(bus_u(15 downto 8)),13)+resize(unsigned(bus_u(7 downto 0)),13)+resize(unsigned(set_u(15 downto 8)),13)+resize(unsigned(set_u(7 downto 0)),13)+resize(unsigned(u_p(15 downto 8)),13)+resize(unsigned(u_p(7 downto 0)),13)+resize(unsigned(u_n(15 downto 8)),13)+resize(unsigned(u_n(7 downto 0)),13)+resize(unsigned(temp1),13)+resize(unsigned(temp2),13)+resize(unsigned(temp3),13)+resize(unsigned(st2),13)+resize(unsigned(rsv),13);
  equal<='1' when head=x"EB" and end2=x"AA" and sum(7 downto 0)=unsigned(chk) else '0';
end architecture rtl;
