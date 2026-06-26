--=============================================================================
-- aux_deal - 辅助指令解码器（6选1，EN=1时根据AUX[7:0]置位对应输出）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity aux_deal is port(aux:in std_logic_vector(7 downto 0); en:in std_logic; aux01,aux02,aux03,aux04,aux05,aux06:out std_logic); end entity aux_deal;
architecture rtl of aux_deal is
  signal d:std_logic_vector(6 downto 1):=(others=>'0');
begin
  process(aux,en)begin
    if en='1' then d<=(others=>'0');
      case aux is when x"01"=>d(1)<='1';when x"02"=>d(2)<='1';when x"03"=>d(3)<='1';when x"04"=>d(4)<='1';when x"05"=>d(5)<='1';when x"06"=>d(6)<='1';when others=>null; end case;
    else d<=(others=>'0'); end if;
  end process;
  aux01<=d(1);aux02<=d(2);aux03<=d(3);aux04<=d(4);aux05<=d(5);aux06<=d(6);
end architecture rtl;
