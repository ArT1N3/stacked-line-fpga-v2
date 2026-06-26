--=============================================================================
-- err_detector_block - 单通道故障检测器
--=============================================================================
-- 功能：每通道故障检测流水线：
--   err_in → mac_32（毛刺滤波器，3.2ms窗口）→ pulse_filtered（干净信号）
--   pulse_filtered → err_dff（故障锁存器，由滤波输出作为时钟）
--
-- 为何用滤波信号作为DFF时钟？
--   mac_32的输出（pulse_filtered）作为err_dff的"干净时钟"。
--   当mac_32判定确实存在故障（32个连续采样一致），其输出上升。
--   此上升沿触发err_dff，锁存永久的'1'（故障已记录）。
--   err_dff只能通过rst='0'（来自UART指令x"01"）清除。
--   这实现了"粘滞"故障指示：一旦检测到故障，保持锁存直到主控显式复位。
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity err_detector_block is
  port (clk,rst,en,err_in:in std_logic; err_out:out std_logic);
end entity err_detector_block;

architecture rtl of err_detector_block is
  component mac_32 is port(in1,clk:in std_logic;o1:out std_logic); end component;
  component err_dff is port(clk,rst,en,d:in std_logic;q:out std_logic); end component;
  constant logic_vcc:std_logic:='1'; -- err_dff在故障边沿时始终锁存'1'
  signal pulse_filtered:std_logic;    -- mac_32输出（故障检测到时的干净上升沿）
begin
  u1:mac_32 port map(clk=>clk,in1=>err_in,o1=>pulse_filtered); -- 32级过采样毛刺滤波
  u2:err_dff port map(clk=>pulse_filtered,rst=>rst,en=>en,d=>logic_vcc,q=>err_out); -- 故障锁存
end architecture rtl;
