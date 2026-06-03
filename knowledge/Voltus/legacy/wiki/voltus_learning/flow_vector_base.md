---
source: knowledge/Voltus/legacy/json/voltustxtcmdref__211 | chapters: [0016, 0019, 0022, 0023, 0034, 0037, 0096, 0099, 0107, 0109, 0121, 0150, 0152, 0153, 0154, 0175]
---

# Voltus 功耗分析学习笔记

> 脚本执行顺序：Step 0 读入设计数据 → Step 1 配置功耗分析模式 → Step 2 加载 include 文件 → Step 3 向量 profiling 找最差窗口 → Step 4 配置 Rail 分析模式 → Step 5 定义 PG Net / Domain / 电压源位置 → Step 6 运行 Rail 分析

---

## Step 0：读入设计数据

在一切分析之前，需读入所有设计文件。

### `read_lib -lef` — LEF（tlef / std cell lef / mem lef）


```tcl
read_lib -lef file_names
```

LEF 通过 `read_lib` 的 `-lef` 参数读入（Voltus legacy 没有独立的 `read_lef` 命令）。首个文件必须为 technology LEF。`dotlib_file`（.lib）与 `-lef` 互斥。

### `read_lib` — Timing Library

```tcl
read_lib dotlib_file [-min min_lib_list] [-max max_lib_list]
```

支持文本格式 `.lib` 和 Cadence 二进制格式（LDB）。多 corner 分析时通过 `-min`/`-max` 分别指定。

> `read_lib` 和 `read_lib -lef` 实际加载发生在 `set_top_module` 之后（schedule 机制）。

### `set_top_module` — 指定顶层

```tcl
set_top_module <TOP_NAME>
```

触发此前 schedule 的所有 `read_lib` 和 `read_verilog` 实际加载。

### `read_verilog` — Netlist

```tcl
read_verilog netlist
```

读入门级结构化 Verilog 网表。支持多文件和 `.gz` 自动匹配。

### `read_sdc` — SDC（top flatten）

```tcl
read_sdc fileName [-reset]
```

加载 SDC 时序约束文件。`-reset` 替换之前加载的全部约束。

### `read_twf` — TWF（top）

```tcl
read_twf filenames [-scope string] [-cell master_cell_name]
```

用于 power / noise 计算的时序窗口。`-scope` 指定层次化路径。

### `specify_def` — DEF（top + sub blocks）

```tcl
specify_def fileNameList
```

轻量模式，**不加载物理数据入内存**，推荐用于 >500 万实例的大设计。DEF 须按**顶层 → block → sub-block**的层次顺序列出。

### `read_spef` — SPEF（top + sub blocks）

```tcl
read_spef -decoupled <spef_files>
```

读入 RC 寄生参数文件，`-decoupled` 解耦加载。作为参考，`specify_spef` 是轻量替代，使用时必须有外部 TWF。

### `read_activity_file` — FSDB（动态向量功耗分析）

```tcl
read_activity_file -format {VCD | FSDB | TCF | SAIF | PHY | SHM} \
  [-start time] [-end time] [-scope scope_name] name
```

用于动态向量功耗分析的 VCD/FSDB 活动文件。`-start`/`-end` 可从 vector profiling 的 `$worst_power_window_start`/`$worst_power_window_end` 传入。

> **读入两次**：先在 `report_vector_profile` 之前无 `-start`/`-end` 读入一次供 profiling 扫描全波形；profiling 完成后获得 `$worst_power_window_start` / `$worst_power_window_end`，再带 `-start`/`-end` 重新读入一次，截取最差窗口做精确功耗分析。

### TWF vs FSDB 对比

| | TWF | FSDB |
|---|---|---|
| **本质** | 时序窗口（信号*可能*何时翻转） | 波形数据（信号*实际*如何翻转） |
| **来源** | STA 工具（Tempus `write_twf`） | 仿真器（VCS/SPICE） |
| **关联命令** | `read_twf` | `read_activity_file -format FSDB` |
| **分析方法** | Vectorless（无需仿真向量） | Vector-Driven（需仿真向量） |
| **精度** | 估算级，适中 | 仿真精确，最高 |
| **速度** | 快，适合 full-chip | 慢，通常只跑 peak 窗口 |
| **文件内容** | 每 pin 的 arrival time 窗口/slew/slack | 信号实际翻转的时间点和状态变化 |


### 不通过独立命令读入的文件

| 文件类型 | 传入方式 |
|----------|----------|
| .cl（Power Grid View Library） | `set_power_analysis_mode -power_grid_library` 或 `set_rail_analysis_mode -power_grid_library` |
| QRC Tech File | `set_power_analysis_mode -extraction_tech_file` 或 `set_rail_analysis_mode -extraction_tech_file` |
| ICT-EM Rule File | `set_rail_analysis_mode -ict_em_models` |

---

## Step 1：`set_power_analysis_mode` 配置分析模式

**语法**：
```
-method { static | dynamic_vectorless | dynamic_vectorbased | dynamic_mixed_mode | event_based | vector_profile }
```

**默认值**：`static`

### 各选项说明

| 选项 | 需 VCD/FSDB | 适用阶段 | 精度 | 说明 |
|------|:---:|:--------:|:----:|------|
| `static` | 否 | 早期估算 | 平均 | 静态功耗分析，计算平均功耗（Internal + Switching + Leakage），不含时间维度。不需要 VCD |
| `dynamic_vectorless` | 否 | 无向量时的动态分析 | 中 | 用 STA 的 TWF + activity propagation 确定翻转时刻，覆盖全设计 |
| `dynamic_vectorbased` | 是 | Signoff | 高 | 用 VCD/FSDB 驱动，知道哪些 instance 在什么时间翻转，精度最高 |
| `dynamic_mixed_mode` | 部分 | 混合场景 | 中高 | 结合 vector-based 和 vectorless，部分 block 有 VCD 时使用 |
| `event_based` | 是 | 事件精确分析 | 高 | 基于事件，单次运行支持多种分析流程 |
| `vector_profile` | 是 | 向量预处理 | — | 从 VCD/FSDB 中识别最差功耗窗口，不产生最终功耗结果 |


---

## Step 2：`set_power_include_file` 加载补充配置

**作用**：加载一个补充 Tcl 文件，文件中可以写 Voltus 不支持的老版本（legacy EPS）命令，以及 `report_power` 的额外选项。

**原文**：
> *"Specifies a power analysis include file. You can use the set_power_include_file command to specify certain commands of the dynamic engine which do not have a Voltus equivalent."*

> *"This file will include all commands that can not be translated to Voltus commands. In addition, you can also include the report_power command options to generate different power reports."*

### 核心用途
1. **跑 legacy 命令** — 有些老版功耗分析命令没有 Voltus 等价命令，通过 include 文件传入
2. **传 `report_power` 选项** — 在 dynamic 模式下，`report_power` 的某些参数不能在命令行直接指定，只能通过 include 文件传入

### 使用时机
- **仅 dynamic 模式生效**（`method dynamic_vectorbased` / `dynamic_vectorless`）
- **static 模式下该命令会被忽略**
- 当 `set_power_analysis_mode -static_netlist def` 时**必须使用**

### 语法
```tcl
set_power_include_file <filename> [-reset]
```

### 典型 include 文件内容

include 文件中通常包含额外的 report_power 命令来生成专项报告，例如：

```tcl
report_power -compress 9 -format detailed -pg_net -toggle_rate
```

| 参数 | 值 | 作用 |
|------|----|------|
| `-compress 9` | 9 | 报告文件用 gzip 压缩（最大压缩比 9），生成 `.gz` 后缀文件 |
| `-format detailed` | detailed | 输出详细格式，包含 pin 电容、net 电容、总负载电容、Max Activity、Cell Name、库信息等。仅对 `-pg_net` 报告生效，生成 `report.*.detailed.rpt` |
| `-pg_net` | (默认 all) | 报告每个 power net 消耗的功耗，显示各 instance 从每个 power net 抽取的电流 |
| `-toggle_rate` | — | 输出每个 instance 的 toggle rate（以其所属时钟频率为参考），用于检查 activity 传播是否正确 |

组合效果：生成一份详细的 Power Net 功耗报告（含 toggle rate 和电容信息），gzip 压缩存储。


---

## Step 3：`report_vector_profile` — 向量 Profiling 找最差窗口

**作用**：在 `-method vector_profile` 模式下，从 VCD/FSDB 中识别最大 activity / 最大功耗的时间窗口，找到合适的 `$worst_power_window_start` 和 `$worst_power_window_end`。

`report_vector_profile` 可作为 `report_power` 的替代命令使用。

**为什么需要 profiling**：全 VCD 做动态分析计算量太大。先用 profiling 快速扫描整段 VCD，找出功耗最高的窗口，然后只截取那一段（建议不超过 dominant clock 的 5 个周期）做精确分析。

### 三种 Profiling 模式

| 模式 | 参数 | 输出 |
|------|------|------|
| Average | `-vector_profile_mode {average}`（默认） | 各分量平均功耗报告，最差窗口报告后缀 `.avgpower` |
| Activity | `-vector_profile_mode {activity}` | 最差 activity 报告 |
| Power Density | `-vector_profile_mode {power_density}` | 按 tiling 的报告，默认 10x10 tiles |

### 完整流程

```tcl
# a. 设置 vector_profile 模式
set_power_analysis_mode -method vector_profile \
    -worst_step_size 2ns \
    -write_profiling_db true \
    -worst_window_count 2

# b. 运行 profiling（report_power 或 report_vector_profile 二选一）
report_power -nworst 5 -outfile eventbased_profiler.rpt -time_based_report
# ── 或 ──
report_vector_profile

# c. 工具自动填充变量，脚本从中提取 start_time / end_time
#    $worst_power_window_start
#    $worst_power_window_end

# d. 用最差窗口截取 VCD，切换到动态向量分析
set_power_analysis_mode -reset
set_power_analysis_mode -method dynamic_vectorbased
read_activity_file -format VCD design.vcd \
    -start $worst_power_window_start \
    -end $worst_power_window_end

# e. 运行动态功耗分析
report_power
```

**注意**：也可通过 `-worst_window_count` 支持多窗口分析，通过 `-worst_window_type` 选择按 power / activity / delta_power 等排序。


---

## Step 4：`set_rail_analysis_mode` 配置 Rail 分析模式

**作用**：指定如何进行 Rail 分析（IR Drop / EM 分析），是 Voltus 中最重要的分析设置命令之一。

**语法**：
```tcl
set_rail_analysis_mode
  -method {static | dynamic | era_static | era_dynamic}
  -accuracy {xd | hd}
  -power_grid_library dir_list
  # ... (大量可选参数)
```

**默认值**：`-method static`、`-accuracy hd`

### 补充说明

#### `-method` 四种模式

| 模式 | 说明 |
|------|------|
| `static` | 静态 Rail 分析（平均电流），用于早期验证 power grid 健壮性 |
| `dynamic` | 动态 Rail 分析（含时间维度），与动态功耗分析配合，精度最高 |
| `era_static` | Early Rail Analysis 静态模式 |
| `era_dynamic` | Early Rail Analysis 动态模式 |

#### `-accuracy` 两种精度

| 模式 | 用途 | PGV 类型 | Via Clustering |
|------|------|----------|----------------|
| **XD** (Accelerated Definition) | 早期实现阶段 IR/EM 分析 | Early | 25x25 |
| **HD** (High Definition) | 最终签核阶段 IR/EM 分析 | IR/EM | 4x4 |

#### 关于 RMS EM 分析

**关键区别**：
- **Power Grid EM** — 主要关注 **AVG（平均电流）**，模拟芯片长期运行的平均电流效应，检查 DC 电流密度是否超限
- **Signal EM** — 主要关注 **RMS（有效值电流）**，模拟交流信号导致的焦耳热效应，检查 AC 电流的热效应是否导致过热

EM（Electromigration，电迁移）分析按电流类型分为三个维度：

| 维度 | 报告文件 | 检查内容 |
|------|----------|----------|
| **AVG (Average)** | `.rj.avg.rpt` | DC 平均电流密度 — 模拟长期平均效应 |
| **RMS** | `.rj.rms.rpt` | AC 有效值电流密度 — 模拟交流电流的**焦耳热效应** |
| **Peak** | `.rj.peak.rpt` | 峰值电流密度 — 瞬时电流峰值 |

**物理原理**：交流电流流过金属导线产生焦耳热（Joule Heating = I²R），导致导线局部升温，加速 EM 失效。RMS 电流值精确量化了交流电流的**热效应等效值**——无论电流波形如何，其 RMS 值对应的发热量与相同大小的 DC 电流相同。因此 RMS EM 分析本质是检查：**交流电流引起的自热是否会让导线温度超过 EM 安全限值**。

**相关参数联动**：
- `-rms_em_analysis true` — 启用 RMS EM 分析（若提供了 EM 模型文件会自动启用）
- `-em_rms_delta_T 5` — 指定 RMS EM 电流限值分析的温度增量（默认 5°C），用于计算更保守的 EM 限值


---

## Step 5：定义 PG Net / Domain / 电压源位置

**作用**：在 Rail 分析之前，完成三项准备工作——声明各 power/ground net 的电压、将 net 绑定为逻辑域、指定电压源物理位置。

这三条命令无前后顺序约束（均在 `analyze_rail` 之前即可），通常成组书写。

---

### 5a. `set_pg_nets` — 声明 PG Net 电压

**语法**：
```tcl
set_pg_nets -net net_name -voltage value [-threshold value] [-tolerance value] [-force]
```

**参数说明**：

| 参数 | 说明 |
|------|------|
| `-voltage` | 该 net 的标称电压 |
| `-threshold` | 该 net 的最小允许电压（绝对值）。IR drop 超限即标记为 violation |
| `-tolerance` | 电压容差百分比，默认 `0.3`（±30%）。用于 library binding：选择电压最接近的库 |
| `-force` | 跳过 net 有效性检查 |

**示例**：
```tcl
set_pg_nets -net VDD_AO -voltage 0.9 -threshold 0.85 -tolerance 0.3
set_pg_nets -net VSS    -voltage 0.0 -threshold 0.05 -tolerance 0.3
```

> `set_pg_nets` 必须在 `report_power` / `analyze_rail` 之前指定。可在设计加载前指定（不依赖 `set_top_module`），也同时服务于功耗分析和 Rail 分析流程——两者共用同一组 net 电压设定。

---

### 5b. `set_rail_analysis_domain` — 绑定 Power Domain

**语法**：
```tcl
set_rail_analysis_domain \
  -name domain_name \
  -pwrnets {power_net_list} \
  -gndnets {ground_net_list} \
  [-threshold value]
```

**参数说明**：

| 参数 | 必填 | 说明 |
|------|:---:|------|
| `-name` | 是 | 域名（任意取），如 `core`、`PD_AO`、`TDSP` |
| `-pwrnets` | 是 | 该域包含的 power net 列表，支持 `{VDD VDD_AO}` 多 net |
| `-gndnets` | 是 | 该域包含的 ground net 列表 |
| `-threshold` | 否 | domain 级 IR drop 阈值（百分比 0~0.5）。若同时设置了 `set_pg_nets -threshold`，以 net 级为准 |

**示例**：

```tcl
# 单 net domain
set_rail_analysis_domain -name core -pwrnets VDD -gndnets VSS

# 多 net domain
set_rail_analysis_domain -name core \
  -pwrnets {VDD_AO VDD_external} -gndnets VSS

# 带 domain 级阈值（-threshold 0.10 = 10% IR drop，对 0.9V 相当于 90mV）
set_rail_analysis_domain -name PD_AO \
  -pwrnets VDD_AO -gndnets VSS -threshold 0.10
```

**注意事项**：

1. **Power-gated domain** 的 domain 定义中只包含 **always-on net**，switched net 由工具自动追踪，不要显式写在 `-pwrnets` 中
2. **无 CPF 时**必须手动使用 `set_pg_nets` + `set_rail_analysis_domain` 定义 power net 和 domain
3. **阈值优先级**：`set_pg_nets -threshold`（net 级）> `set_rail_analysis_domain -threshold`（domain 级）
4. **MSMV（Multi-Standard Multi-Voltage）** 不支持 domain 级 `-threshold`

---

### 5c. `set_power_pads` — 指定电压源位置

**语法**：
```tcl
set_power_pads -net net_name -format padcell -file filename [-short_pin_nodes {true|false}]
```

**作用**：告知工具电压源（power pad / bump）的物理位置，Rail 分析据此注入电流。

**`-format` 五种类型**：

| 格式 | 说明 |
|------|------|
| `padcell` | 指定 pad cell 列表，每个 cell 可附带封装寄生参数（默认 0） |
| `xy` | 坐标文件，每行 `vsrc_name X Y LAYER [R= C= L=]` |
| `defpin` | 自动从 DEF power pin 提取电压源，无需 `-file` |
| `boundary` | 用设计边界 instance 确定电压源位置 |
| `xyiv` | 类似 xy，额外指定电流/电压源类型及值 |

---

**`-format padcell` 详解**：

padcell 文件格式：
```
* cellname   r=resistance   l=inductance   c=capacitance
PVDD1        r=2.5e-3       l=2.5e-11      c=120e-12
PVDD2        r=2.5e-3       l=2.5e-11      c=120e-12
```

- 每行一个 pad cell 实例名
- `r=`、`l=`、`c=` 为封装寄生参数（电阻/电感/电容），可选，默认 0

| 参数 | 默认值 | 说明 |
|------|:-----:|------|
| `-short_pin_nodes` | `false` | 将 pad cell pin 上所有 interface node 短路为单一节点再建电压源 |

**`-format xy` 坐标文件格式**：
```
* vsrc name     X(um)       Y(um)      LEF/Tech Layer   <R=ohm> <C=F> <L=H>
VDD100         5.000      793.500     M7
VDD101      1187.835      293.500     M7
```

**`-auto_voltage_source_creation` 自动创建**（无 padcell/xy 文件时）：
```tcl
set_power_pads -net VSS -auto_voltage_source_creation true -layer VIA6
set_power_pads -auto_voltage_source_creation true -net ALL -layer VIA5
```

**典型示例**：
```tcl
set_pg_nets -net VDD_AO -voltage 0.9 -threshold 0.85
set_pg_nets -net VSS    -voltage 0.0 -threshold 0.05
set_rail_analysis_domain -name core -pwrnets VDD_AO -gndnets VSS

# padcell 方式（最常用）
set_power_pads -net VDD_AO -format padcell -file VDD_AO.padcell
set_power_pads -net VSS    -format padcell -file VSS.padcell
```

---

### 与 analyze_rail 的对应关系

```
set_pg_nets              →  声明各 net 电压/阈值
    ↓
set_rail_analysis_domain →  将 net 绑定为逻辑域
    ↓
set_power_pads           →  指定电压源物理位置
    ↓
analyze_rail -type domain →  执行 Rail 分析
```

```tcl
# 分析指定 domain
analyze_rail -type domain core

# 分析全部 domain（一键遍历所有已定义的 domain）
analyze_rail -type domain ALL

# 不定义 domain，直接分析单个 net
analyze_rail -type net VDD
```

> `analyze_rail -type net` 可跳过 domain 定义直接分析单个 net，但 domain 方式更常用——它能同时分析一组 power/ground net 的相互作用。


---

## Step 6：`analyze_rail` 执行 Rail 分析

**语法**：
```tcl
analyze_rail [-type {domain | net}] [-output directory_name] name
```

**作用**：在 `set_rail_analysis_mode` 定义分析模式之后，执行 IR Drop / EM Rail 分析。

**参数说明**：

| 参数 | 说明 |
|------|------|
| `name` | 待分析的 domain 名或 net 名。`-type domain` 时可指定 `ALL` 分析全部 domain |
| `-type {domain \| net}` | 按 domain 分析还是按单个 net 分析 |
| `-output directory_name` | 输出目录名，默认 `./`（当前工作目录） |

**三种使用方式**：

```tcl
# 按 domain 分析（最常用）
analyze_rail -type domain core

# 分析全部已定义的 domain
analyze_rail -type domain ALL

# 按单个 net 分析（跳过 domain 定义）
analyze_rail -type net VDD
```

**输出**：运行后在指定目录下生成 state directory（如 `core_25C_dynamic_1`），内含 reports（IR drop / EM）、logs、GIF 图等分析结果。

**典型调用链**：
```tcl
set_pg_nets -net VDD -voltage 0.9 -threshold 0.85
set_pg_nets -net VSS -voltage 0.0 -threshold 0.05
set_rail_analysis_domain -name core -pwrnets VDD -gndnets VSS
set_power_pads -net VDD -format padcell -file VDD.padcell
set_power_pads -net VSS -format padcell -file VSS.padcell
analyze_rail -type domain core
```


---

## 分析结果报告

`analyze_rail` 运行完成后，主要关注以下报告文件。由于脚本设置了 `-report_power_in_parallel true`，`analyze_rail` 会同步触发功耗计算，报告文件分属两类目录：**POWER**（功耗分析报告）和 **RAIL**（Rail 分析报告），可在输出目录下按文件夹名区分。

---

### POWER 目录下

#### `power.rpt` — 总功耗报告

**内容**：

1. **读入文件清单**：报告头部列出本次分析实际读入的各项文件（LEF、Netlist、DEF、SPEF、lib、PGV、activity 文件等）
2. **总功耗汇总**：按 Internal / Switching / Leakage 分类的全芯片功耗，以及各 power domain / clock domain 的功耗分布

**关注点**：
- 确认读入文件列表与预期一致——有无文件路径报错、有无意外读入了旧版本文件
- 总功耗数值是否在合理范围内，与历史 baseline 或预期估算对比

---

### RAIL 目录下

#### `report_generation.log` — IR Drop 总报告与电容报告

**内容**：

1. **IR Drop 分布汇总**：列出各 IR Drop 范围区间（range）的节点数量及占比分布，快速判断全芯片 IR Drop 整体情况，是 debug 的第一步入口。

2. **电容报告（Capacitance Report）**：以 `Begin Report Generation: Capacitance Report Generation` 为标志段，按 net 分别汇报各类电容的 disconnected / connected / used 三列值。

| 电容类型 | 说明 |
|---|---|
| `Intrinsic-decap/filler` | decap 单元和 filler 单元提供的本征去耦电容 |
| `Intrinsic-standard` | 标准单元的本征电容（栅电容、扩散电容等） |
| `Intrinsic-macro` | 宏单元（memory、IP）的本征电容 |
| `Load Cap` | 信号 net 上的负载电容（自然去耦） |
| `Grid Cap` | power grid 金属走线自身的寄生电容 |
| `Total Cap` | 以上各项之和 |

三列的含义：
- **disconnected**：物理上未连接到 power mesh 的电容量（理论上越小越好，过大说明 power mesh 连接有问题）
- **connected**：已连接到 power mesh 的电容量
- **used**：实际参与 Rail 仿真计算的电容量（通常与 connected 相同）

**关注点**：
- `disconnected` 列数值异常偏大，说明大量电容未被 power mesh 覆盖，影响 IR Drop 仿真精度
- `Intrinsic-decap/filler` 的 connected 值反映 decap 的实际效果，可作为 decap 覆盖率的判断依据
- VSS 与 VDD 的 Total Cap 应大致相当，差距过大时需排查

---

#### `VDD_VSS.worst.iv` — 实例级电压违例报告

**内容**：每行记录一个实例（instance）在其翻转时间窗口内的有效工作电压（EIV，Effective Instance Voltage），列出具体违例的 inst。

**关注哪些列**：

| 列 | 说明 | 是否关注 |
|---|---|---|
| `win_eiv` | switching window 内的有效电压差（VDD-VSS），影响时序的关键值 | ✅ 重点关注 |
| `pwr_win_iv` | switching window 内 VDD pin 的最差电压 | ✅ 重点关注 |
| `gnd_win_iv` | switching window 内 VSS pin 的最差电压（ground bounce） | ✅ 重点关注 |
| `elapse_eiv` | 整个仿真时段内的有效电压差，不限于翻转窗口 | ⚠️ 过于悲观，仅参考 |
| `pwr_elapse_iv` | 整个仿真时段内 VDD pin 最差电压 | ⚠️ 过于悲观，仅参考 |
| `gnd_elapse_iv` | 整个仿真时段内 VSS pin 最差电压 | ⚠️ 过于悲观，仅参考 |

> `win_*` 列只取实例**翻转时刻**的最差电压，是真正影响时序的值，用于 STA 关联分析。  
> `elapse_*` 列取整个仿真时段最差值，不区分是否在翻转窗口内，通常比实际情况更悲观，做参考即可。

计算关系：
```
win_eiv    = pwr_win_iv  - gnd_win_iv
elapse_eiv = pwr_elapse_iv - gnd_elapse_iv
```

---

#### `instDisconPin` — 未连接 Power Mesh 的 Pin 报告

**内容**：列出设计中存在 power/ground pin 未连接到 power mesh 的实例。

**含义**：这些 pin 处于悬空状态，Voltus 无法为其注入电压/电流，直接影响该实例的 IR Drop 计算准确性，严重时会导致功能失效风险。

**处理方式**：
1. 确认是否为真实连接问题（缺少 follow-pin routing、via 缺失等）
2. 若是设计问题，需反馈给布局布线工具（Innovus）修复
3. 若是 PGV 库问题（cell 缺少 power-grid view），需重新生成对应 PGV
