--=============================================================================
-- err_charge_or_short - 故障合并OR逻辑（短路OR供电）
--=============================================================================
-- 极性处理：short_in低有效→取反, charge_in高有效→直通
-- 同步寄存：rising_edge(clk)寄存结果，防止LED闪烁
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity err_charge_or_short is port(clk:in std_logic;short_in,charge_in:in std_logic_vector(10 downto 1);err_out:out std_logic_vector(10 downto 1)); end entity err_charge_or_short;
architecture rtl of err_charge_or_short is
begin
  process(clk)begin if rising_edge(clk) then err_out<=(not short_in)or charge_in; end if; end process;
end architecture rtl;
