--=============================================================================
-- dat_confm_rx - UART帧校验和验证器
--=============================================================================
-- 三重验证：HEAD=0xEB, END2=0xAA, 校验和匹配（17字节求和，低12位比较）
-- 校验和=CMD+8个数据字拆成16字节的和，不含HEAD/CHK/END2
-- 组合逻辑：equal在任意输入变化时立即更新
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity dat_confm_rx is port(head,cmd,end2:in std_logic_vector(7 downto 0);dat1,dat3,dat5,dat7,dat9,dat11,dat13,dat15,chk:in std_logic_vector(15 downto 0);equal:out std_logic); end entity dat_confm_rx;
architecture rtl of dat_confm_rx is
  signal checksum:unsigned(11 downto 0);
begin
  checksum<=resize(unsigned(cmd),12)+resize(unsigned(dat1(15 downto 8)),12)+resize(unsigned(dat1(7 downto 0)),12)+resize(unsigned(dat3(15 downto 8)),12)+resize(unsigned(dat3(7 downto 0)),12)+resize(unsigned(dat5(15 downto 8)),12)+resize(unsigned(dat5(7 downto 0)),12)+resize(unsigned(dat7(15 downto 8)),12)+resize(unsigned(dat7(7 downto 0)),12)+resize(unsigned(dat9(15 downto 8)),12)+resize(unsigned(dat9(7 downto 0)),12)+resize(unsigned(dat11(15 downto 8)),12)+resize(unsigned(dat11(7 downto 0)),12)+resize(unsigned(dat13(15 downto 8)),12)+resize(unsigned(dat13(7 downto 0)),12)+resize(unsigned(dat15(15 downto 8)),12)+resize(unsigned(dat15(7 downto 0)),12);
  equal<='1' when head=x"EB" and end2=x"AA" and checksum=unsigned(chk(11 downto 0)) else '0';
end architecture rtl;
