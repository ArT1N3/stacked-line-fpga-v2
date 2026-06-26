--=============================================================================
-- rcv_deal - UART帧接收与校验（顶层封装）
--=============================================================================
-- 功能：UART帧组装与校验的顶层封装。
--   包含字节存储阵列（dat_store_rx）和校验和验证器（dat_confm_rx）。
--
-- 两级输出寄存：
--   第1级（dat_store_rx）：逐字节到达时存储，lock_in=延时rx_lk脉冲→按addr写入
--                         lock_out=延时帧完成脉冲→所有寄存器锁存到输出
--   第2级（dat_confm_rx）：同时校验所有帧字段，HEAD=0xEB, END2=0xAA, 校验和匹配
--                         confm='1'当三项条件全部满足（组合逻辑输出）
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity rcv_deal is
  port (
    lock_in,lock_out,rst:in std_logic; addr:in std_logic_vector(4 downto 0);
    dat:in std_logic_vector(7 downto 0); confm:out std_logic;
    cmd:out std_logic_vector(7 downto 0);
    dat1,dat3,dat5,dat7,dat9,dat11,dat13,dat15:out std_logic_vector(15 downto 0)
  );
end entity rcv_deal;

architecture rtl of rcv_deal is
  component dat_confm_rx is port(head,cmd,end2:in std_logic_vector(7 downto 0);dat1,dat3,dat5,dat7,dat9,dat11,dat13,dat15,chk:in std_logic_vector(15 downto 0);equal:out std_logic); end component;
  component dat_store_rx is port(dat:in std_logic_vector(7 downto 0);addr:in std_logic_vector(4 downto 0);lock_in,lock_out,rst:in std_logic;head,cmd,end2:out std_logic_vector(7 downto 0);dat1,dat3,dat5,dat7,dat9,dat11,dat13,dat15,chk:out std_logic_vector(15 downto 0)); end component;
  signal head_s,cmd_s,end2_s:std_logic_vector(7 downto 0);
  signal chk_s:std_logic_vector(15 downto 0);
  signal d1,d3,d5,d7,d9,d11,d13,d15:std_logic_vector(15 downto 0);
begin
  cmd<=cmd_s; dat1<=d1; dat3<=d3; dat5<=d5; dat7<=d7; dat9<=d9; dat11<=d11; dat13<=d13; dat15<=d15;
  u_store:dat_store_rx port map(lock_in=>lock_in,lock_out=>lock_out,rst=>rst,addr=>addr,dat=>dat,head=>head_s,cmd=>cmd_s,dat1=>d1,dat3=>d3,dat5=>d5,dat7=>d7,dat9=>d9,dat11=>d11,dat13=>d13,dat15=>d15,chk=>chk_s,end2=>end2_s);
  u_validate:dat_confm_rx port map(head=>head_s,cmd=>cmd_s,dat1=>d1,dat3=>d3,dat5=>d5,dat7=>d7,dat9=>d9,dat11=>d11,dat13=>d13,dat15=>d15,chk=>chk_s,end2=>end2_s,equal=>confm);
end architecture rtl;
