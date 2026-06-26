--=============================================================================
-- lm75bd - LM75B温度传感器I2C驱动（LM75B_DRV1+分频+LED指示）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity lm75bd is port(clk_1m,clk_1ms:in std_logic; sda:inout std_logic; scl:out std_logic; lk_o:out std_logic; led:out std_logic; tem1:out std_logic_vector(8 downto 0)); end entity lm75bd;
architecture rtl of lm75bd is
  component lm75b_drv1 is port(clk_1M,SDA_IN,CLR:in std_logic; ADDR1:in std_logic_vector(2 downto 0); TEM1:out std_logic_vector(8 downto 0); SCL,SDA,DIR,LK_O:out std_logic); end component;
  component clk_div_500 is port(clk_in:in std_logic; div_out:out std_logic); end component;
  component const_3 is generic(const:integer:=1); port(result:out std_logic_vector(2 downto 0)); end component;
  signal led_clk,sda_out,sda_dir:std_logic; signal c3:std_logic_vector(2 downto 0);
begin
  u_drv:lm75b_drv1 port map(clk_1M=>clk_1m, SDA_IN=>sda, CLR=>'1', ADDR1=>c3, TEM1=>tem1, SCL=>scl, SDA=>sda_out, DIR=>sda_dir, LK_O=>lk_o);
  sda <= sda_out when sda_dir='1' else 'Z';
  u_div:clk_div_500 port map(clk_in=>clk_1ms, div_out=>led_clk);
  u_c3:const_3 generic map(const=>4) port map(result=>c3);
  led<=led_clk;
end architecture rtl;
