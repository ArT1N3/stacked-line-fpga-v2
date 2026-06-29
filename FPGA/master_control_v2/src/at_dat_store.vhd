--=============================================================================
-- at_dat_store - EEPROM数据存储管理（AT24C02读写+Flash时序+数据选择）
--=============================================================================
library ieee; use ieee.std_logic_1164.all;
entity at_dat_store is port(trig_n,rst,clk_1m,clk_1ms:in std_logic; at2402_sda:inout std_logic; dat1,dat2,dat3,dat4:in std_logic_vector(7 downto 0); at2402_scl:out std_logic; dat1_o,dat2_o,dat3_o:out std_logic_vector(7 downto 0)); end entity at_dat_store;
architecture rtl of at_dat_store is
  component countor_addr22 is port(clk,en:in std_logic; qout:out std_logic_vector(2 downto 0); co:out std_logic); end component;
  component countor_clk_flash is port(clk,en:in std_logic; co:out std_logic); end component;
  component dly_rd_rom is port(clk,en:in std_logic; co:out std_logic); end component;
  component dly_rw_sel is port(clk,en:in std_logic; co:out std_logic); end component;
  component flash_i2c_core is port(clk_1m,rd_wr_n,sda_in,start:in std_logic; addr,dat_in:in std_logic_vector(7 downto 0); scl,sda_out,dir:out std_logic; ok:out std_logic; dat_r:out std_logic_vector(7 downto 0)); end component;
  component lock_8 is port(din:in std_logic_vector(7 downto 0); lk:in std_logic; q:out std_logic_vector(7 downto 0)); end component;
  component syn_dat_lock is port(lock:in std_logic; dat1,dat2,dat3,dat4,dat5:in std_logic_vector(15 downto 0); dt1,dt2,dt3,dt4,dt5:out std_logic_vector(15 downto 0); ext1,ext2,ext3:out std_logic_vector(23 downto 0); err_en:out std_logic_vector(7 downto 0)); end component;
  component dat_pick16 is port(dat1,dat2,dat3,dat4:in std_logic_vector(7 downto 0); addr:in std_logic_vector(2 downto 0); lock:in std_logic; dat,adr:out std_logic_vector(7 downto 0)); end component;
  component read_flash is port(shift_clk:in std_logic; dat:in std_logic_vector(7 downto 0); dat1,dat2,dat3,dat4:out std_logic_vector(7 downto 0)); end component;
  signal wren,rd_rom_en,rw_sel,clk_flash,clk_shift:std_logic;
  signal i2c_sda_out,i2c_dir,i2c_ok,i2c_start:std_logic;
  signal i2c_addr,i2c_dat_in,i2c_dat_r:std_logic_vector(7 downto 0);
  signal pick_dat,pick_adr:std_logic_vector(7 downto 0);
  signal addr_cnt:std_logic_vector(2 downto 0);
begin
  -- 写使能逻辑
  wren<=not trig_n;
  -- 地址计数器+时钟链
  u_addr:countor_addr22 port map(clk=>clk_flash,en=>wren,qout=>addr_cnt,co=>clk_shift);
  u_clk:countor_clk_flash port map(clk=>clk_1m,en=>wren,co=>clk_flash);
  u_dly_rd:dly_rd_rom port map(clk=>clk_1ms,en=>rd_rom_en,co=>open);
  u_dly_sel:dly_rw_sel port map(clk=>clk_1ms,en=>rw_sel,co=>open);
  -- 数据选择器
  u_pick:dat_pick16 port map(dat1=>dat1,dat2=>dat2,dat3=>dat3,dat4=>dat4,addr=>addr_cnt,lock=>clk_shift,dat=>pick_dat,adr=>pick_adr);
  -- I2C Flash核心
  i2c_start<=wren; i2c_addr<=pick_adr; i2c_dat_in<=pick_dat;
  u_i2c:flash_i2c_core port map(clk_1m=>clk_1m,rd_wr_n=>wren,sda_in=>at2402_sda,start=>i2c_start,addr=>i2c_addr,dat_in=>i2c_dat_in,scl=>at2402_scl,sda_out=>i2c_sda_out,dir=>i2c_dir,ok=>i2c_ok,dat_r=>i2c_dat_r);
  at2402_sda<=i2c_sda_out when i2c_dir='1' else 'Z';
  -- 读取Flash数据
  u_read:read_flash port map(shift_clk=>clk_shift,dat=>i2c_dat_r,dat1=>dat1_o,dat2=>dat2_o,dat3=>dat3_o,dat4=>open);
  rw_sel<=wren; rd_rom_en<=not wren;
end architecture rtl;
