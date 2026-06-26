--=============================================================================
-- pulse_charge_m - 充电脉冲控制器（LOCK锁存T_BASE，clk_100us计数，q1在1~T间T_OVER=1）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity pulse_charge_m is port(clk_100us,clr,trig,lock:in std_logic; t_base:in std_logic_vector(15 downto 0); t_over:out std_logic; t_chg:out std_logic_vector(15 downto 0)); end entity pulse_charge_m;
architecture rtl of pulse_charge_m is signal q1:unsigned(15 downto 0):=to_unsigned(65532,16); signal t:unsigned(15 downto 0);
begin
  t_chg<=std_logic_vector(t);
  process(lock)begin if rising_edge(lock) then t<=unsigned(t_base); end if; end process;
  process(clk_100us,clr)
  begin
    if clr='1' then q1<=to_unsigned(65532,16); t_over<='0';
    elsif rising_edge(clk_100us) then
      if trig='1' then q1<=(others=>'0'); else if q1<=t+1 then q1<=q1+1; end if; end if;
      if q1>=1 and q1<=t then t_over<='1'; else t_over<='0'; end if;
    end if;
  end process;
end architecture rtl;
