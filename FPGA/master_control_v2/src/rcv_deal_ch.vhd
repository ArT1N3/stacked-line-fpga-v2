--=============================================================================
-- rcv_deal_ch - 充电机帧接收校验（dat_store_rx_ch+dat_confm_rx_ch封装）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity rcv_deal_ch is port(lock_in,lock_out,rst:in std_logic; addr:in std_logic_vector(4 downto 0); dat:in std_logic_vector(7 downto 0); confm:out std_logic; adr,rsv,st,st2,tm1,tm2,tm3:out std_logic_vector(7 downto 0); bus_u,set_u,u_n,u_p:out std_logic_vector(15 downto 0)); end entity rcv_deal_ch;
architecture rtl of rcv_deal_ch is
  component dat_store_rx_ch is port(dat:in std_logic_vector(7 downto 0); addr:in std_logic_vector(4 downto 0); lock_in,lock_out,rst:in std_logic; head,adr,st,st2,rsv,end2:out std_logic_vector(7 downto 0); bus_u,set_u,u_p,u_n:out std_logic_vector(15 downto 0); temp1,temp2,temp3,chk:out std_logic_vector(7 downto 0)); end component;
  component dat_confm_rx_ch is port(head,adr,st,st2,rsv,end2:in std_logic_vector(7 downto 0); bus_u,set_u,u_p,u_n:in std_logic_vector(15 downto 0); temp1,temp2,temp3,chk:in std_logic_vector(7 downto 0); equal:out std_logic); end component;
  signal head_s,adr_s,st_s,st2_s,rsv_s,end2_s,chk_s,tp1,tp2,tp3:std_logic_vector(7 downto 0);
  signal bu_s,su_s,up_s,un_s:std_logic_vector(15 downto 0);
begin
  adr<=adr_s;rsv<=rsv_s;st<=st_s;st2<=st2_s;tm1<=tp1;tm2<=tp2;tm3<=tp3;bus_u<=bu_s;set_u<=su_s;u_n<=un_s;u_p<=up_s;
  u_store:dat_store_rx_ch port map(lock_in=>lock_in,lock_out=>lock_out,rst=>rst,addr=>addr,dat=>dat,head=>head_s,adr=>adr_s,st=>st_s,st2=>st2_s,rsv=>rsv_s,end2=>end2_s,bus_u=>bu_s,set_u=>su_s,u_p=>up_s,u_n=>un_s,temp1=>tp1,temp2=>tp2,temp3=>tp3,chk=>chk_s);
  u_valid:dat_confm_rx_ch port map(head=>head_s,adr=>adr_s,st=>st_s,st2=>st2_s,rsv=>rsv_s,end2=>end2_s,bus_u=>bu_s,set_u=>su_s,u_p=>up_s,u_n=>un_s,temp1=>tp1,temp2=>tp2,temp3=>tp3,chk=>chk_s,equal=>confm);
end architecture rtl;
