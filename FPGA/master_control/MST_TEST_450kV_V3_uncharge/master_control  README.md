# 450kV 高压电源总控板 FPGA 工程说明

## 工程概览

| 项目 | 说明 |
|------|------|
| **工程名称** | MST_TEST_450kV_V3_uncharge |
| **FPGA 型号** | 高云 GW1N-9C (GW1N-UV9QN88C6/I5) |
| **开发环境** | Gowin IDE (高云半导体) |
| **HDL 语言** | VHDL (IEEE 1076-1993) |
| **顶层模块** | `Top` (`top.vhd`) |
| **约束文件** | `GoWin.cst` |
| **时钟频率** | 50MHz 外部晶振 |
| **工程路径** | `GoWin\src\` |

---

## 一、系统架构

本 FPGA 是 450kV 高压电源系统的**主控板核心**，负责：

- 接收上位机（PC）UART 指令
- 分发指令到分控、充电机等子系统
- 采集 ADC 电压/电流数据
- 监测温度（LM75B）
- 生成高压脉冲触发时序
- 控制继电器上电序列
- 错误检测与保护
- 参数存储（EEPROM AT24C02）

### 顶层框图

```
                    ┌─────────────────────────────────────────────┐
  clk_50M ─────────┤                                             ├── LED1~4
                    │  ┌─────────┐                                │
  RXD1 (PC) ───────┤  │ clk_gen │→ clk_2M/1M/100k/10k/1ms/115200├── TX_A
                    │  └─────────┘                                │
  RXD3_A (充电机) ─┤                                             ├── EXT_IO2_TX4 (PC回传)
                    │  ┌───────────┐                              │
  EXT_IO21_AD_DO ──┤  │ ad_mcp3202│→ AD_U1/AD_U2 (12bit ADC)     ├── CTR_RLY1~6
                    │  └───────────┘                              │
  SDA_LM75 ────────┤                                             ├── EXT_IO8_CHG_EN
  SCL_LM75 ────────┤  ┌─────────┐                                │
                    │  │ lm75bd  │→ TEM (9bit 温度)               ├── EXT_IO9_DI_485 (充电机TX)
  EXT_IO3_COM_R1 ──┤  └─────────┘                                │
  EXT_IO4_COM_R2 ──┤                                             ├── EXT_IO17_COM_T1/18_COM_T2
                    │  ┌───────────────┐                          │
  EXT_X1~X6 ───────┤  │ multi_signal  │→ TRIG_MS/EXP1~3/CHK      ├── EXT_IO19_AD_CLK_IN (SPI)
  EXT_IO11/12 ─────┤  │ pulse_generate│→ pls/WK                  ├── EXT_IO20_AD_DI (SPI)
  EXT_IO7_CHG_ERR ─┤  │ err_chk       │→ ERR_ON                  ├── EXT_IO22_AD_CS_IN (SPI)
                    │  └───────────────┘                          │
  SDA ─────────────┤                                             ├── EXT_IO6_DI2_485
  SCL ─────────────┤  ┌────────────┐                             │
                    │  │at_dat_store│→ EEPROM 读写                ├── EXT_IO1/14/16_TX
                    │  └────────────┘                             │
                    └─────────────────────────────────────────────┘
```

---

## 二、时钟架构

```
  50MHz (外部晶振)
      │
      ├── clk_gen ──┬── clk_5M  (5 MHz)
      │             ├── clk_2M  (2 MHz)    → syn_out_ctr
      │             ├── clk_1M  (1 MHz)    → trig_aux, e_trig_l, chk_tx
      │             ├── clk_100k(100 kHz)  → clk_500us, lm75bd
      │             ├── clk_10k (10 kHz)   → pulse_generate, pulse_charge_m
      │             ├── clk_1ms (1 kHz)    → div_500, wk_st_delay, auto_ask
      │             └── clk_115200 (115.2kHz) → 全 UART 通信
      │
      └── div_500 (clk_1ms÷500) → clk_500ms (2Hz 心跳)
```

---

## 三、引脚分配

| FPGA引脚 | 信号名 | 方向 | 功能 | 配置 |
|----------|--------|------|------|------|
| 52 | clk_50M | IN | 50MHz 系统时钟 | PULL_UP |
| 81 | EXT_X1 | IN | 外部输入1 | PULL_UP |
| 82 | EXT_X2 | IN | 外部输入2 | PULL_UP |
| 83 | EXT_X3 | IN | 外部输入3 | PULL_UP |
| 84 | EXT_X4 | IN | 外部输入4 | PULL_UP |
| 85 | EXT_X5 | IN | 外部输入5 | PULL_UP |
| 86 | EXT_X6 | IN | 外部输入6 | PULL_UP |
| 75 | RXD1 | IN | PC通信RX | PULL_UP |
| 74 | RXD2 | IN | 备用RX | PULL_UP |
| 72 | RXD3_A | IN | 充电机通信RX | PULL_UP |
| 35 | EXT_IO15 | IN | 通用输入 | PULL_UP |
| 19 | EXT_IO3_COM_R1 | IN | 485通信R1 | PULL_UP |
| 20 | EXT_IO4_COM_R2 | IN | 485通信R2 | PULL_UP |
| 25 | EXT_IO5_RO2_485 | IN | 485通道2输入 | PULL_UP |
| 27 | EXT_IO7_CHG_ERR | IN | 充电机错误 | PULL_UP |
| 30 | EXT_IO10_RO_485 | IN | 充电机485输入 | PULL_UP |
| 31 | EXT_IO11_CHK2 | IN | 检测信号2 | PULL_UP |
| 32 | EXT_IO12_CHK1 | IN | 检测信号1 | PULL_UP |
| 41 | EXT_IO21_AD_DO | IN | ADC数据输出(SPI MISO) | PULL_UP |
| 13 | SDA | INOUT | EEPROM I2C数据 | DRIVE=8 |
| 16 | SDA_LM75 | INOUT | 温度传感器I2C数据 | DRIVE=8 |
| 14 | SCL | OUT | EEPROM I2C时钟 | DRIVE=8 |
| 15 | SCL_LM75 | OUT | 温度传感器I2C时钟 | DRIVE=8 |
| 68 | LED1 | OUT | LED1(常灭) | DRIVE=8 |
| 69 | LED2 | OUT | LED2 | DRIVE=8 |
| 70 | LED3 | OUT | LED3 | DRIVE=8 |
| 71 | LED4 | OUT | LED4(TX忙指示) | DRIVE=8 |
| 61 | CTR_RLY1 | OUT | 继电器1(上电) | DRIVE=8 |
| 56 | CTR_RLY2 | OUT | 继电器2 | DRIVE=8 |
| 55 | CTR_RLY3 | OUT | 继电器3 | DRIVE=8 |
| 54 | CTR_RLY4 | OUT | 继电器4(高压使能) | DRIVE=8 |
| 50 | CTR_RLY5 | OUT | 继电器5(主电) | DRIVE=8 |
| 48 | CTR_RLY6 | OUT | 继电器6 | DRIVE=8 |
| 28 | EXT_IO8_CHG_EN | OUT | 充电机使能 | DRIVE=8 |
| 29 | EXT_IO9_DI_485 | OUT | 充电机485 TX | DRIVE=8 |
| 26 | EXT_IO6_DI2_485 | OUT | 485通道2 TX | DRIVE=8 |
| 17 | EXT_IO1_TX3 | OUT | TX3 | DRIVE=8 |
| 18 | EXT_IO2_TX4 | OUT | PC回传TX | DRIVE=8 |
| 33 | EXT_IO13_TX5_A | OUT | TX5A | DRIVE=8 |
| 34 | EXT_IO14_TX1_A | OUT | TX1A | DRIVE=8 |
| 36 | EXT_IO16_TX2_A | OUT | TX2A | DRIVE=8 |
| 37 | EXT_IO17_COM_T1 | OUT | 485通信T1 | DRIVE=8 |
| 38 | EXT_IO18_COM_T2 | OUT | 485通信T2 | DRIVE=8 |
| 39 | EXT_IO19_AD_CLK_IN | OUT | ADC SPI时钟 | DRIVE=8 |
| 40 | EXT_IO20_AD_DI | OUT | ADC SPI MOSI | DRIVE=8 |
| 42 | EXT_IO22_AD_CS_IN | OUT | ADC SPI片选 | DRIVE=8 |
| 73 | TX_A | OUT | UART TX A | DRIVE=8 |

---

## 四、模块详细说明

### 4.1 时钟与复位

| 模块 | 文件 | 功能 |
|------|------|------|
| `clk_gen` | `clk_Gen.vhd` | 50MHz→多级分频(5M/2M/1M/100k/10k/1ms/115200) |
| `div_500` | `DIV_500.vhd` | 1ms÷500→500ms(2Hz心跳) |
| `rst_g` | `RST_G.vhd` | 上电复位生成器 |

### 4.2 通信模块

| 模块 | 文件 | 功能 |
|------|------|------|
| `com_rxd` | `com_rxd.vhd` | UART接收+22字节帧解析，输出CMD/AUX/Grp/DAT1~15 |
| `com_tx` | `Com_tx.vhd` | UART发送器，并转串，LD触发，busy状态 |
| `com_rx` | `Com_rx.vhd` | 底层UART接收状态机 |
| `com_rx_charger` | `com_rx_charger.vhd` | 充电机UART帧接收器 |
| `cmd_aux_deal` | `cmd_aux_deal.vhd` | 命令译码器：CMD字节→13路控制信号 |
| `fpga_to_pc` | `FPGA_TO_PC.vhd` | FPGA→PC回传帧组包 |
| `mast_to_slave` | `Mast_TO_Slave.vhd` | 主控→分控指令组包 |
| `mast_to_charger` | `Mast_TO_Charger.vhd` | 主控→充电机指令组包 |
| `en_tx_sel` | `EN_TX_SEL.vhd` | TX输出选择器 |
| `rcv_deal` | `rcv_deal.vhd` | 接收数据存储与校验 |
| `rcv_deal_ch` | `rcv_deal_ch.vhd` | 充电机通道接收数据处理 |
| `delay_1` | `delay_1.vhd` | 单周期延迟单元 |

**UART 22字节帧格式：**
```
字节0: 帧头 (Header)
字节1: 命令 (CMD)
字节2: 组号 (Grp)
字节3: 辅助 (Aux)
字节4~19: 数据 DAT1~DAT15 (16bit值按先低后高顺序)
字节20~21: 校验和 (Checksum) + 帧尾 (End)
```

### 4.3 ADC 采集

| 模块 | 文件 | 功能 |
|------|------|------|
| `ad_mcp3202` | `AD_MCP3202.vhd` | MCP3202 12位双通道SPI ADC控制器 |
| `trig_aux` | `trig_AUX.vhd` | ADC触发脉冲生成器 |

**ADC 特性：**
- 芯片：Microchip MCP3202
- 分辨率：12位
- 通道数：2（CH0/CH1）
- SPI时序：add1计数器在2MHz域0→75循环
- 采样率：约50.6kHz
- 比较器：AD值vs REF±阈值 → P_OV/N_OV/P_NF/N_NF/U_HIGH（过压/欠压标志）

### 4.4 温度监测

| 模块 | 文件 | 功能 |
|------|------|------|
| `lm75bd` | `lm75bd.vhd` | LM75B温度传感器I2C驱动顶层 |
| `LM75B_DRV1` | `LM75B_DRV1.vhd` | I2C时序生成（SCL/SDA/读写） |
| `clk_div_500` | `clk_div_500.vhd` | LED闪烁分频 |

**温度传感器特性：**
- 芯片：LM75B
- 接口：I2C
- 时钟：100kHz
- 数据格式：9位温度值（含符号位）
- 刷新率：约 3.8kHz

### 4.5 脉冲与时序控制

| 模块 | 文件 | 功能 |
|------|------|------|
| `multi_signal` | `MULTI_SIGNAL.vhd` | 多路信号时序发生器 |
| `pulse_generate` | `Pulse_generate.vhd` | 脉冲生成器（n脉冲后停止） |
| `pulse_charge_m` | `Pulse_CHARGE_m.vhd` | 充电脉冲时序 |
| `pulse_count` | `Pulse_count.vhd` | 脉冲计数器 |
| `e_trig_l` | `E_trig_L.vhd` | 触发脉冲生成（~140us低脉冲） |
| `single_m` | `Single_M.vhd` | 单脉冲模式 |
| `trig_rvs` | `trig_rvs.vhd` | 触发边沿反转 |
| `level_edg` | `LEVEL_EDG.vhd` | 电平→边沿转换 |

**multi_signal 计算流程：**
1. 锁存 T_CH/T_MS/T_EXP0/T_EXP01/T_EXP2/T_EXP3 参数
2. 计算基准时间 t_bs = T_CH × 5000
3. 计算触发偏移 TRIG_EXP1~3
4. 生成 TRIG_MS（主触发脉冲）、TRIG_CHK（预触发检测）、M_pulse（脉冲窗口）

### 4.6 继电器控制

| 模块 | 文件 | 功能 |
|------|------|------|
| `rly_ctr_8` | `RLY_CTR_8.vhd` | 8路继电器控制器 |

**控制逻辑：**
- 输入：CMD_R 上升沿锁存 DAT(7:0)
- 输出：R1~R8 对应 DAT(0)~DAT(7)
- RLY_st(4:0) 状态输出
- RST 低有效复位

### 4.7 错误检测

| 模块 | 文件 | 功能 |
|------|------|------|
| `err_chk` | `ERR_CHK.vhd` | 16通道错误检测 |
| `rxd_stop` | `RXD_STOP.vhd` | RXD停止检测 |
| `mac_16` | `Mac_16.vhd` | 16周期消抖滤波 |
| `m_ok_chk` | `M_OK_CHK.vhd` | 主电路OK检测 |

**err_chk 检测算法：**
- 错误位 = ENx AND (ENx XOR DAx)，即使能位与数据不一致
- 统计所有错误位，≥10 → ERR_ON='1'
- 任意错误 → ERR_ALL='1'

### 4.8 EEPROM 存储

| 模块 | 文件 | 功能 |
|------|------|------|
| `at_dat_store` | `at_dat_store.vhd` | EEPROM存储管理顶层 |
| `at24c02` | `at24c02.vhd` | AT24C02 I2C EEPROM接口 |
| `Flash_I2C_core` | `Flash_I2C_core.vhd` | I2C Flash核心状态机 |
| `read_flash` | `read_flash.vhd` | Flash数据读取与锁存 |
| `DLY_RD_ROM` | `DLY_RD_ROM.vhd` | 延时参数ROM读取 |
| `DLY_RW_SEL` | `DLY_RW_SEL.vhd` | 延时读写选择 |

### 4.9 辅助模块

| 模块 | 文件 | 功能 |
|------|------|------|
| `dat_sel` | `Dat_SEL.vhd` | 10路×8组数据选择器 |
| `byte_word` | `Byte_Word.vhd` | 双字节拼接为16bit字 |
| `bit_byte` | `Bit_Byte.vhd` | 8bit拼接为字节 |
| `bit_2` | `Bit_2.vhd` | 2bit拼接 |
| `lock_1` | `Lock_1.vhd` | 单bit锁存器 |
| `lock_8` | `Lock_8.vhd` | 8bit锁存器 |
| `lock_en` | `Lock_EN.vhd` | 带使能的多路数据锁存 |
| `lock_chg_dat_sel` | `Lock_CHG_DAT_SEL.vhd` | 充电数据锁存与选择 |
| `set_u_lock` | `SET_U_LOCK.vhd` | 设定值锁存 |
| `syn_out_ctr` | `syn_out_ctr.vhd` | 同步输出控制器 |
| `syn_dat_lock` | `SYN_DAT_LOCK.vhd` | 同步数据锁存 |
| `const_3` | `Const_3.vhd` | 3bit常数（I2C地址） |
| `const_8` | `Const_8.vhd` | 8bit常数 |
| `auto_ask` | `Auto_ask.vhd` | 自动握手请求 |
| `auto_addr_dly` | `Auto_addr_dly.vhd` | 自动地址延时 |
| `chk_trig` | `CHK_trig.vhd` | 检测脉冲触发 |
| `chk_tx` | `CHK_TX.vhd` | 检测发送1 |
| `chk_tx2` | `CHK_TX2.vhd` | 检测发送2 |
| `chk_tx3` | `CHK_TX3.vhd` | 检测发送3 |
| `cmd_deal_m` | `CMD_DEAL_M.vhd` | 命令处理M |
| `cmd_trig` | `cmd_trig.vhd` | 命令触发 |
| `wk_on_show` | `WK_ON_show.vhd` | 工作状态显示 |
| `wk_st_delay` | `WK_st_delay.vhd` | 工作状态延时 |
| `com_dly_en` | `Com_dly_EN.vhd` | 通信延时使能 |
| `com_dly_rst` | `Com_dly_RST.vhd` | 通信延时复位 |
| `com_dly_clr` | `Com_dly_clr.vhd` | 通信延时清除 |
| `hc74374` | `hc74374.vhd` | 8位D触发器(74HC374) |

---

## 五、通信协议详解

### 5.1 UART 参数

| 参数 | 值 |
|------|-----|
| 波特率 | 115200 bps |
| 数据位 | 8 |
| 停止位 | 1 |
| 校验位 | 无（应用层校验） |
| 帧长度 | 22 字节（固定） |

### 5.2 命令编码（cmd_aux_deal）

| CMD输出 | 功能 |
|---------|------|
| CMD04 (SET_LOCK) | 设定值锁存 |
| CMD08 (Single) | 单次触发 |
| CMD09 (BLK_ON) | 脉冲使能 |
| CMD0B (trig_charge) | 充电触发 |
| CMD0C (trig_Main) | 主触发 |
| CMD0E (trig_Ch1) | 通道1触发 |
| CMD0F (ROM_LK) | EEPROM存储触发 |
| CMD11 (trig_Emg) | 紧急停止触发 |

### 5.3 SPI (ADC)

| 参数 | 值 |
|------|-----|
| 模式 | SPI Mode 0 (CPOL=0, CPHA=0) |
| 时钟频率 | ~2MHz (50MHz/14级联分频) |
| 数据位 | 12位/通道 |
| 通道选择 | CH0: 0xD 指令, CH1: 0xF 指令 |

### 5.4 I2C (LM75B)

| 参数 | 值 |
|------|-----|
| 模式 | 标准模式 (100kHz) |
| 器件地址 | 7位地址，由ADDR1引脚设定 |
| 读取间隔 | ~132μs (刷新率~3.8kHz) |
| 数据格式 | 9位温度值 |

---

## 六、复位结构

```
rst_g (clk_50M) ──→ RST (全局复位)
rst_g (clk_1ms) ──→ Out_EN (输出使能)

OUT_EN_ALL = Out_EN AND (NOT ERR_ALL)  ← 错误时禁止输出

SET_LOCK: 参数锁存触发
BLK_OFF:  脉冲关闭
RST_COM:  通信复位
COM_CLR_DAT: 充电机通信清除
```

---

## 七、数据流说明

### 7.1 PC 命令接收流程

```
RXD1 → com_rxd → RX_OK CONFM
                   ├── PC_CMD → cmd_aux_deal → SET_LOCK/Single/BLK_ON...
                   ├── PC_AUX → dat_sel (数据选择)
                   ├── Grp    → en_tx_sel (TX路由)
                   └── RX_DAT1~8 → 各子系统
```

### 7.2 FPGA → PC 数据回传

```
TX_DAT1~8 (选定数据) → fpga_to_pc → pc_tx_data → com_tx → EXT_IO2_TX4 → PC
```

### 7.3 脉冲触发时序

```
SET_LOCK → 锁存 T_CH/T_MS/T_EXP0~3
  → multi_signal: 计算 TMS/TEXP 触发时间点
    → TRIG_MS   (主触发, ~0.3μs脉冲)
    → TRIG_EXP1~3 (偏移触发)
    → TRIG_CHK  (预触发检测, TMS前20μs)
    → M_pulse   (脉冲窗口, ~5ms)
    → Chk2      (TMS后500us检测)
  → pulse_generate: n脉冲后停止
  → e_trig_l: ~140μs低脉冲输出
```

### 7.4 继电器控制流

```
PC命令 → RX_DAT1(15:8) → rly_ctr_8 → R1(PWR_ON)/R2/R3/R4(HV_PWR)/R5(M_PWR_ON)/R6
                 ↑ CMD_R = SET_LOCK（命令锁存时触发）
```

---

## 八、开发指南

### 8.1 综合与布局布线

1. 用 Gowin IDE 打开 `GoWin\GoWin.gprj`
2. 确认顶层模块为 `Top`（文件列表最后一项为 `top.vhd`）
3. 执行**综合 (Synthesis)**
4. 执行**布局布线 (Place & Route)**
5. 生成比特流下载

### 8.2 VHDL 编码规范

- 所有模块使用 **IEEE 1076-1993** 标准
- 必须显式声明 `ieee.numeric_std.all`（不得使用 `std_logic_arith/unsigned`）
- `open` 仅用于输出端口，输入端口必须连接信号
- `when/else` 条件赋值仅在并发语句中使用，process 内部用 `if/else`
- case 选项宽度必须与表达式宽度一致

### 8.3 常见问题

| 问题 | 原因 | 解决 |
|------|------|------|
| `to_integer/unsigned is not declared` | 缺少 `numeric_std` 库 | 添加 `use ieee.numeric_std.all;` |
| `construct only supported in VHDL 1076-2008` | 使用了VHDL 2008语法 | 改用VHDL 93等效写法 |
| `operator "&" match here` | 拼接结果类型不匹配 | 添加 `unsigned()` 类型转换 |
| `Can't find object named` | CST端口与顶层不匹配 | 检查端口名/方向一致性 |
| `TopModule` 不正确 | IDE未指定顶层 | 将 `top.vhd` 放在文件列表最后 |
| null character 错误 | 旧 Quartus 文件残留 | 删除 `db/`、`incremental_db/`、`.qws` 文件 |

### 8.4 修改顶层端口后

如果修改了 `top.vhd` 的实体端口，必须同步更新：
1. `GoWin.cst` — 物理引脚约束
2. 所有实例化该端口的模块连接

---

## 九、文件清单

```
GoWin/
├── GoWin.gprj                          # 工程文件
├── src/
│   ├── top.vhd                         # ★ 顶层模块
│   ├── GoWin.cst                       # ★ 引脚约束
│   │
│   ├── 时钟与复位
│   │   ├── clk_Gen.vhd                 # 时钟生成
│   │   ├── DIV_500.vhd                 # 500分频
│   │   ├── clk_div_500.vhd             # 500分频(通用)
│   │   ├── clk_div_10000.vhd           # 10000分频
│   │   └── RST_G.vhd                   # 复位生成
│   │
│   ├── 通信模块
│   │   ├── com_rxd.vhd                 # UART接收+帧解析
│   │   ├── com_rx_charger.vhd          # 充电机UART接收
│   │   ├── Com_rx.vhd                  # 底层UART接收
│   │   ├── Com_tx.vhd                  # UART发送
│   │   ├── cmd_aux_deal.vhd            # 命令译码
│   │   ├── FPGA_TO_PC.vhd              # PC回传组包
│   │   ├── Mast_TO_Slave.vhd           # 分控指令组包
│   │   ├── Mast_TO_Charger.vhd         # 充电机指令组包
│   │   ├── EN_TX_SEL.vhd               # TX选择
│   │   ├── rcv_deal.vhd                # 接收处理
│   │   ├── rcv_deal_ch.vhd             # 接收处理(充电机)
│   │   ├── rcv_from_pc.vhd             # PC接收
│   │   ├── RXD_STOP.vhd                # RXD停止检测
│   │   ├── auto_ask.vhd                # 自动握手
│   │   ├── Auto_addr_dly.vhd           # 地址延时
│   │   └── delay_1.vhd                 # 单周期延迟
│   │
│   ├── ADC
│   │   ├── AD_MCP3202.vhd              # MCP3202 SPI ADC
│   │   └── trig_AUX.vhd                # ADC触发
│   │
│   ├── 温度
│   │   ├── lm75bd.vhd                  # LM75B顶层
│   │   └── LM75B_DRV1.vhd              # LM75B I2C驱动
│   │
│   ├── 脉冲与时序
│   │   ├── MULTI_SIGNAL.vhd            # 多路时序发生器
│   │   ├── Pulse_generate.vhd          # 脉冲生成
│   │   ├── Pulse_CHARGE_m.vhd          # 充电脉冲
│   │   ├── Pulse_count.vhd             # 脉冲计数
│   │   ├── E_trig_L.vhd                # 低脉冲触发
│   │   ├── Single_M.vhd                # 单脉冲
│   │   ├── LEVEL_EDG.vhd               # 边沿检测
│   │   ├── trig_rvs.vhd                # 触发反转
│   │   └── Trig_OUT.vhd                # 触发输出
│   │
│   ├── 继电器
│   │   └── RLY_CTR_8.vhd               # 8路继电器
│   │
│   ├── 错误检测
│   │   ├── ERR_CHK.vhd                 # 16通道错误检测
│   │   ├── Rx_Module.vhd               # 接收模块错误
│   │   ├── M_OK_CHK.vhd                # 主电路OK检测
│   │   └── Mac_16.vhd                  # 消抖滤波
│   │
│   ├── 存储
│   │   ├── at_dat_store.vhd            # EEPROM存储管理
│   │   ├── at24c02.vhd                 # AT24C02 I2C接口
│   │   ├── Flash_I2C_core.vhd          # I2C Flash核心
│   │   ├── read_flash.vhd              # Flash读取
│   │   ├── DLY_RD_ROM.vhd              # ROM读取
│   │   └── DLY_RW_SEL.vhd              # 读写选择
│   │
│   ├── 锁存与选择
│   │   ├── Dat_SEL.vhd                 # 数据选择器
│   │   ├── Lock_1.vhd                  # 1bit锁存
│   │   ├── Lock_8.vhd                  # 8bit锁存
│   │   ├── Lock_EN.vhd                 # 使能锁存
│   │   ├── Lock_CHG_DAT_SEL.vhd        # 充电数据锁存
│   │   ├── SET_U_LOCK.vhd              # 设定值锁存
│   │   ├── SYN_DAT_LOCK.vhd            # 同步锁存
│   │   └── syn_out_ctr.vhd             # 同步输出控制
│   │
│   ├── 辅助
│   │   ├── Byte_Word.vhd               # 字节→字
│   │   ├── Bit_Byte.vhd                # 位→字节
│   │   ├── Bit_2.vhd                   # 2bit拼接
│   │   ├── Const_3.vhd                 # 3bit常数
│   │   ├── Const_8.vhd                 # 8bit常数
│   │   ├── hc74374.vhd                 # 74HC374
│   │   ├── shift10.vhd                 # 移位寄存器
│   │   └── dat_pick16.vhd              # 16bit数据选择
│   │
│   └── 显示与控制
│       ├── WK_ON_show.vhd              # 工作状态
│       ├── WK_st_delay.vhd             # 工作延时
│       ├── Com_dly_EN.vhd              # 通信延时使能
│       ├── Com_dly_RST.vhd             # 通信延时复位
│       └── Com_dly_clr.vhd             # 通信延时清除
│
└── impl/                               # 综合/布局输出目录(自动生成)
```

---

## 十、版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| V1.0 | 2020-2021 | 原 Quartus II 版本 (Altera Cyclone IV) |
| V2.0 | 2023-2024 | 移植到 Gowin GW1N-9C |
| V3.0 | 2025-2026 | 代码重构：模块化、标准化、添加注释 |

---

*文档生成日期：2026-06-25*
