--=============================================================================
-- comtx - 完整UART发送器（comt+波特率时钟+握手控制）
--   LD=1时发送DAT[7:0], Busy=1时忙, Dout串行输出
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity comtx is port(ld,rst,clk:in std_logic; dat:in std_logic_vector(7 downto 0); busy:out std_logic; dout:out std_logic); end entity comtx;
architecture rtl of comtx is
  component comt is port(clkin,ld,rst:in std_logic; d:in std_logic_vector(7 downto 0); qout:out std_logic); end component;
  component countor11 is port(clk,en:in std_logic; qout:out std_logic_vector(3 downto 0); co:out std_logic); end component;
  component countor3 is port(clk,en:in std_logic; qout:out std_logic_vector(2 downto 0); co:out std_logic); end component;
  component level_edg is port(level_in,clk:in std_logic; edg_out:out std_logic); end component;
  signal clk_inv,baud_en,baud_clk,frame_done,frame_done_edg,start_sync:std_logic;
  signal busy_int,busy_set,busy_clr:std_logic;
begin
  clk_inv<=not clk;
  -- 波特率时钟：countor3×countor11级联分频
  u_ctr3:countor3 port map(clk=>clk,en=>baud_en,co=>baud_clk);
  u_ctr11:countor11 port map(clk=>baud_clk,en=>baud_en,co=>frame_done);
  u_edg:level_edg port map(level_in=>frame_done,clk=>clk,edg_out=>frame_done_edg);
  baud_en<=busy_int and ld;
  -- busy控制（异步置位/复位DFF模拟）
  process(clk)begin if rising_edge(clk) then busy_int<=(not busy_clr)and(busy_int or busy_set); end if; end process;
  busy_set<=ld; busy_clr<=rst and(not frame_done_edg);
  busy<=busy_int;
  -- 发送器
  u_comt:comt port map(clkin=>baud_clk,ld=>ld,rst=>rst,d=>dat,qout=>dout);
end architecture rtl;
