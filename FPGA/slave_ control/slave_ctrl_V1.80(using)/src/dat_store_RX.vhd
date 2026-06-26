--=============================================================================
-- dat_store_rx - UART帧字节存储阵列
--=============================================================================
-- 功能：
--   两级帧组装：
--     第1级（写入）：每个接收到的字节在lock_in上升沿按addr位置存储。
--     第2级（锁存）：在lock_out上升沿，所有组装好的帧字段同时锁存到输出。
--
-- 帧内存映射（20字节，5位地址空间）：
--   addr=1 ("00001"): HEAD[7:0]      帧起始标记（应为0xEB）
--   addr=2 ("00010"): CMD[7:0]       指令字节
--   addr=3-4:         dat1[15:0]     数据字1
--   addr=5-6:         dat3[15:0]     数据字3
--   ...                              数据字5,7,9,11,13
--   addr=17("10001"): dat15[15:8]    数据字15（仅高字节，低字节=0x00）
--   addr=18-19:       CHK[15:0]      校验和
--   addr=20("10100"): END[7:0]       帧结束标记（应为0xAA）
--
-- 为何需要两级？
--   帧是逐字节组装的。如果输出持续更新，下游逻辑会看到
--   部分组装（可能是垃圾）的帧数据。两级设计确保输出
--   仅在完整帧接收完毕后才改变。
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity dat_store_rx is
  port (
    dat:in std_logic_vector(7 downto 0); addr:in std_logic_vector(4 downto 0);
    lock_in,lock_out,rst:in std_logic;
    head,cmd,end2:out std_logic_vector(7 downto 0);
    dat1,dat3,dat5,dat7,dat9,dat11,dat13,dat15:out std_logic_vector(15 downto 0);
    chk:out std_logic_vector(15 downto 0)
  );
end entity dat_store_rx;

architecture rtl of dat_store_rx is
  signal head1,cmd1,end1:std_logic_vector(7 downto 0);
  signal da1,da3,da5,da7,da9,da11,da13,da15,ck1:std_logic_vector(15 downto 0);
begin
  -- 第2级：输出寄存器（帧锁存），lock_out上升沿时所有字段同时更新
  process(lock_out,rst)
  begin
    if rst='0' then
      head<=(others=>'0');cmd<=(others=>'0');end2<=(others=>'0');
      dat1<=(others=>'0');dat3<=(others=>'0');dat5<=(others=>'0');dat7<=(others=>'0');
      dat9<=(others=>'0');dat11<=(others=>'0');dat13<=(others=>'0');dat15<=(others=>'0');
      chk<=(others=>'0');
    elsif rising_edge(lock_out) then
      head<=head1;cmd<=cmd1;end2<=end1;
      dat1<=da1;dat3<=da3;dat5<=da5;dat7<=da7;dat9<=da9;dat11<=da11;dat13<=da13;dat15<=da15;
      chk<=ck1;
    end if;
  end process;
  -- 第1级：字节存储（地址解码写入），lock_in上升沿时存储一个字节
  process(lock_in)
  begin
    if rising_edge(lock_in) then
      case addr is
        when "00001"=>head1<=dat;          when "00010"=>cmd1<=dat;
        when "00011"=>da1(15 downto 8)<=dat; when "00100"=>da1(7 downto 0)<=dat;
        when "00101"=>da3(15 downto 8)<=dat; when "00110"=>da3(7 downto 0)<=dat;
        when "00111"=>da5(15 downto 8)<=dat; when "01000"=>da5(7 downto 0)<=dat;
        when "01001"=>da7(15 downto 8)<=dat; when "01010"=>da7(7 downto 0)<=dat;
        when "01011"=>da9(15 downto 8)<=dat; when "01100"=>da9(7 downto 0)<=dat;
        when "01101"=>da11(15 downto 8)<=dat;when "01110"=>da11(7 downto 0)<=dat;
        when "01111"=>da13(15 downto 8)<=dat;when "10000"=>da13(7 downto 0)<=dat;
        when "10001"=>da15(15 downto 8)<=dat; da15(7 downto 0)<=(others=>'0'); -- 最后数据字仅高字节
        when "10010"=>ck1(15 downto 8)<=dat; when "10011"=>ck1(7 downto 0)<=dat;
        when "10100"=>end1<=dat;
        when others=>null;
      end case;
    end if;
  end process;
end architecture rtl;
