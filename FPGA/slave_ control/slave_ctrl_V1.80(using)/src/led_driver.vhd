--=============================================================================
-- led_driver - LED输出选择器（2选1）
--=============================================================================
-- err_en='0'→上电闪烁模式, err_en='1'→实时故障状态显示
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity led_driver is port(red_led_in,flicker_out:in std_logic_vector(10 downto 1);err_en:in std_logic;red_led_out:out std_logic_vector(10 downto 1)); end entity led_driver;
architecture rtl of led_driver is
begin
  process(err_en,red_led_in,flicker_out)
  begin
    if err_en='0' then red_led_out<=flicker_out; else red_led_out<=red_led_in; end if;
  end process;
end architecture rtl;
