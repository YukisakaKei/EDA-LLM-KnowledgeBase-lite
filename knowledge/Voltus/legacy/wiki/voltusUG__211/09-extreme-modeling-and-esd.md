---
source: knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl | entries: [0184, 0185, 0186, 0187, 0188, 0189, 0190, 0191, 0192, 0193, 0194, 0195, 0196, 0197, 0198, 0199, 0200, 0201]
---

# 09 Extreme Modeling and ESD Analysis

## 一、Extreme Modeling (XM) 层次化 PI 分析

### 1.1 概述

Voltus-XM（Extreme Modeling）是一种高级 PGV 建模技术，用于对大规模设计进行层次化 power integrity (PI) 分析。其核心思路是为 IP 模块创建 **xPGV 模型**，精确捕获模块的 demand current 和 electrical parasitics。相比于全芯片 flat 分析，xPGV 模型显著更小，能大幅降低 runtime 和 memory，且生成的 IP 模型可在不同设计或多个 instance 间复用。

Voltus-XM 需要独立的 **Voltus-XM license**（Voltus-XL 的 option）：
- **xPGV generation**：每生成一个 xPGV 模型需要 1 个 XM license
- **xPGV usage**：每个 xPGV 模型消耗 1 个 XM license，最多 10 个 license，超过 10 个模型不额外增加。按模型种类（而非 instance 数）计费

### 1.2 建模方法

**xPGV 模型生成**可在以下两种分析之后进行：
- Signoff 静态/动态 IR drop 分析
- 静态/动态 Early Rail Analysis (ERA)

xPGV 基于 block 的 R-C grid 和 via 层电流信息生成，具有以下特点：
- **Context-independent**：模型不依赖 chip-level 上下文，无需模拟周围分区
- 用户指定 **via cut layer**，保留 cut layer 以上 layer，丢弃以下 grid 和 LEF ports
- 在 cut layer 与 current taps 之间创建大幅简化的 RC 网络
- 外部连接由 LEF 定义

### 1.3 层次化 PI 分析流程

整个流程分为两步，需要两个 Tcl script：

**Step 1: xPGV Generation（Block-Level Analysis）**

在 block-level DEF 上执行标准的功耗计算和 rail analysis，通过 `-xpgv_config_file` 参数指定 cut layer 和 block LEF。

```tcl
# 加载 block 设计数据
read_lib -lef $lefs
specify_def {top.def hier_block.def}
specify_spef {top.spef hier_block.spef}

# 设置功耗分析
set_power_analysis_mode \
    -method dynamic_vectorless \
    -disable_static false \
    -binary_db_name dynvectorlessPower.db \
    -power_grid_library /path/All_merge.cl \
    -enable_state_propagation true

# 设置 rail analysis（关键：-xpgv_config_file）
set_rail_analysis_mode \
    -accuracy hd \
    -method dynamic \
    -temperature 125 \
    -power_grid_library $pgv_list \
    -xpgv_config_file xpgv.conf

set_pg_nets -net VDD1 -force -voltage 1.21 -threshold 1.08
set_pg_nets -net VSS -force -voltage 0.0 -threshold 0.12
set_rail_analysis_domain -name core -pwrnets VDD1 -gndnets VSS
analyze_rail -type domain -output dynamic_rail core

# 生成 xPGV 模型
generate_xpgv -cell hier_block -output_dir xpgv \
    -state_directory dynamic_rail/core_125C_dynamic_1
```

**xPGV 配置文件 (xpgv.conf) 格式：**
```
CELL <block_name>
CUT_LAYER <cut_via_layer_name>
Lef {<tech_lef> <block_lef>}
END
```

**Step 2: xPGV Instantiation（Top-Level Analysis）**

在 top-level 加载生成的 xPGV library，执行 top-level rail analysis。

```tcl
set_rail_analysis_mode \
    -accuracy hd -method dynamic -temperature 125 \
    -power_grid_library {/path/All_merge.cl ../xpgv/hier_block/hier_block.cl} \
    -flatten_xpgv_block_instances use_def.txt
# ... 其余 rail analysis 设置同上
analyze_rail -type domain -output dynamic_rail core
```

关键参数：
- `-power_grid_library`：同时指定普通 PGV library 和生成的 xPGV .cl 文件
- `-flatten_xpgv_block_instances`：指定一个文件，列出哪些 instance 使用 DEF（而非 xPGV）进行分析。格式为 `<block_name> <instance_name|All|None>`

**xPGV 输出文件：**

| 文件 | 说明 |
|------|------|
| `<cell>.cl` | 宏模块 power-grid library，含物理和电气表示 |
| `<cell>.report` | 各 power/ground net 的 tap 数量和电压信息 |
| `<cell>.summary` | 电容、电流、电阻、tap 数和 layer 等统计 |

---

## 二、ESD Analysis

### 2.1 概述

ESD（Electrostatic Discharge）分析用于检查芯片中 power/ground bump 到 ESD clamp 器件之间的 **effective resistance** 和 **current density** 是否满足要求，确保 ESD 事件发生时存在低阻泄放路径。随着工艺节点缩小，器件对 ESD 更加敏感。

Voltus 通过 `analyze_esd_network` 命令支持以下检查类型：

| 检查类型 | 说明 |
|----------|------|
| **bump2clamp** | 每个 bump 到所有 ESD clamp 的有效电阻 |
| **bump2bump** | 从 power bump 经 ESD device 到 ground bump 的最有效低阻路径 |
| **clamp2clamp** | 同一 net 上所有 clamp 之间的有效电阻 |
| **bump2instance** | bump 到 instance 的电阻，与 bump2clamp 对比判定 |
| **clamp2instance** | instance 到最近 clamp 的电阻，用于 CDM 检查 |
| **connectivity** | 孤立 bump 或 clamp 检查 |
| **em** | ESD zap 事件下的 current density / EM 检查 |

额外支持 **CDM（Charged-Device Model）** 分析，通过 `analyze_esd_voltage` 命令检查 driver/receiver 间的 potential difference 是否超过阈值。

### 2.2 数据需求

| 输入 | 说明 |
|------|------|
| ESD Cell PGV | 使用 `set_advanced_pg_library_mode -esd_cells_list_file -esd_pin_list -esd_parameters_file` 生成 |
| ESD Rule File | 定义检查规则和阈值，所有规则在一个文件中 |
| ESD EM Tech File | 与 ICT EM 文件格式相同，定义每层 metal 的 current density 限值 |
| Technology PGV | LEF-based 的 technology library |
| Design DEFs | 含 cell placement、power grid、signal routing |

### 2.3 ESD Rule File 关键参数

ESD Rule File 通过 `analyze_esd_network -config_file` 指定，主要参数：

| 参数 | 说明 |
|------|------|
| `type` | 规则类型：clamp2clamp / bump2bump / bump2clamp / bump2instance / clamp2instance / connectivity / em |
| `reff_threshold` | 有效电阻 pass/fail 阈值 |
| `rule` | 规则名称 |
| `power -nets {list\|all} -short_bumps {true\|false}` | 指定 power nets |
| `ground -nets {list\|all} -short_bumps {true\|false}` | 指定 ground nets |
| `nets -from {list\|all} -to {list\|all}` | 灵活指定任意 nets |
| `bumps {list}` / `bumps -from {list} -to {list}` | 指定 bump 列表 |
| `clamp_cells -from {list} -to {list}` | 指定 clamp cell 名称 |
| `clamp_types -from {list} -to {list}` | 按 clamp 类型（PGV 中存储）指定 |
| `current` | zap 电流值，用于 em 和 bump2bump |
| `path_reff_threshold` | bump-to-bump 路径有效电阻阈值 |
| `lerp_threshold` | 最小有效电阻路径（LERP）阈值 |
| `parallel_clamp_threshold` | 并联 clamp 数量阈值（结合 effective_calculation） |
| `effective_calculation {true\|false}` | 是否对 clamp 做短路并联计算 |
| `pass_criteria {all\|one}` | pass 条件：所有路径通过或至少一条通过 |
| `reporting {original\|reverse\|both}` | 报告排序方式 |
| `report_threshold` | EM violation 报告阈值（I/Ilimit 比率） |
| `check_isolated_bumps/clamps {true\|false}` | 是否检查孤立 bump/clamp |
| `cell_list_file / instance_list_file [-include\|-exclude]` | 指定要包含/排除的 cell 或 instance |
| `bump_region_xy_size x y` | 半径 bump-to-bump 检查的区域大小 |
| `setup -iv_lib {true\|false} -cross_domain {true\|false}` | 跨域 zap 分析设置 |

### 2.4 ESD 分析流程

**Step 1: 创建 ESD Cell PGV**

```tcl
read_lib -lef $lefs
set_pg_library_mode -celltype techonly \
    -ground_pins {VSS} -power_pins {VDD1} \
    -extraction_tech_file ./qrcTechFile
set_advanced_pg_library_mode \
    -esd_cells_list_file esd_cell_list \
    -esd_parameters_file param_file.txt \
    -esd_pin_list {VDD VSS VDDESD VSSESD}
generate_pg_library -output esd_pgv
```

- `-esd_cells_list_file` 格式：`<cell_name> <clamp_type>`
- `-esd_parameters_file` 格式：`Cell <cell_name> <Ron> <Roff> <power_pin> <ground_pin> <voltage>`

**Step 2: 加载设计并设置 Rail Analysis**

```tcl
read_lib -lef $lefs
specify_def {top_final.def dmu.def}
set_rail_analysis_mode \
    -method static -accuracy hd \
    -power_grid_library ./data/esd_pgv/techonly.cl \
    -ignore_shorts true -enable_rlrp_analysis true \
    -ict_em_models ./data/ESD_em.ict
set_pg_nets -net VDD -voltage 0.9 -threshold 0.8 -force
set_pg_nets -net VSS -voltage 0 -threshold 0.1 -force
set_power_pads -format xy -net VDD -file ./top_VDD.pp
set_power_pads -format xy -net VSS -file ./top_VSS.pp
set_rail_analysis_domain -name PD -pwrnets {VDD} -gndnets {VSS}
```

**Step 3: 运行 ESD 分析**

```tcl
analyze_esd_network PD \
    -config_file rule1.txt \
    -output ESD_analysis \
    -type domain -use_power_pad true
```

可选参数：`-clamp_pin_short_file` 指定 clamp pin layer 短路列表。

### 2.5 输出报告

ESD 分析结果位于 `<output_dir>/<state_dir>/ESD/` 目录：

| 文件 | 说明 |
|------|------|
| `summary.rpt` | 所有规则的 PASS/FAIL 汇总 |
| `b2c_<rule>.reff` | bump-to-clamp 详细报告 |
| `c2c_<rule>.reff` | clamp-to-clamp 详细报告 |
| `b2b_<rule>.reff` | bump-to-bump 详细报告 |
| `c2i_<rule>.reff` | clamp-to-instance 详细报告 |
| `b2i_<rule>.reff` | bump-to-instance 详细报告 |
| `esd_isolation.reff` | 孤立 bump/clamp 报告 |
| `<em_rule>_<domain>/<net>` | EM current density 详细结果目录 |

GUI 可通过 **Power Rail -> ESD Results** 加载结果，以 fly-line 形式可视化显示 bump/clamp 之间的连接关系。

### 2.6 CDM 分析

CDM（Charged-Device Model）分析使用 `analyze_esd_voltage` 命令，检查 driver/receiver 对之间的 voltage drop 是否超过给定阈值，预防栅氧击穿风险。

基本流程：
1. 加载设计数据
2. 执行功耗分析并生成 driver/receiver pair（`set_power_analysis_mode -create_driver_db`）
3. 设置 rail extraction
4. 运行 `analyze_esd_voltage` 注入电流并报告 violation
