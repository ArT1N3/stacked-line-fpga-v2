--=============================================================================
-- cmd_aux_deal - 指令解码+触发门控（cmd_deal_m→cmd_trig: 解码后AND Trig输出）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity cmd_aux_deal is port(trig,en:in std_logic; cmd:in std_logic_vector(7 downto 0); cmd01,cmd02,cmd03,cmd04,cmd05,cmd06,cmd07,cmd08,cmd09,cmd0a,cmd0b,cmd0c,cmd0d,cmd0e,cmd0f,cmd10,cmd11,cmd12,cmd13:out std_logic); end entity cmd_aux_deal;
architecture rtl of cmd_aux_deal is
  component cmd_deal_m is port(cmd:in std_logic_vector(7 downto 0); en:in std_logic; cmd01,cmd02,cmd03,cmd04,cmd05,cmd06,cmd07,cmd08,cmd09,cmd0a,cmd0b,cmd0c,cmd0d,cmd0e,cmd0f,cmd10,cmd11,cmd12,cmd13:out std_logic); end component;
  component cmd_trig is port(c01,c02,c03,c04,c05,c06,c07,c08,c09,c0a,c0b,c0c,c0d,c0e,c0f,c10,c11,c12,c13,trig:in std_logic; cmd01,cmd02,cmd03,cmd04,cmd05,cmd06,cmd07,cmd08,cmd09,cmd0a,cmd0b,cmd0c,cmd0d,cmd0e,cmd0f,cmd10,cmd11,cmd12,cmd13:out std_logic); end component;
  signal c:std_logic_vector(1 to 19);
begin
  u_dec:cmd_deal_m port map(cmd=>cmd,en=>en,cmd01=>c(1),cmd02=>c(2),cmd03=>c(3),cmd04=>c(4),cmd05=>c(5),cmd06=>c(6),cmd07=>c(7),cmd08=>c(8),cmd09=>c(9),cmd0a=>c(10),cmd0b=>c(11),cmd0c=>c(12),cmd0d=>c(13),cmd0e=>c(14),cmd0f=>c(15),cmd10=>c(16),cmd11=>c(17),cmd12=>c(18),cmd13=>c(19));
  u_trig:cmd_trig port map(c01=>c(1),c02=>c(2),c03=>c(3),c04=>c(4),c05=>c(5),c06=>c(6),c07=>c(7),c08=>c(8),c09=>c(9),c0a=>c(10),c0b=>c(11),c0c=>c(12),c0d=>c(13),c0e=>c(14),c0f=>c(15),c10=>c(16),c11=>c(17),c12=>c(18),c13=>c(19),trig=>trig,cmd01=>cmd01,cmd02=>cmd02,cmd03=>cmd03,cmd04=>cmd04,cmd05=>cmd05,cmd06=>cmd06,cmd07=>cmd07,cmd08=>cmd08,cmd09=>cmd09,cmd0a=>cmd0a,cmd0b=>cmd0b,cmd0c=>cmd0c,cmd0d=>cmd0d,cmd0e=>cmd0e,cmd0f=>cmd0f,cmd10=>cmd10,cmd11=>cmd11,cmd12=>cmd12,cmd13=>cmd13);
end architecture rtl;
