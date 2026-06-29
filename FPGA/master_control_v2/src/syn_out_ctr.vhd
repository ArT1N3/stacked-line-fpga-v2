--=============================================================================
-- syn_out_ctr - 4通道同步输出控制器（trig_out脉冲OR INx, EN门控）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity syn_out_ctr is port(in1,in2,in3,in4,clk_2m,trig1,trig2,trig3,trig4,en:in std_logic; o1,o2,o3,o4:out std_logic); end entity syn_out_ctr;
architecture rtl of syn_out_ctr is
  component trig_out is port(clk,trig:in std_logic; s_out:out std_logic); end component;
  signal p1,p2,p3,p4:std_logic;
begin
  u1:trig_out port map(clk=>clk_2m,trig=>trig1,s_out=>p1); u2:trig_out port map(clk=>clk_2m,trig=>trig2,s_out=>p2);
  u3:trig_out port map(clk=>clk_2m,trig=>trig3,s_out=>p3); u4:trig_out port map(clk=>clk_2m,trig=>trig4,s_out=>p4);
  o1<=en and(p1 or in1); o2<=en and(p2 or in2); o3<=en and(p3 or in3); o4<=en and(p4 or in4);
end architecture rtl;
