--=============================================================================
-- trig_rvs - 翻转触发器（trig上升沿时rvs翻转）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity trig_rvs is port(trig:in std_logic; rvs:out std_logic); end entity trig_rvs;
architecture rtl of trig_rvs is signal dff:std_logic:='0'; signal dff_n:std_logic:='1';
begin
  process(trig)begin if rising_edge(trig) then dff<=dff_n; end if; end process;
  dff_n<=not dff; rvs<=dff;
end architecture rtl;
