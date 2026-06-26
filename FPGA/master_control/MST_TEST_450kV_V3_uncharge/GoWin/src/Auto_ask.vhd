--=============================================================================
-- auto_ask - 自动查询（Rx='1'清零，DDR输出，q=147时trig=1，q>=145时Ask=1）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity auto_ask is port(clk,rx:in std_logic; trig,ask:out std_logic); end entity auto_ask;
architecture rtl of auto_ask is signal q:unsigned(7 downto 0):=(others=>'0');
begin
  process(clk,rx)
  begin
    if rx='1' then q<=(others=>'0');ask<='0';trig<='0';
    else
      if rising_edge(clk) then if q<150 then q<=q+1; else q<=(others=>'0'); end if; end if;
      if falling_edge(clk) then if q>=145 then ask<='1'; else ask<='0'; end if; end if;
      if falling_edge(clk) then if q=147 then trig<='1'; else trig<='0'; end if; end if;
    end if;
  end process;
end architecture rtl;
