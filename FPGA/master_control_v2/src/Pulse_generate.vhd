--=============================================================================
-- pulse_generate - 脉冲生成器（LOCK锁存t_pls/n_pls，DDR输出pls/WK，n个脉冲后停止）
--=============================================================================
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity pulse_generate is port(clk_100us,clr,trig,lock:in std_logic; t_pls,n_pls:in std_logic_vector(15 downto 0); pls,wk:out std_logic; t_ps,n_ps:out std_logic_vector(15 downto 0)); end entity pulse_generate;
architecture rtl of pulse_generate is
  signal q1:unsigned(15 downto 0):=to_unsigned(65528,16); signal t,n:unsigned(15 downto 0); signal n1:unsigned(15 downto 0):=to_unsigned(65534,16);
begin
  t_ps<=t_pls; n_ps<=n_pls;
  process(lock)begin if rising_edge(lock) then t<=unsigned(t_pls); if unsigned(n_pls)<=60000 then n<=unsigned(n_pls); else n<=to_unsigned(60000,16); end if; end if; end process;
  process(clk_100us,clr)
  begin
    if clr='1' then n1<=to_unsigned(65534,16);q1<=to_unsigned(65528,16);pls<='0';wk<='0';
    else
      if rising_edge(clk_100us) then
        if trig='1' then q1<=(others=>'0');
        else if n1<n then if q1<t-1 then q1<=q1+1; else q1<=(others=>'0'); end if; else q1<=to_unsigned(65528,16); end if; end if;
      end if;
      if falling_edge(clk_100us) then if q1=1 then pls<='1'; else pls<='0'; end if; end if;
      if falling_edge(clk_100us) then
        if trig='1' then n1<=(others=>'0'); wk<='0';
        else if n1<n then if q1=2 then n1<=n1+1; end if; wk<='1'; else n1<=to_unsigned(65534,16); wk<='0'; end if; end if;
      end if;
    end if;
  end process;
end architecture rtl;
