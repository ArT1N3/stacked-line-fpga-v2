--=============================================================================
-- comt - UART字节发送器（封装coms: 起始位0+8数据+停止位1, SER=1空闲填充）
--   d[7:0]映射到coms的d9..d2, d10/d1/d0固定值形成帧格式
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity comt is port(clkin,ld,rst:in std_logic; d:in std_logic_vector(7 downto 0); qout:out std_logic); end entity comt;
architecture rtl of comt is
  component coms is port(ser,stld,clk,clkih,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,d10:in std_logic; qhn,qh:out std_logic); end component;
  signal stld_s:std_logic;
begin
  stld_s<=ld and rst; -- STLD=0加载, =1移位
  u:coms port map(ser=>'1',stld=>stld_s,clk=>clkin,clkih=>'0',d10=>'1',d9=>d(7),d8=>d(6),d7=>d(5),d6=>d(4),d5=>d(3),d4=>d(2),d3=>d(1),d2=>d(0),d1=>'0',d0=>'1',qh=>qout,qhn=>open);
end architecture rtl;
