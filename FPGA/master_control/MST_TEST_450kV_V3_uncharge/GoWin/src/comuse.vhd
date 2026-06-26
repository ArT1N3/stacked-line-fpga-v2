--=============================================================================
-- comuse - UART字节接收器（com+shift10+hc74374: 串行→8位并行）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity comuse is port(dat,clk,rst:in std_logic; busy:out std_logic; d:out std_logic_vector(7 downto 0)); end entity comuse;
architecture rtl of comuse is
  component com is port(dat,rst,clkin:in std_logic; busy,clkedg,finish:out std_logic); end component;
  component shift10 is port(clrn,clk,din:in std_logic; d0,d1,d2,d3,d4,d5,d6,d7:out std_logic); end component;
  component hc74374 is port(oen,clk,d1,d2,d3,d4,d5,d6,d7,d8:in std_logic; q1,q2,q3,q4,q5,q6,q7,q8:out std_logic); end component;
  signal sr_d0,sr_d1,sr_d2,sr_d3,sr_d4,sr_d5,sr_d6,sr_d7:std_logic;
  signal com_clkedg,com_finish:std_logic;
begin
  u_com:com port map(dat=>dat,rst=>rst,clkin=>clk,busy=>busy,clkedg=>com_clkedg,finish=>com_finish);
  u_sr:shift10 port map(din=>dat,clrn=>rst,clk=>com_clkedg,d0=>sr_d0,d1=>sr_d1,d2=>sr_d2,d3=>sr_d3,d4=>sr_d4,d5=>sr_d5,d6=>sr_d6,d7=>sr_d7);
  u_reg:hc74374 port map(oen=>'0',clk=>com_finish,d1=>sr_d0,d2=>sr_d1,d3=>sr_d2,d4=>sr_d3,d5=>sr_d5,d6=>sr_d4,d7=>sr_d7,d8=>sr_d6,q2=>d(6),q3=>d(5),q5=>d(3),q4=>d(4),q6=>d(2),q7=>d(1),q8=>d(0),q1=>d(7));
end architecture rtl;
