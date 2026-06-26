--=============================================================================
-- led_flicker - LED上电闪烁模式发生器
--=============================================================================
-- 功能：FPGA复位后产生约2秒基于地址的闪烁模式，然后切换到正常故障指示。
-- 闪烁作为上电"我还活着"的视觉指示，操作员可目视验证FPGA配置正确和地址拨码正确。
--
-- 两阶段行为：
--   第1阶段（前约2秒，err_en='0'）：LED显示地址闪烁，10Hz、50%占空比
--     LED[4:1]=addr_in, LED[6:5]="00", LED[10:7]=NOT addr_in
--   第2阶段（2秒后，err_en='1'）：切换到实时故障状态显示
--
-- 时序：
--   clk_500ms: 2Hz, cnt_1计数0→4=2秒闪烁持续时间
--   clk_5ms: 200Hz, cnt_2计数0→100=500ms周期, 50%占空比
--=============================================================================

library ieee;
use ieee.std_logic_1164.all; use ieee.numeric_std.all;

entity led_flicker is
  port (clk_5ms,clk_500ms:in std_logic; addr_in:in std_logic_vector(3 downto 0); flicker_out:out std_logic_vector(10 downto 1); err_en:out std_logic);
end entity led_flicker;

architecture rtl of led_flicker is
  signal cnt_1,cnt_2:unsigned(7 downto 0):=(others=>'0'); signal cnt2_en:std_logic:='0';
begin
  -- 阶段控制器（clk_500ms域）：计数4次×500ms=2秒
  process(clk_500ms)
  begin
    if rising_edge(clk_500ms) then
      if cnt_1<4 then cnt_1<=cnt_1+1; cnt2_en<='1'; err_en<='0'; -- 闪烁阶段
      else cnt_1<=(others=>'1'); cnt2_en<='0'; err_en<='1'; end if; -- 切换故障显示
    end if;
  end process;
  -- 闪烁模式发生器（clk_5ms域）：100步×5ms=500ms周期
  process(cnt2_en,clk_5ms)
  begin
    if cnt2_en='1' then
      if rising_edge(clk_5ms) then
        if cnt_2<100 then cnt_2<=cnt_2+1; else cnt_2<=(others=>'0'); end if;
        if cnt_2<50 then flicker_out<=(others=>'0'); -- 前250ms全灭
        else flicker_out(4 downto 1)<=addr_in; flicker_out(10 downto 7)<=not addr_in; flicker_out(6 downto 5)<="00"; end if;
      end if;
    end if;
  end process;
end architecture rtl;
