--=============================================================================
-- rx_module - 串行数据接收模块（trig=1复位，Ck时钟采样DAT填充ST1-ST8，q1=123时ok=1）
--   功能：从DAT串行输入120位数据，每16位存入ST1-ST7，最后8位存入ST8
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity rx_module is port(clk_1m,trig,dat:in std_logic; st1,st2,st3,st4,st5,st6,st7:out std_logic_vector(15 downto 0); st8:out std_logic_vector(7 downto 0); ok:out std_logic); end entity rx_module;
architecture rtl of rx_module is
  signal q:unsigned(3 downto 0):=(others=>'0'); signal q1:unsigned(6 downto 0):=(others=>'0'); signal ck:std_logic;
begin
  -- 采样时钟生成（clk_1M/10分频，q=4时Ck=1）
  process(clk_1m,trig)begin if trig='1' then q<=(others=>'0');ck<='0'; elsif rising_edge(clk_1m) then if q<9 then q<=q+1; else q<=(others=>'0'); end if; if q=4 then ck<='1'; else ck<='0'; end if; end if; end process;
  -- 位计数器与数据分配（Ck时钟域，DDR输出采样）
  process(ck,trig)
  begin
    if trig='1' then q1<=(others=>'0');
    else
      if rising_edge(ck) then if q1<=125 then q1<=q1+1; end if; end if;
      if falling_edge(ck) then
        if q1=123 then ok<='1'; else ok<='0'; end if; -- 帧完成
      end if;
      if falling_edge(ck) then
        case q1 is -- 120位数据分配到8个寄存器
          when "0000001"|"0000010"|"0000011"|"0000100"|"0000101"|"0000110"|"0000111"|"0001000"|"0001001"|"0001010"|"0001011"|"0001100"|"0001101"|"0001110"|"0001111"|"0010000"=>st1(to_integer(q1)-1)<=dat;
          when "0010001"|"0010010"|"0010011"|"0010100"|"0010101"|"0010110"|"0010111"|"0011000"|"0011001"|"0011010"|"0011011"|"0011100"|"0011101"|"0011110"|"0011111"|"0100000"=>st2(to_integer(q1)-17)<=dat;
          when "0100001"|"0100010"|"0100011"|"0100100"|"0100101"|"0100110"|"0100111"|"0101000"|"0101001"|"0101010"|"0101011"|"0101100"|"0101101"|"0101110"|"0101111"|"0110000"=>st3(to_integer(q1)-33)<=dat;
          when "0110001"|"0110010"|"0110011"|"0110100"|"0110101"|"0110110"|"0110111"|"0111000"|"0111001"|"0111010"|"0111011"|"0111100"|"0111101"|"0111110"|"0111111"|"1000000"=>st4(to_integer(q1)-49)<=dat;
          when "1000001"|"1000010"|"1000011"|"1000100"|"1000101"|"1000110"|"1000111"|"1001000"|"1001001"|"1001010"|"1001011"|"1001100"|"1001101"|"1001110"|"1001111"|"1010000"=>st5(to_integer(q1)-65)<=dat;
          when "1010001"|"1010010"|"1010011"|"1010100"|"1010101"|"1010110"|"1010111"|"1011000"|"1011001"|"1011010"|"1011011"|"1011100"|"1011101"|"1011110"|"1011111"|"1100000"=>st6(to_integer(q1)-81)<=dat;
          when "1100001"|"1100010"|"1100011"|"1100100"|"1100101"|"1100110"|"1100111"|"1101000"|"1101001"|"1101010"|"1101011"|"1101100"|"1101101"|"1101110"|"1101111"|"1110000"=>st7(to_integer(q1)-97)<=dat;
          when "1110001"|"1110010"|"1110011"|"1110100"|"1110101"|"1110110"|"1110111"|"1111000"=>st8(to_integer(q1)-113)<=dat;
          when others=>null;
        end case;
      end if;
    end if;
  end process;
end architecture rtl;
