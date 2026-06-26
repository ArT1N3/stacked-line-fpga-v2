--=============================================================================
-- order_shift - 脉宽指令检测与状态上传（顶层封装）
--=============================================================================
-- 功能：脉宽协议通信路径的顶层封装。
--   包含指令检测器（err_order_and_deal）和状态上传移位寄存器（err_shift_top）。
--
-- 数据流：
--   RXD → err_order_and_deal → 测量脉宽 → 解码指令 → 产生load_1/2/3+en_charge
--   故障/状态 → err_shift_top → 并行加载 → 串行移位输出到TXD → shift_done握手
--
-- 握手协议：
--   1. 主控在RXD上发送低脉冲（脉宽编码指令）
--   2. err_order_and_deal测量脉宽、解码、置位load_X='0'
--   3. err_shift_top加载对应状态数据到移位寄存器
--   4. err_shift_top在TXD上串行移位输出10位
--   5. 完成后shift_done='1' → err_order_and_deal返回空闲
--
-- 一 pin 双协议：
--   RXD引脚由脉宽协议和UART协议共享：
--     脉宽：主控发送低脉冲（100-500us），UART起始位仅8.7us，err_order忽略<150us的脉冲
--     UART：主控发送标准串行帧，空闲高电平与脉宽空闲一致
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity order_shift is
  port (
    clk:in std_logic; rst:in std_logic; rs_232:in std_logic;
    address:in std_logic_vector(3 downto 0);
    err_total,err_charge:in std_logic_vector(10 downto 1);
    en_charge:out std_logic; en_state:in std_logic_vector(10 downto 1);
    txd_out:out std_logic
  );
end entity order_shift;

architecture rtl of order_shift is
  signal load_1,load_2,load_3,shift_done:std_logic;
  component err_order_and_deal is port(clk,rst,input,shift_done:in std_logic;address:in std_logic_vector(3 downto 0);en_charge,load_1,load_2,load_3:out std_logic); end component;
  component err_shift_top is port(clk,rst,load_1,load_2,load_3:in std_logic;err_total,err_charge,en_state:in std_logic_vector(10 downto 1);shift_done,dout:out std_logic); end component;
begin
  u1:err_order_and_deal port map(clk=>clk,rst=>rst,input=>rs_232,shift_done=>shift_done,address=>address,en_charge=>en_charge,load_1=>load_1,load_2=>load_2,load_3=>load_3);
  u2:err_shift_top port map(clk=>clk,rst=>rst,load_1=>load_1,load_2=>load_2,load_3=>load_3,err_total=>err_total,err_charge=>err_charge,en_state=>en_state,shift_done=>shift_done,dout=>txd_out);
end architecture rtl;
