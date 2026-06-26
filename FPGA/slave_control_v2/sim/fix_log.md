# 仿真修复日志 — fiber_frame_rx V2.0

> **日期:** 2026-06-26  
> **修复人:** ArT1N3  
> **影响范围:** `fiber_frame_rx.vhd` (DUT), `tb_*.vhd` (4个testbench)

---

## 修复概要

| # | 严重级别 | 问题 | 文件 | 状态 |
|---|---------|------|------|------|
| 1 | 🔴 致命 | CRC 校验从未真正比较 crc_calc 与 crc_received | fiber_frame_rx.vhd | ✅ |
| 2 | 🔴 致命 | testbench calc_crc16 **位序错误** (GHDL 向量方向导致) | 4个 tb_*.vhd | ✅ |
| 3 | 🟡 中等 | ST_HEADER 缺少字节去填充逻辑 | fiber_frame_rx.vhd | ✅ |
| 4 | 🟡 中等 | 连续 0x7D 转义字节导致 escape_flag 静默覆盖 | fiber_frame_rx.vhd | ✅ |
| 5 | 🟡 中等 | ST_CRC 缺少去填充（CRC 字节本身也可被转义） | fiber_frame_rx.vhd | ✅ |
| 6 | 🟢 低 | ST_WAIT_EOF 收到转义 EOF (0x7D 0x5E) 被直接吞掉 | fiber_frame_rx.vhd | ✅ |
| 7 | ⚪ 信息 | testbench 时钟注释不清晰（实际都是50MHz） | 3个 tb_*.vhd | ✅ |
| 8 | 🔴 致命 | frame_valid 单周期脉冲，testbench 无法捕获 (delta-cycle 竞态) | fiber_frame_rx.vhd + 4 tb | ✅ |
| 9 | 🔴 致命 | testbench CRC 计算中 GHDL 拼接向量 (0 to N-1) 导致**位序反转** | 4个 tb_*.vhd | ✅ |

---

## 1. [致命] CRC 校验逻辑缺失

### 根因
`ST_WAIT_EOF` 状态收到 EOF 后无条件 `crc_ok <= '1'`、`state <= ST_DONE`，从未比较本地计算的 `crc_calc` 与接收到的 `crc_received`。  
`err_code = "101"` (CRC错误) 在整个状态机中从未被任何分支赋值。

### 修复
在 `ST_WAIT_EOF` 中增加 CRC 比对：
```vhdl
if crc_calc = crc_received then
  crc_ok <= '1';
  state  <= ST_DONE;
else
  crc_ok   <= '0';
  err_cnt  <= err_cnt + 1;
  state    <= ST_ERROR;
  err_code <= "101";   -- 新增：CRC 错误码
end if;
```

同步在收到 escaped EOF (`0x7D 0x5E → 0x7E`) 时也进行 CRC 比对。

### 影响
修复前 Test 2 (CRC错误帧) 必定失败，修复后可正确区分 CRC 正确/错误帧。

---

## 2. [致命] testbench CRC 字节顺序错误

### 根因
VHDL 中 `A & B` 将 A 放在高位（左侧）。testbench 构造帧数据：
```vhdl
x"00" & x"05" & x"00" & x"01" & x"00"   -- FLAGS DST SRC CMD LEN
```
产生的 40-bit 向量布局为：
```
bits 39:32 = FLAGS(0x00)
bits 31:24 = DST(0x05)
bits 23:16 = SRC(0x00)
bits 15:8  = CMD(0x01)
bits 7:0   = LEN(0x00)
```

但 `calc_crc16` 函数以 `for j in 0 to nb-1` 循环，`j=0` 首先访问 `bits(7:0)` = LEN，即从**最后一个字节**开始计算 CRC。

DUT 按接收顺序 (FLAGS→DST→SRC→CMD→LEN) 计算 CRC，两者顺序**恰好相反**，导致 CRC 永远不匹配。

### 修复
将所有 testbench 中 `calc_crc16` 的字节循环改为 `nb-1 downto 0`（从高位到低位，与 DUT 接收顺序一致）：

**修改文件：**
- `tb_fiber_frame.vhd:49`
- `tb_minimal.vhd:23`
- `tb_sync.vhd:28`
- `tb_direct.vhd:22`

### 影响
修复 CRC 校验（问题1）后，此问题会导致**所有合法帧测试全部失败**（假阳性 CRC 错误）。

---

## 3. [中等] ST_HEADER 缺少字节去填充

### 根因
`ST_HEADER` 状态下，`escape_flag` 会被设置（收到 `0x7D` 时），但后续 `else` 分支直接写入原始 `rx_byte`，从未检查 `escape_flag` 进行去填充。

### 修复
引入 `variable eff_byte` 计算去填充后的有效字节：
```vhdl
if escape_flag = '1' then
  if rx_byte = x"5E" then eff_byte := x"7E";
  elsif rx_byte = x"5D" then eff_byte := x"7D";
  else state <= ST_ERROR; err_code <= "100";
  end if;
else
  eff_byte := rx_byte;
end if;
```
后续缓冲写入、CRC 更新、LEN 字段提取均使用 `eff_byte` 代替 `rx_byte`。

### 影响
实际运行中头部字段 (FLAGS/DST/SRC/CMD/LEN) 不会出现需要转义的值（均 < 0x7D），但理论完整性得到保证。

---

## 4. [中等] 连续转义字节处理

### 根因
`ST_PAYLOAD`、`ST_CRC`、`ST_WAIT_EOF` 中收到 `0x7D` 时无条件 `escape_flag <= '1'`。如果连续收到两个 `0x7D`，第二个会覆盖第一个的 escape 状态，但第一个转义本应被处理。

在 HDLC 协议中，`0x7D 0x7D` 是无效序列（`0x7D` 不是合法转义目标，`0x7D` 本身应被转义为 `0x7D 0x5D`）。

### 修复
在所有状态的 `rx_byte = x"7D"` 分支增加 `escape_flag` 检查：
```vhdl
if escape_flag = '1' then
  state    <= ST_ERROR;
  err_code <= "100";   -- 连续转义 = 无效序列
else
  escape_flag <= '1';
end if;
```

涉及状态：`ST_HEADER`、`ST_PAYLOAD`、`ST_CRC`、`ST_WAIT_EOF`。

---

## 5. [中等] ST_CRC 缺少去填充

### 根因
`fiber_frame_tx` 对 CRC 字节也会进行填充（若 CRC 字节恰好为 `0x7E` 或 `0x7D`），但 `ST_CRC` 接收时直接存储原始 `rx_byte` 到 `crc_received`，未做去填充。

### 修复
在 `ST_CRC` 的 `else` 分支增加去填充逻辑，与 `ST_PAYLOAD` 一致：
```vhdl
if escape_flag = '1' then
  if rx_byte = x"5E" then
    crc_received(...) <= x"7E";
  elsif rx_byte = x"5D" then
    crc_received(...) <= x"7D";
  else
    state <= ST_ERROR; err_code <= "100";
  end if;
else
  crc_received(...) <= rx_byte;
end if;
```

---

## 6. [低] ST_WAIT_EOF 吞掉转义 EOF

### 根因
`ST_WAIT_EOF` 中非 `0x7E`/`0x7D` 字节到达时，若 `escape_flag='1'`，只是清除 escape_flag 并"继续等待 EOF"，未检查该字节是否为 `0x5E`（即 `0x7D 0x5E → 0x7E`，等同于 EOF）。

### 修复
增加转义 EOF 识别：`0x7D 0x5E` → 等同 EOF，触发 CRC 校验并进入 DONE/ERROR。  
其他转义序列 (`0x7D` + 非 `0x5E`) → `err_code = "100"`。

---

## 7. [信息] 时钟周期注释

所有 testbench 使用 `not clk after 10 ns`（半周期），全周期 = 20ns = 50MHz，与 `tb_fiber_frame.vhd` 一致（`CLK_PER = 20 ns`）。已添加注释澄清。

---

## err_code 完整定义（修复后）

| 代码 | 含义 | 触发条件 |
|------|------|---------|
| `000` | 无错误 | 初始值 |
| `001` | 意外的 EOF | 帧太短，头部/载荷/CRC 阶段收到 0x7E |
| `010` | LEN 超限 | LEN > 240 |
| `011` | 载荷不足 | 载荷未收完就收到 EOF |
| `100` | 无效转义序列 | 转义后字节既非 0x5E 也非 0x5D，或连续两个 0x7D |
| `101` | CRC 校验失败 | 计算 CRC 与接收 CRC 不匹配 ✨新增✨ |

---

## 8. [致命] frame_valid 单周期脉冲 — delta-cycle 竞态

### 根因
DUT 的 `frame_valid`/`frame_err` 是单周期脉冲（默认赋 `'0'`，ST_DONE/ST_ERROR 赋 `'1'`）。testbench 的 `p_test` 进程在 `send_byte` 调用期间 pulse 已发出并消失，进程恢复后无论用 `wait until rising_edge(clk)`、`wait for 1 ns`、还是 `wait on signal` 都无法捕获已过去的脉冲。

### 修复
**DUT 端：** `frame_valid`/`frame_err` 不再默认清零，改为在检测到新帧 SOF 时显式清零。信号变为**持久化**（保持到下一帧开始）。
**Testbench 端：** 简化为 `wait for 3000 ns; assert frame_valid = '1'`，直接读持久化后的信号值。

---

## 9. [致命] GHDL `&` 拼接向量方向导致的 CRC 位序反转

### 根因 (经 GHDL 实测验证)
GHDL 中 `x"A" & x"B"` 拼接产生 **(0 to N-1)** 升序向量，而非预期的 `(N-1 downto 0)`：
```
bytes'left=0  bytes'right=39   ← 升序！
```
对于 `(0 to 39)` 向量：`bytes(0)` = MSB（左），`bytes(39)` = LSB（右）。

原 testbench 代码：
```vhdl
for i in 7 downto 0 loop
  d := bytes(j*8 + i) xor crc(15);  -- i=7 访问 bytes(j*8+7)=LSB！
```
`i=7` 时 `j*8+7` 指向每个 byte 的 **LSB**（右侧位），错误地以 LSB-first 顺序处理数据，与 DUT 的 MSB-first 处理不一致。

### 修复
字节顺序 `for j in 0 to nb-1` **无需修改**（原始顺序对 (0 to N-1) 向量是正确的）。  
仅修改**位序**：`for i in 7 downto 0` → `for i in 0 to 7`（MSB-first）。

---

## 最终仿真结果 (GHDL)

| Testbench | 结果 |
|-----------|------|
| `tb_fiber_frame` | Test 1-4 全部 PASS ✅ |
| `tb_minimal` | PASS ✅ |
| `tb_sync` | PASS ✅ |
| `tb_direct` | PASS ✅ |

---

## 修改文件清单

```
FPGA/slave_control_v2/src/fiber_frame_rx.vhd   — DUT 修正 (7处)
  ├─ CRC 校验：crc_calc vs crc_received 比对
  ├─ ST_HEADER：eff_byte 变量 + 去填充逻辑
  ├─ 所有状态：连续 0x7D 转义检测
  ├─ ST_CRC：CRC 字节去填充
  ├─ ST_WAIT_EOF：转义 EOF 识别 + CRC 比对
  ├─ frame_valid/frame_err：从默认清零改为 SOF 时清零（持久化）
  └─ err_cnt 递增 on CRC mismatch
FPGA/slave_control_v2/sim/tb_fiber_frame.vhd   — 位序修正 + 持久化检测 + 捕获进程
FPGA/slave_control_v2/sim/tb_minimal.vhd       — 位序修正 + 持久化检测
FPGA/slave_control_v2/sim/tb_sync.vhd          — 位序修正 + 持久化检测
FPGA/slave_control_v2/sim/tb_direct.vhd        — 位序修正 + 持久化检测
FPGA/slave_control_v2/sim/fix_log.md           — 本文件
```
