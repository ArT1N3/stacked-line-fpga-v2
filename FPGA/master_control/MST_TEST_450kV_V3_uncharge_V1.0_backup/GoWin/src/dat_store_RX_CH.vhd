--=============================================================================
-- dat_store_rx_ch - 充电机帧字节存储（18字节帧）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity dat_store_rx_ch is port(dat:in std_logic_vector(7 downto 0); addr:in std_logic_vector(4 downto 0); lock_in,lock_out,rst:in std_logic; head,adr,st,st2,rsv,end2:out std_logic_vector(7 downto 0); bus_u,set_u,u_p,u_n:out std_logic_vector(15 downto 0); temp1,temp2,temp3,chk:out std_logic_vector(7 downto 0)); end entity dat_store_rx_ch;
architecture rtl of dat_store_rx_ch is
  signal h1,a1,s1,e1,c1,tp1,tp2,tp3,s21,rv1:std_logic_vector(7 downto 0); signal b1,su1,up1,un1:std_logic_vector(15 downto 0);
begin
  process(lock_out,rst)begin if rst='0' then head<=(others=>'0');adr<=(others=>'0');st<=(others=>'0');bus_u<=(others=>'0');set_u<=(others=>'0');u_p<=(others=>'0');u_n<=(others=>'0');chk<=(others=>'0');temp1<=(others=>'0');temp2<=(others=>'0');temp3<=(others=>'0');st2<=(others=>'0');rsv<=(others=>'0');end2<=(others=>'0'); elsif rising_edge(lock_out) then head<=h1;adr<=a1;st<=s1;bus_u<=b1;set_u<=su1;u_p<=up1;u_n<=un1;chk<=c1;end2<=e1;temp1<=tp1;temp2<=tp2;temp3<=tp3;st2<=s21;rsv<=rv1; end if; end process;
  process(lock_in)begin if rising_edge(lock_in) then case addr is
    when"00001"=>h1<=dat;when"00010"=>a1<=dat;when"00011"=>b1(15 downto 8)<=dat;when"00100"=>b1(7 downto 0)<=dat;
    when"00101"=>su1(15 downto 8)<=dat;when"00110"=>su1(7 downto 0)<=dat;when"00111"=>up1(15 downto 8)<=dat;when"01000"=>up1(7 downto 0)<=dat;
    when"01001"=>un1(15 downto 8)<=dat;when"01010"=>un1(7 downto 0)<=dat;when"01011"=>s1<=dat;
    when"01100"=>tp1<=dat;when"01101"=>tp2<=dat;when"01110"=>tp3<=dat;when"01111"=>s21<=dat;when"10000"=>rv1<=dat;
    when"10001"=>c1<=dat;when"10010"=>e1<=dat;when others=>null; end case; end if; end process;
end architecture rtl;
