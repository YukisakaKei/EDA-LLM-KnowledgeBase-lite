---
source: knowledge/Voltus/legacy/json/voltusUG__211 | chapters: [0284, 0285, 0286, 0287, 0288, 0289, 0290, 0291, 0292, 0293, 0294, 0295, 0296, 0297, 0298, 0299, 0300, 0301, 0302, 0303, 0304]
---

# 信号电迁移分析 (Signal ElectroMigration)

## 概述

信号电迁移分为两大类：

- **AC Signal EM** (wire self-heating / Joule Heating)：信号互连线中交流电流导致的发热，违反 foundry 规定的 AC 电流限值
- **DC Signal EM** (hot-carrier injection)：晶体管开关时载流子注入栅氧化层导致 Vth 漂移

---

## AC 信号电迁移

### 核心概念

AC 信号电迁移分析通过 `verify_AC_limit` 命令检查三种电流限值：

| 类型 | 限值来源 | 支持格式 |
|------|----------|----------|
| RMS (Irms) | Technology LEF + QRC Tech 文件 | PWL 表 / 方程 |
| Peak (Ipeak) | QRC Tech 文件 (ICT) | 方程 |
| Average (Iavg) | QRC Tech 文件 (ICT) | 方程 |

### 波形计算

**Irms**：AAE (Advanced Analysis Engine) delay calculator 内部积分计算。

**Ipeak**：

- Ipeak_ac_limit = Ipeak_dc_limit / sqrt(r)，其中 r 为 duty ratio
- 默认最小有效频率 1MHz (`-minPeakFreq`)，默认最小 duty ratio 0.05 (`-minPeakDutyRatio`)
- 低于阈值时跳过 peak 检查，给出 warning

**Iavg**：

- Iavg = abs.max(rising, falling) - EM Recovery factor * abs.min(rising, falling)
- EM recovery factor 定义在 QRC Tech 文件中，默认值 = 1（此时 Iavg = 0）

### 有效频率 (Effective Frequency)

- **Clock nets**：Feff = 1 / Tsw，switching factor (S) 恒为 2.0
- **Signal nets** 两种方式：
  1. `verify_AC_limit -toggle <S>`：全局切换因子，默认 S = 1.0
  2. 通过 TCF / VCD / FSDB 文件设置 activity，使用 `read_activity_file -set_net_freq true`

活动传播流程：
```
set_default_switching_activity -input_activity 0.2 -seq_activity 0.15 -period 7.0
propagate_activity
write_tcf <design>.tcf
read_activity_file -format TCF -set_net_freq true <design>.tcf
verify_AC_limit -method avg -detailed -avgRecovery 0.5 -useQRCTech -use_db_freq -report AVG.rpt
```

### 每段布线 (Routing Segment) 电流计算

避免 false violation，逐段计算 downstream 负载：

- Cnet(total) = Cwire(total) + Cpin(sinks)，不包含 driver 的 Cpin
- Irms 正比于 downstream Cnet，按 segment 面积比例分配

### AC 限值检查

**LEF ACCURRENTDENSITY 表**：

- PWL 表，按 width 和 frequency 索引
- 至少需要两个 width 值，必须单调递增
- 无表的 layer 视为 infinite limit
- 温度缩放：Irms_limit 正比于 sqrt(maxTchange)

**QRC Tech 文件 (ICT)**：

- 通过 `create_rc_corner -qx_tech_file` 或 `update_rc_corner` 加载
- ICT 文件中 `em_model` construct 定义三种方程：
  - `em_jmax_ac_peak`：Peak 限值
  - `em_jmax_ac_rms`：RMS 限值
  - `em_jmax_ac_avg`：Average 限值
- 支持变量：w (线宽), deltaT, jmax_factor, jmax_lifetime
- Via 支持基于面积的 PWL 限值

示例 ICT 规则：
```
em_jmax_ac_peak EQU 58.10 * ( w - 0.02 ) w >= 0.1 Td >= 0.5 apply r = 1
em_jmax_ac_peak EQU 58.10 * ( w - 0.02 ) w >= 0.1 Td >= 0.001 Td < 0.5
```

MMMC 设计需用 `set_default_view` 指定一个 view 进行检查。

### AC 违规预防与修复

**预防**：CTS 阶段通过 spec 中的 max_cap 参数避免 clock net 违规。

**修复**：`fixACLimitViolation` 命令通过插入 buffer 拆分 net load。通常不应在 clock net 上执行。

### 层次化设计中 Top Scope 分析

使用 `create_top_scope` 命令在 `read_sdc` 之前定义，只分析 top-level 逻辑和与 block 接口的 nets。

边界模型 (Boundary Model) 使用 `create_cell_signal_em_model` 命令生成，支持两种模式：

- 在 `set_top_module` 之前：为 sub-cell 生成并加载模型，需指定 `-cell`, `-dir`, `-spef`, `-verilog`
- 在 `set_top_module` 之后：为当前 top cell 生成模型供上层使用，需指定 `-dir`

### GUI 结果查看

1. 运行 `verify_AC_limit -report_db <filename>.db` 生成数据库
2. 使用 `read_power_rail_results -sem_db <filename>.db` 加载
3. `set_power_rail_display -plot sem_rms` / `sem_peak` / `sem_avg` 显示对应 plot
4. 在 GUI 的 Power & Rail Plots 界面中通过 SemLayers tab 控制可见性

### 报告格式 (signal.rpt)

| 字段 | 说明 |
|------|------|
| Irms/Limit | 实测 RMS 电流 / 限值 |
| Ipeak/Limit | 实测 Peak 电流 / 限值 |
| Iavg/Limit | 实测 Average 电流 / 限值 |
| Width/CutArea | 金属线宽 / via cut 面积 |
| FixWidth/FixCutNum | 修复所需的宽度 / cut 数量 |
| Cap | segment 电容 |
| PathLength | 从 driver 到 segment 的路径长度 |
| Blechlength | 同一层上连接 wire shape 的最长中心线路径 |
| RMS_V2VFactor | via-to-via spacing 的 EM 收益 |

---

## DC 信号电迁移

### 核心原理

DC 信号 EM 源自 hot-carrier injection：晶体管开关时载流子获得足够动能注入栅氧化层，导致 Vth 漂移。

- Idc = frequency * Cout
- 高频输出需较小的 Cout 以保持在 DC EM 限值内
- 通常以 maxCap vs frequency 的形式表示限值

### maxCap / maxTran 分析

Liberty 库中的三种约束类型：

| 约束 | 命令 |
|------|------|
| maxCapPerFreq | `report_design_rule -cap` |
| maxCapPerTran | `report_design_rule -tran` |
| maxCapPerFreqTran | `report_design_rule -tran` |

也可以手工设置：
```
set_max_cap_per_freq <lib_name> <pin_name> <freq> <cap>
set_max_tran_per_freq <lib_name> <pin_name> <freq> <tran>
```

### Liberty 中的频率单元 EM 限值

Liberty 的 `electromigration` group 支持：

- **Input Pin**：1-D LUT，频率限值基于 input transition time
- **Output Pin**：2-D LUT，频率限值基于 input transition time + output load capacitance

`report_freq_violation` 命令通过 STA 计算各 instance pin 的有效频率（switching factor * clock domain freq），结合 Liberty 中的 EM 模板判定违规。

### DC 违规修复

- Innovus 中：`optDesign` 命令通过 upsize cell 降低负载电容
- Voltus 中：`optDesign` 不可用，`report_freq_violation` 报告的违规暂不支持自动修复

---

## 关键命令参考

### AC 信号 EM

| 命令 | 用途 |
|------|------|
| `verify_AC_limit -method {rms\|peak\|avg} -detailed -toggle <S> -report <file>` | 执行 AC 信号 EM 检查 |
| `verify_AC_limit -minPeakFreq <freq> -minPeakDutyRatio <ratio>` | 设置 Peak 检查阈值 |
| `verify_AC_limit -report_db <file.db>` | 输出 EM 数据库供 GUI 加载 |
| `fixACLimitViolation` | 修复 AC EM 违规 (Innovus) |
| `create_top_scope` | 层次化设计 Top Scope 分析 |
| `create_cell_signal_em_model` | 生成边界模型 |
| `read_power_rail_results -sem_db <file.db>` | 加载信号 EM 结果 |
| `set_power_rail_display -plot sem_rms` | 显示 RMS 电流密度图 |

### DC 信号 EM

| 命令 | 用途 |
|------|------|
| `report_design_rule -cap` | 报告 maxCap 违规 |
| `report_design_rule -tran` | 报告 maxTran 违规 |
| `report_freq_violation` | 报告基于频率的 EM 违规 |
| `set_max_cap_per_freq` | 手工设置频率相关 cap 限值 |
| `set_max_tran_per_freq` | 手工设置频率相关 tran 限值 |
| `optDesign` | 修复 DC EM 违规 (Innovus only) |

### 活动与频率设置

| 命令 | 用途 |
|------|------|
| `set_default_switching_activity` | 设置默认切换活动 |
| `propagate_activity` | 传播切换活动 |
| `write_tcf` | 写出 TCF 活动文件 |
| `read_activity_file -format TCF -set_net_freq true` | 读入活动文件用于频率计算 |
