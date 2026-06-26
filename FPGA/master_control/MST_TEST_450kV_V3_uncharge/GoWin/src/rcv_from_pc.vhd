--=============================================================================
-- rcv_from_pc - PC端UART帧接收器（comuse+地址计数+rcv_deal+delay对齐）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity rcv_from_pc is port(rxd,rst,clk:in std_logic; ok:out std_logic; aux,cmd,grp:out std_logic_vector(7 downto 0); dat1,dat3,dat5,dat7,dat9:out std_logic_vector(15 downto 0)); end entity rcv_from_pc;
architecture rtl of rcv_from_pc is
  component countor_t_over is port(clk,clr:in std_logic; co:out std_logic); end component;
  component countor_addr_rx_cnt is port(clk,clk2,en:in std_logic; qout:out std_logic_vector(4 downto 0); co:out std_logic); end component;
  component comp_clr is port(in1:in std_logic_vector(4 downto 0); same:out std_logic); end component;
  component rcv_deal is port(lock_in,lock_out,rst:in std_logic; addr:in std_logic_vector(4 downto 0); dat:in std_logic_vector(7 downto 0); confm:out std_logic; aux,cmd:out std_logic_vector(7 downto 0); dat1,dat3,dat5,dat7,dat9,dat11,dat13,dat15:out std_logic_vector(15 downto 0); grp:out std_logic_vector(7 downto 0)); end component;
  component comuse is port(dat,clk,rst:in std_logic; busy:out std_logic; d:out std_logic_vector(7 downto 0)); end component;
  component delay_1 is port(clk,in1:in std_logic; dly_out:out std_logic); end component;
  signal rx_busy,rx_byte_lock,tmo_rst,tmo_co,addr_en,addr_co,addr_clr:std_logic;
  signal addr:std_logic_vector(4 downto 0); signal rx_byte:std_logic_vector(7 downto 0);
  signal lk_d1,lk_d2,co_d1,co_d2,confm,confm_d:std_logic;
begin
  -- UART字节接收
  u_comuse:comuse port map(dat=>rxd,clk=>clk,rst=>addr_en,busy=>rx_busy,d=>rx_byte);
  -- 超时计数器
  tmo_rst<=not rx_busy; u_tmo:countor_t_over port map(clk=>clk,clr=>tmo_rst,co=>tmo_co);
  -- 地址计数器使能
  u_comp:comp_clr port map(in1=>addr,same=>addr_clr);
  addr_en<=rst and(not tmo_co)and(not addr_clr);
  -- 字节地址计数器（rx_busy作为时钟）
  u_addr:countor_addr_rx_cnt port map(clk=>rx_busy,clk2=>lk_d1,en=>addr_en,co=>addr_co,qout=>addr);
  -- 帧组装+校验
  u_rcv:rcv_deal port map(lock_in=>lk_d2,lock_out=>co_d2,rst=>addr_en,addr=>addr,dat=>rx_byte,confm=>confm,aux=>aux,cmd=>cmd,dat1=>dat1,dat3=>dat3,dat5=>dat5,dat7=>dat7,dat9=>dat9,grp=>grp);
  -- delay链对齐
  u_d1:delay_1 port map(clk=>clk,in1=>rx_busy,dly_out=>lk_d1); u_d2:delay_1 port map(clk=>clk,in1=>lk_d1,dly_out=>lk_d2);
  u_d3:delay_1 port map(clk=>clk,in1=>addr_co,dly_out=>co_d1); u_d4:delay_1 port map(clk=>clk,in1=>co_d1,dly_out=>co_d2);
  u_d5:delay_1 port map(clk=>clk,in1=>co_d2,dly_out=>confm_d);
  ok<=confm and confm_d;
end architecture rtl;
