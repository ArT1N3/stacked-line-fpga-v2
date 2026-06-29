# 层叠线控制工程 V2.0 — 剩余工作计划

> **日期:** 2026-06-29  
> **版本:** V2.0 "光纤环网"  
> **仓库:** [stacked-line-fpga-v2](https://github.com/ArT1N3/stacked-line-fpga-v2)

---

## 当前状态总览

| 模块 | 状态 | 说明 |
|------|------|------|
| 协议规范 | ✅ 完成 | `PROTOCOL_V2.0.md` (579行) |
| 帧收发器 (fiber_frame_rx/tx) | ✅ 完成 | CRC+填充+仿真验证通过 |
| 分控环网转发 (ring_forward) | ✅ 完成 | 地址匹配+命令处理+转发 |
| 分控命令处理 (cmd_processor) | ✅ 完成 | 12条命令全部实现 |
| 分控顶层 (slave_ctrl_v2) | ✅ 基本完成 | 光纤+继电器+故障灯已连接 |
| 分控仿真 | ✅ 完成 | 4个 testbench 全部 PASS |
| 主控环网管理 (ring_master) | ⚠️ 骨架完成 | 状态机框架有，细节待完善 |
| 主控顶层 (master_v2_top) | ❌ 仅占位 | 外设全部接地/悬空，需集成 |
| V1.0 外设模块 | ✅ 已复制 | 109个文件已复制到V2.0目录 |
| 综合验证 | ❌ 未跑 | 主控/分控都没综合 |

---

## 工作计划

### 阶段一：主控顶层集成 (master_v2_top.vhd)

当前 `master_v2_top.vhd` 只连接了光纤环网链路，其他外设全部是占位符：
```vhdl
PC_TXD   <= '1';   -- 占位
CHG_TX   <= '1';   -- 占位
SDA      <= 'Z';   -- 占位
...
```

#### 1.1 PC UART 通信 (上位机 → 主控)
**涉及模块:** `com_rx.vhd`, `rcv_from_pc.vhd`, `FPGA_TO_PC.vhd`, `com_tx.vhd`

```
PC_RXD → mac_16 → rxd_clk → com_rx → rcv_from_pc → [命令解析]
[响应数据] → FPGA_TO_PC → com_tx → PC_TXD
```

**要点:**
- PC UART 使用独立的 com_rx/com_tx（不能和光纤环网共用）
- 需要例化第二套 `com_rx`/`com_tx` + `rxd_clk`
- `rcv_from_pc` 解析 22字节帧 → 提取 CMD/DAT → 触发 `ring_master.cmd_req`
- `ring_master.rsp_valid` → 触发 `FPGA_TO_PC` 构建响应帧 → 发回上位机

#### 1.2 充电机 RS-485 通信
**涉及模块:** `com_rx_charger.vhd`, `Mast_TO_Charger.vhd`, `com_tx.vhd`

```
CHG_RX → com_rx_charger → [充电机数据处理]
[充电机控制] → Mast_TO_Charger → com_tx → CHG_TX
```

**要点:**
- 充电机使用独立 UART (115200bps，参数可能不同)
- 需要第3套 `com_rx`/`com_tx` 实例
- RS-485 方向控制: `CHG_EN` (发送使能)

#### 1.3 PFC 通信
**涉及模块:** `com_rx_pfc.vhd`, `Mast_TO_PFC.vhd`

同充电机结构，独立的 UART 链路。

#### 1.4 命令处理状态机 (CMD_DEAL_M)
**涉及模块:** `CMD_DEAL_M.vhd`, `cmd_trig.vhd`, `cmd_aux_deal.vhd`

```
rcv_from_pc → CMD_DEAL_M → ring_master (cmd_req/cmd_code/cmd_dst/...)
ring_master (rsp_valid/rsp_src/rsp_data) → FPGA_TO_PC → PC_TXD
```

**要点:**
- 这是 V1.0 → V2.0 的核心桥接模块
- 将 V1.0 的上位机命令翻译为 `ring_master` 的 cmd_* 接口信号
- 将 `ring_master` 的 rsp_* 输出翻译回 V1.0 PC UART 帧格式

#### 1.5 ADC 采样 (MCP3202)
**涉及模块:** `AD_MCP3202.vhd`, `AD_trig.vhd`

读取电压/电流采样值，用于监控和故障检测。

#### 1.6 I²C (温度 + EEPROM)
**涉及模块:** `LM75B_DRV1.vhd`, `lm75bd.vhd`, `at24c02.vhd`, `read_flash.vhd`, `Flash_I2C_core.vhd`

读取温度和配置数据。

#### 1.7 继电器控制
**涉及模块:** `RLY_CTR_8.vhd`

6路继电器输出 (CTR_RLY1~6)，由环网响应数据驱动。

#### 1.8 脉冲触发
**涉及模块:** `Pulse_generate.vhd`, `Pulse_CHARGE_m.vhd`, `Trig_OUT.vhd`, `trig_100.vhd`

充电/测试脉冲生成，V2.0 升级为高精度可调。

#### 1.9 故障检测 + LED 指示
**涉及模块:** `ERR_CHK.vhd`, `HV_CHK.vhd`, `LED_TEST.vhd`

综合故障检测，LED 状态指示。

#### 1.10 引脚约束更新
**涉及文件:** `master_v2.cst`

确认所有 I/O 引脚分配正确（光纤 + UART + ADC + I2C + 继电器 + 脉冲）。

---

### 阶段二：主控 ring_master 完善

当前 `ring_master.vhd` 有状态机骨架但细节待补：

#### 2.1 帧构建逻辑 (ST_BUILD_HDR / ST_BUILD_PAYLOAD)
- 根据 `cmd_code/cmd_dst/cmd_mod/cmd_data` 填充帧缓冲
- 计算 CRC-16
- 控制 fiber_frame_tx 发送

#### 2.2 响应解析逻辑 (ST_WAIT_RESP)
- 解析 fiber_frame_rx 接收的响应帧
- 提取 rsp_src/rsp_data/rsp_cmd
- 提取拓扑表数据 (TOPO_DISCOVER 响应)

#### 2.3 超时与重试 (ST_TIMEOUT / ST_RETRY)
- 超时计数器（当前硬编码 `timeout_ms=x"64"` = 100ms）
- 3次重试逻辑
- 重试失败 → 标记从机离线

#### 2.4 拓扑表维护
- `topo_table` 数据结构已定义
- 需实现 TOPO_DISCOVER 响应解析和拓扑表更新

#### 2.5 定期轮询
- 周期性发送 STAT_COLLECT 广播
- 间隔可配置（默认 500ms）

---

### 阶段三：综合验证

#### 3.1 分控综合
```tcl
open_project slave_ctrl_v2.gprj
run_synthesis
```
- 检查资源利用率 (GW1N-4)
- 检查时序收敛 (50MHz)
- 修复 warning/error

#### 3.2 主控综合
```tcl
open_project master_v2.gprj
run_synthesis
```
- 检查资源利用率 (GW1N-9, QFN88)
- 检查时序收敛
- 检查引脚分配冲突
- 修复所有综合错误

#### 3.3 仿真补充
- `ring_forward` + `cmd_processor` 联仿
- `ring_master` 独立仿真
- 主控+分控 端到端环网仿真（可选）

---

### 阶段四：硬件测试准备

#### 4.1 光纤模块适配
- 确认 AFBR-1521CZ/2521CZ 接口电平
- 确认 UART 空闲高电平兼容性
- 确认 50MHz → 921.6kHz 分频精度 (50M÷52=961.5kHz, 偏差 4.2%)

#### 4.2 分控硬件检查
- 继电器输出极性
- 故障检测阈值
- 拨码开关地址

#### 4.3 分控数量扩展测试
- 2节点环 → 4节点环 → N节点环
- 测量实际环游延迟

---

## 优先级排序

| 优先级 | 任务 | 预估工时 | 依赖 |
|--------|------|---------|------|
| 🔴 P0 | 1.1 PC UART 集成 | 2h | — |
| 🔴 P0 | 1.4 命令处理桥接 (CMD_DEAL_M → ring_master) | 3h | 1.1 |
| 🔴 P0 | 3.1 分控综合 | 0.5h | 分控代码完备 |
| 🔴 P0 | 3.2 主控综合 | 0.5h | 阶段一完成 |
| 🟡 P1 | 1.2 充电机通信 | 2h | — |
| 🟡 P1 | 1.7 继电器控制 | 1h | 1.4 |
| 🟡 P1 | 2.1 帧构建逻辑 | 2h | — |
| 🟡 P1 | 2.2 响应解析逻辑 | 2h | 2.1 |
| 🟡 P1 | 2.3 超时重试 | 1.5h | 2.2 |
| 🟢 P2 | 1.6 I²C (温度+EEPROM) | 2h | — |
| 🟢 P2 | 1.8 脉冲触发 | 1.5h | — |
| 🟢 P2 | 1.9 故障检测+LED | 1h | — |
| 🟢 P2 | 2.4 拓扑表维护 | 1.5h | 2.2 |
| 🟢 P2 | 2.5 定期轮询 | 1h | 2.4 |
| ⚪ P3 | 1.3 PFC 通信 | 1.5h | — |
| ⚪ P3 | 1.5 ADC 采样 | 1h | — |
| ⚪ P3 | 1.10 引脚约束更新 | 0.5h | 阶段一完成 |
| ⚪ P3 | 3.3 补充仿真 | 4h | — |
| ⚪ P3 | 4.x 硬件测试 | 4h | 综合通过 |

---

## 关键风险

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| UART 实例数量不够 | GW1N-9 资源限制 | V1.0 已验证可承载多路 UART |
| 波特率时钟偏差 | 4.2% 偏差可能超 UART 容限 | 可调整分频系数或使用独立时钟 |
| V1.0 模块接口不兼容 | 信号命名/时序差异 | 逐一对比 V1.0 top.vhd 的连接方式 |
| ring_master 状态机不完备 | 命令丢失/响应超时 | 先完善基本收发，再逐步加超时重试 |
| 引脚分配冲突 | CST 中未考虑新外设 | 对比 V1.0 cst 和 V2.0 cst |

---

*计划结束 — 建议从 P0 任务开始推进*
