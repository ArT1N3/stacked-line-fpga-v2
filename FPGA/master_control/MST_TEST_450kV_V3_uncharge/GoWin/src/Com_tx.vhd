--=============================================================================
-- com_tx - UART字节发送器（DDR，1起始+8数据+1停止，LD下降沿锁存数据）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity com_tx is port(clk,ld:in std_logic; dat:in std_logic_vector(7 downto 0); dout:out std_logic; busy:out std_logic); end entity com_tx;
architecture rtl of com_tx is
  signal q:unsigned(2 downto 0):=(others=>'0'); signal q2:unsigned(3 downto 0):=(others=>'0');
  signal da:std_logic_vector(7 downto 0); signal ck,ld2:std_logic;
begin
  -- 过采样时钟生成（DDR，q>3时ck=1）
  process(clk,ld)begin if ld='0' then q<=(others=>'0');ck<='0'; else if rising_edge(clk) then if q<7 then q<=q+1; else q<=(others=>'0'); end if; end if; if falling_edge(clk) then if q>3 then ck<='1'; else ck<='0'; end if; end if; end if; end process;
  -- LD下降沿锁存发送数据
  process(ld)begin if falling_edge(ld) then da<=dat; end if; end process;
  -- 位序列输出：空闲高，起始位低，数据位D0-D7，停止位高
  process(ck,ld)
  begin
    if ld='0' then q2<=(others=>'0');busy<='0';dout<='1';
    else
      if rising_edge(ck) then if q2<12 then q2<=q2+1; end if; end if;
      if falling_edge(ck) then
        case q2 is
          when "0000"=>dout<='1'; when "0001"=>dout<='0'; -- 空闲+起始位
          when "0010"=>dout<=da(0);when"0011"=>dout<=da(1);when"0100"=>dout<=da(2);when"0101"=>dout<=da(3);
          when "0110"=>dout<=da(4);when"0111"=>dout<=da(5);when"1000"=>dout<=da(6);when"1001"=>dout<=da(7);
          when others=>dout<='1'; -- 停止位+空闲
        end case;
      end if;
      if falling_edge(ck) then if q2<"1011" then busy<='1'; else busy<='0'; end if; end if;
    end if;
  end process;
end architecture rtl;
