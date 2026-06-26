--=============================================================================
-- com - UART位接收器（起始位检测+位时钟生成+字节完成检测）
--   countor3×countor10级联: baud时钟+10位计数器, level_edg检测finish边沿
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity com is port(rst,dat,clkin:in std_logic; busy,clkedg,finish:out std_logic); end entity com;
architecture rtl of com is
  component countor10 is port(clk,en:in std_logic; qout:out std_logic_vector(3 downto 0); co:out std_logic); end component;
  component countor3 is port(clk,en:in std_logic; qout:out std_logic_vector(2 downto 0); co:out std_logic); end component;
  component level_edg is port(level_in,clk:in std_logic; edg_out:out std_logic); end component;
  signal baud_clk,busy_int,finish_int,finish_edg,start_det:std_logic;
begin
  -- 波特率时钟: countor3级联分频
  u_ctr3:countor3 port map(clk=>clkin,en=>busy_int,co=>baud_clk);
  -- 10位计数器: 1起始+8数据+1停止
  u_ctr10:countor10 port map(clk=>baud_clk,en=>busy_int,co=>finish_int);
  u_edg:level_edg port map(level_in=>finish_int,clk=>clkin,edg_out=>finish_edg);
  -- busy控制: dat=0(起始位)置位, 完成或超时清零
  start_det<=dat and(not busy_int);
  process(busy_int,start_det)begin if busy_int='0' then busy_int<=start_det; end if; end process;
  busy<=busy_int; clkedg<=baud_clk; finish<=finish_int;
end architecture rtl;
