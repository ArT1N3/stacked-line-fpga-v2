--=============================================================================
-- comp_clr - 零比较器（地址计数器清零检测）
--=============================================================================
-- same='1'当in1="00000"→地址计数器回零，门控addr_en防止帧完成后重启计数
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity comp_clr is port(in1:in std_logic_vector(4 downto 0);same:out std_logic); end entity comp_clr;
architecture rtl of comp_clr is
begin same<='1' when in1="00000" else '0'; end architecture rtl;
