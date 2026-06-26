--=============================================================================
-- err_shift_top - 状态上传移位寄存器与输出选择器（封装）
--=============================================================================
-- 功能：封装移位寄存器（err_shift_test）与2选1输出选择器（mux21a），
--   用于在TXD输出端插入帧间间隔。
--
-- 输出选择器操作：
--   out_sel='0' → 选err_out（移位数据送往TXD）
--   out_sel='1' → 选VCC（空闲高电平/RS-232 mark）
--   10位上传帧内（共100us）：前1us空闲、中8us数据、后1us空闲
--
-- 注意（mux21a取反，2022.11.13修改）：
--   y=NOT(a)当sel='0', y=NOT(b)当sel='1'
--   因此VCC('1')在b输入端 → TXD=NOT('1')='0'（间隔期间）
--   err_out在a输入端 → TXD=NOT(err_out)（数据期间）
--   这反转了串行输出，配合外部RS-232驱动器再次取反后得到正确极性。
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity err_shift_top is
  port (
    clk,rst,load_1,load_2,load_3:in std_logic;
    err_total,err_charge,en_state:in std_logic_vector(10 downto 1);
    shift_done,dout:out std_logic
  );
end entity err_shift_top;

architecture rtl of err_shift_top is
  component err_shift_test is port(clk,rst:in std_logic;err_total,err_charge,en_state:in std_logic_vector(10 downto 1);load_1,load_2,load_3:in std_logic;err_out,out_sel,shift_done:out std_logic); end component;
  component mux21a is port(a,b,sel:in std_logic;y:out std_logic); end component;
  signal dout_net,out_sel_net:std_logic; constant VCC:std_logic:='1';
begin
  u1:err_shift_test port map(clk=>clk,rst=>rst,err_charge=>err_charge,err_total=>err_total,en_state=>en_state,shift_done=>shift_done,out_sel=>out_sel_net,load_1=>load_1,load_2=>load_2,load_3=>load_3,err_out=>dout_net);
  u2:mux21a port map(sel=>out_sel_net,a=>dout_net,b=>VCC,y=>dout); -- 空闲间隔插入（含取反）
end architecture rtl;
