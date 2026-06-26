--=============================================================================
-- aux_trig - 辅助触发门控（6路AND: Auxx = Cxx AND trig）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity aux_trig is port(c01,c02,c03,c04,c05,c06,trig:in std_logic; aux1,aux2,aux3,aux4,aux5,aux6:out std_logic); end entity aux_trig;
architecture rtl of aux_trig is
begin aux1<=c01 and trig;aux2<=c02 and trig;aux3<=c03 and trig;aux4<=c04 and trig;aux5<=c05 and trig;aux6<=c06 and trig; end architecture rtl;
