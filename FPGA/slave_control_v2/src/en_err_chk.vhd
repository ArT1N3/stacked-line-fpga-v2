--=============================================================================
-- en_err_chk - 使能门控短路输入掩码
--=============================================================================
-- EN='1'时所有输出强制为'1'（屏蔽短路输入），防止主控空闲期间的误检。
-- EN='0'时直通。EN由滤波后的RXD驱动：主控拉低RXD时取消屏蔽。
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity en_err_chk is port(en:in std_logic;in1:in std_logic_vector(10 downto 1);out1:out std_logic_vector(10 downto 1)); end entity en_err_chk;
architecture rtl of en_err_chk is
begin out1<=in1 or(in1'range=>en); end architecture rtl;
