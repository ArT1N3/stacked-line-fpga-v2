--=============================================================================
-- auto_addr_dly - 自动地址延时器（DDR，q1=Addr*8时Txd_trig=1）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity auto_addr_dly is port(clk_500us,clr:in std_logic; addr:in std_logic_vector(4 downto 0); txd_trig:out std_logic); end entity auto_addr_dly;
architecture rtl of auto_addr_dly is signal q1:integer range 0 to 250:=0; signal ref:std_logic_vector(7 downto 0);
begin
  ref(7 downto 3)<=addr; ref(2 downto 0)<="000";
  process(clk_500us,clr)
  begin
    if clr='1' then q1<=0;
    else
      if rising_edge(clk_500us) then if q1<250 then q1<=q1+1; end if; end if;
      if falling_edge(clk_500us) then if q1=to_integer(unsigned(ref)) then txd_trig<='1'; else txd_trig<='0'; end if; end if;
    end if;
  end process;
end architecture rtl;
