--=============================================================================
-- rst_g - 上电复位发生器（DDR，约2us复位脉冲）
--=============================================================================
-- 上升沿计数0→110(饱和), 下降沿输出rst='0'当q≤100→约2us复位保持
-- 注意：当前工程未使用（不在.gprj中），外部RST引脚提供复位。
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity rst_g is port(clk:in std_logic;rst:out std_logic); end entity rst_g;
architecture rtl of rst_g is signal q:integer range 0 to 127:=0;
begin
  process(clk)
  begin
    if rising_edge(clk) then if q<110 then q<=q+1; end if; end if;
    if falling_edge(clk) then if q>100 then rst<='1'; else rst<='0'; end if; end if;
  end process;
end architecture rtl;
