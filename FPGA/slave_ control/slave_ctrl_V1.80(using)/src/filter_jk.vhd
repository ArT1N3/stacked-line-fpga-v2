--=============================================================================
-- filter_jk - 50级多数表决毛刺滤波器
--=============================================================================
-- 功能：需要50个连续相同采样才改变输出。50MHz下提供1us抗毛刺能力。
--
-- 工作原理：50位移位寄存器（q）作为滑动窗口。
--   快速通道优化：当x==pulse_in（输出匹配输入），整个移位寄存器填充该值→0延迟
--   仅信号跳变时需要50个时钟（1us）才能传播到输出→毛刺被过滤
--   en='1'→滤波器运行, en='0'→冻结保持, rst='0'→复位为全'1'（默认无故障）
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity filter_jk is port(clk,rst,en,pulse_in:in std_logic; pulse_out:out std_logic); end entity filter_jk;

architecture rtl of filter_jk is
  signal q:std_logic_vector(49 downto 0):=(others=>'1'); signal x:std_logic:='0';
begin
  process(clk,rst)
  begin
    if rst='0' then q<=(others=>'1'); -- 复位：全高（无故障）
    elsif rising_edge(clk) then
      if en='1' then
        if x=pulse_in then q<=(others=>x); -- 快速通道：输出已正确
        else q<=q(48 downto 0)&pulse_in; x<=q(49); end if; -- 跳变中：移位输入
      end if;
    end if;
  end process;
  pulse_out<=x;
end architecture rtl;
