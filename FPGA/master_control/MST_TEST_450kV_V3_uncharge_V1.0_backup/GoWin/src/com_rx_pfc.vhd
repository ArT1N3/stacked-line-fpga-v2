--=============================================================================
-- com_rx_pfc - PFC UART帧接收器（com_rx+地址计数+rcv_deal_pfc+delay对齐）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity com_rx_pfc is port(din,clk,rst,rst_o:in std_logic; confm:out std_logic; adr,st:out std_logic_vector(7 downto 0); bus_u,set_u,u_n,u_p:out std_logic_vector(15 downto 0)); end entity com_rx_pfc;
architecture rtl of com_rx_pfc is
  component countor_t_over is port(clk,clr:in std_logic; co:out std_logic); end component;
  component countor_addr_rx_cnt_pfc is port(clk,clk2,en:in std_logic; qout:out std_logic_vector(4 downto 0); co:out std_logic); end component;
  component comp_clr is port(in1:in std_logic_vector(4 downto 0); same:out std_logic); end component;
  component com_rx is port(clk,din:in std_logic; busy,lk:out std_logic; dat:out std_logic_vector(7 downto 0)); end component;
  component rcv_deal_pfc is port(lock_in,lock_out,rst:in std_logic; addr:in std_logic_vector(4 downto 0); dat:in std_logic_vector(7 downto 0); confm:out std_logic; adr,st:out std_logic_vector(7 downto 0); crt_i,crt_u,set_i,set_u:out std_logic_vector(15 downto 0)); end component;
  component delay_1 is port(clk,in1:in std_logic; dly_out:out std_logic); end component;
  signal clk_inv,rx_lk,rx_busy,tmo_clr,tmo_co,addr_en,addr_co,addr_clr:std_logic;
  signal addr:std_logic_vector(4 downto 0); signal rx_byte:std_logic_vector(7 downto 0);
  signal lk_d1,lk_d2,co_d1,co_d2,confm_int:std_logic; signal crt_i,set_i:std_logic_vector(15 downto 0);
begin
  clk_inv<=not clk;
  u_rx:com_rx port map(clk=>clk,din=>din,busy=>rx_busy,lk=>rx_lk,dat=>rx_byte);
  tmo_clr<=not rx_busy; u_tmo:countor_t_over port map(clk=>clk,clr=>tmo_clr,co=>tmo_co);
  u_comp:comp_clr port map(in1=>addr,same=>addr_clr);
  addr_en<=rst and(not tmo_co)and(not addr_clr);
  u_addr:countor_addr_rx_cnt_pfc port map(clk=>rx_lk,clk2=>lk_d1,en=>addr_en,co=>addr_co,qout=>addr);
  u_rcv:rcv_deal_pfc port map(lock_in=>lk_d2,lock_out=>co_d2,rst=>rst_o,addr=>addr,dat=>rx_byte,confm=>confm_int,adr=>adr,st=>st,crt_i=>crt_i,crt_u=>u_p,set_i=>set_i,set_u=>set_u);
  u_n<=crt_i; -- CRT_I → U_N
  u_d1:delay_1 port map(clk=>clk_inv,in1=>rx_lk,dly_out=>lk_d1); u_d2:delay_1 port map(clk=>clk_inv,in1=>lk_d1,dly_out=>lk_d2);
  u_d3:delay_1 port map(clk=>clk_inv,in1=>addr_co,dly_out=>co_d1); u_d4:delay_1 port map(clk=>clk_inv,in1=>co_d1,dly_out=>co_d2);
  confm<=confm_int;
end architecture rtl;
