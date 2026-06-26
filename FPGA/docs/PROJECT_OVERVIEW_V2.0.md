# 层叠线控制工程 V2.0 — 项目总览

> **项目名称：** 层叠线控制工程 (Stacked Line FPGA Control System)  
> **版本：** V2.0 "光纤环网"  
> **仓库：** [ArT1N3/stacked-line-fpga-v2](https://github.com/ArT1N3/stacked-line-fpga-v2)  
> **日期：** 2026-06-26  
> **硬件平台：** GoWin GW1N-9 (主控) / GW1N-4 (分控)  
> **开发工具：** GoWin EDA / GHDL 仿真  
> **协议规范：** `FPGA/docs/PROTOCOL_V2.0.md`

---

## 一、工程背景

本项目为 **450kV 高压电源系统** 的 FPGA 控制固件，实现一个主控板 + 多个分控板的通信与控制。

### V1.0 → V2.0 核心变化

| 维度 | V1.0 (原版) | V2.0 (层叠线) |
|------|-------------|---------------|
| **物理介质** | 同轴电缆 (RXD/TXD) | 光纤 (2 根组成环) |
| **通信拓扑** | 星型总线 + 时隙仲裁 | **单向光纤环网**（存储转发） |
| **协议** | UART + 脉宽双协议 | **统一帧协议** (HDLC 风格) |
| **寻址** | 4-bit 地址 (1~9) | **8-bit 地址** (1~254) |
| **差错检测** | 13位累加和 | **CRC-16-CCITT** |
| **帧格式** | 固定 20/22 字节 | **可变长 9~249 字节** |
| **拓扑发现** | 无 | **TOPO_DISCOVER 自动发现** |
| **冲突避免** | 分时仲裁 | **环网转发，无冲突** |
| **电气隔离** | 无 (同轴电缆) | **光纤隔离** (450kV 耐压) |
| **设计方法** | BDF 原理图 + VHDL 混合 | **纯 VHDL RTL**（模块化） |
| **仿真验证** | 无 | **GHDL testbench 覆盖** ✅ |

---

## 二、物理拓扑

```
                         ┌── 光纤环下行 ──┐
                         ▼                 │
  ┌──────────┐      ┌──────────┐      ┌──────────┐         ┌──────────┐
  │  主控板   │      │ 分控 #1   │      │ 分控 #2   │         │ 分控 #N   │
  │  GW1N-9  │      │  GW1N-4  │      │  GW1N-4  │  ...    │  GW1N-4  │
  │          │      │ RX    TX  │      │ RX    TX  │         │ RX    TX  │
  │  TX   RX │      │  ↓    ↑   │      │  ↓    ↑   │         │  ↓    ↑   │
  └──┬───▲──┘      └──┬───┬──┘      └──┬───┬──┘         └──┬───┬──┘
     │   │             │   │            │   │               │   │
     │   └─────────────┴───┴────────────┴───┴───────────────┘   │
     │                    光纤环上行                               │
     └───────────────────────────────────────────────────────────┘
```

- **单向逻辑环：** 主控 TX → 分控1 RX → 分控1 TX → 分控2 RX → ... → 分控N TX → 主控 RX
- **每节点 1 光口：** 一个光纤接收器 (RX) + 一个光纤发送器 (TX)
- **数据永远单向流动**，不存在反向通信
- 物理上使用 **N+1 段光纤**连接 N 个分控 + 1 个主控

---

## 三、文件结构

```
FPGA/
├── docs/
│   └── PROTOCOL_V2.0.md              # 完整协议规范 (579行)
│
├── master_control/                    # V1.0 主控（保留，参考）
│   └── MST_TEST_450kV_V3_uncharge/
│
├── slave_ control/                    # V1.0 分控（保留，参考）
│   └── slave_ctrl_V1.80(using)/
│
├── master_control_v2/                 # ★ V2.0 主控
│   ├── master_v2.gprj                # GoWin 工程文件
│   └── src/
│       ├── master_v2_top.vhd         # 顶层
│       ├── ring_master.vhd           # 环网管理器（帧生成+超时+重试+拓扑表）
│       ├── fiber_frame_rx.vhd        # 帧接收器 (CRC校验+去填充)
│       ├── fiber_frame_tx.vhd        # 帧发送器 (CRC生成+字节填充)
│       ├── com_rx.vhd                # UART 字节接收 (115200bps, 8×过采样)
│       ├── com_tx.vhd                # UART 字节发送
│       ├── rxd_clk.vhd               # 波特率时钟恢复 (50MHz÷52→921.6kHz)
│       ├── mac_16.vhd                # 16级毛刺滤波器
│       ├── err_dff.vhd               # 故障锁存
│       ├── master_v2.cst             # 引脚约束
│       └── master_v2.sdc             # 时序约束
│
└── slave_control_v2/                  # ★ V2.0 分控
    ├── slave_ctrl_v2.gprj            # GoWin 工程文件
    ├── synth.tcl                     # 综合脚本
    ├── sim/                          # ★ 仿真验证
    │   ├── tb_fiber_frame.vhd        # 完整帧收发测试 (4项测试)
    │   ├── tb_minimal.vhd            # 最小帧测试
    │   ├── tb_sync.vhd               # 同步发送测试
    │   ├── tb_direct.vhd             # 直接发送测试
    │   └── fix_log.md                # 仿真修复日志
    └── src/
        ├── slave_ctrl_v2.vhd         # 顶层
        ├── ring_forward.vhd          # 环网转发控制器 (地址匹配+状态机)
        ├── fiber_frame_rx.vhd        # 帧接收器 (同主控)
        ├── fiber_frame_tx.vhd        # 帧发送器 (同主控)
        ├── cmd_processor.vhd         # 命令解析+响应构建+载荷追加
        ├── fault_detector_v2.vhd     # 故障检测 (短路/过流/过温)
        ├── com_rx.vhd                # UART 字节接收
        ├── com_tx.vhd                # UART 字节发送
        ├── rxd_clk.vhd               # 波特率时钟恢复
        ├── mac_16.vhd                # 16级毛刺滤波器
        ├── mac_32.vhd                # 32级毛刺滤波器
        ├── err_dff.vhd               # 故障锁存
        ├── en_err_chk.vhd            # 故障检测使能
        ├── top.vhd                   # 备选顶层
        ├── slave_ctrl_v2.cst         # 引脚约束
        └── slave_ctrl_v2.sdc         # 时序约束
```

---

## 四、核心模块架构

### 4.1 分控数据流

```
fiber_rx_pin
    │
    ▼
[mac_16] 毛刺滤波 (16级DDR, ~320ns)
    │
    ▼
[rxd_clk] 波特率时钟恢复 (50MHz ÷ 52 = 921.6kHz)
    │
    ▼
[com_rx] UART 字节接收 (起始位+8数据位+停止位)
    │ rx_byte, rx_lk, rx_busy
    ▼
┌──────────────────────────────────────┐
│         ring_forward (环网转发)        │
│  ┌─────────────────────────────────┐ │
│  │ fiber_frame_rx (帧接收器)        │ │
│  │  · HDLC 字节去填充               │ │
│  │  · CRC-16-CCITT 校验             │ │
│  │  · 帧缓冲 (256B)                 │ │
│  └──────────┬──────────────────────┘ │
│             │ frame_valid / frame_err │
│             ▼                         │
│  ┌─────────────────────────────────┐ │
│  │ cmd_processor (命令处理器)       │ │
│  │  · 地址匹配 (单播/广播/收集)     │ │
│  │  · 命令执行 (12条命令)           │ │
│  │  · 响应构建 + 载荷追加           │ │
│  │  · 重算 CRC                     │ │
│  └──────────┬──────────────────────┘ │
│             │ tx_start                │
│             ▼                         │
│  ┌─────────────────────────────────┐ │
│  │ fiber_frame_tx (帧发送器)        │ │
│  │  · CRC-16-CCITT 生成             │ │
│  │  · HDLC 字节填充                 │ │
│  │  · UART 字节输出                 │ │
│  └─────────────────────────────────┘ │
└──────────────────────────────────────┘
    │ tx_byte, tx_load, tx_busy
    ▼
[com_tx] UART 字节发送 → fiber_tx_pin
```

### 4.2 主控架构

```
ring_master (环网管理器)
├── fiber_frame_tx    # 命令帧发送
├── fiber_frame_rx    # 响应帧接收
├── 超时定时器         # 环游超时检测
├── 重试计数器         # 最多3次重试
├── 拓扑表            # 物理顺序映射
└── PC UART 接口      # 上位机通信 (复用V1.0 22B帧)
```

---

## 五、协议帧格式

```
┌──────┬──────┬──────┬──────┬──────┬──────┬──────────┬──────┬──────┐
│ SOF  │ FLAGS│ DST  │ SRC  │ CMD  │ LEN  │ PAYLOAD  │CRC16 │ EOF  │
│ 1B   │ 1B   │ 1B   │ 1B   │ 1B   │ 1B   │ 0~240B   │ 2B   │ 1B   │
│ 0x7E │      │      │      │      │      │          │      │ 0x7E │
└──────┴──────┴──────┴──────┴──────┴──────┴──────────┴──────┴──────┘
```

- **最小帧：** 9 字节 (LEN=0)
- **最大帧：** 249 字节 (LEN=240)
- **CRC：** CRC-16-CCITT (poly=0x1021, init=0xFFFF)，小端序
- **字节填充：** 0x7E→0x7D 0x5E, 0x7D→0x7D 0x5D (HDLC 风格)

### 命令集 (12 条)

| 命令 | 名称 | 说明 |
|------|------|------|
| 0x01 | STAT_QUERY | 单从机状态查询 |
| 0x02 | STAT_COLLECT | 广播收集状态 (边走边追加) |
| 0x03 | RLY_CTRL | 继电器控制 |
| 0x04 | CFG_WRITE | 配置写入 |
| 0x05 | CFG_READ | 配置读取 |
| 0x06 | TOPO_DISCOVER | 拓扑发现 |
| 0x08 | FAULT_CLEAR | 清除故障锁存 |
| 0x09 | RESET_SLAVE | 软复位分控 |
| 0x0A | IDENTIFY | 读取从机身份 |
| 0x0B | ADDR_ASSIGN | 软件分配地址 |
| 0x0D | BROADCAST_RLY | 广播继电器控制 |
| 0x0E | BROADCAST_CFG | 广播配置写入 |

---

## 六、仿真验证

### 测试环境

- **仿真器：** GHDL (C:\ghdl\GHDL\bin\)
- **时钟：** 50MHz (T=20ns)
- **DUT：** `fiber_frame_rx.vhd`（帧接收器）

### 测试结果

| Testbench | 测试内容 | 结果 |
|-----------|---------|------|
| `tb_fiber_frame` | 完整测试套件 (4项) | ✅ ALL PASS |
| 　├ Test 1 | 最小帧 (LEN=0) | ✅ PASS |
| 　├ Test 2 | CRC 错误帧 | ✅ PASS (frame_err='1') |
| 　├ Test 3 | 带载荷帧 (LEN=2) | ✅ PASS |
| 　└ Test 4 | 字节填充 (0x7E/0x7D 转义往返) | ✅ PASS |
| `tb_minimal` | 最小帧测试 | ✅ PASS |
| `tb_sync` | 同步发送测试 | ✅ PASS |
| `tb_direct` | 直接时钟边沿发送 | ✅ PASS |

### 修复历史

详见 `FPGA/slave_control_v2/sim/fix_log.md`。主要修复项：
1. CRC 校验逻辑缺失（从未真正比对）
2. testbench CRC 位序错误（GHDL `(0 to N-1)` 向量方向）
3. ST_HEADER / ST_CRC 缺少字节去填充
4. 连续转义字节处理
5. frame_valid 单周期脉冲 delta-cycle 竞态

---

## 七、与上位机接口（不变）

V2.0 完全复用 V1.0 的上位机通信协议：

- **物理接口：** PC UART (115200bps, 8N1)
- **帧格式：** 22 字节固定帧 (EB + CMD + 数据 + CHK + AA)
- **温度传感器：** LM75B I²C
- **充电机通信：** RS-485

上位机无需任何修改即可兼容 V2.0。

---

## 八、版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| V1.0 | 2024 | 同轴电缆星型总线，时隙仲裁，12 分控 |
| V1.80 | 2025 | 优化分控固件，增加故障检测 |
| **V2.0** | **2026-06** | **光纤环网，统一帧协议，拓扑发现，254 分控** |

---

## 九、快速开始

### 综合 (GoWin EDA)
```tcl
# 分控
open_project slave_ctrl_v2.gprj
run_synthesis

# 主控
open_project master_v2.gprj
run_synthesis
```

### 仿真 (GHDL)
```bash
cd FPGA/slave_control_v2/sim
ghdl -a --work=work ../src/fiber_frame_rx.vhd tb_fiber_frame.vhd
ghdl -e tb_fiber_frame
ghdl -r tb_fiber_frame --assert-level=error
```

---

*文档结束 — 层叠线控制工程 V2.0*
