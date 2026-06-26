--=============================================================================
-- cmd_deal_m - 指令解码器（19选1，EN=1时根据CMD[7:0]置位对应输出）
--   CMD=01→CMD01,...,08→CMD08, 0A→CMD0A且CMD02-07同时置位
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity cmd_deal_m is port(cmd:in std_logic_vector(7 downto 0); en:in std_logic; cmd01,cmd02,cmd03,cmd04,cmd05,cmd06,cmd07,cmd08,cmd09,cmd0a,cmd0b,cmd0c,cmd0d,cmd0e,cmd0f,cmd10,cmd11,cmd12,cmd13:out std_logic); end entity cmd_deal_m;
architecture rtl of cmd_deal_m is
  signal decoded:std_logic_vector(1 to 19):=(others=>'0');
begin
  process(cmd,en)begin
    if en='1' then decoded<=(others=>'0');
      case cmd is
        when x"01"=>decoded(1)<='1';when x"02"=>decoded(2)<='1';decoded(10)<='1';
        when x"03"=>decoded(3)<='1';decoded(10)<='1';when x"04"=>decoded(4)<='1';decoded(10)<='1';
        when x"05"=>decoded(5)<='1';decoded(10)<='1';when x"06"=>decoded(6)<='1';decoded(10)<='1';
        when x"07"=>decoded(7)<='1';decoded(10)<='1';when x"08"=>decoded(8)<='1';
        when x"09"=>decoded(9)<='1';when x"0A"=>decoded(10)<='1';
        when x"0B"=>decoded(11)<='1';when x"0C"=>decoded(12)<='1';decoded(10)<='1';
        when x"0D"=>decoded(13)<='1';decoded(10)<='1';when x"0E"=>decoded(14)<='1';decoded(10)<='1';
        when x"0F"=>decoded(15)<='1';decoded(10)<='1';when x"10"=>decoded(16)<='1';decoded(10)<='1';
        when x"11"=>decoded(17)<='1';decoded(10)<='1';when x"12"=>decoded(18)<='1';decoded(10)<='1';
        when x"13"=>decoded(19)<='1';decoded(10)<='1';when others=>null;
      end case;
    else decoded<=(others=>'0'); end if;
  end process;
  cmd01<=decoded(1);cmd02<=decoded(2);cmd03<=decoded(3);cmd04<=decoded(4);cmd05<=decoded(5);
  cmd06<=decoded(6);cmd07<=decoded(7);cmd08<=decoded(8);cmd09<=decoded(9);cmd0a<=decoded(10);
  cmd0b<=decoded(11);cmd0c<=decoded(12);cmd0d<=decoded(13);cmd0e<=decoded(14);cmd0f<=decoded(15);
  cmd10<=decoded(16);cmd11<=decoded(17);cmd12<=decoded(18);cmd13<=decoded(19);
end architecture rtl;
