# 分控板 FPGA 工程说明 (slave_ctrl V1.80)

## 工程概览

| 项目 | 说明 |
|------|------|
| **工程名称** | slave_ctrl V1.80 |
| **FPGA 型号** | 高云 GW1N-9C (GW1N-UV9QN88C6/I5) |
| **开发环境** | Gowin IDE (高云半导体) |
| **HDL 语言** | VHDL (IEEE 1076-1993) |
| **顶层模块** | `top` (`top.vhd`) |
| **主控核心** | `slave_ctrl` (`slave_ctrl.vhd`) |
| **约束文件** | `slave_ctrl.cst` / `slave_ctrl.sdc` |
| **时钟频率** | 50MHz 外部晶振 |
| **工程路径** | `src\` |

---

## 一、系统概述

本 FPGA 是 450kV 高压电源系统的**分控板核心**，负责单个电源模块的本地控制。每块分控板管理 **10 个独立通道**，通过**单线共享总线**与主控板通信。

### 核心功能

- **双协议通信**：在同一根 RXD 线上同时支持脉宽调制协议和 UART 协议
- **10 通道故障检测**：短路检测（有源低）+ 电源故障检测（有源高）
- **多节点仲裁**：支持最多 12 块分控板共享同一总线，地址编码避免冲突
- **通道使能控制**：主控通过 UART 远程配置每通道的触发/工作使能
- **LED 状态显示**：上电地址显示 + 实时故障指示

---

## 二、系统架构

### 顶层框图 (top.vhd)

```
                    ┌──────────────────────────────────────────┐
  clk (50MHz) ─────┤                                          ├── TXD (RS-232 TX)
  rst ─────────────┤  ┌──────────┐    ┌───────────┐           │
  RXD ────┬────────┤  │ mac_16   │───→│ slave_ctrl│───┬───────├── en_trig[10:1]
          │        │  │(320ns滤波)│    │  (主核心)  │   │       │
          │        │  └──────────┘    └─────┬─────┘   │       ├── en_work[10:1]
          │        │         ↓              │         │       │
          │        │  ┌───────────┐   ┌─────┴─────┐   │       ├── red_led[10:1]
          ├────────┤  │en_err_chk │   │uart_cmd   │   │       │
  short_in[10:1] ──┤  │(RXD高时屏蔽)│   │_deal      │───┤       │
          │        │  └─────┬─────┘   └───────────┘   │       │
          │        │        ↓                          │       │
  charge_in[10:1] ─┴───────slave_ctrl.charge_in───────┘       │
  address[3:0] ───────────────────────────────────────────────┘
```

### 内部数据流 (slave_ctrl.vhd)

```
                               ┌─────────────────────────────────────────────┐
                               │                 slave_ctrl                   │
  clk ───────────┬─────────────┤                                              │
                 │             │  ┌──────────┐   ┌───────────┐               │
                 ├─────────────┤→│ rxd_clk  │──→│clock_     │→clk_5ms/500ms  │
                 │             │  │(/52分频) │   │divider    │               │
                 │             │  └──────────┘   └───────────┘               │
  rxd ───────────┼─────────────┤       ↓                                     │
                 │             │  clk_115200                                 │
                 │             │  ┌──────────┐   ┌───────────┐  en_work[10:1]│
                 ├─────────────┤→│ com_rxd  │──→│uart_cmd   │──→─────────────┤
                 │             │  │(UART RX) │   │_deal      │  en_trig[10:1]│
                 │             │  └──────────┘   └───────────┘               │
                 │             │                     │ rst_err                │
  short_in[10:1]─┼─────────────┤  ┌────────────────┐ ↓                       │
  charge_in[10:1]┼─────────────┤→│ err_detector   │←┘                       │
                 │             │  │ _led           │──→red_led_total[10:1]   │
  address[3:0] ──┼─────────────┤  │ (10ch故障检测)  │                         │
                 │             │  └───────┬────────┘                         │
                 │             │          │ err_charge[10:1]                  │
                 │             │  ┌───────┴────────┐                         │
                 ├─────────────┤→│ order_shift     │──→TXD                  │
                 │             │  │ (脉宽协议+TXD)   │                         │
                 │             │  └────────────────┘                         │
                 │             │                                              │
                 │             │  ┌──────────┐                               │
                 │             ├─→│led_flicker│──→flicker_out[10:1]          │
                 │             │  │(上电闪烁)  │                               │
                 │             │  └──────────┘                               │
                 │             │       ↓                                     │
                 │             │  ┌──────────┐                               │
                 │             ├─→│led_driver│──→red_led_out[10:1]           │
                 │             │  │(2选1输出) │                               │
                 │             │  └──────────┘                               │
                 │             └─────────────────────────────────────────────┘
```

---

## 三、双协议通信机制

分控板在一根 RXD 线上同时支持两种协议，通过**脉宽区分**互不干扰：

### 协议对比

| 特性 | 脉宽协议 | UART 协议 |
|------|----------|-----------|
| **通路** | RXD → order_shift → TXD | RXD → com_rxd → uart_cmd_deal |
| **物理层** | 低脉冲宽度编码 | 标准异步串行 8N1 |
| **波特率** | — (脉冲计时) | 115200 bps |
| **帧长度** | 1 个脉冲 | 20 字节 |
| **响应方式** | 从机主动上传 10bit 状态 | 从机被动接收/执行 |
| **多节点** | 地址×100μs 时隙仲裁 | 地址编码在数据帧内 |
| **用途** | 实时状态查询/充电控制 | 通道配置/故障复位 |

### 脉宽协议命令

| 脉冲宽度 | 命令 | 说明 |
|----------|------|------|
| 150~220 μs | 在线状态查询 | 返回电源故障状态 |
| 380~420 μs | 使能状态查询 | 返回通道使能状态 |
| 480~520 μs | 充电测试 | 触发过流检测窗口 |

### UART 命令

| 命令码 | 说明 |
|--------|------|
| `0x55` ('U') | 更新通道配置：8×16bit 数据包锁存 |
| `0x01` (SOH) | 故障复位：清除所有故障锁存器 |

### UART 帧格式（20 字节）

```
字节 1:     帧头 HEAD  = 0xEB
字节 2:     命令 CMD
字节 3~17:  8×16bit 数据 (dat1/3/5/7/9/11/13/15，高字节在前)
字节 18~19: 16bit 校验和 (字节2~17的低12位累加)
字节 20:    帧尾 END2  = 0xAA
```

---

## 四、引脚分配 (top.vhd)

| FPGA 引脚 | 信号名 | 方向 | 位宽 | 功能 | CST 配置 |
|-----------|--------|------|------|------|----------|
| 52 | clk | IN | 1 | 50MHz 系统时钟 | LVCMOS33, PULL_UP |
| — | rst | IN | 1 | 异步复位(低有效) | — |
| — | RXD | IN | 1 | RS-232 接收 | — |
| — | address | IN | 4 | 板卡地址(1~9) | — |
| — | charge_in | IN | 10 | 电源故障(高有效) | — |
| — | short_in | IN | 10 | 短路故障(低有效) | — |
| 25 | TXD | OUT | 1 | RS-232 发送 | LVCMOS33, DRIVE=8 |
| — | en_trig | OUT | 10 | 触发输出(低有效) | — |
| — | en_work | OUT | 10 | 通道使能输出 | — |
| 68 | red_led[10] | OUT | 1 | 故障LED 10 | LVCMOS33, DRIVE=8 |
| 69 | red_led[9] | OUT | 1 | 故障LED 9 | LVCMOS33, DRIVE=8 |
| 70 | red_led[8] | OUT | 1 | 故障LED 8 | LVCMOS33, DRIVE=8 |
| 71 | red_led[7] | OUT | 1 | 故障LED 7 | LVCMOS33, DRIVE=8 |
| 72 | red_led[6] | OUT | 1 | 故障LED 6 | LVCMOS33, DRIVE=8 |
| ... | red_led[5:1] | OUT | 5 | 故障LED 5~1 | LVCMOS33, DRIVE=8 |
| — | en_work[10:1] | OUT | 10 | 通道使能 | LVCMOS33, DRIVE=8 |
| — | en_trig[10:1] | OUT | 10 | 触发输出 | LVCMOS33, DRIVE=8 |

> 注：完整引脚分配见 `slave_ctrl.cst`

---

## 五、模块详细说明

### 5.1 时钟与复位

| 模块 | 文件 | 功能 |
|------|------|------|
| `rxd_clk` | `rxd_clk.vhd` | 50MHz÷52→~961.5kHz UART 采样时钟 |
| `clock_divider` | `clock_divider.vhd` | 961.5kHz→200Hz(clk_5ms)→2Hz(clk_500ms) LED 时钟链 |

**时钟域分布：**

| 时钟 | 频率 | 来源 | 使用者 |
|------|------|------|--------|
| clk | 50MHz | 外部晶振 | 主核心、故障检测、脉宽测量 |
| clk_115200 | ~961.5kHz | rxd_clk | UART 收发、LED 分频链 |
| clk_5ms | ~200Hz | clock_divider | LED 闪烁 |
| clk_500ms | ~2Hz | clock_divider | LED 闪烁 |

### 5.2 通信模块

| 模块 | 文件 | 功能 |
|------|------|------|
| `com_rxd` | `com_rxd.vhd` | UART 多帧接收器：20 字节帧解析 |
| `Com_rx` | `Com_rx.vhd` | UART 字节接收器：8×过采样 DDR |
| `rcv_deal` | `rcv_deal.vhd` | 帧数据存储与校验（HEAD+END+Checksum） |
| `dat_store_RX` | `dat_store_RX.vhd` | 帧字节存储阵列（两级锁存） |
| `dat_CONFM_RX` | `dat_CONFM_RX.vhd` | 校验验证器（三重检查） |
| `uart_cmd_deal` | `uart_cmd_deal.vhd` | UART 命令执行：配置/复位+地址路由 |
| `order_shift` | `order_shift.vhd` | 脉宽协议顶层：命令检测+状态上传 |
| `ERR_order` | `ERR_order.vhd` | 脉宽测量器（100ns 分辨率, 13bit） |
| `ERR_ctrl` | `ERR_ctrl.vhd` | 脉宽命令状态机（3 种命令+多节点仲裁） |
| `ERR_shift_top` | `ERR_shift_top.vhd` | 状态上传移位寄存器 |
| `ERR_shift_test` | `ERR_shift_test.vhd` | 10bit 并转串（10μs/bit LSB 先出） |
| `mux21a` | `mux21a.vhd` | 位间空闲间隔插入 |
| `countor_addr_RX_cnt` | `countor_addr_RX_cnt.vhd` | UART 帧字节地址计数器(0→20) |
| `countor_T_over` | `countor_T_over.vhd` | 帧超时计数器(~416μs) |
| `comp_clr` | `comp_clr.vhd` | 零比较器（帧完成保护） |
| `delay_1` | `delay_1.vhd` | DDR 延迟线（~1.5 时钟周期） |
| `mac_16` | `Mac_16.vhd` | RXD 毛刺滤波器（16 级 DDR, 320ns 窗口） |

### 5.3 故障检测

| 模块 | 文件 | 功能 |
|------|------|------|
| `err_detector_led` | `err_detector_led.vhd` | 故障检测顶层（10 通道） |
| `ERR_detector_block_top` | `ERR_detector_block_top.vhd` | 短路检测阵列（10×独立通道） |
| `ERR_detector_block` | `ERR_detector_block.vhd` | 单通道检测：Mac_32 + DFF 锁存 |
| `Mac_32` | `Mac_32.vhd` | 32 级过采样滤波器（~10kHz, 3.2ms 窗口） |
| `ERR_DFF` | `ERR_DFF.vhd` | 故障锁存 DFF（异步复位+时钟使能） |
| `ERR_charge_or_short` | `ERR_charge_or_short.vhd` | 故障 OR 合并：short(低有效) OR charge(高有效) |
| `ERR_LED` | `ERR_LED.vhd` | LED 输出寄存器 |
| `EN_ERR_CHK` | `EN_ERR_CHK.vhd` | 使能门控：RXD 空闲高时屏蔽短路输入 |

**故障检测流程：**
```
short_in(有源低) → en_err_chk(RXD高时屏蔽) → Mac_32(3.2ms消抖) → ERR_DFF(锁存) → ERR_charge_or_short(OR合并) → ERR_LED(寄存) → red_led
charge_in(有源高) ───────────────────────────────────────────────────────↗
```

### 5.4 LED 与显示

| 模块 | 文件 | 功能 |
|------|------|------|
| `led_driver` | `led_driver.vhd` | 2 选 1 输出：闪烁模式/故障状态 |
| `LED_FLICKER` | `LED_FLICKER.vhd` | 上电地址显示（~2 秒）+ 实时故障切换 |

**LED 行为：**
- 上电 ~2 秒：显示地址编码闪烁（10Hz），验证 FPGA 配置和拨码开关
- 2 秒后：自动切换到实时故障状态显示

---

## 六、时序约束 (.sdc)

```
create_clock -name clk -period 20.000 -waveform {0.000 10.000} [get_ports {clk}]
```

- 时钟频率：50MHz (周期 20ns，占空比 50%)
- 无其他时序例外约束

---

## 七、数据流说明

### 7.1 主控查询在线状态

```
主控 RXD 发送 150~220μs 低脉冲
  → 分控 err_order 测量脉宽
  → err_ctrl 解码为 "在线查询"
  → 按地址延时 (N-1)×100μs
  → err_shift_test 加载电源故障状态
  → 10bit 串行输出 → mux21a → TXD → 主控
```

### 7.2 主控配置通道使能

```
主控 RXD 发送 UART 帧 (CMD=0x55 + 128bit 配置数据)
  → com_rxd 解析 20 字节帧
  → rcv_deal 验证 HEAD/END/Checksum
  → uart_cmd_deal 锁存配置
  → 根据 address [3:0] 路由 10bit 到 en_work/en_trig
```

### 7.3 主控复位故障

```
主控 RXD 发送 UART 帧 (CMD=0x01)
  → uart_cmd_deal 生成 rst_err 低脉冲
  → err_detector_led 清除所有故障锁存器
```

---

## 八、多节点总线架构

```
                        共享 RS-232 总线 (RXD+TXD)
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
   ┌────┴────┐          ┌────┴────┐          ┌────┴────┐
   │ 主控板   │          │ 分控 #1  │          │ 分控 #N  │
   │ address │          │ addr=1  │   ...    │ addr=N  │
   │  N/A    │          │延时=0μs │          │延时=N×100μs│
   └─────────┘          └─────────┘          └─────────┘
```

- 最多 12 块分控板共享同一总线
- 每块板通过 address[3:0] 拨码开关设置唯一地址(1~9)
- 脉宽协议响应时，各分控按地址延时发送，避免总线冲突
- UART 协议通过数据帧内地址字段区分目标板

---

## 九、开发指南

### 9.1 综合与布局布线

1. 用 Gowin IDE 打开 `slave_ctrl.gprj`
2. 确认顶层模块为 `top`
3. 执行**综合 (Synthesis)**
4. 执行**布局布线 (Place & Route)**

### 9.2 编码规范

- 所有模块使用 **IEEE 1076-1993** 标准
- 聚合表达式必须显式指定范围：`(in1'range=>en)` 而非 `(others=>en)`
- 输入端口不能使用 `open`，必须连接信号

### 9.3 常见问题

| 问题 | 原因 | 解决 |
|------|------|------|
| `Illegal aggregate choice 'others'` | 未约束聚合表达式 | 使用 `signal'range=>value` |
| `Failed to open .sdc file` | SDC 文件被删除 | 重新创建含时钟约束的 SDC |
| `Can't set timing constraint` | SDC 端口名不匹配 | 核对顶层实体端口名 |
| null character 错误 | 旧 Quartus 文件残留 | 删除 `db/`/`output_files/`/`simulation/` |

---

## 十、文件清单

```
slave_ctrl_V1.80(using)/
├── slave_ctrl.gprj                  # 工程文件
├── src/
│   ├── top.vhd                      # ★ 顶层实体
│   ├── slave_ctrl.vhd               # ★ 主控核心
│   ├── slave_ctrl.cst               # ★ 引脚约束
│   ├── slave_ctrl.sdc               # ★ 时序约束
│   │
│   ├── 通信模块
│   │   ├── com_rxd.vhd              # UART 多帧接收器
│   │   ├── Com_rx.vhd               # UART 字节接收器
│   │   ├── rcv_deal.vhd             # 帧校验与存储
│   │   ├── dat_store_RX.vhd         # 帧字节存储阵列
│   │   ├── dat_CONFM_RX.vhd         # 校验和验证
│   │   ├── uart_cmd_deal.vhd        # UART 命令执行
│   │   ├── countor_addr_RX_cnt.vhd  # 帧字节地址计数
│   │   ├── countor_T_over.vhd       # 帧超时计数器
│   │   ├── comp_clr.vhd             # 零比较器
│   │   └── delay_1.vhd              # DDR 延迟线
│   │
│   ├── 脉宽协议
│   │   ├── order_shift.vhd          # 脉宽协议顶层
│   │   ├── ERR_order.vhd            # 脉宽测量器
│   │   ├── ERR_ctrl.vhd             # 脉宽命令状态机
│   │   ├── ERR_shift_top.vhd        # 状态上传顶层
│   │   ├── ERR_shift_test.vhd       # 10bit 并转串
│   │   ├── mux21a.vhd               # 位间空闲插入
│   │   └── interval_sel.vhd         # 位间时序(已集成)
│   │
│   ├── 故障检测
│   │   ├── err_detector_led.vhd     # 故障检测顶层
│   │   ├── ERR_detector_block_top.vhd   # 短路检测阵列
│   │   ├── ERR_detector_block.vhd   # 单通道检测
│   │   ├── Mac_32.vhd               # 32 级消抖滤波
│   │   ├── Mac_16.vhd               # 16 级消抖滤波(RXD)
│   │   ├── ERR_DFF.vhd              # 故障锁存 DFF
│   │   ├── ERR_charge_or_short.vhd  # 故障 OR 合并
│   │   ├── ERR_LED.vhd              # LED 输出寄存器
│   │   └── EN_ERR_CHK.vhd           # RXD 门控屏蔽
│   │
│   ├── 时钟与复位
│   │   ├── rxd_clk.vhd              # UART 波特率时钟
│   │   ├── clock_divider.vhd        # LED 时钟分频链
│   │   ├── DIV_921600.vhd           # 高精度分频(未用)
│   │   └── RST_G.vhd                # 内部上电复位(未用)
│   │
│   ├── LED 与显示
│   │   ├── led_driver.vhd           # LED 2 选 1 输出
│   │   └── LED_FLICKER.vhd          # 上电地址闪烁
│   │
│   └── 辅助模块
│       ├── Const_8.vhd              # 8bit 常数(未用)
│       ├── filter_jk.vhd            # JK 滤波器(未用)
│       └── err_detector_level.vhd   # 电平检测(未用)
│
└── impl/                            # 综合/布局输出(自动生成)
```

---

## 十一、版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| V1.0 ~ V1.7 | 2021-2022 | 原 Quartus II 版本 |
| V1.80 | 2023 | 移植到 Gowin GW1N-9C，适配高云 EDA |

---

*文档生成日期：2026-06-25*
