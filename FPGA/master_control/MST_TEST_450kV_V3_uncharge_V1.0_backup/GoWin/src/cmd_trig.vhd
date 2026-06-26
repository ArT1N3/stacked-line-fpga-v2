--=============================================================================
-- cmd_trig - 指令触发门控（19路AND: CMDxx = Cxx AND Trig）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity cmd_trig is port(c01,c02,c03,c04,c05,c06,c07,c08,c09,c0a,c0b,c0c,c0d,c0e,c0f,c10,c11,c12,c13,trig:in std_logic; cmd01,cmd02,cmd03,cmd04,cmd05,cmd06,cmd07,cmd08,cmd09,cmd0a,cmd0b,cmd0c,cmd0d,cmd0e,cmd0f,cmd10,cmd11,cmd12,cmd13:out std_logic); end entity cmd_trig;
architecture rtl of cmd_trig is
begin
  cmd01<=c01 and trig;cmd02<=c02 and trig;cmd03<=c03 and trig;cmd04<=c04 and trig;cmd05<=c05 and trig;
  cmd06<=c06 and trig;cmd07<=c07 and trig;cmd08<=c08 and trig;cmd09<=c09 and trig;cmd0a<=c0a and trig;
  cmd0b<=c0b and trig;cmd0c<=c0c and trig;cmd0d<=c0d and trig;cmd0e<=c0e and trig;cmd0f<=c0f and trig;
  cmd10<=c10 and trig;cmd11<=c11 and trig;cmd12<=c12 and trig;cmd13<=c13 and trig;
end architecture rtl;
