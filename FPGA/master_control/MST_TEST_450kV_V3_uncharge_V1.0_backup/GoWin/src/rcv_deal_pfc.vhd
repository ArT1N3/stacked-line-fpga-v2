--=============================================================================
-- rcv_deal_pfc - PFC帧接收校验（dat_store_rx_pfc+dat_confm_rx_pfc封装）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity rcv_deal_pfc is port(lock_in,lock_out,rst:in std_logic; addr:in std_logic_vector(4 downto 0); dat:in std_logic_vector(7 downto 0); confm:out std_logic; adr,st:out std_logic_vector(7 downto 0); crt_i,crt_u,set_i,set_u:out std_logic_vector(15 downto 0)); end entity rcv_deal_pfc;
architecture rtl of rcv_deal_pfc is
  component dat_store_rx_pfc is port(dat:in std_logic_vector(7 downto 0); addr:in std_logic_vector(4 downto 0); lock_in,lock_out,rst:in std_logic; head,adr,st,end2:out std_logic_vector(7 downto 0); bus_u,set_u,u_p,u_n:out std_logic_vector(15 downto 0); chk:out std_logic_vector(7 downto 0)); end component;
  component dat_confm_rx_pfc is port(head,adr,st,end2:in std_logic_vector(7 downto 0); bus_u,set_u,u_p,u_n:in std_logic_vector(15 downto 0); chk:in std_logic_vector(7 downto 0); equal:out std_logic); end component;
  signal head_s,adr_s,st_s,end2_s,chk_s:std_logic_vector(7 downto 0);
  signal bu_s,su_s,up_s,un_s:std_logic_vector(15 downto 0);
begin
  adr<=adr_s;st<=st_s;crt_u<=up_s;crt_i<=un_s;set_i<=su_s;set_u<=bu_s;
  u_store:dat_store_rx_pfc port map(lock_in=>lock_in,lock_out=>lock_out,rst=>rst,addr=>addr,dat=>dat,head=>head_s,adr=>adr_s,st=>st_s,end2=>end2_s,bus_u=>bu_s,set_u=>su_s,u_p=>up_s,u_n=>un_s,chk=>chk_s);
  u_valid:dat_confm_rx_pfc port map(head=>head_s,adr=>adr_s,st=>st_s,end2=>end2_s,bus_u=>bu_s,set_u=>su_s,u_p=>up_s,u_n=>un_s,chk=>chk_s,equal=>confm);
end architecture rtl;
