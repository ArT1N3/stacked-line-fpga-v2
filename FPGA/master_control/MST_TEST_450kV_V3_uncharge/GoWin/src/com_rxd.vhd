--=============================================================================
-- com_rxd - UART多帧接收器（分控通信: com_rx+地址计数+rcv_deal+delay对齐）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity com_rxd is port(din,clk,rst:in std_logic; confm:out std_logic; aux,cmd,grp:out std_logic_vector(7 downto 0); dat1,dat3,dat5,dat7,dat9,dat11,dat13:out std_logic_vector(15 downto 0); dat15:out std_logic_vector(7 downto 0)); end entity com_rxd;
architecture rtl of com_rxd is
  component countor_t_over is port(clk,clr:in std_logic; co:out std_logic); end component;
  component countor_addr_rx_cnt is port(clk,clk2,en:in std_logic; qout:out std_logic_vector(4 downto 0); co:out std_logic); end component;
  component comp_clr is port(in1:in std_logic_vector(4 downto 0); same:out std_logic); end component;
  component rcv_deal is port(lock_in,lock_out,rst:in std_logic; addr:in std_logic_vector(4 downto 0); dat:in std_logic_vector(7 downto 0); confm:out std_logic; aux,cmd:out std_logic_vector(7 downto 0); dat1,dat3,dat5,dat7,dat9,dat11,dat13:out std_logic_vector(15 downto 0); dat15:out std_logic_vector(7 downto 0); grp:out std_logic_vector(7 downto 0)); end component;
  component com_rx is port(clk,din:in std_logic; busy,lk:out std_logic; dat:out std_logic_vector(7 downto 0)); end component;
  component delay_1 is port(clk,in1:in std_logic; dly_out:out std_logic); end component;
  signal clk_inv,rx_lk,rx_busy,tmo_clr,tmo_co,addr_en,addr_co,addr_clr:std_logic;
  signal addr:std_logic_vector(4 downto 0); signal rx_byte:std_logic_vector(7 downto 0);
  signal lk_d1,lk_d2,co_d1,co_d2,confm_int,confm_d:std_logic;
begin
  clk_inv<=not clk;
  u_rx:com_rx port map(clk=>clk,din=>din,busy=>rx_busy,lk=>rx_lk,dat=>rx_byte);
  tmo_clr<=not rx_busy; u_tmo:countor_t_over port map(clk=>clk,clr=>tmo_clr,co=>tmo_co);
  u_comp:comp_clr port map(in1=>addr,same=>addr_clr);
  addr_en<=rst and(not tmo_co)and(not addr_clr);
  u_addr:countor_addr_rx_cnt port map(clk=>rx_lk,clk2=>lk_d1,en=>addr_en,co=>addr_co,qout=>addr);
  u_rcv:rcv_deal port map(lock_in=>lk_d2,lock_out=>co_d2,rst=>rst,addr=>addr,dat=>rx_byte,confm=>confm_int,aux=>aux,cmd=>cmd,dat1=>dat1,dat3=>dat3,dat5=>dat5,dat7=>dat7,dat9=>dat9,dat11=>dat11,dat13=>dat13,dat15=>dat15,grp=>grp);
  u_d1:delay_1 port map(clk=>clk_inv,in1=>rx_lk,dly_out=>lk_d1); u_d2:delay_1 port map(clk=>clk_inv,in1=>lk_d1,dly_out=>lk_d2);
  u_d3:delay_1 port map(clk=>clk_inv,in1=>addr_co,dly_out=>co_d1); u_d4:delay_1 port map(clk=>clk_inv,in1=>co_d1,dly_out=>co_d2);
  u_d5:delay_1 port map(clk=>clk_inv,in1=>co_d2,dly_out=>confm_d);
  confm<=confm_int and confm_d;
end architecture rtl;
