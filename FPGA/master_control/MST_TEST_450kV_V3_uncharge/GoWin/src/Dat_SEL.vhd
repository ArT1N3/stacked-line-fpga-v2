--=============================================================================
-- dat_sel - 10路数据选择器（根据Aux[7:0]从10组输入中选择一组输出）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity dat_sel is
  port(aux:in std_logic_vector(7 downto 0);
       datA1,datA2,datA3,datA4,datA5,datA6,datA7:in std_logic_vector(15 downto 0); datA8:in std_logic_vector(7 downto 0);
       datB1,datB2,datB3,datB4,datB5,datB6,datB7:in std_logic_vector(15 downto 0); datB8:in std_logic_vector(7 downto 0);
       datC1,datC2,datC3,datC4,datC5,datC6,datC7:in std_logic_vector(15 downto 0); datC8:in std_logic_vector(7 downto 0);
       datD1,datD2,datD3,datD4,datD5,datD6,datD7:in std_logic_vector(15 downto 0); datD8:in std_logic_vector(7 downto 0);
       datE1,datE2,datE3,datE4,datE5,datE6,datE7:in std_logic_vector(15 downto 0); datE8:in std_logic_vector(7 downto 0);
       datF1,datF2,datF3,datF4,datF5,datF6,datF7:in std_logic_vector(15 downto 0); datF8:in std_logic_vector(7 downto 0);
       datG1,datG2,datG3,datG4,datG5,datG6,datG7:in std_logic_vector(15 downto 0); datG8:in std_logic_vector(7 downto 0);
       datH1,datH2,datH3,datH4,datH5,datH6,datH7:in std_logic_vector(15 downto 0); datH8:in std_logic_vector(7 downto 0);
       datI1,datI2,datI3,datI4,datI5,datI6,datI7:in std_logic_vector(15 downto 0); datI8:in std_logic_vector(7 downto 0);
       datJ1,datJ2,datJ3,datJ4,datJ5,datJ6,datJ7:in std_logic_vector(15 downto 0); datJ8:in std_logic_vector(7 downto 0);
       dat1,dat2,dat3,dat4,dat5,dat6,dat7:out std_logic_vector(15 downto 0); dat8:out std_logic_vector(7 downto 0));
end entity dat_sel;
architecture rtl of dat_sel is
begin
  -- 10选1选择器，每路独立
  with aux select dat1<=datA1 when "00000001",datB1 when "00000010",datC1 when "00000011",datD1 when "00000100",datE1 when "00000101",datF1 when "00000110",datG1 when "00000111",datH1 when "00001000",datI1 when "00001001",datJ1 when "00001010",(others=>'0') when others;
  with aux select dat2<=datA2 when "00000001",datB2 when "00000010",datC2 when "00000011",datD2 when "00000100",datE2 when "00000101",datF2 when "00000110",datG2 when "00000111",datH2 when "00001000",datI2 when "00001001",datJ2 when "00001010",(others=>'0') when others;
  with aux select dat3<=datA3 when "00000001",datB3 when "00000010",datC3 when "00000011",datD3 when "00000100",datE3 when "00000101",datF3 when "00000110",datG3 when "00000111",datH3 when "00001000",datI3 when "00001001",datJ3 when "00001010",(others=>'0') when others;
  with aux select dat4<=datA4 when "00000001",datB4 when "00000010",datC4 when "00000011",datD4 when "00000100",datE4 when "00000101",datF4 when "00000110",datG4 when "00000111",datH4 when "00001000",datI4 when "00001001",datJ4 when "00001010",(others=>'0') when others;
  with aux select dat5<=datA5 when "00000001",datB5 when "00000010",datC5 when "00000011",datD5 when "00000100",datE5 when "00000101",datF5 when "00000110",datG5 when "00000111",datH5 when "00001000",datI5 when "00001001",datJ5 when "00001010",(others=>'0') when others;
  with aux select dat6<=datA6 when "00000001",datB6 when "00000010",datC6 when "00000011",datD6 when "00000100",datE6 when "00000101",datF6 when "00000110",datG6 when "00000111",datH6 when "00001000",datI6 when "00001001",datJ6 when "00001010",(others=>'0') when others;
  with aux select dat7<=datA7 when "00000001",datB7 when "00000010",datC7 when "00000011",datD7 when "00000100",datE7 when "00000101",datF7 when "00000110",datG7 when "00000111",datH7 when "00001000",datI7 when "00001001",datJ7 when "00001010",(others=>'0') when others;
  with aux select dat8<=datA8 when "00000001",datB8 when "00000010",datC8 when "00000011",datD8 when "00000100",datE8 when "00000101",datF8 when "00000110",datG8 when "00000111",datH8 when "00001000",datI8 when "00001001",datJ8 when "00001010",(others=>'0') when others;
end architecture rtl;
