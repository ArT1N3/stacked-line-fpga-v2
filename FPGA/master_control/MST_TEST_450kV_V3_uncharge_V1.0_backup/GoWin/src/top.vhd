--=============================================================================
-- Top - 450kV高压电源总控板顶层（高云GW1N-9C）
--=================================================================================
-- 功能：系统顶层，连接所有子模块到物理IO引脚。包含：
--   - 时钟生成(clk_gen): 50M→5M/2M/1M/100k/10k/1ms/115200
--   - ADC采集(ad_mcp3202): MCP3202双通道12位SPI ADC
--   - 温度采集(lm75bd): LM75B I2C温度传感器
--   - 分控通信(com_rxd+mast_to_slave): 22字节帧, RXD1
--   - 上位机通信(fpga_to_pc+com_tx): 22字节帧, TX_A
--   - 充电机通信(com_rx_charger+mast_to_charger): UART, RXD3
--   - 脉冲突发(multi_signal+pulse_generate): 时序控制
--   - 继电器控制(rly_ctr_8): 8路继电器
--   - 错误检测(err_chk+rx_module): 16通道
--   - EEPROM存储(at_dat_store): I2C EEPROM
--===================================================================================
library ieee; use ieee.std_logic_1164.all;   

entity Top is
  port(
    clk_50M:in std_logic; EXT_X1,EXT_X2,EXT_X3,EXT_X4,EXT_X5,EXT_X6:in std_logic;
    RXD1,RXD2:in std_logic; EXT_IO15:in std_logic;
    EXT_IO3_COM_R1,EXT_IO4_COM_R2:in std_logic; EXT_IO5_RO2_485:in std_logic;
    EXT_IO7_CHG_ERR:in std_logic; EXT_IO10_RO_485:in std_logic;
    EXT_IO11_CHK2,EXT_IO12_CHK1:in std_logic; RXD3_A:in std_logic;
    EXT_IO21_AD_DO:in std_logic; EXT_IO1_TX3,EXT_IO16_TX2_A,EXT_IO14_TX1_A:out std_logic;
    SDA,SDA_LM75:inout std_logic;
    SCL,SCL_LM75:out std_logic; LED1,LED2,LED3,LED4:out std_logic;
    EXT_IO6_DI2_485,EXT_IO9_DI_485:out std_logic;
    EXT_IO18_COM_T2,EXT_IO19_AD_CLK_IN,EXT_IO20_AD_DI,EXT_IO22_AD_CS_IN:out std_logic;
    TX_A,EXT_IO13_TX5_A,EXT_IO8_CHG_EN,EXT_IO17_COM_T1,EXT_IO2_TX4:out std_logic;
    CTR_RLY1,CTR_RLY2,CTR_RLY3,CTR_RLY4,CTR_RLY5,CTR_RLY6:out std_logic
  );
end entity Top;

architecture rtl of Top is
  -- Component declarations (all standardized sub-modules)
  component ad_mcp3202 is port(CLK_50M,trig:in std_logic; DIN:in std_logic; REF:in std_logic_vector(11 downto 0); AD_CS,AD_CLK,AD_DIN,LK:out std_logic; AD_DAT1,AD_DAT2:out std_logic_vector(11 downto 0); P_OV,N_OV,P_NF,N_NF,U_HIGH:out std_logic); end component;
  component rst_g is port(clk:in std_logic; RST:out std_logic); end component;
  component div_500 is port(clk:in std_logic; CLK2:out std_logic); end component;
  component lock_1 is port(clk,rst,clr:in std_logic; Q:out std_logic); end component;
  component trig_rvs is port(trig:in std_logic; rvs:out std_logic); end component;
  component rxd_stop is port(Rxd,clk_10us:in std_logic; ERR:out std_logic); end component;
  component chk_tx3 is port(clk_1M,trig:in std_logic; TX,chk:out std_logic); end component;
  component level_edg is port(Level_in,clk:in std_logic; Edg_out:out std_logic); end component;
  component single_m is port(clk,CLR,Stp:in std_logic; M_ON:out std_logic); end component;
  component m_ok_chk is port(clk,CLR:in std_logic; M_OK:out std_logic); end component;
  component wk_on_show is port(clk,Wk:in std_logic; St:out std_logic); end component;
  component com_dly_en is port(clk,trig:in std_logic; EN:out std_logic); end component;
  component lock_en is port(Lock:in std_logic; DA1,DA2,DA3,DA4,DA5,DA6,DA7:in std_logic_vector(15 downto 0); DA8:in std_logic_vector(7 downto 0); SEL:in std_logic_vector(7 downto 0); D1,D2,D3,D4,D5,D6,D7:out std_logic_vector(15 downto 0); D8:out std_logic_vector(7 downto 0); D9,D10,D11,D12,D13,D14,D15:out std_logic_vector(15 downto 0); D16:out std_logic_vector(7 downto 0)); end component;
  component multi_signal is port(clk_20ns,CLR,trig,LOCK:in std_logic; T_CH:in std_logic_vector(15 downto 0); T_MS:in std_logic_vector(15 downto 0); T_EXP0,T_EXP01:in std_logic_vector(15 downto 0); T_EXP2,T_EXP3:in std_logic_vector(23 downto 0); TRIG_MS,TRIG_EXP1,TRIG_EXP2,TRIG_EXP3,TRIG_CHK,M_pulse,Chk2:out std_logic; T_DLY,DLY1_H,DLY1_L:out std_logic_vector(15 downto 0)); end component;
  component const_8 is generic(const:integer:=102); port(result:out std_logic_vector(7 downto 0)); end component;
  component at_dat_store is port(trig_N,RST,clk_1M,clk_1ms:in std_logic; AT2402_SDA:inout std_logic; dat1,dat2,dat3,dat4:in std_logic_vector(7 downto 0); AT2402_SCL:out std_logic; DAT1_O,DAT2_O,DAT3_O:out std_logic_vector(7 downto 0)); end component;
  component auto_addr_dly is port(clk_500us,CLR:in std_logic; Addr:in std_logic_vector(4 downto 0); Txd_trig:out std_logic); end component;
  component lock_chg_dat_sel is port(LOCK,CLR:in std_logic; D1:in std_logic_vector(7 downto 0); D2,D3,D4,D5:in std_logic_vector(15 downto 0); D6,D7,D8,D9,D10,D11:in std_logic_vector(7 downto 0); C1_D1:out std_logic_vector(7 downto 0); C1_D2,C1_D3,C1_D4,C1_D5:out std_logic_vector(15 downto 0); C1_D6,C1_D7,C1_D8,C1_D9,C1_D10,C1_D11:out std_logic_vector(7 downto 0); C2_D1:out std_logic_vector(7 downto 0); C2_D2,C2_D3,C2_D4,C2_D5:out std_logic_vector(15 downto 0); C2_D6,C2_D7,C2_D8,C2_D9,C2_D10,C2_D11:out std_logic_vector(7 downto 0)); end component;
  component dat_sel is port(aux:in std_logic_vector(7 downto 0); datA1,datA2,datA3,datA4,datA5,datA6,datA7:in std_logic_vector(15 downto 0); datA8:in std_logic_vector(7 downto 0); datB1,datB2,datB3,datB4,datB5,datB6,datB7:in std_logic_vector(15 downto 0); datB8:in std_logic_vector(7 downto 0); datC1,datC2,datC3,datC4,datC5,datC6,datC7:in std_logic_vector(15 downto 0); datC8:in std_logic_vector(7 downto 0); datD1,datD2,datD3,datD4,datD5,datD6,datD7:in std_logic_vector(15 downto 0); datD8:in std_logic_vector(7 downto 0); datE1,datE2,datE3,datE4,datE5,datE6,datE7:in std_logic_vector(15 downto 0); datE8:in std_logic_vector(7 downto 0); datF1,datF2,datF3,datF4,datF5,datF6,datF7:in std_logic_vector(15 downto 0); datF8:in std_logic_vector(7 downto 0); datG1,datG2,datG3,datG4,datG5,datG6,datG7:in std_logic_vector(15 downto 0); datG8:in std_logic_vector(7 downto 0); datH1,datH2,datH3,datH4,datH5,datH6,datH7:in std_logic_vector(15 downto 0); datH8:in std_logic_vector(7 downto 0); datI1,datI2,datI3,datI4,datI5,datI6,datI7:in std_logic_vector(15 downto 0); datI8:in std_logic_vector(7 downto 0); datJ1,datJ2,datJ3,datJ4,datJ5,datJ6,datJ7:in std_logic_vector(15 downto 0); datJ8:in std_logic_vector(7 downto 0); dat1,dat2,dat3,dat4,dat5,dat6,dat7:out std_logic_vector(15 downto 0); dat8:out std_logic_vector(7 downto 0)); end component;
  component mast_to_slave is port(CMD:in std_logic_vector(7 downto 0); DAT1,DAT3,DAT5,DAT7,DAT9,DAT11,DAT13:in std_logic_vector(15 downto 0); DAT15:in std_logic_vector(7 downto 0); CLK,CLR_N:in std_logic; DAT:out std_logic_vector(7 downto 0); LD:out std_logic); end component;
  component en_tx_sel is port(clk,TX:in std_logic; Grp:in std_logic_vector(7 downto 0); TX1,TX2:out std_logic); end component;
  component mast_to_charger is port(CMD:in std_logic_vector(7 downto 0); DAT_U:in std_logic_vector(15 downto 0); ASK,CLK,CLR_N:in std_logic; DAT:out std_logic_vector(7 downto 0); LD:out std_logic); end component;
  component com_tx is port(clk,LD:in std_logic; DAT:in std_logic_vector(7 downto 0); dout:out std_logic; busy:out std_logic); end component;
  component cmd_aux_deal is port(Trig,EN:in std_logic; CMD:in std_logic_vector(7 downto 0); CMD01,CMD02,CMD03,CMD04,CMD05,CMD06,CMD07,CMD08,CMD09,CMD0A,CMD0B,CMD0C,CMD0D,CMD0E,CMD0F,CMD10,CMD11,CMD12,CMD13:out std_logic); end component;
  component fpga_to_pc is port(CMD,Grp,AUX:in std_logic_vector(7 downto 0); DAT1,DAT3,DAT5,DAT7,DAT9,DAT11,DAT13:in std_logic_vector(15 downto 0); DAT15:in std_logic_vector(7 downto 0); CLK,CLR_N:in std_logic; DAT:out std_logic_vector(7 downto 0); LD:out std_logic); end component;
  component com_rxd is port(Din,clk,RST:in std_logic; CONFM:out std_logic; Aux,CMD,Grp:out std_logic_vector(7 downto 0); dat1,dat3,dat5,dat7,dat9,dat11,dat13:out std_logic_vector(15 downto 0); dat15:out std_logic_vector(7 downto 0)); end component;
  component com_dly_clr is port(clk,trig:in std_logic; CLR,ERR:out std_logic); end component;
  component byte_word is port(Byte_H,Byte_L:in std_logic_vector(7 downto 0); Word:out std_logic_vector(15 downto 0)); end component;
  component auto_ask is port(clk,Rx:in std_logic; trig,Ask:out std_logic); end component;
  component com_rx_charger is port(Din,clk,RST,RST_O:in std_logic; CONFM:out std_logic; ADR,RSV,ST,ST2,TM1,TM2,TM3:out std_logic_vector(7 downto 0); Bus_U,Set_U,U_N,U_P:out std_logic_vector(15 downto 0)); end component;
  component rx_module is port(clk_1M,trig,DAT:in std_logic; ok:out std_logic; ST1,ST2,ST3,ST4,ST5,ST6,ST7:out std_logic_vector(15 downto 0); ST8:out std_logic_vector(7 downto 0)); end component;
  component com_dly_rst is port(clk,trig:in std_logic; RST:out std_logic); end component;
  component trig_aux is port(clk:in std_logic; trig:out std_logic); end component;
  component pulse_generate is port(clk_100us,CLR,TRIG,LOCK:in std_logic; n_pls,t_pls:in std_logic_vector(15 downto 0); pls,WK:out std_logic; N_PS,T_PS:out std_logic_vector(15 downto 0)); end component;
  component set_u_lock is port(LOCK:in std_logic; DAT_I:in std_logic_vector(15 downto 0); DAT_O:out std_logic_vector(15 downto 0)); end component;
  component err_chk is port(Lock:in std_logic; en1,en2,en3,en4,en5,en6,en7:in std_logic_vector(15 downto 0); en8:in std_logic_vector(7 downto 0); en9,en10,en11,en12,en13,en14,en15:in std_logic_vector(15 downto 0); en16:in std_logic_vector(7 downto 0); da1,da2,da3,da4,da5,da6,da7:in std_logic_vector(15 downto 0); da8:in std_logic_vector(7 downto 0); da9,da10,da11,da12,da13,da14,da15:in std_logic_vector(15 downto 0); da16:in std_logic_vector(7 downto 0); e1,e2,e3,e4,e5,e6,e7:out std_logic_vector(15 downto 0); e8:out std_logic_vector(7 downto 0); e9,e10,e11,e12,e13,e14,e15:out std_logic_vector(15 downto 0); e16:out std_logic_vector(7 downto 0); err_all,err_on:out std_logic); end component;
  component clk_gen is port(clk_50M,RST:in std_logic; clk_2M,clk_1M,clk_100k,clk_1ms,clk_115200,clk_10k,clk_5M:out std_logic); end component;
  component pulse_count is port(clr,pulse:in std_logic; NUM:out std_logic_vector(23 downto 0)); end component;
  component e_trig_l is port(clk,CLR:in std_logic; Trig_L:out std_logic); end component;
  component chk_tx is port(clk_1M,trig:in std_logic; TX,chk:out std_logic); end component;
  component chk_tx2 is port(clk_1M,trig:in std_logic; TX,chk:out std_logic); end component;
  component rly_ctr_8 is port(CMD_R,RST:in std_logic; DAT:in std_logic_vector(7 downto 0); R1,R2,R3,R4,R5,R6,R7,R8:out std_logic; RLY_st:out std_logic_vector(4 downto 0)); end component;
  component bit_2 is port(D1,D0:in std_logic; Bit2:out std_logic_vector(1 downto 0)); end component;
  component lm75bd is port(clk_1M,clk_1ms:in std_logic; SDA:inout std_logic; SCL,LK_O,LED:out std_logic; TEM1:out std_logic_vector(8 downto 0)); end component;
  component pulse_charge_m is port(clk_100us,CLR,TRIG,LOCK:in std_logic; T_BASE:in std_logic_vector(15 downto 0); T_OVER:out std_logic; T_CHG:out std_logic_vector(15 downto 0)); end component;
  component chk_trig is port(clk_100us,trig,CLR:in std_logic; TX1,TX2,TX3:out std_logic); end component;
  component syn_out_ctr is port(IN1,IN2,IN3,IN4,Trig1,Trig2,Trig3,Trig4,clk_2M,EN:in std_logic; O1,O2,O3,O4:out std_logic); end component;
  component wk_st_delay is port(clk,Wk:in std_logic; St:out std_logic); end component;
  component bit_byte is port(D7,D6,D5,D4,D3,D2,D1,D0:in std_logic; Byte:out std_logic_vector(7 downto 0)); end component;
  component mac_16 is port(IN1,clk:in std_logic; O1:out std_logic); end component;

  -- Clock signals
  signal clk_2M,clk_1M,clk_100k,clk_1ms,clk_115200bps,clk_10k,clk_5M,clk_500ms,clk_500us:std_logic;
  -- Reset/Control
  signal RST,Out_EN,OUT_EN_ALL,BLK_OFF,BLK_ON,BLK_ON1,SET_LOCK:std_logic;
  -- Communication signals
  signal RX_OK,RX_Start1,RX_Start1X,RX_Start2,RX_Start3,TXD_trig,Charger_rx:std_logic;
  signal PC_AUX,PC_CMD,Grp,SYN_DAT,ADR:std_logic_vector(7 downto 0);
  signal RX_DAT1,RX_DAT2,RX_DAT3,RX_DAT4,RX_DAT5,RX_DAT6,RX_DAT7:std_logic_vector(15 downto 0);
  signal RX_DAT8:std_logic_vector(7 downto 0);
  signal TX_DAT1,TX_DAT2,TX_DAT3,TX_DAT4,TX_DAT5,TX_DAT6,TX_DAT7:std_logic_vector(15 downto 0);
  signal TX_DAT8:std_logic_vector(7 downto 0);
  -- ADC
  signal AD_trig,U_high,P_OV,P_OV1,N_OV,N_OV1,P_NF,P_NF1,N_NF,N_NF1:std_logic;
  signal AD_U1,AD_U2:std_logic_vector(15 downto 0);
  -- Pulse/Charge
  signal SET_U,SET_T,SET_N,SET_CHG_T,T_trg_dly,DLY1_H,DLY1_L,RSV:std_logic_vector(15 downto 0);
  signal M_pulse,Single,Single1,trig_charge,trig_Main,trig_Main1,trig_Ch1:std_logic;
  signal Wk_st,WK_ON,St_out:std_logic;
  -- Error
  signal ERR_ALL,ERR_ON,ERR_Module,dis_M_ERR,Local_EMG,EMG_stop,NOT_K:std_logic;
  signal Chg_ERR,CHG_COM_ERR,ERR_M_LOCK,M_NO_ERR,Button_EMG,trig_Emg:std_logic;
  -- Error channel signals (individual, mostly unconnected)
  signal err_en1,err_en2,err_en3,err_en4,err_en5,err_en6,err_en7:std_logic_vector(15 downto 0);
  signal err_en8,err_en16:std_logic_vector(7 downto 0);
  signal err_en9,err_en10,err_en11,err_en12,err_en13,err_en14,err_en15:std_logic_vector(15 downto 0);
  signal err_da1,err_da2,err_da3,err_da4,err_da5,err_da6,err_da7:std_logic_vector(15 downto 0);
  signal err_da8,err_da16:std_logic_vector(7 downto 0);
  signal err_da9,err_da10,err_da11,err_da12,err_da13,err_da14,err_da15:std_logic_vector(15 downto 0);
  signal err_e1,err_e2,err_e3,err_e4,err_e5,err_e6,err_e7:std_logic_vector(15 downto 0);
  signal err_e8,err_e16:std_logic_vector(7 downto 0);
  signal err_e9,err_e10,err_e11,err_e12,err_e13,err_e14,err_e15:std_logic_vector(15 downto 0);
  -- Charger
  signal CHG_ST,CHG_DAT1,CHG_DAT2,CHG_DAT3,CHG_DAT4,CHG_DAT5:std_logic_vector(15 downto 0);
  signal CHG_DAT6,CHG_RSV:std_logic_vector(7 downto 0);
  signal Ask,Ask_Trig,CHG_EN,chg_trig,COM_CLR_DAT,RST_COM,HV_COM_EN,HV_PWR:std_logic;
  -- Misc
  signal M_OK,M_PWR_ON,PWR_ON,ROM_LK:std_logic;
  signal CTR_state,CTR_state2:std_logic_vector(15 downto 0);
  signal Pulse_cnt:std_logic_vector(23 downto 0);
  signal TEM:std_logic_vector(8 downto 0);
  signal TX1,TX2,TX3,CHK_TXX,CHK_trig1,CHK_trig2,CHK_trig3:std_logic;
  signal R1_COM,R2_COM:std_logic;
  signal TRIG_MS,TRIG_EXP1,TRIG_EXP2,TRIG_EXP3,TRIG_CHK,U_chk2:std_logic;
  signal slave_tx,charger_tx,pc_tx_data,pc_tx_out:std_logic_vector(7 downto 0);
  signal slave_ld,charger_ld,pc_ld:std_logic;
  -- Dummy signals for open inputs and e_trig output
  signal dummy_logic:std_logic:='0';
  signal vcc:std_logic:='1';
  signal dummy_byte:std_logic_vector(7 downto 0):=(others=>'0');
  signal e_trig_sig:std_logic;
begin
  -- Clock generation
  u_clk:clk_gen port map(clk_50M=>clk_50M,RST=>RST,clk_2M=>clk_2M,clk_1M=>clk_1M,clk_100k=>clk_100k,clk_1ms=>clk_1ms,clk_115200=>clk_115200bps,clk_10k=>clk_10k);
  u_div500:div_500 port map(clk=>clk_1ms,CLK2=>clk_500ms);
  clk_500us<=clk_100k; -- 100kHz→500us周期

  -- Reset chain
  u_rst:rst_g port map(clk=>clk_50M,RST=>RST);
  u_rst_out:rst_g port map(clk=>clk_1ms,RST=>Out_EN);
  OUT_EN_ALL<=Out_EN and(not ERR_ALL);

  -- ADC
  u_adc:ad_mcp3202 port map(CLK_50M=>clk_50M,trig=>AD_trig,DIN=>EXT_IO21_AD_DO,REF=>SET_U(12 downto 1),AD_CS=>EXT_IO22_AD_CS_IN,AD_CLK=>EXT_IO19_AD_CLK_IN,AD_DIN=>EXT_IO20_AD_DI,P_OV=>P_OV1,N_OV=>N_OV1,P_NF=>P_NF1,N_NF=>N_NF1,U_HIGH=>U_high,AD_DAT1=>AD_U1(11 downto 0),AD_DAT2=>AD_U2(11 downto 0));
  AD_U1(15 downto 12)<="0000"; AD_U2(15 downto 12)<="0000";
  u_ad_trig:trig_aux port map(clk=>clk_1M,trig=>AD_trig);

  -- SComms: RXD1→com_rxd→fpga_to_pc/mast_to_slave
  u_com_rxd:com_rxd port map(Din=>RXD1,clk=>clk_115200bps,RST=>RST,CONFM=>RX_OK,Aux=>PC_AUX,CMD=>PC_CMD,dat1=>RX_DAT1,dat3=>RX_DAT2,dat5=>RX_DAT3,dat7=>RX_DAT4,dat9=>RX_DAT5,dat11=>RX_DAT6,dat13=>RX_DAT7,dat15=>RX_DAT8,Grp=>Grp);
  u_txd_edg:level_edg port map(Level_in=>RX_OK,clk=>clk_115200bps,Edg_out=>TXD_trig);
  u_cmd:cmd_aux_deal port map(Trig=>TXD_trig,EN=>RX_OK,CMD=>PC_CMD,CMD01=>open,CMD02=>open,CMD03=>open,CMD04=>SET_LOCK,CMD05=>open,CMD08=>Single1,CMD09=>BLK_ON1,CMD0A=>open,CMD0B=>trig_charge,CMD0C=>trig_Main1,CMD0E=>trig_Ch1,CMD0F=>ROM_LK,CMD11=>trig_Emg,CMD13=>open);
  BLK_ON<=BLK_ON1 and M_NO_ERR;
  -- FPGA→PC
  u_f2pc:fpga_to_pc port map(CLK=>clk_115200bps,CLR_N=>not TXD_trig,CMD=>PC_CMD,Grp=>ADR,AUX=>PC_AUX,DAT1=>TX_DAT1,DAT3=>TX_DAT2,DAT5=>TX_DAT3,DAT7=>TX_DAT4,DAT9=>TX_DAT5,DAT11=>TX_DAT6,DAT13=>TX_DAT7,DAT15=>TX_DAT8,LD=>pc_ld,DAT=>pc_tx_data);
  u_pc_tx:com_tx port map(clk=>clk_115200bps,LD=>pc_ld,DAT=>pc_tx_data,dout=>EXT_IO2_TX4,busy=>LED4);
  -- Mast→Slave
  u_m2s:mast_to_slave port map(CLK=>not clk_115200bps,CLR_N=>not TXD_trig,CMD=>PC_CMD,DAT1=>RX_DAT1,DAT3=>RX_DAT2,DAT5=>RX_DAT3,DAT7=>RX_DAT4,DAT9=>RX_DAT5,DAT11=>RX_DAT6,DAT13=>RX_DAT7,DAT15=>RX_DAT8,LD=>slave_ld,DAT=>slave_tx);
  u_slave_tx:com_tx port map(clk=>clk_115200bps,LD=>slave_ld,DAT=>slave_tx,dout=>open);
  -- TX输出选择
  u_tx_sel:en_tx_sel port map(clk=>clk_50M,TX=>dummy_logic,Grp=>PC_AUX,TX1=>open,TX2=>open);

  -- Charger comms: RXD3
  u_ask:auto_ask port map(clk=>clk_1ms,Rx=>TXD_trig,trig=>Ask_Trig,Ask=>Ask);
  u_charger_rx:com_rx_charger port map(Din=>EXT_IO10_RO_485,clk=>clk_115200bps,RST=>OUT_EN_ALL,RST_O=>RST,CONFM=>Charger_rx,ADR=>open,RSV=>CHG_RSV,Bus_U=>CHG_DAT1,Set_U=>CHG_DAT2,ST=>open,ST2=>open,TM1=>open,TM2=>open,TM3=>open,U_N=>CHG_DAT4,U_P=>CHG_DAT3);
  chg_trig<=trig_charge or Single;
  u_m2c:mast_to_charger port map(ASK=>Ask,CLK=>not clk_115200bps,CLR_N=>not TXD_trig,CMD=>PC_CMD,DAT_U=>RX_DAT1,LD=>charger_ld,DAT=>charger_tx);
  u_charger_tx:com_tx port map(clk=>clk_115200bps,LD=>charger_ld,DAT=>charger_tx,dout=>EXT_IO9_DI_485);
  u_charger_edg:level_edg port map(Level_in=>Charger_rx,clk=>clk_115200bps);
  u_charger_clr:com_dly_clr port map(clk=>clk_1ms,trig=>Charger_rx,CLR=>COM_CLR_DAT,ERR=>open);
  u_charger_rst:com_dly_rst port map(clk=>clk_1ms,trig=>dummy_logic,RST=>RST_COM);

  -- Pulse generation
  u_set_u:set_u_lock port map(LOCK=>SET_LOCK,DAT_I=>RX_DAT1,DAT_O=>SET_U);
  u_pulse:multi_signal port map(clk_20ns=>clk_50M,CLR=>BLK_OFF,trig=>Single or BLK_ON1,LOCK=>SET_LOCK,T_CH=>RX_DAT4,T_MS=>RX_DAT5,T_EXP0=>RX_DAT6,T_EXP01=>RX_DAT7,T_EXP2=>(others=>'0'),T_EXP3=>(others=>'0'),TRIG_MS=>TRIG_MS,TRIG_EXP1=>TRIG_EXP2,TRIG_EXP2=>open,TRIG_EXP3=>open,TRIG_CHK=>TRIG_CHK,M_pulse=>M_pulse,Chk2=>U_chk2,DLY1_H=>DLY1_H,DLY1_L=>DLY1_L,T_DLY=>T_trg_dly);
  u_pgen:pulse_generate port map(clk_100us=>clk_10k,CLR=>BLK_OFF,TRIG=>e_trig_sig,LOCK=>SET_LOCK,n_pls=>RX_DAT3,t_pls=>RX_DAT2,pls=>open,WK=>Wk_st,N_PS=>SET_N,T_PS=>SET_T);
  u_pchg:pulse_charge_m port map(clk_100us=>clk_10k,CLR=>BLK_OFF,TRIG=>trig_Main,LOCK=>SET_LOCK,T_BASE=>RX_DAT4,T_OVER=>open,T_CHG=>SET_CHG_T);
  u_trig_l1:e_trig_l port map(clk=>clk_1M,CLR=>chg_trig,Trig_L=>e_trig_sig);
  u_trig_l2:e_trig_l port map(clk=>clk_1M,CLR=>BLK_ON,Trig_L=>open);
  Single<=Single1 and M_NO_ERR;
  trig_Main<=trig_Main1 and M_NO_ERR;

  -- Error check
  u_err:err_chk port map(Lock=>ERR_M_LOCK, en1=>err_en1,en2=>err_en2,en3=>err_en3,en4=>err_en4,en5=>err_en5,en6=>err_en6,en7=>err_en7,en8=>err_en8,en9=>err_en9,en10=>err_en10,en11=>err_en11,en12=>err_en12,en13=>err_en13,en14=>err_en14,en15=>err_en15,en16=>err_en16, da1=>err_da1,da2=>err_da2,da3=>err_da3,da4=>err_da4,da5=>err_da5,da6=>err_da6,da7=>err_da7,da8=>err_da8,da9=>err_da9,da10=>err_da10,da11=>err_da11,da12=>err_da12,da13=>err_da13,da14=>err_da14,da15=>err_da15,da16=>err_da16, e1=>err_e1,e2=>err_e2,e3=>err_e3,e4=>err_e4,e5=>err_e5,e6=>err_e6,e7=>err_e7,e8=>err_e8,e9=>err_e9,e10=>err_e10,e11=>err_e11,e12=>err_e12,e13=>err_e13,e14=>err_e14,e15=>err_e15,e16=>err_e16, err_all=>open,err_on=>ERR_ON);

  -- RXD1 stop detection
  u_rxd_stop:rxd_stop port map(Rxd=>RXD1,clk_10us=>clk_100k,ERR=>Button_EMG);

  -- Mac filters
  u_mac1:mac_16 port map(IN1=>EXT_IO7_CHG_ERR,clk=>not clk_100k);
  u_mac2:mac_16 port map(IN1=>EXT_IO12_CHK1,clk=>not clk_100k);
  u_mac3:mac_16 port map(IN1=>EXT_IO11_CHK2,clk=>not clk_1ms);

  -- Relay control
  u_rly:rly_ctr_8 port map(CMD_R=>SET_LOCK,RST=>vcc,DAT=>RX_DAT1(15 downto 8),R1=>PWR_ON,R2=>CTR_RLY2,R3=>CTR_RLY3,R4=>HV_PWR,R5=>M_PWR_ON,R6=>CTR_RLY6,R7=>open,R8=>open,RLY_st=>CTR_state(12 downto 8));

  -- Misc outputs
  CHG_EN<=OUT_EN_ALL and(not dummy_logic);
  EXT_IO8_CHG_EN<=CHG_EN; CTR_RLY1<=PWR_ON; CTR_RLY4<=HV_PWR; CTR_RLY5<=M_PWR_ON;
  EXT_IO17_COM_T1<=dummy_logic; EXT_IO18_COM_T2<=dummy_logic;
  EXT_IO1_TX3<=dummy_logic; EXT_IO16_TX2_A<=dummy_logic; EXT_IO14_TX1_A<=dummy_logic;
  TX_A<=dummy_logic; EXT_IO13_TX5_A<=dummy_logic;
  R1_COM<=not EXT_IO3_COM_R1; R2_COM<=not EXT_IO4_COM_R2;
  LED1<='0';

  -- Temperature
  u_lm75:lm75bd port map(clk_1M=>clk_100k,clk_1ms=>clk_1ms,SDA=>SDA_LM75,SCL=>SCL_LM75,LK_O=>open,LED=>open,TEM1=>TEM);
  u_bw:byte_word port map(Byte_H=>CTR_state2(7 downto 0),Byte_L=>TEM(7 downto 0),Word=>RSV);

  -- EEPROM
  u_eeprom:at_dat_store port map(trig_N=>not ROM_LK,clk_1M=>clk_1M,clk_1ms=>clk_1ms,RST=>RST,AT2402_SDA=>SDA,dat1=>Grp,dat2=>PC_AUX,dat3=>dummy_byte,dat4=>dummy_byte,AT2402_SCL=>SCL,DAT1_O=>ADR,DAT2_O=>SYN_DAT);

  -- WK/ST display
  u_wk_dly:wk_st_delay port map(clk=>clk_1ms,Wk=>CHG_EN or Wk_st,St=>WK_ON);
  u_wk_show:wk_on_show port map(clk=>clk_1ms,Wk=>WK_ON,St=>open);
end architecture rtl;
