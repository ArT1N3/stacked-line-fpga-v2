--=============================================================================
-- interval_sel - 帧间间隔时序发生器（10us周期）
--=============================================================================
-- 功能：产生10us周期，前1us高（空闲间隔）、中8us低（数据窗口）、后1us高（空闲间隔）。
-- 注意：当前设计中未使用，时序逻辑已集成到ERR_shift_test内部。保留作为参考。
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity interval_sel is port(clk,sel_in:in std_logic;sel_out:out std_logic); end entity interval_sel;
architecture rtl of interval_sel is
  signal interval_count:integer range 0 to 499:=0; signal sel_out_buf:std_logic:='1';
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if sel_in='1' then
        if interval_count=0 then sel_out_buf<='1'; interval_count<=interval_count+1;
        elsif interval_count=49 then sel_out_buf<='0'; interval_count<=interval_count+1;
        elsif interval_count=449 then sel_out_buf<='1'; interval_count<=interval_count+1;
        elsif interval_count=499 then interval_count<=0;
        else interval_count<=interval_count+1; end if;
      else sel_out_buf<='1'; end if;
    end if;
  end process;
  sel_out<=sel_out_buf;
end architecture rtl;
