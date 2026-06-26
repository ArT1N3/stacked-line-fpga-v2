--=============================================================================
-- clk_gen - 多时钟发生器（50MHz→5M/2M/1M/100k/10k/1ms/115200）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity clk_gen is port(clk_50m,rst:in std_logic; clk_2m,clk_1m,clk_100k,clk_1ms,clk_115200,clk_10k,clk_5m:out std_logic); end entity clk_gen;
architecture rtl of clk_gen is
  signal q0:integer range 0 to 63:=0; signal q,q2:integer range 0 to 63:=0;
  signal q4:integer range 0 to 120:=0; signal clk_1m2,clk_100k2:std_logic;
  signal qx1:integer range 0 to 6000:=0; signal q3:integer range 0 to 1000:=0;
begin
  -- 1MHz时钟（50MHz/50→1MHz，DDR，q<25时低）
  process(clk_50m,rst)begin
    if rst='0' then q<=0;clk_1m2<='0';clk_2m<='0';
    else
      if rising_edge(clk_50m) then if q<49 then q<=q+1; else q<=0; end if; end if;
      if falling_edge(clk_50m) then if q<25 then clk_1m2<='0'; else clk_1m2<='1'; end if; end if;
      if falling_edge(clk_50m) then if q<12 or(q>=25 and q<37) then clk_2m<='0'; else clk_2m<='1'; end if; end if;
    end if;
  end process;
  -- 5MHz时钟（50MHz/10→5MHz）
  process(clk_50m,rst)begin
    if rst='0' then q0<=0;clk_5m<='0';
    else
      if rising_edge(clk_50m) then if q0<9 then q0<=q0+1; else q0<=0; end if; end if;
      if falling_edge(clk_50m) then if q0<5 then clk_5m<='0'; else clk_5m<='1'; end if; end if;
    end if;
  end process;
  -- 115200波特率时钟（50MHz/54→~925.9kHz）
  process(clk_50m,rst)begin
    if rst='0' then q2<=0;clk_115200<='0';
    else
      if rising_edge(clk_50m) then if q2<53 then q2<=q2+1; else q2<=0; end if; end if;
      if falling_edge(clk_50m) then if q2<26 then clk_115200<='0'; else clk_115200<='1'; end if; end if;
    end if;
  end process;
  -- 100kHz时钟（50MHz/500→100kHz）
  process(clk_1m2,rst)begin
    if rst='0' then q3<=0;
    else
      if rising_edge(clk_50m) then if q3<499 then q3<=q3+1; else q3<=0; end if; end if;
      if falling_edge(clk_50m) then if q3<250 then clk_100k2<='0'; else clk_100k2<='1'; end if; end if;
    end if;
  end process;
  -- 1ms时钟（100kHz/100→1kHz→1ms周期）
  process(clk_100k2,rst)begin
    if rst='0' then q4<=0;
    else
      if rising_edge(clk_100k2) then if q4<99 then q4<=q4+1; else q4<=0; end if; end if;
      if falling_edge(clk_100k2) then if q4<49 then clk_1ms<='0'; else clk_1ms<='1'; end if; end if;
    end if;
  end process;
  -- 10kHz时钟（50MHz/5000→10kHz）
  process(clk_100k2,rst)begin
    if rst='0' then qx1<=0;
    else
      if rising_edge(clk_50m) then if qx1<4999 then qx1<=qx1+1; else qx1<=0; end if; end if;
      if falling_edge(clk_50m) then if qx1<2500 then clk_10k<='0'; else clk_10k<='1'; end if; end if;
    end if;
  end process;
  clk_1m<=clk_1m2; clk_100k<=clk_100k2;
end architecture rtl;
