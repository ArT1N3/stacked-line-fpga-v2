--=============================================================================
-- lock_chg_dat_sel - 充电数据选择锁存器（CLR=0清零，LOCK上升沿按D1选择C1或C2输出）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity lock_chg_dat_sel is
  port(lock,clr:in std_logic; d1:in std_logic_vector(7 downto 0); d2,d3,d4,d5:in std_logic_vector(15 downto 0); d6,d7,d8,d9,d10,d11:in std_logic_vector(7 downto 0);
       c1_d1:out std_logic_vector(7 downto 0); c1_d2,c1_d3,c1_d4,c1_d5:out std_logic_vector(15 downto 0); c1_d6,c1_d7,c1_d8,c1_d9,c1_d10,c1_d11:out std_logic_vector(7 downto 0);
       c2_d1:out std_logic_vector(7 downto 0); c2_d2,c2_d3,c2_d4,c2_d5:out std_logic_vector(15 downto 0); c2_d6,c2_d7,c2_d8,c2_d9,c2_d10,c2_d11:out std_logic_vector(7 downto 0));
end entity lock_chg_dat_sel;
architecture rtl of lock_chg_dat_sel is
begin
  process(lock)begin
    if clr='0' then c1_d1<=(others=>'0');c1_d2<=(others=>'0');c1_d3<=(others=>'0');c1_d4<=(others=>'0');c1_d5<=(others=>'0');c1_d6<=(others=>'0');c1_d7<=(others=>'0');c1_d8<=(others=>'0');c1_d9<=(others=>'0');c1_d10<=(others=>'0');c1_d11<=(others=>'0');c2_d1<=(others=>'0');c2_d2<=(others=>'0');c2_d3<=(others=>'0');c2_d4<=(others=>'0');c2_d5<=(others=>'0');c2_d6<=(others=>'0');c2_d7<=(others=>'0');c2_d8<=(others=>'0');c2_d9<=(others=>'0');c2_d10<=(others=>'0');c2_d11<=(others=>'0');
    elsif rising_edge(lock) then
      if d1="00000001" then c1_d1<="00000001";c1_d2<=d2;c1_d3<=d3;c1_d4<=d4;c1_d5<=d5;c1_d6<=d6;c1_d7<=d7;c1_d8<=d8;c1_d9<=d9;c1_d10<=d10;c1_d11<=d11;
      else c2_d1<=d1;c2_d2<=d2;c2_d3<=d3;c2_d4<=d4;c2_d5<=d5;c2_d6<=d6;c2_d7<=d7;c2_d8<=d8;c2_d9<=d9;c2_d10<=d10;c2_d11<=d11; end if;
    end if;
  end process;
end architecture rtl;
