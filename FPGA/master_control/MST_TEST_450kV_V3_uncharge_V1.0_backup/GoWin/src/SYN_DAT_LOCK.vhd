--=============================================================================
-- syn_dat_lock - 同步数据锁存器（LOCK上升沿锁存并拼接扩展数据）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity syn_dat_lock is port(lock:in std_logic; dat1,dat2,dat3,dat4,dat5:in std_logic_vector(15 downto 0); dt1,dt2,dt3,dt4,dt5:out std_logic_vector(15 downto 0); ext1,ext2,ext3:out std_logic_vector(23 downto 0); err_en:out std_logic_vector(7 downto 0)); end entity syn_dat_lock;
architecture rtl of syn_dat_lock is
begin
  process(lock)begin
    if rising_edge(lock) then
      dt1<=dat1;dt2<=dat2;dt3<=dat3;dt4<=dat4;dt5<=dat5;err_en<=dat5(7 downto 0);
      ext1(23 downto 8)<=dat1;ext1(7 downto 0)<=dat2(15 downto 8);
      ext2(23 downto 16)<=dat2(7 downto 0);ext2(15 downto 0)<=dat3;
      ext3(23 downto 8)<=dat4;ext3(7 downto 0)<=dat5(15 downto 8);
    end if;
  end process;
end architecture rtl;
