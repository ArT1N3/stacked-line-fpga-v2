--=============================================================================
-- err_chk - 16通道错误检测（Lock上升沿锁存并计算错误位）
--   错误检测：ERx = ENx AND (ENx XOR DAx)  -- 使能位与数据不一致即为错误
--   错误统计：统计所有ERx中置位的位数，>=10则ERR_ON='1'
--   错误汇总：任何ERx非零则ERR_ALL='1'
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;

entity err_chk is
  port(lock:in std_logic;
       en1,en2,en3,en4,en5,en6,en7:in std_logic_vector(15 downto 0); en8:in std_logic_vector(7 downto 0);
       en9,en10,en11,en12,en13,en14,en15:in std_logic_vector(15 downto 0); en16:in std_logic_vector(7 downto 0);
       da1,da2,da3,da4,da5,da6,da7:in std_logic_vector(15 downto 0); da8:in std_logic_vector(7 downto 0);
       da9,da10,da11,da12,da13,da14,da15:in std_logic_vector(15 downto 0); da16:in std_logic_vector(7 downto 0);
       e1,e2,e3,e4,e5,e6,e7:out std_logic_vector(15 downto 0); e8:out std_logic_vector(7 downto 0);
       e9,e10,e11,e12,e13,e14,e15:out std_logic_vector(15 downto 0); e16:out std_logic_vector(7 downto 0);
       err_all,err_on:out std_logic);
end entity err_chk;

architecture rtl of err_chk is
  type arr16 is array(1 to 15) of std_logic_vector(15 downto 0);
  type arr8 is array(1 to 16) of std_logic_vector(7 downto 0);
  signal er16:arr16; signal er8_1,er8_16:std_logic_vector(7 downto 0);
  signal err_sum:unsigned(7 downto 0):=(others=>'0');
  signal sum_all:std_logic_vector(15 downto 0);
begin
  process(lock)
    -- 辅助函数：统计16位向量中'1'的个数
    impure function popcount(v:std_logic_vector(15 downto 0)) return unsigned is
      variable cnt:unsigned(7 downto 0):=(others=>'0');
    begin for i in 0 to 15 loop if v(i)='1' then cnt:=cnt+1; end if; end loop; return cnt; end function;
    impure function popcount8(v:std_logic_vector(7 downto 0)) return unsigned is
      variable cnt:unsigned(7 downto 0):=(others=>'0');
    begin for i in 0 to 7 loop if v(i)='1' then cnt:=cnt+1; end if; end loop; return cnt; end function;
  begin
    if rising_edge(lock) then
      er16(1)<=en1 and(en1 xor da1); er16(2)<=en2 and(en2 xor da2); er16(3)<=en3 and(en3 xor da3);
      er16(4)<=en4 and(en4 xor da4); er16(5)<=en5 and(en5 xor da5); er16(6)<=en6 and(en6 xor da6);
      er16(7)<=en7 and(en7 xor da7); er8_1<=en8 and(en8 xor da8);
      er16(9)<=en9 and(en9 xor da9); er16(10)<=en10 and(en10 xor da10); er16(11)<=en11 and(en11 xor da11);
      er16(12)<=en12 and(en12 xor da12); er16(13)<=en13 and(en13 xor da13); er16(14)<=en14 and(en14 xor da14);
      er16(15)<=en15 and(en15 xor da15); er8_16<=en16 and(en16 xor da16);
      -- 统计所有16位ER寄存器中置位的总位数
      err_sum<=popcount(er16(1))+popcount(er16(2))+popcount(er16(3))+popcount(er16(4))+popcount(er16(5))
              +popcount(er16(6))+popcount(er16(7))+popcount(er16(9))+popcount(er16(10))+popcount(er16(11))
              +popcount(er16(12))+popcount(er16(13))+popcount(er16(14))+popcount(er16(15));
    end if;
  end process;
  -- 错误汇总（组合逻辑）
  sum_all<=er16(1)or er16(2)or er16(3)or er16(4)or er16(5)or er16(6)or er16(7)or er16(9)or er16(10)or er16(11)or er16(12)or er16(13)or er16(14)or er16(15);
  err_all<='0' when(sum_all="0000000000000000"and(er8_1 or er8_16)="00000000")else '1';
  err_on<='1' when err_sum>=10 else '0';
  -- 输出
  e1<=er16(1);e2<=er16(2);e3<=er16(3);e4<=er16(4);e5<=er16(5);e6<=er16(6);e7<=er16(7);e8<=er8_1;
  e9<=er16(9);e10<=er16(10);e11<=er16(11);e12<=er16(12);e13<=er16(13);e14<=er16(14);e15<=er16(15);e16<=er8_16;
end architecture rtl;
