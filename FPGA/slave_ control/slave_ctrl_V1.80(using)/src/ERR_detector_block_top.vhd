--=============================================================================
-- err_detector_block_top - 10通道短路故障检测器阵列
--=============================================================================
-- 功能：使用for-generate循环实例化10个相同的err_detector_block模块。
--   每个通道独立检测故障。
--
-- 架构改进（for-generate替代手动实例化）：
--   原代码有10行独立的u1..u10端口映射（88行代码）。
--   for-generate循环将其缩减为8行，同时产生完全相同的硬件。
--   好处：更少维护代码、通道数易调整、无复制粘贴错误。
--   高云Synplify Pro综合器完全支持for-generate。
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity err_detector_block_top is
  port (
    clk,rst,en:in std_logic;
    short_err_in:in std_logic_vector(10 downto 1);
    short_err_out:out std_logic_vector(10 downto 1)
  );
end entity err_detector_block_top;

architecture rtl of err_detector_block_top is
  component err_detector_block is port(clk,rst,en,err_in:in std_logic;err_out:out std_logic); end component;
begin
  -- 生成10个相同的故障检测通道（i=1到10），综合时展开为10个并行硬件实例
  gen_channels:for i in 1 to 10 generate
    u:err_detector_block port map(clk=>clk,rst=>rst,en=>en,err_in=>short_err_in(i),err_out=>short_err_out(i));
  end generate gen_channels;
end architecture rtl;
