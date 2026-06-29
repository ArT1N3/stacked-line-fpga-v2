--=============================================================================
-- rcv_deal - UART帧接收校验（dat_store_rx+dat_confm_rx封装，22字节帧含Grp/Aux）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity rcv_deal is port(lock_in,lock_out,rst:in std_logic; addr:in std_logic_vector(4 downto 0); dat:in std_logic_vector(7 downto 0); confm:out std_logic; aux,cmd,grp:out std_logic_vector(7 downto 0); dat1,dat3,dat5,dat7,dat9,dat11,dat13:out std_logic_vector(15 downto 0); dat15:out std_logic_vector(7 downto 0)); end entity rcv_deal;
architecture rtl of rcv_deal is
  component dat_store_rx is port(dat:in std_logic_vector(7 downto 0); addr:in std_logic_vector(4 downto 0); lock_in,lock_out,rst:in std_logic; head,cmd,grp,aux,end2:out std_logic_vector(7 downto 0); dat1,dat3,dat5,dat7,dat9,dat11,dat13:out std_logic_vector(15 downto 0); dat15:out std_logic_vector(7 downto 0); chk:out std_logic_vector(15 downto 0)); end component;
  component dat_confm_rx is port(head,cmd,grp,aux,end2:in std_logic_vector(7 downto 0); dat1,dat3,dat5,dat7,dat9,dat11,dat13:in std_logic_vector(15 downto 0); dat15:in std_logic_vector(7 downto 0); chk:in std_logic_vector(15 downto 0); equal:out std_logic); end component;
  signal h_s,cmd_s,grp_s,aux_s,e2_s:std_logic_vector(7 downto 0);
  signal d1,d3,d5,d7,d9,d11,d13:std_logic_vector(15 downto 0); signal d15_s:std_logic_vector(7 downto 0); signal chk_s:std_logic_vector(15 downto 0);
begin
  cmd<=cmd_s;grp<=grp_s;aux<=aux_s;dat1<=d1;dat3<=d3;dat5<=d5;dat7<=d7;dat9<=d9;dat11<=d11;dat13<=d13;dat15<=d15_s;
  u_store:dat_store_rx port map(lock_in=>lock_in,lock_out=>lock_out,rst=>rst,addr=>addr,dat=>dat,head=>h_s,cmd=>cmd_s,grp=>grp_s,aux=>aux_s,end2=>e2_s,dat1=>d1,dat3=>d3,dat5=>d5,dat7=>d7,dat9=>d9,dat11=>d11,dat13=>d13,dat15=>d15_s,chk=>chk_s);
  u_valid:dat_confm_rx port map(head=>h_s,cmd=>cmd_s,grp=>grp_s,aux=>aux_s,end2=>e2_s,dat1=>d1,dat3=>d3,dat5=>d5,dat7=>d7,dat9=>d9,dat11=>d11,dat13=>d13,dat15=>d15_s,chk=>chk_s,equal=>confm);
end architecture rtl;
