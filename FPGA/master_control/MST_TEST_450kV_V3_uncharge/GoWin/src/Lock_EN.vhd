--=============================================================================
-- lock_en - 数据锁存使能（Lock上升沿，根据SEL选择输出到D1..D8或D9..D16）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity lock_en is port(lock:in std_logic; sel:in std_logic_vector(7 downto 0); da1,da2,da3,da4,da5,da6,da7:in std_logic_vector(15 downto 0); da8:in std_logic_vector(7 downto 0); d1,d2,d3,d4,d5,d6,d7:out std_logic_vector(15 downto 0); d8:out std_logic_vector(7 downto 0); d9,d10,d11,d12,d13,d14,d15:out std_logic_vector(15 downto 0); d16:out std_logic_vector(7 downto 0)); end entity lock_en;
architecture rtl of lock_en is
begin
  process(lock)
  begin
    if rising_edge(lock) then
      if sel="00000001" then d1<=da1;d2<=da2;d3<=da3;d4<=da4;d5<=da5;d6<=da6;d7<=da7;d8<=da8;
      elsif sel="00000010" then d9<=da1;d10<=da2;d11<=da3;d12<=da4;d13<=da5;d14<=da6;d15<=da7;d16<=da8; end if;
    end if;
  end process;
end architecture rtl;
