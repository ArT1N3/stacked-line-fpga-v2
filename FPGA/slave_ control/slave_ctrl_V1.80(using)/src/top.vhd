--=============================================================================
-- top - 高云GW1N-9C FPGA顶层实体
--=============================================================================
-- 功能：连接外部I/O引脚到slave_ctrl核心。增加RXD毛刺滤波(mac_16)
--   和short_in使能掩码(en_err_chk)。
--
-- 信号流：
--   RXD(pin26)→mac_16(320ns滤波)→rxd_filtered→slave_ctrl.RXD, en_err_chk.EN
--   short_in→en_err_chk(RXD高时屏蔽)→short_masked→slave_ctrl.short_in
--   charge_in/address→直通→slave_ctrl
--   slave_ctrl→TXD/en_work/en_trig/red_led→IO引脚
--
-- 注意：此文件从Quartus BDF自动生成后手工适配高云GW1N。
--   .bdf原理图为Quartus专用，高云EDA不使用。本VHD文件为权威顶层。
--=============================================================================
library ieee; use ieee.std_logic_1164.all;

entity top is
  port(clk,rst,RXD:in std_logic; address:in std_logic_vector(3 downto 0);
       charge_in,short_in:in std_logic_vector(10 downto 1);
       TXD:out std_logic; en_trig,en_work,red_led:out std_logic_vector(10 downto 1));
end entity top;

architecture rtl of top is
  component slave_ctrl is port(clk,rst,RXD:in std_logic;address:in std_logic_vector(3 downto 0);charge_in,short_in:in std_logic_vector(10 downto 1);TXD:out std_logic;en_trig,en_work,red_led:out std_logic_vector(10 downto 1)); end component;
  component en_err_chk is port(EN:in std_logic;IN1:in std_logic_vector(10 downto 1);OUT1:out std_logic_vector(10 downto 1)); end component;
  component mac_16 is port(IN1,clk:in std_logic;O1:out std_logic); end component;
  signal rxd_filtered,clk_inv:std_logic; signal short_masked:std_logic_vector(10 downto 1);
begin
  clk_inv<=not clk; -- mac_16 DDR采样用反相时钟
  b2v_inst:slave_ctrl port map(clk=>clk,rst=>rst,RXD=>rxd_filtered,address=>address,charge_in=>charge_in,short_in=>short_masked,TXD=>TXD,en_trig=>en_trig,en_work=>en_work,red_led=>red_led);
  b2v_inst1:en_err_chk port map(EN=>rxd_filtered,IN1=>short_in,OUT1=>short_masked); -- RXD空闲高时屏蔽短路输入
  b2v_inst4:mac_16 port map(IN1=>RXD,clk=>clk_inv,O1=>rxd_filtered); -- RXD毛刺滤波320ns
end architecture rtl;
