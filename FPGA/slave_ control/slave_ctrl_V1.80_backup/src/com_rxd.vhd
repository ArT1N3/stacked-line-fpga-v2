--=============================================================================
-- com_rxd - UART多帧接收器（顶层）
--=============================================================================
-- 功能：
--   接收来自主控的UART字节流，组装20字节帧，校验完整性
--   （帧头+校验和），输出解析后的指令和数据字。
--
-- 帧格式（共20字节）：
--   字节1:   HEAD = 0xEB（帧起始标记）
--   字节2:   CMD  = 指令字节
--   字节3-4: dat1（16位数据字，高字节在前）
--   字节5-6: dat3   ...  字节15-16: dat13
--   字节17:  dat15（仅高字节，低字节=0x00）
--   字节18-19: CHK（字节2-17的16位校验和）
--   字节20:  END2 = 0xAA（帧结束标记）
--
-- 数据流：
--   RXD引脚 → com_rx（UART字节接收器）→ rx_byte[7:0]
--     ↓ rx_lk（锁存脉冲，每接收一个字节产生一次）
--   countor_addr_rx_cnt（字节地址计数器1→20）
--     ↓ addr_cnt[4:0]
--   dat_store_rx（按地址存储字节）
--     ↓ 组装完成的帧（HEAD, CMD, dat1..dat15, CHK, END）
--   dat_confm_rx（校验和验证）
--     ↓ confm脉冲（帧确认有效）
--
-- 时序：
--   clk = 约961.5kHz（波特率时钟，115200波特的8倍过采样）
--   每字节约87us（10位×8.68us @115200波特）
--   完整20字节帧约1.74ms
--   超时：约400个时钟周期（约416us）——帧不完整时复位
--
-- 信号对齐（delay_1链）：
--   lk → lk_d1 → lk_d2          （字节锁存的2级延时）
--   addr_co → co_d1 → co_d2     （帧完成的2级延时）
--   confm = confm_int AND co_d2 （最终门控，产生干净脉冲）
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity com_rxd is
  port (
    din   : in  std_logic;          -- UART RX串行输入
    clk   : in  std_logic;          -- 约961.5kHz波特率时钟
    rst   : in  std_logic;          -- 异步复位（低有效）
    confm : out std_logic;          -- 帧确认脉冲（1周期）
    cmd   : out std_logic_vector(7 downto 0);   -- 指令字节
    dat1, dat3, dat5, dat7  : out std_logic_vector(15 downto 0);
    dat9, dat11, dat13, dat15 : out std_logic_vector(15 downto 0)
  );
end entity com_rxd;

architecture rtl of com_rxd is
  component com_rx is port(clk,din:in std_logic;busy,lk:out std_logic;dat:out std_logic_vector(7 downto 0)); end component;
  component countor_t_over is port(clk,clr:in std_logic;co:out std_logic); end component;
  component countor_addr_rx_cnt is port(clk,clk2,en:in std_logic;qout:out std_logic_vector(4 downto 0);co:out std_logic); end component;
  component comp_clr is port(in1:in std_logic_vector(4 downto 0);same:out std_logic); end component;
  component rcv_deal is port(lock_in,lock_out,rst:in std_logic;addr:in std_logic_vector(4 downto 0);dat:in std_logic_vector(7 downto 0);confm:out std_logic;cmd:out std_logic_vector(7 downto 0);dat1,dat3,dat5,dat7,dat9,dat11,dat13,dat15:out std_logic_vector(15 downto 0)); end component;
  component delay_1 is port(clk,in1:in std_logic;dly_out:out std_logic); end component;

  signal clk_inv:std_logic; signal rx_lk,rx_busy:std_logic; signal rx_byte:std_logic_vector(7 downto 0);
  signal addr_cnt:std_logic_vector(4 downto 0); signal addr_co,addr_clr,addr_en,tmo_co,tmo_clr:std_logic;
  signal lk_d1,lk_d2,co_d1,co_d2,confm_int:std_logic;
begin
  clk_inv<=not clk;
  u_rx:com_rx port map(clk=>clk,din=>din,dat=>rx_byte,busy=>rx_busy,lk=>rx_lk);
  u_addr_cnt:countor_addr_rx_cnt port map(clk=>rx_lk,clk2=>lk_d1,en=>addr_en,co=>addr_co,qout=>addr_cnt);
  u_comp_clr:comp_clr port map(in1=>addr_cnt,same=>addr_clr);
  u_rcv_deal:rcv_deal port map(lock_in=>lk_d2,lock_out=>co_d2,rst=>rst,addr=>addr_cnt,dat=>rx_byte,confm=>confm_int,cmd=>cmd,dat1=>dat1,dat3=>dat3,dat5=>dat5,dat7=>dat7,dat9=>dat9,dat11=>dat11,dat13=>dat13,dat15=>dat15);
  tmo_clr<=not rx_busy;
  u_timeout:countor_t_over port map(clk=>clk,clr=>tmo_clr,co=>tmo_co);
  addr_en<=rst and(not tmo_co)and(not addr_clr); -- 地址计数器使能：复位有效、未超时、未到帧尾
  u_dly_lk:delay_1 port map(clk=>clk_inv,in1=>rx_lk,dly_out=>lk_d1);     -- 锁存信号对齐
  u_dly_lk2:delay_1 port map(clk=>clk_inv,in1=>lk_d1,dly_out=>lk_d2);
  u_dly_co:delay_1 port map(clk=>clk_inv,in1=>addr_co,dly_out=>co_d1);   -- 帧完成信号对齐
  u_dly_co2:delay_1 port map(clk=>clk_inv,in1=>co_d1,dly_out=>co_d2);
  confm<=confm_int and co_d2; -- 最终confm门控：校验通过且帧完成
end architecture rtl;
