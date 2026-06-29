--=============================================================================
-- fpga_to_pc - FPGA→上位机帧组包器（22字节帧：HEAD+CMD+Grp+AUX+7×16bit数据+CHK+END）
--   比Mast_TO_Slave多Grp和AUX两个字段（18个数据字节）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity fpga_to_pc is
  port(cmd,grp,aux:in std_logic_vector(7 downto 0); dat1,dat3,dat5,dat7,dat9,dat11,dat13:in std_logic_vector(15 downto 0); dat15:in std_logic_vector(7 downto 0); clk,clr_n:in std_logic; dat:out std_logic_vector(7 downto 0); ld:out std_logic);
end entity fpga_to_pc;
architecture rtl of fpga_to_pc is
  type byte_arr is array(1 to 18) of unsigned(7 downto 0); signal tmp:byte_arr;
  signal checksum:unsigned(12 downto 0); signal sum_out:std_logic_vector(15 downto 0);
  signal add_div:unsigned(7 downto 0):=to_unsigned(118,8); signal clk2,co2:std_logic;
  signal add_txd:unsigned(5 downto 0):=(others=>'0'); signal d1,d2,d3,d4:std_logic;
  signal cmd_mapped:std_logic_vector(7 downto 0);
begin
  cmd_mapped<=x"02" when cmd=x"00" else cmd; -- CMD翻译: 0x00→0x02
  process(clr_n)begin
    if falling_edge(clr_n) then
      tmp(1)<=unsigned(cmd_mapped);tmp(2)<=unsigned(grp);tmp(3)<=unsigned(aux);
      tmp(4)<=unsigned(dat1(15 downto 8));tmp(5)<=unsigned(dat1(7 downto 0));tmp(6)<=unsigned(dat3(15 downto 8));
      tmp(7)<=unsigned(dat3(7 downto 0));tmp(8)<=unsigned(dat5(15 downto 8));tmp(9)<=unsigned(dat5(7 downto 0));
      tmp(10)<=unsigned(dat7(15 downto 8));tmp(11)<=unsigned(dat7(7 downto 0));tmp(12)<=unsigned(dat9(15 downto 8));
      tmp(13)<=unsigned(dat9(7 downto 0));tmp(14)<=unsigned(dat11(15 downto 8));tmp(15)<=unsigned(dat11(7 downto 0));
      tmp(16)<=unsigned(dat13(15 downto 8));tmp(17)<=unsigned(dat13(7 downto 0));tmp(18)<=unsigned(dat15(7 downto 0));
    end if;
  end process;
  checksum<=resize(tmp(1),13)+resize(tmp(2),13)+resize(tmp(3),13)+resize(tmp(4),13)+resize(tmp(5),13)+resize(tmp(6),13)+resize(tmp(7),13)+resize(tmp(8),13)+resize(tmp(9),13)+resize(tmp(10),13)+resize(tmp(11),13)+resize(tmp(12),13)+resize(tmp(13),13)+resize(tmp(14),13)+resize(tmp(15),13)+resize(tmp(16),13)+resize(tmp(17),13)+resize(tmp(18),13);
  sum_out<=std_logic_vector(resize(checksum,16));
  process(clk,clr_n)begin if clr_n='0' then add_div<=to_unsigned(118,8);elsif rising_edge(clk) then if add_div<=100 then add_div<=add_div+1;clk2<='0';else add_div<=(others=>'0');clk2<='1';end if;end if;end process;
  process(clk2,clr_n)begin if clr_n='0' then add_txd<=(others=>'0');elsif rising_edge(clk2) then if add_txd<22 then add_txd<=add_txd+1;co2<='0';else co2<='1';end if;end if;end process;
  process(clk2)begin
    if falling_edge(clk2) then
      case add_txd is
        when "000001"=>dat<=x"EB";when"000010"=>dat<=std_logic_vector(tmp(1));when"000011"=>dat<=std_logic_vector(tmp(2));
        when"000100"=>dat<=std_logic_vector(tmp(3));when"000101"=>dat<=std_logic_vector(tmp(4));when"000110"=>dat<=std_logic_vector(tmp(5));
        when"000111"=>dat<=std_logic_vector(tmp(6));when"001000"=>dat<=std_logic_vector(tmp(7));when"001001"=>dat<=std_logic_vector(tmp(8));
        when"001010"=>dat<=std_logic_vector(tmp(9));when"001011"=>dat<=std_logic_vector(tmp(10));when"001100"=>dat<=std_logic_vector(tmp(11));
        when"001101"=>dat<=std_logic_vector(tmp(12));when"001110"=>dat<=std_logic_vector(tmp(13));when"001111"=>dat<=std_logic_vector(tmp(14));
        when"010000"=>dat<=std_logic_vector(tmp(15));when"010001"=>dat<=std_logic_vector(tmp(16));when"010010"=>dat<=std_logic_vector(tmp(17));
        when"010011"=>dat<=std_logic_vector(tmp(18));when"010100"=>dat<=sum_out(15 downto 8);when"010101"=>dat<=sum_out(7 downto 0);
        when"010110"=>dat<=x"AA";when others=>dat<=x"00";
      end case;
    end if;
  end process;
  process(clk)begin if falling_edge(clk) then d1<=clk2;d3<=d2;end if;if rising_edge(clk) then d2<=d1;d4<=d3;end if;end process;
  ld<=(not d4)or co2;
end architecture rtl;
