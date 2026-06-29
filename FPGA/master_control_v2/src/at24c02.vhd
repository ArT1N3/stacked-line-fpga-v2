--=============================================================================
-- at24c02 - AT24C02 I2C EEPROM控制器（Flash_I2C_core+SDA双向+SCL输出）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity at24c02 is port(rd_wr_n,start,clk_1m:in std_logic; at2402_sda:inout std_logic; addr:in std_logic_vector(7 downto 0); dat_in:in std_logic_vector(7 downto 0); ok:out std_logic; at2402_scl:out std_logic; dat_r:out std_logic_vector(7 downto 0)); end entity at24c02;
architecture rtl of at24c02 is
  component flash_i2c_core is port(clk_1m,rd_wr_n,sda_in,start:in std_logic; addr,dat_in:in std_logic_vector(7 downto 0); scl,sda_out,dir:out std_logic; ok:out std_logic; dat_r:out std_logic_vector(7 downto 0)); end component;
  signal sda_out,dir,sda_in_s:std_logic;
begin
  sda_in_s<=at2402_sda;
  u_core:flash_i2c_core port map(clk_1m=>clk_1m,rd_wr_n=>rd_wr_n,sda_in=>sda_in_s,start=>start,addr=>addr,dat_in=>dat_in,scl=>at2402_scl,sda_out=>sda_out,dir=>dir,ok=>ok,dat_r=>dat_r);
  at2402_sda<=sda_out when dir='1' else 'Z'; -- dir=1输出, dir=0输入
end architecture rtl;
