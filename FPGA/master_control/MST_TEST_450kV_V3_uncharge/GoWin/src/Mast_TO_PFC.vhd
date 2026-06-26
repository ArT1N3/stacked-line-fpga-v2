--=============================================================================
-- mast_to_pfc - 主控→PFC帧组包器（8字节帧：EB+Aux+dat_U[15:8]+dat_U[7:0]+dat_I[15:8]+dat_I[7:0]+CHK_L+AA）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity mast_to_pfc is port(cmd,aux:in std_logic_vector(7 downto 0); dat_u,dat_i:in std_logic_vector(15 downto 0); ask,clk,clr_n:in std_logic; dat:out std_logic_vector(7 downto 0); ld:out std_logic); end entity mast_to_pfc;
architecture rtl of mast_to_pfc is
  signal tmp1,tmp2,tmp3,tmp4,tmp5:unsigned(7 downto 0); signal checksum:unsigned(11 downto 0); signal sum_out:std_logic_vector(15 downto 0);
  signal add_div:unsigned(7 downto 0):=to_unsigned(118,8); signal clk2,co2:std_logic;
  signal add_txd:unsigned(5 downto 0):=(others=>'0'); signal d1,d2,d3,d4:std_logic;
begin
  process(clr_n)begin
    if falling_edge(clr_n) then
      if cmd=x"12" and ask='0' then tmp1<=unsigned(aux);tmp2<=unsigned(dat_u(15 downto 8));tmp3<=unsigned(dat_u(7 downto 0));tmp4<=unsigned(dat_i(15 downto 8));tmp5<=unsigned(dat_i(7 downto 0));
      else tmp1<=x"01";tmp2<=x"00";tmp3<=x"00";tmp4<=x"00";tmp5<=x"00"; end if;
    end if;
  end process;
  checksum<=resize(tmp1,12)+resize(tmp2,12)+resize(tmp3,12)+resize(tmp4,12)+resize(tmp5,12); sum_out<=std_logic_vector(resize(checksum,16));
  process(clk,clr_n)begin if clr_n='0' then add_div<=to_unsigned(118,8);elsif rising_edge(clk) then if add_div<=100 then add_div<=add_div+1;clk2<='0';else add_div<=(others=>'0');clk2<='1';end if;end if;end process;
  process(clk2,clr_n)begin if clr_n='0' then add_txd<=(others=>'0');elsif rising_edge(clk2) then if add_txd<8 then add_txd<=add_txd+1;co2<='0';else co2<='1';end if;end if;end process;
  process(clk2)begin if falling_edge(clk2) then case add_txd is when"000001"=>dat<=x"EB";when"000010"=>dat<=std_logic_vector(tmp1);when"000011"=>dat<=std_logic_vector(tmp2);when"000100"=>dat<=std_logic_vector(tmp3);when"000101"=>dat<=std_logic_vector(tmp3);when"000110"=>dat<=std_logic_vector(tmp3);when"000111"=>dat<=sum_out(7 downto 0);when"001000"=>dat<=x"AA";when others=>dat<=x"00";end case;end if;end process;
  process(clk)begin if falling_edge(clk) then d1<=clk2;d3<=d2;end if;if rising_edge(clk) then d2<=d1;d4<=d3;end if;end process;
  ld<=(not d4)or co2;
end architecture rtl;
