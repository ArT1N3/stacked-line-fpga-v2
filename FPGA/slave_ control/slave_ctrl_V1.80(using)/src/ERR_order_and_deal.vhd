--=============================================================================
-- err_order_and_deal - 脉宽指令识别与控制（封装）
--=============================================================================
-- 功能：脉宽协议指令路径的顶层封装。
--   连接脉宽检测器（err_order）和指令状态机（err_ctrl）。
--
-- 握手环路：
--   err_order检测脉冲→cmd_flag脉冲→err_ctrl解码
--   err_ctrl置位load_X→移位寄存器上传状态
--   移位寄存器完成→shift_done→err_ctrl返回free
--   err_ctrl置位rst_detector→err_order解锁以检测下一个脉冲
--
-- 关键连接：rst_detector（err_ctrl到err_order的反馈）
--   err_order检测到脉冲并进入lock状态后，err_ctrl处理指令。
--   当err_ctrl完成（返回free状态），它置位rst_detector='0'，
--   复位err_order回到unlock状态，准备接收下一个脉冲。
--   这实现了一个握手机制，防止err_order对同一脉冲重复触发。
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity err_order_and_deal is
  port (
    clk,rst,input,shift_done:in std_logic; address:in std_logic_vector(3 downto 0);
    en_charge,load_1,load_2,load_3:out std_logic
  );
end entity err_order_and_deal;

architecture rtl of err_order_and_deal is
  signal rst_detector:std_logic; signal cmd_bus:std_logic_vector(12 downto 0);
  signal cmd_flag,posedge_sig:std_logic;
  component err_order is port(clk,rst,input:in std_logic;cmd_flag:out std_logic;cmd_bus:out std_logic_vector(12 downto 0);posedge_out:out std_logic); end component;
  component err_ctrl is port(clk,rst,cmd_flag:in std_logic;cmd_bus:in std_logic_vector(12 downto 0);shift_done:in std_logic;address:in std_logic_vector(3 downto 0);posedge:in std_logic;load_1,load_2,load_3,rst_detecor,en_charge:out std_logic); end component;
begin
  u1:err_order port map(clk=>clk,rst=>rst_detector,input=>input,cmd_bus=>cmd_bus,cmd_flag=>cmd_flag,posedge_out=>posedge_sig);
  u2:err_ctrl port map(clk=>clk,rst=>rst,cmd_flag=>cmd_flag,cmd_bus=>cmd_bus,shift_done=>shift_done,address=>address,posedge=>posedge_sig,load_1=>load_1,load_2=>load_2,load_3=>load_3,rst_detecor=>rst_detector,en_charge=>en_charge);
end architecture rtl;
