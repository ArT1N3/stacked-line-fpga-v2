--=============================================================================
-- rly_ctr_8 - 8路继电器控制器（CMD_R上升沿锁存DAT→R1..R8，RLY_st[4:0]）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity rly_ctr_8 is port(cmd_r,rst:in std_logic; dat:in std_logic_vector(7 downto 0); r1,r2,r3,r4,r5,r6,r7,r8:out std_logic; rly_st:out std_logic_vector(4 downto 0)); end entity rly_ctr_8;
architecture rtl of rly_ctr_8 is
begin
  process(cmd_r,rst)
  begin
    if rst='0' then r1<='0';r2<='0';r3<='0';r4<='0';r5<='0';r6<='0';r7<='0';r8<='0';rly_st<="00000";
    elsif rising_edge(cmd_r) then rly_st(4 downto 0)<=dat(4 downto 0); r1<=dat(0);r2<=dat(1);r3<=dat(2);r4<=dat(3);r5<=dat(4);r6<=dat(5);r7<=dat(6);r8<=dat(7); end if;
  end process;
end architecture rtl;
