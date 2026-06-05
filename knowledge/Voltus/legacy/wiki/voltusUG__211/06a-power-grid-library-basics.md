---
source: knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl | entries: [0101, 0102, 0103, 0104, 0105, 0106, 0107, 0108, 0109]
---

# Power-Grid Library Generation 基础

## 概述

Library Generation 引擎用于创建和维护单元库数据库中的 power-grid view。通过预处理标准单元和宏单元，可以减少后续每次分析的整体运行时间。

Library Generation 以 LEF、GDSII 或两者组合作为输入，生成二进制格式的 power-grid view，其中包含：

- **Rail 分析所需**：RC parasitics、tap 电流、几何信息
- **功耗分析所需**：网表和输出电容负载

---

## 输入文件

| 文件 | 说明 |
|------|------|
| Technology LEF (`header.LEF`) | 工艺层定义 |
| Cell LEF（含 power pin） | 单元物理信息 |
| Cell GDS | 宏单元必需 |
| Quantus 工艺文件（`qrcTechFile`） | RC 提取技术文件 |
| GDS → qrcTechFile layermap | GDS 层映射 |
| LEF → qrcTechFile layermap | LEF 层映射（可选，不指定时自动生成） |
| SPICE device models（Spectre 或 Hspice） | 器件模型 |
| SPICE subcircuit netlist（含 X,Y 坐标） | 带坐标时 tap 电流精确定位到最近器件；无坐标则均匀分布 |

---

## 输出文件

- **单元库数据库**（`.cl` 文件）：包含 LEF 工艺信息、单元几何视图、port 信息、power-grid view、工艺数据及每个单元的 bounding box
- **日志文件**：`Libgen_*/library_name/*.log`
- **文本报告和摘要文件**：包含 power-grid library 的详细统计信息

---

## Power-Grid Library 类型

### Technology Library（技术库）

- 包含：tech file、面积电容规格、decap/filler/power gate 单元、所有单元的 Tech view
- **Rail 分析的最低要求**，必须指定为 `set_rail_analysis_mode` 中 PGV 列表的第一项
- 若同时存在 Technology Library 和 Standard Cell PGV，Standard Cell PGV 优先级更高

### Power-Grid Library（PG 库）

- 包含三种 PGV（Early / IR / EM），适用于标准单元、宏单元/存储器/IO
- 不含 tech file，decoupling capacitance 来自 SPICE 仿真
- 标准单元 PG 库通常由第三方随工艺一起提供；先进工艺（< 90nm）可能有多个工艺变体，Voltus 使用嵌入在 Technology Library 中的 Quantus techfile 处理所有 PGV

---

## Power-Grid View（PGV）类型

不同精度模式的 rail 分析使用不同类型的 PGV：

| PGV 类型 | 适用单元 | 电容来源 | Current Taps | Rail 提取 | Rail 缩减 | 默认精度模式 |
|----------|----------|----------|--------------|-----------|-----------|-------------|
| **Tech** | 所有单元（技术库） | 面积估算 | LEF Pins | 否 | N/A | 无 PGV 时回退 |
| **Early** | 标准单元 / 宏单元 | SPICE 仿真 | LEF/GDS Pins | 否 | N/A | XD 模式（早期设计阶段） |
| **IR** | 宏单元 | SPICE 仿真 | Contact/VIA（合并小电流 tap） | 是 | 是 | HD 模式 |
| **EM** | 宏单元 | SPICE 仿真 | Contact/VIA（每个器件） | 是 | 否 | 静态 EM rail 分析 |

**各类型说明：**

- **Tech View**：最基础的视图，仅含电流分布因子和 decoupling capacitance，无单元内部信息。无 PGV 时自动回退使用，但建议为所有标准单元和宏单元生成完整 PGV。
- **Early View**：含 SPICE 仿真的 decoupling capacitance，不含互连 parasitics，无法分析单元内部 IR drop。推荐用于设计早期阶段（XD 精度模式）。
- **IR View**：对提取的 power-grid 进行缩减，合并小电流 tap，提升工具性能和内存效率。存储器 bit cell 区域的 tap 可能被合并，对单元内部可见性有限。HD 模式默认使用（静态 EM 分析除外）。
- **EM View**：从 GDSII 提取完整 power-grid，在最底层导体层或其上 via 层位置创建 current tap。需要 GDSII 和含 XY 坐标的 SPICE netlist 以获得精确的电流分布和 decoupling capacitance。

---

## 生成 Technology Library

### 所需输入

- Technology LEF
- Cell LEF
- Quantus technology file
- LEFDEF layermap（可选，不指定时自动生成）

### 流程

```tcl
# 步骤 1：读取 LEF 文件
read_lib -lef ../data/lef/tech.lef \
         ../data/lef/cell_macro.lef \
         ../data/lef/pso_header.lef \
         ../data/lef/decap.lef

# 步骤 2：设置技术库表征参数
set_pg_library_mode \
  -extraction_tech_file RCgen.tch \
  -lef_layermap lefdef.map \
  -celltype techonly \
  -power_pins { VDD 1.08 VDDO 1.08 VDDG 1.08 } \
  -ground_pins { VSS GND VSSG } \
  -temperature -40 \
  -powergate_parameters { { cell1 VDDG VDD 100 0.003 0.00015 } \
                           { cell2 VDDG VDD 100 0.003 0.00015 } }

# 步骤 3：生成库
generate_pg_library -output tech_pgv
```

GUI 路径：**Power & Rail → Set PowerGrid Library Mode** / **Generate PowerGrid Library**

### 输出文件

| 文件 | 内容 |
|------|------|
| `techonly.cl` | 技术库主体；Tech view 含面积估算电容、LEF pin 处的 current tap，无单元内部可见性 |
| `techonly.report` | 每个单元的 power/ground net 名称、电压、电容值、tap 数量；power gate 单元的 Idsat/Ileakage/Ron |
| `techonly.summary` | 单元类型（STDCELL/FILLER/DECOUPLING CAP/POWER_GATE）、pin 数、金属层数、current tap 数等统计 |

---

## 生成标准单元 Power-Grid Library

标准单元的 Early、EM、IR 三种 view 内容相同。Voltus 使用 SPICE subcircuit 和 Spectre 仿真生成 decoupling capacitance；对 power gate 单元表征 Ron、Idsat 和 Ileakage。

### 所需输入

- Technology LEF + Cell LEF
- Quantus technology file（可选，不指定时 LEF 层名须在所有 PGV 中保持一致）
- LEFDEF layermap（可选）
- SPICE netlists（标准单元）
- Spectre 模型文件或 SPICE 模型

### 流程

```tcl
# 步骤 1：读取 LEF
read_lib -lef ../data/lef/tech.lef \
         ../data/lef/buf_ao.lef \
         ../data/lef/decap.lef

# 步骤 2：设置标准单元库表征参数
set_pg_library_mode \
  -ground_pins VSS \
  -power_pins {VDD 0.9 TVDD 0.9} \
  -decap_cells {DECAP8 DECAP64 DECAP4 DECAP32 DECAP2 DECAP16 DECAP1} \
  -filler_cells {FILL8 FILL64 FILL4 FILL32 FILL2 FILL16 FILL1} \
  -celltype stdcells \
  -cell_decap_file ../data/voltus/decap.cmd \
  -cell_list_file ../data/voltus/cell.list \
  -spice_subckts { ../data/netlists/gsclib090.sp \
                   ../data/netlists/pso_header.spi } \
  -lef_layermap ../data/voltus/lefdef.layermap \
  -current_distribution propagation \
  -spice_models ../data/netlists/spectre_load.sp \
  -extraction_tech_file ../data/qrc/gpdk090_9l.tch \
  -powergate_parameters { {RING_SWITCH TVDD VDD} {HEADER_SWITCH TVDD VDD} }

# 步骤 3：生成库
generate_pg_library -output stdcell_pgv
```

### 输出文件

| 文件 | 内容 |
|------|------|
| `stdcells.cl` | 标准单元库主体；含 SPICE 仿真的精确 decoupling capacitance，current tap 添加在 power pin 处 |
| `stdcells.report` | 每个单元的 power/ground net、电压、仿真电容值、tap 数量；power gate 的 Idsat/Ileakage/Ron |
| `stdcells.summary` | 单元类型、pin 数、金属层数、current tap 数等统计 |

---

## 为宏单元创建 Power-Grid View

宏单元（macro/memory/IO）生成 Early、EM、IR 三种 view，精确捕获单元内部的电流和电容分布。

**关键要求**：每个 LEF、SPICE netlist（或 CDL）和 GDS 文件只能包含一个宏单元定义。

SPICE netlist 含 XY 坐标时，tap 电流精确定位到最近器件；无坐标时电流均匀分布，可能掩盖真实 IR drop 和 EM 问题或产生误报。

### 所需输入

- Technology LEF + Cell LEF
- Quantus technology file
- LEFDEF layermap（可选）
- 宏单元 SPICE netlist
- Spectre 模型文件或 SPICE 模型
- 宏单元 GDS 文件
- GDS layermap

### 流程

```tcl
# 步骤 1：读取 LEF
read_lib -lef ../data/lef/tech.lef \
         ../data/lef/pll.lef

# 步骤 2：设置宏单元库表征参数
set_pg_library_mode \
  -gds_files ../data/gds/pll.gds \
  -ground_pins VSS \
  -cell_list_file ../data/voltus/macro.list \
  -power_pins {VDD 0.9} \
  -celltype macros \
  -spice_subckts ../data/netlists/pll.sp \
  -gds_layermap ../data/voltus/gds.layermap \
  -lef_layermap ../data/voltus/lefdef.layermap \
  -stop@via CONT \
  -spice_models ../data/netlists/spectre_load.sp \
  -current_distribution propagation \
  -extraction_tech_file ../data/qrc/gpdk090_9l.tch

# 步骤 3：生成库
generate_pg_library -output macro_pgv
```

**`-stop@via` 参数说明**：

| 值 | 用途 |
|----|------|
| `CONT`（diffusion contact） | IP 未做 EM 认证时使用 |
| `VIA_1`（常用） | 创建 current tap 的标准层 |
| `VIA_2` / `VIA_3` | IP 已做 EM 认证，需在顶层可见时使用；层越高，内存/磁盘占用和运行时间越少 |

### 输出文件

| 文件 | 内容 |
|------|------|
| `macros_<cellname>.cl` | 宏单元库主体；Early view 含 power pin 处的 parasitics 和精确 decoupling capacitance；IR view 含缩减后的分布式 RC 和合并 tap；EM view 含完整分布式 RC 和每个器件的 contact tap |
| `macros_<cellname>.report` | power/ground net 名称、电压、仿真电容值、Early/EM/IR 各 view 的 tap 数量 |
| `macros_<cellname>.summary` | 电容、电流、电阻、current tap 数量和层数统计（按 Early/EM/IR 分列） |

---

## 关键命令速查

| 命令 | 用途 |
|------|------|
| `read_lib -lef <files>` | 读取 LEF 文件 |
| `set_pg_library_mode` | 设置库生成参数（celltype / power_pins / ground_pins 等） |
| `generate_pg_library -output <dir>` | 执行库生成，输出到指定目录 |
| `set_rail_analysis_mode -pgv_lib <list>` | 指定 rail 分析使用的 PGV 列表（Technology Library 须排第一） |

**`set_pg_library_mode` 常用参数**：

| 参数 | 说明 |
|------|------|
| `-celltype` | `techonly` / `stdcells` / `macros` |
| `-power_pins` | 电源 pin 名称及电压，如 `{VDD 0.9}` |
| `-ground_pins` | 地 pin 名称 |
| `-extraction_tech_file` | Quantus qrcTechFile 路径 |
| `-lef_layermap` | LEF 层映射文件 |
| `-gds_layermap` | GDS 层映射文件（宏单元） |
| `-spice_subckts` | SPICE subcircuit netlist |
| `-spice_models` | SPICE/Spectre 模型文件 |
| `-gds_files` | GDS 文件（宏单元） |
| `-stop@via` | 提取截止 via 层（宏单元） |
| `-current_distribution` | 电流分布方法（`propagation` 等） |
| `-decap_cells` | decap 单元列表（标准单元库） |
| `-filler_cells` | filler 单元列表（标准单元库） |
| `-powergate_parameters` | power gate 单元参数 `{cell switch_pin ctrl_pin [ron idsat ileak]}` |
