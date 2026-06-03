---
source: knowledge/PrimeTime/json/htmlView_20/topic | entries: [0001, 0002, 0003, 0004, 0005, 0006, 0007, 0008, 0010, 0011, 0012, 0013, 0014, 0015, 0016]
---

# PrimeTime HyperScale 检查违规类型参考

## 概述

PrimeTime HyperScale 流程在 block-level 和 top-level 分析之间进行一致性检查，当发现约束不匹配时报告对应的违规（violation）。违规分为两大类：

### Auto-Fixable（可自动修复）

工具可在后续迭代中自动解决。包括以下 5 种：

```
boundary_logic_value    clock_latency    clock_skew_with_uncertainty
data_arrival            input_slews
```

修复方式：
- 用最新的 top-level context 重新运行 block 分析并重新优化 block
- 优化 top-level 设计以适配 block 设计范围

### Non-Auto-Fixable（不可自动修复）

**必须手动修复**，否则 HyperScale 流程无效。包括以下 9 种：

```
boundary_ideal_network    clock_attributes      clock_mapping
clock_relations           clock_uncertainty      env_variables
global_timing_derate      library_mapping        operating_conditions
```

修复原则：
- 优先将 block-level 约束对齐到 top-level 约束（环境、时钟等）
- 必要时改进 top-level 约束定义以兼容层次化分析

---

## 时钟相关违规

### clock_mapping（Non-Auto-Fixable）

**含义：** PrimeTime 无法为 block 或 top-level 时钟找到匹配的对应时钟。

**自动映射机制：** 工具按以下优先级自动匹配 top 与 block 级时钟：
1. 同一物理源网络上的重叠时钟源对象
2. 匹配的时钟周期
3. 匹配的时钟波形
4. 匹配的时钟名称（前缀匹配）

**典型原因：**
- `extra_clock` — block 级定义了多余的时钟，top 级无对应
- `missing_clock` — top 级时钟传播到 block 边界，但 block 级未定义匹配时钟

**修复：** 编辑 block 或 top 级时序约束，确保所有时钟在两级别间完整且一致地定义。

**相关命令：** `report_clock` / `report_constraint`

---

### clock_relations（Non-Auto-Fixable）

**含义：** top 级与 block 级之间时钟的异步（asynchronous）或互斥（exclusive）关系不匹配。

**修复：** 使用 `set_clock_groups` 命令统一两级别的时钟关系设置。

**相关命令：** `set_clock_groups` / `report_clock` / `report_constraint`

---

### clock_latency（Auto-Fixable）

**含义：** 给定 pin 上的时钟延迟（clock latency）在 top 级与 block 级分析间不匹配。

**修复：** 工具可在后续迭代中自动修复，但**不保证**一定成功（因 block 间存在交互）。需**先修复所有时钟存在性违规**，否则 arrival 违规可能无法修复。

**相关命令：** `set_clock_latency` / `report_constraint`

---

### clock_skew_with_uncertainty（Auto-Fixable）

**含义：** block 级时钟已成功映射到 top 级时钟，但两级别间的 interclock skew 值不同。

**修复：**
- 若由 clock latency 不匹配导致 → 工具可在后续迭代中自动修复（不保证）；需**先修复时钟存在性违规**
- 若由 uncertainty 不匹配导致 → 使用 `set_clock_uncertainty` 修改 block 或 top 级时钟 uncertainty

**相关命令：** `set_clock_latency` / `set_clock_uncertainty` / `report_clock` / `report_constraint`

---

### clock_uncertainty（Non-Auto-Fixable）

**含义：** block 级时钟已成功映射到 top 级时钟，但 uncertainty（skew）值不同。

**修复：** 使用 `set_clock_uncertainty` 修改 block 或 top 级时钟 uncertainty。

**相关命令：** `set_clock_uncertainty` / `report_clock` / `report_constraint`

---

## 边界相关违规

### boundary_ideal_network（Non-Auto-Fixable）

**含义：** 在给定对象上，top 级与 block 级之间的 ideal network 设置不匹配。

**触发场景：** 某对象在 top 级被标记为 ideal_network 但在 block 级未被标记（或相反）。

**修复：** 使用 `set_ideal_network` 或 `remove_ideal_network` 在 top 或 block 级调整设置。

**相关命令：** `set_ideal_network` / `remove_ideal_network` / `report_constraint`

---

### boundary_logic_value（Auto-Fixable）

**含义：** 在层次化边界 pin/port 上设置或传播的逻辑值存在冲突。

**典型场景：**
- HyperScale block 级分析将 SCANEN port 设为 case value 0 并进行时序分析
- 该 block 在 top 级实例化时，传播到层次化 pin 的逻辑值 ≠ 0（或没有 case/constant 值）

**注意：** 报告的冲突逻辑值可能来自用户定义的 `set_case_analysis`，也可能来自设计中的功能常量（如 Verilog 定义）或 tie-high/tie-low 库单元连接。

**自动处理：** HyperScale top flow 自动捕获实例边界的逻辑值并覆盖 block 级用户设置，因此此类违规被视为 auto-fixable。对于多实例 block，工具将同一 port 上不同实例的冲突 case analysis 合并为无 case 值，不报告此类违规。

**修复：** 确认 case value 差异后，手动对齐约束，或在下次 block 级运行中应用最新的 top context。

**相关命令：** `get_attribute` / `report_case_analysis` / `report_constraint`

---

## 数据与时序违规

### data_arrival（Auto-Fixable）

**含义：** HyperScale top 级报告的数据到达窗口不匹配 — block 级定义的 data arrival window 未能完全包含同 pin 上 top 级传播的实际 arrival window。

**具体条件：**
- block 级最小/early window 比实际到达 pin/port 的最小到达时间**更大或更晚**
- block 级最大/late window 比 top 级实际最大到达时间**更小或更早**

**影响：** 这意味着 block 内部 reg-to-reg 路径可能存在未被 top 级分析覆盖的时序违规。原因是 block 接口路径的线耦合（wire coupling）扩展到 block 内部，导致 crosstalk 效应在 block 级分析中未被充分考虑。

**修复：** 此为二阶效应检查，无需用户直接修复设计或约束。若需验证更宽窗口的影响，保存更新后的 block context 并用新 context 重新运行 HyperScale block 级分析。

**相关命令：** `report_constraint` / `hier_enable_analysis`

---

### input_slews（Auto-Fixable）

**含义：** pin 上的输入斜率（input slew）在 top 级与 block 级之间不匹配。

**修复：** HyperScale 在后续迭代中自动解决。

**相关命令：** `report_constraint`

---

## 约束一致性违规

### env_variables（Non-Auto-Fixable）

**含义：** block 级与 top 级分析中影响时序分析结果（QoR）的应用定义 Tcl 变量存在差异。

**检查范围：** 仅检查影响时序分析结果的应用级别 Tcl 变量。

**修复：** 必须手动统一变量设置，确保时序分析结果一致。

**相关命令：** `report_constraint`

---

### operating_conditions（Non-Auto-Fixable）

**含义：** 工作条件相关设置（operating condition、温度、电压）在两级分析间存在差异。

**相关设置命令：** `set_operating_condition` / `set_temperature` / `set_voltage`

**检查范围：** 仅检查 design-wide 工作条件或 block 边界 port 上的设置，不检查特定 pin/cell 上的局部设置。

**修复：** 统一工作条件设置。若违规是 library 不匹配的副作用，需**先解决 library_mapping 违规**。

**相关命令：** `set_operating_conditions` / `set_temperature` / `set_voltage` / `report_constraint`

---

### library_mapping（Non-Auto-Fixable）

**含义：** block 级与 top 级使用的库（library）存在差异。涉及 link 设计、选择工作条件、定义 scaling library group 等操作。

**涉及命令：** `set_min_library` / `define_scaling_lib_group` / `set_operating_condition` / `set_wire_load_model`，以及变量 `link_path` 等。

**连锁影响：** library 不匹配可能引发其他违规（如 operating_conditions、timing derate），统一库设置可同时解决这些连锁违规。

**修复：** 统一 block 级与 top 级的库使用和设置。

**相关命令：** `define_scaling_lib_group` / `set_min_library` / `set_operating_conditions` / `set_wire_load_model` / `link_path` / `search_path` / `report_constraint`

---

### global_timing_derate（Non-Auto-Fixable）

**含义：** block 级与 top 级分析中应用的时序降额（timing derate）存在差异。

**检查机制：** block 级分析时捕获并保存全局时序 derate 值（包括 design-level 和 library cell derate，不含 instance-specific derate），与 top 级分析设置进行比较。

**判断标准：** 不要求精确匹配：
- block 级 derate 更保守 → **不报违规**（block 级分析已覆盖）
- top 级需要更大 margin → **报告违规**

**修复：** 使 block 级与 top 级使用相同 derate，或使 block 级使用更保守的设置。

**注意：** library cell derate 违规也可能由库差异引起，先检查 `library_mapping`。

**相关命令：** `set_timing_derate` / `report_timing_derate` / `report_constraint`

---

## 违规汇总

| 违规类型 | 分类 | 可自动修复 | 关键修复命令 |
|----------|------|:----------:|-------------|
| clock_mapping | 时钟 | | 手动编辑约束 |
| clock_relations | 时钟 | | `set_clock_groups` |
| clock_latency | 时钟 | ✓ | `set_clock_latency` |
| clock_skew_with_uncertainty | 时钟 | ✓ | `set_clock_uncertainty` |
| clock_uncertainty | 时钟 | | `set_clock_uncertainty` |
| boundary_ideal_network | 边界 | | `set_ideal_network` / `remove_ideal_network` |
| boundary_logic_value | 边界 | ✓ | 手动对齐或应用 top context |
| data_arrival | 时序 | ✓ | 重新运行 block 级分析 |
| input_slews | 时序 | ✓ | 自动修复 |
| env_variables | 约束 | | 手动统一变量 |
| operating_conditions | 约束 | | `set_operating_conditions` / `set_temperature` / `set_voltage` |
| library_mapping | 约束 | | 统一库设置 |
| global_timing_derate | 约束 | | `set_timing_derate` |

> **优先级建议：** 先修复 Non-Auto-Fixable 违规（特别是 library_mapping，因为它可能连锁引发其他违规），再处理 Auto-Fixable 违规。时钟存在性违规应优先于其他时钟相关违规修复。
