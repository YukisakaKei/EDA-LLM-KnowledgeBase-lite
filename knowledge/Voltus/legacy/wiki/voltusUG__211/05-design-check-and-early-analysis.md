---
source: knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl | entries: [0074, 0075, 0076, 0077, 0078, 0079, 0080, 0081, 0082, 0083, 0084, 0085, 0086, 0087, 0088, 0089, 0090, 0091, 0092, 0093, 0094, 0095, 0096, 0097, 0098, 0099, 0100]
---

# 设计健全性检查与早期功率网格分析

> **术语说明**：ERA 中的 "static"（`era_static`）指**时间平均分析模式**，使用平均电流做 IR drop/EM 分析，与 `era_dynamic`（使用时变波形）对立。非 leakage 分析。

## 一、设计健全性检查（Design Sanity Checks）

### 1.1 Check Design

在设计流程各阶段检查库数据和设计数据的完整性与一致性。

**可检查的数据类型：**
- Physical library（物理库）
- Timing library（时序库）
- Netlist（网表）
- I/Os
- Tie-high / tie-low pins
- Power and ground pins

**推荐检查时机：**

| 检查类型 | 推荐时机 |
|---|---|
| I/O 检查 | 任意阶段 |
| Netlist 检查 | 设计加载后任意阶段 |
| Physical library 检查 | floorplan 之前 |
| Power/Ground 检查 | routing 和 extraction 之前 |
| Timing library 检查 | 任何时序相关操作之前 |
| Tie-high/low 检查 | routing 和 extraction 之前 |

**GUI 操作：** File → Check → Check Design

**TCL 命令：**
```tcl
check_design -out_file checkDesign \
  -type {power_intent timing hierarchical pin_assign budget \
         assign_statements place opt cts route signoff all}
```

**查看报告：** Tools → Report → File → Open File（从 check_design 输出目录加载）

---

### 1.2 Check Timing Library

检查 timing library 中缺失 internal power 或 leakage power 数据的单元。

**GUI 操作：** File → Check → Timing Library

**TCL 命令：**
```tcl
check_library -outfile design.talib -checkpower -reportMissingPowerOnly
```

---

### 1.3 Verify Connectivity

检测 opens、unconnected pins、dangling wires（antenna）、loops 等连通性问题，生成 violation markers 和报告。

**前提条件：**
- 设计已完成 routing
- 设计已加载到当前 Voltus session

**可检测的违规类型：**
- **Antennas**：悬空导线（dangling wires）
  - Regular wires：必须终止于 pin 或 via 中心
  - Regular net vias：必须被 pin 覆盖，via 中心须为导线起/终点
  - Special wires：距终端边缘 1/4 线宽处须被 via、pin 或同层导线覆盖
  - Special net vias：金属矩形须与同 net 的 special wire 或 via 重叠
- **Opens**：net 中各部分相互连接但缺少整体连接
- **Loops**：连通性环路
- **Unconnected pins**：未连接到任何对象的 pin

**GUI 操作：** Verify → Connectivity

**TCL 命令：**
```tcl
verify_connectivity -type special -error 1000 -warning 50 \
  -report dma_mac.conn.rpt
```

---

### 1.4 Verify Power Via

检查 PG net 上的 via 缺失情况。

**功能：**
- 检查 PG net 上金属几何重叠处的 via
- 默认忽略 metal fill
- 支持 stacked power via 检查
- 生成文本报告，标注缺失 via 位置
- 在 layout canvas 中高亮违规（cross-mark）
- 支持指定区域检查、非正交重叠检查、wire-pin 重叠检查、via 利用率检查

**GUI 操作：** Verify → Power Via

**TCL 命令示例：**
```tcl
# 检查所有 power net 上所有金属重叠处的缺失 via
verify_power_via -report power_via.report

# 检查 M5-M8 之间 VDD net 的 stacked via 缺失
verify_power_via -layer_range "M5 M8" -nets VDD

# 检查 via 利用率是否达到 70%
verify_power_via -via_util 0.7 -report via_utilization.rpt
```

清除违规标记：使用工具栏 **Clear DRC Violations** 按钮。

---

### 1.5 Verify Power and Ground Shorts

检测 PG net 之间、PG net 与 signal net 之间、PG net 与其他 special net 之间的短路。

**前提条件：** 需先恢复物理设计：
```tcl
read_design -physical_data <directory> <topcell>
# 或
read_def <filename>
```

**TCL 命令示例：**
```tcl
# 检查 VDD net 上的短路违规
verify_PG_short -net {VDD}

# 多线程加速
set_multi_cpu_usage -localCpu 4
verify_PG_short

# 指定区域检查
verify_PG_short -area {-1045.174 -2848.612 -284.521 -2038.7}
```

---

### 1.6 Violation Browser

通过 Tools → Violation Browser 交互式查看和高亮 violation markers。

**注意：** `verify_connectivity`、`verify_power_via`、`verify_AC_limit` 重复运行时，Violation Browser 会覆盖上次结果（非增量更新）。

**主要功能：**
- 点击列表查看违规详情（actual/target 值）
- 展开/折叠各违规类型
- 导航按钮：First / Previous / Next / Last / Up / Down
- 违规层级：tool → type → subtype → Description
- 双击 layout 中的 marker 可在 Browser 中定位
- 支持高亮、去高亮、删除、标记 False/True
- 点击 Save 生成报告文件
- Settings 页可按类型、区域、其他条件过滤

**清除违规：** 工具栏 Clear DRC Violations 按钮（无对应 GUI 表单）

---

### 1.7 Design Browser

通过 Tools → Design Browser 访问，详见 Voltus Menu Reference。

---

## 二、早期功率网格分析（Early Power-Grid Analysis / ERA）

### 2.1 概述

Early Rail Analysis（ERA）在设计早期阶段（floorplan、placement、post-route）提供与 Signoff Rail Analysis 相同使用模型的 rail analysis。

**关键特性：**
- Static ERA 可使用 Innovus base license 运行；dynamic analysis 或自定义 PGV 需要 Voltus license
- 不要求 power-grid 完全布线，ERA 引擎可自动创建 virtual follow pins 和 virtual vias 补全 grid
- 支持 floorplan 阶段、部分 placement、完全 placed and routed 设计
- PGV library 可选，未提供时自动从 tech file 生成
- 支持 multi-CPU 时间平均/动态分析
- 支持 unplaced flow、What-if shape 分析、native power-up 分析

**ERA 分析流程：**
1. **Grid Completion**：检查 follow pin routing，创建 virtual follow pins 和 virtual vias
2. **Power Estimation**：指定各模块功耗（三种方式，见下）
3. **Static IR drop and EM Analysis**：运行时间平均 IR drop 和 EM 分析
4. **Dynamic Analysis**：运行动态 IR drop 分析（需指定 dynamic current region 或 instance current 文件）

**功耗指定方式：**

| 方式 | 适用场景 |
|---|---|
| Region-based power specification | 完全未 placed 设计，按区域和层指定电流 |
| Total Power + Text Power File | 部分 placed 设计，指定总功耗，可附加 macro/cell 功耗文件 |
| Power Engine Calculated Power | 完全 placed 设计，用 `report_power` 计算 |

---

### 2.2 运行前提条件

- 设计中目标 net 必须有 power stripes
- instances 须在逻辑上连接到待分析的 PG net（无需 placed）
- 设计须加载到内存（用于 virtual follow pin routing 和 virtual via completion）
- 若设计无 instances，ERA 可自动创建单一 current region，但该层须至少有一个 tap/sink current

---

### 2.3 所需输入文件

- Design data（LEF、netlist、DEF）
- CPF 文件（power domain 信息）
- SPEF 文件（signal net parasitic）
- Power-grid libraries（`.cl`）或 Extraction Technology File（二选一）

---

### 2.4 ERA 运行流程（TCL）

```tcl
# 1. 加载设计
read_lib -lef $lefs
read_view_definition ../design/viewDefinition.tcl
read_verilog ../design/postRouteOpt.enc.dat/super_filter.v.gz
set_top_module super_filter -ignore_undefined_cell
read_def ../design/super_filter.def.gz

# 2. 加载 CPF
read_power_domain -cpf ../design/super_filter.cpf

# 3. 加载 SPEF
read_spef -rc_corner RC_wc_125 -decoupled \
  ../design/postRouteOpt_RC_wc_125.spef.gz

# 4. 设置 ERA 模式（时间平均）
set_rail_analysis_mode \
  -method era_static \
  -accuracy xd \
  -analysis_view AV_wc_on \
  -extraction_tech_file ../data/qrc/gpdk090_9l.tch \
  -temperature 125 \
  -era_current_region_file ../tcl/VSS_1.curRegion

# 5. 若无 CPF，手动定义 PG nets
set_pg_nets -net VSS -voltage 0.0 -threshold 0.05
set_pg_nets -net VDD -voltage 1.8 -threshold 1.62
set_rail_analysis_domain -name PD1 -pwrnets VDD -gndnets VSS

# 6. 定义 voltage source 位置
set_power_pads -net VSS -format xy -file ../design/super_filter_VSS.pp

# 7. 运行分析
analyze_rail -output ./era_run -type net VSS
```

**`set_rail_analysis_mode` ERA 关键参数：**

| 参数 | 说明 |
|---|---|
| `-method era_static \| era_dynamic` | 时间平均或动态 ERA |
| `-accuracy xd` | 早期实现阶段 IR 分析精度模式 |
| `-extraction_tech_file` | Quantus tech file（与 PGV 二选一） |
| `-era_current_region_file` | current region 文件路径 |
| `-era_current_distribution` | 电流分布方式（`all` / `unplaced`） |
| `-era_current_distribution_layer` | 电流分布所在层 |
| `-era_insert_virtual_followpins` | 插入 virtual follow pins |
| `-era_skip_virtual_via_by_type` | 跳过特定类型的 virtual via |

**Current Region 文件格式：**
```
# 时间平均(DC)示例
label test1 net VDD area 100 200 400 500 layer M1 current 10

# 动态示例
label test1 net VDD area 100 200 400 500 layer M1 \
  pwl (0ns 0mA 1ns 0mA 2ns 10mA) intrinsic_cap 10 loading_cap 60
```

---

### 2.5 GUI 设置 ERA

1. Power & Rail → Set Rail Analysis Mode
2. Analysis Stage 设为 **Early**
3. Analysis Method 选 **Static** 或 **Dynamic**（默认 XD 精度）
4. 指定 Power-Grid Libraries 或 Extraction Tech File
5. Advanced 标签页 → 勾选 Specify Current Region → 点击 Create 创建 current region
6. 在 Create Current Region 表单中指定坐标、层、电流值
7. 点击 Add → Save → OK

---

### 2.6 查看 ERA 结果

```tcl
# 加载 rail database 后绘制 IR drop 图
set_power_rail_display -plot ir
```

**GUI 操作：**
1. Power & Rail Plots → DB Setup → Browse 加载 Rail Database
2. 选择 plot 类型（Rail Analysis / Power Analysis / Capacitance）
3. 查看方式与 Signoff Analysis 相同

**输出目录结构：**
- 默认目录名：`<domainName>_<temperature>_avg_<X>`
- 每个 net（VDD/VSS）有独立 state 目录，包含：
  - `results`：rail analysis 汇总（tap current、resistor current 等）
  - `Reports/`：完整 power-grid integrity 报告
  - 自动生成的 GIF 图（各 rail analysis plot）

---

### 2.7 典型 ERA 脚本示例

**时间平均分析（含 virtual follow pin 和 virtual via 生成）：**
```tcl
read_design -physical_data design.dat CHIP
set_rail_analysis_mode -method era_static -accuracy xd \
  -extraction_tech_file tech.tch \
  -era_current_distribution_layer MET1 \
  -era_current_distribution unplaced \
  -era_current_region_file power/cur_region \
  -era_insert_virtual_followpins standard \
  -era_skip_virtual_via_by_type none
set_pg_nets -net VDD -voltage 1.1 -threshold 1.067
set_power_data -format area -power 0.744 -bias_voltage 1.2 \
  power/cell_power.txt
set_power_pads -net VDD -format xy -file pads/vdd.pp
analyze_rail -type net -output ./early_vdd VDD
```

**MSMV 动态分析：**
```tcl
read_verilog design/test.v.gz
set_top_module test
read_def design/full.def
set_pg_nets -net VSS -voltage 0 -threshold 0.18
set_pg_nets -net VDD -voltage 0.84 -threshold 0.756
set_power_pads -net VDD -format xy -file design/vdd.pp
set_power_pads -net VSS -format xy -file design/vss.pp
set_power_data -format current {
  instance_current_files/dynamic_VSS.ptiavg
  instance_current_files/dynamic_VDD.ptiavg
}
set_rail_analysis_mode -method era_dynamic -accuracy xd \
  -power_grid_library {stdcells_accurate/accurate_stdcells.cl \
                        memories_accurate/MEM.cl}
set_rail_analysis_domain -name PD -pwrnets VDD -gndnets VSS
analyze_rail -type domain PD
```
