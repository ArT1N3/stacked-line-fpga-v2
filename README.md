# 层叠线控制工程 V2.0

> **Stacked Line FPGA Control System — Fiber Ring Topology**  
> 450kV 高压电源系统 — 主控+分控 FPGA 光纤环网控制固件

[![VHDL](https://img.shields.io/badge/VHDL-RTL-blue)](FPGA/) [![Sim](https://img.shields.io/badge/GHDL-Passing-brightgreen)](FPGA/slave_control_v2/sim/) [![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

---

## 概述

V2.0 是 450kV FPGA 控制系统的重大升级版本，核心变化是从 V1.0 的**同轴电缆星型总线**迁移到**光纤环网拓扑**。

| 特性 | V1.0 | V2.0 |
|------|------|------|
| 物理介质 | 同轴电缆 | **光纤 (2根)** |
| 拓扑 | 星型总线 + 时隙仲裁 | **单向环网 (存储转发)** |
| 协议 | UART + 脉宽 | **统一帧协议 (HDLC)** |
| 最大分控 | 12 | **254** |
| 差错检测 | 13位累加和 | **CRC-16-CCITT** |
| 拓扑发现 | 无 | **自动发现** |

## 物理拓扑

```
主控 TX → 分控1 RX → 分控1 TX → 分控2 RX → ... → 分控N TX → 主控 RX
```

单向逻辑环，数据永远单向流动。每节点 1×RX + 1×TX。光纤隔离 450kV 耐压。

## 目录结构

```
FPGA/
├── docs/                    # 协议规范 + 项目文档
├── master_control_v2/       # V2.0 主控 FPGA (GW1N-9)
├── slave_control_v2/        # V2.0 分控 FPGA (GW1N-4)
│   ├── sim/                 # GHDL 仿真验证 ✅
│   └── src/                 # RTL 源码
├── master_control/          # V1.0 主控 (参考)
└── slave_ control/          # V1.0 分控 (参考)
```

## 快速开始

### 综合 (GoWin EDA)
```bash
cd FPGA/slave_control_v2
gw_sh synth.tcl
```

### 仿真 (GHDL)
```bash
cd FPGA/slave_control_v2/sim
ghdl -a --work=work ../src/fiber_frame_rx.vhd tb_fiber_frame.vhd
ghdl -e tb_fiber_frame
ghdl -r tb_fiber_frame --assert-level=error
```

## 文档

- [协议规范 V2.0](FPGA/docs/PROTOCOL_V2.0.md)
- [项目总览](FPGA/docs/PROJECT_OVERVIEW_V2.0.md)
- [仿真修复日志](FPGA/slave_control_v2/sim/fix_log.md)

## 许可证

MIT License — 详见 [LICENSE](LICENSE)
