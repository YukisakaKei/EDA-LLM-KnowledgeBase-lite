---
source: knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl | entries: [0110, 0111, 0112, 0113, 0114, 0115, 0116, 0117, 0118, 0119, 0120, 0121, 0122, 0123, 0124, 0125, 0126, 0127]
---

# 功率网格库表征与高级流程

> **术语说明**：PGV 中的 "static"/"dynamic" 指存储的电流数据类型——static = 时间平均 DC 值，dynamic = 时变 PWL 波形。与物理 leakage 无关（leakage 通过独立的 `LEAKAGE_CURRENT` 关键字指定）。

## 宏单元 EM View 电流波形表征

Voltus 支持对 custom macro 的动态电流行为进行表征，生成准确的电流波形用于 Rail Analysis，替代默认的三角波。

### 输入数据

宏单元电流表征需要以下输入之一：
- **FSDB** — SPICE 仿真输出的电流波形
- **Datasheet parameters** — 数据手册参数
- **User-defined PWL** — 用户自定义的分段线性波形
- **Simulation vectors** — 仿真向量
- **Liberty-based vectors (Dotlib)** — 基于 Liberty 库的向量（仅限 memory）
- **User-specified Spice deck** — 用户指定的 SPICE 网表

### 核心命令

```tcl
set_pg_library_mode \
  -power_pins {VDD 1} \
  -ground_pins VSS \
  -celltype macros \
  -extraction_tech_file ../tech_worst.tch \
  -lef_layermap ../lef_layermap.txt \
  -cell_list_file ../16x32memory/cell.list \
  -spice_models {../model1.l ../model2.l ../model3.l.special} \
  -spice_corners {{TT tt_hvt tt_lvt DIO TT_DIO} {TT_sr} {TT_sr}} \
  -current_distribution {dynamic_simulation trigger.txt}

set_advanced_pg_library_mode \
  -pgdb_list_file ../cell_32x64.hdr \
  -pgdb_layermap ../pgdb_layermap.txt \
  -libgen_command_file ../cell_32x64_1/lib.inc

generate_pg_library -output .
```

关键参数 `-current_distribution {dynamic_simulation trigger_file}` 指定使用动态仿真和 trigger 文件进行电流表征。

### Trigger 文件基本原理

Trigger 文件定义了宏单元在不同 mode 条件下的电流特征，包含输入向量、波形触发引脚、电流信息。Power Analysis 读取 PGV 中的 trigger 条件，在 vectorless 或 vector-based 分析时生成 trigger 文件，Rail Analysis 加载 trigger 文件后自动匹配并触发对应波形，进行全芯片动态 IR drop 分析。

### Trigger 文件关键字参考

| 关键字 | 说明 |
|--------|------|
| `CURRENT_CHARACTERIZATION_METHOD <method>` | 表征方法：SIMULATION / DOTLIB / PWL / FSDB / DATASHEET / SPICE_DECK_BASED |
| `CELL <cellname>` | 宏单元名称 |
| `MODE_NAME | MODE <name> static|dynamic` | mode 名称，可选 static/dynamic 关键字 |
| `CONDITIONAL_INPUT = <表达式>` | 当前 mode 的条件输入，支持 `!`(NOT) `&`(AND) `|`(OR) |
| `CONDITIONAL_PIN <pin> {rise|fall|both}` | 触发条件引脚及边沿 |
| `CONDITIONAL_PIN_REFERENCE_TIME <time>` | 触发引脚参考时间，Rail Analysis 据此计算波形起始时间 |
| `LEAKAGE_CURRENT {PGPin value}` | 漏电流值，当宏单元 idle 或 switch pattern 中为 `-` 时使用 |
| `CUSTOM_LABEL <label>` | 子 mode 标签，用于区分同一 mode 内不同电压/频率组合 |
| `VOLTAGE {net voltage}` | 各 supply net 的仿真电压值 |
| `CAPACITANCE <value>` | 负载电容值 |
| `BIAS_VOLTAGE {pin voltage}` | 电容表征的偏置电压 |
| `SIMULATOR APS|SPECTRE|UltraSim` | 指定仿真器，默认 APS |
| `SIM_STOP_TIME / SIM_STEP_SIZE` | 仿真停止时间和步长 |
| `STIMULUS_FILE / INCLUDE_FILE` | 激励文件和包含文件 |

### PGV 中 trigger 信息的上下游使用

1. **Library Characterization**：生成 PGV 时保存 trigger 条件及电流波形
2. **Power Analysis**：识别 trigger 条件，基于 activity ratio 调度切换事件，输出 `DYNAMIC_POWER/trigger.txt`（格式：`INST1 2.1995e-07 1 READ`）
3. **Rail Analysis**：加载 PGV 和 trigger 文件，按触发时间激活波形，移除 off nets，执行 IR drop 分析

日誌示例：
- Power Analysis: `INFO: (VOLTUS_POWR-2061): Writing ASCII trigger file DYNAMIC_POWER/trigger.txt`
- Rail Analysis: `INFO (VOLTUS_RAIL-5023): Found a dynamic tap current view for instance "INST1" whose waveform is triggered at time 1e-07s.`

### Optimized Collapsed Views

PGV 内部对位单元区域等低电流区域自动执行 RC reduction 和 device 合并，生成 optimized collapsed views，在 IR drop 分析中选择 Fast: Accurate 精度模式时使用，可显著提升性能而不显著损失精度。

## Trigger 文件格式

Trigger 文件以 `CURRENT_CHARACTERIZATION_METHOD` 开头，支持的六种方法：

### 1. SIMULATION（仿真向量类）

```tcl
CURRENT_CHARACTERIZATION_METHOD SIMULATION SIMULATOR APS \
  CELL <cellname> \
  MODE_NAME <name> \
  CONDITIONAL_INPUT = (<布尔表达式>) \
  CONDITIONAL_PIN <pin> {RISE|FALL} \
  CONDITIONAL_STIMULUS_FILE <usim.txt> \
  END_MODE END
```

条件表达式中 `!` 表示低电平，`&` 表示 AND，`|` 表示 OR。每个 mode 需要独立的 stimulus 文件。

### 2. PWL（用户自定义波形）

```tcl
CURRENT_CHARACTERIZATION_METHOD PWL \
  CELL <cellname> \
  MODE_NAME <name> \
  CONDITIONAL_INPUT = (<表达式>) \
  CONDITIONAL_PIN <pin> {RISE|FALL} \
  USER_PWL_FILE pwl.txt \
  PWL_START_TIME <time> PWL_END_TIME <time> \
  END_MODE END
```

PWL 文件格式有两种：
- **单 PWL 格式**：`UNIT CURRENT <unit> UNIT TIME <unit> NET <net> REGION {t1 i1 t2 i2 ...}`
- **多 PWL 格式**（不同区域不同波形）：在 NET 段内使用多个 `REGION + RECT {llx lly urx ury}` 指定区域内波形

推荐使用 `PWLFILE` 关键字引用外部文件以便编辑长波形。

关键扩展参数：
- `CUSTOM_LABEL <name>` — 子 mode 标签
- `VOLTAGE {net voltage}` — 仿真电压
- `CAPACITANCE <value>` — 负载电容
- `TIME_FACTOR=X CURRENT_FACTOR=Y` — 时间/电流缩放因子
- `SWITCHBIT_WINDOW {Tmin Tmax}` — 开关位时间窗口
- `LEAKAGE_CURRENT {VSS value VDD value}` — 漏电流
- `STATIC_INTERNAL_POWER {net value}` — net 级内部功耗（A/MHz）
- `CELL_DECAP_FILE <file>` — 去耦电容文件

### 3. FSDB

```tcl
CURRENT_CHARACTERIZATION_METHOD FSDB \
  CELL <cellname> \
  MODE_NAME <name> \
  CONDITIONAL_INPUT = (<表达式>) \
  CONDITIONAL_PIN <pin> {RISE|FALL} \
  FSDB_START_TIME <t> FSDB_END_TIME <t> END_MODE \
  FSDB_PATH <path> FSDB_NET_NAME <net> [<generic_name>] END
```

支持为不同 mode 指定不同 FSDB 文件和起止时间。支持 `BIAS_VOLTAGE` 指定偏置条件。

### 4. Datasheet

```tcl
CURRENT_CHARACTERIZATION_METHOD DATASHEET \
  CELL <cellname> \
  MODE_NAME <name> \
  CONDITIONAL_INPUT = (<表达式>) \
  CONDITIONAL_PIN <pin> {RISE|FALL} \
  DATASHEET_DELAY <time> \
  DATASHEET_PARAMETER {{power_pin cap leakage_pwr}} \
  PEAK_CURRENT {{power_pin peak_current}} END_MODE \
  DATASHEET_INPUT_SLEW <time> DATASHEET_OUTPUT_SLEW <time> END
```

- `PEAK_CURRENT` 指定时构建三角波；未指定时构建梯形波
- `DATASHEET_START_TIME` 指定波形起始时间

### 5. SPICE_DECK_BASED（用户指定 SPICE 网表）

```tcl
CURRENT_CHARACTERIZATION_METHOD SPICE_DECK_BASED \
  CELL <cellname> \
  MODE_NAME <name> \
  CONDITIONAL_INPUT = (<表达式>) \
  CONDITIONAL_PIN <pin> {RISE|FALL} \
  FSDB_START_TIME <t> FSDB_END_TIME <t> END_MODE \
  DECK_FILE <filename> \
  FSDB_NET_NAME <net> [<generic_name>] \
  FSDB_FILE <filename> \
  SIM_OPTIONS +aps END
```

Voltus 执行指定的 SPICE deck，读取仿真生成的 FSDB 波形。

### 6. Dotlib（Liberty 库自动生成）

```tcl
CURRENT_CHARACTERIZATION_METHOD DOTLIB \
  DOTLIB_LIST {list of dotlib files} \
  MODE_COUNT all \
  MODE_CONFIG_FILE <file_path> \
  SIM_STOP_TIME 10ns SIM_STEP_SIZE 100ps
```

仅适用于 memory cell，自动从 dotlib 中读取 `when` 条件的 internal power group，构造 stimulus 向量。包含两类：**pin power based**（关联输入 pin）和 **arc-based**（关联输出 pin）。arc-based 类型需要 `MODE_CONFIG_FILE` 提供 memory description（含 slew、信号、memory_write 信息）。

## 库生成输出报告

库生成报告格式示例：

```
Cell      PowerNets   Capacitance   PowerGrid Views
-------------------------------------------------------
Cell1
  VSS(0.0000)  5.3e-12  EARLY(255 taps) EM(5279 devices) IR(4890 devices)
  VDD(0.9000)  5.2e-12  EARLY(193 taps) EM(3371 devices) IR(2326 devices)
Cell_Status: PASS
```

`.summary` 文件包含 functional mode 和 area 信息。

### Tap Current Report（tapSnapReport.txt）

报告文件中包含每个 device 的电流、电容赋值及 tap 分布：

```
Cell Name: Net Name: Layer Name: NODE DEVICE(X,Y) NODE(X,Y) CURRENT CAPVALUE TAP NAME SWITCH_NODE(X,Y)
```

### PGV 库内部内容

- 分布式 RC 和内禀电容
- 每个 device 的 PWL 电流 tap
- 完整的 power grid 和 transistor 可视性
- **Optimized collapsed views**：对位单元等低电流区域做 RC reduction 和 device 合并，提升 IR drop 分析性能

## 从 PGDB/xDSPF 生成 PG View

支持使用第三方提取器生成的 xDSPF 或 Quantus 生成的 PGDB 作为输入，**无需 GDS 文件**。

**PGDB 输入命令：**

```tcl
set_pg_library_mode ...
set_advanced_pg_library_mode \
  -pgdb_layermap ../pgdb_layermap.txt \
  -pgdb_list_file ../voltus_pgdb_dynamic_1/cell1.hdr
```

PGDB header 文件语法：`CELL cell_name PGDB pgdb_directory`
PGDB layermap 文件将工艺层名映射到 PGDB 层名。

**xDSPF 输入命令：**

```tcl
set_advanced_pg_library_mode \
  -import_xdspf_list_file ../voltus_xdspf_dynamic_1/cell2.xdspf \
  -xdspf_layermap ../voltus_xdspf_dynamic_1/layermap_dspf
```

xDSPF layermap 需从顶层到底层定义层堆叠。

## 多模式 PG View 生成（Multi-Mode PGV）

允许在单个 PGV 中保存每个 functional mode 的多个电压/频率下的时间平均或动态电流。适用于同一 cell 的不同 instance 在不同电压/频率下工作。

### Trigger 文件关键字

- `MODE <name> static|dynamic` — 时间平均/动态电流行为
- `VOLTAGE {net voltage}` — 仿真电压
- `FREQ <value>` — 仿真频率
- `CUSTOM_LABEL <label>` — 区分不同电压/频率对
- `SIM_DIR <dir>` — 仿真结果目录
- `RON_FILE <file>` — powergate RON 值文件（含 min/max/avg）
- `RON_METHOD min|max|avg` — RON 选择方法（默认 max）
- `RON_THRESHOLD <value>` — 判定 powergate 通断的阈值
- `OFF_NETS {net_list}` — 指定 switched-net 为 off net（用户指定或根据 RON 推导）

### 动态 PGV 示例

```tcl
CELL cell1 RON_THRESHOLD = 5 \
  MODE READ dynamic \
  CONDITIONAL_INPUT = ( !CEN & !WEN ) CONDITIONAL_PIN clk4 { RISE }
  CUSTOM_LABEL One VOLTAGE { VDDG 0.6 } FREQ 100 \
    RON_FILE ./ronfile1.txt RON_METHOD min OFF_NETS { VVDDG }
  CUSTOM_LABEL two VOLTAGE { VDDG 0.9 } FREQ 100 \
    RON_FILE ./ronfile1.txt
END_MODE ..... END
```

### RON 文件格式

RON 文件包含 powergate 的导通电阻值，格式如下：

```
D-Term-Net S-Term_Net  Avg  Max  Min  Gate
VDD        VDDG        1    2    3    X2_unmatched
VDD        VDDG        1    2    3    X3_unmatched
```

`RON_THRESHOLD` 判定 powergate 通断，`RON_METHOD` 选择使用 min/max/avg。OFF_NETS 有两种方式：
- **User-specified**：通过 `OFF_NETS {net_list}` 显式指定
- **Derived**：当所有 powergate 的 RON > RON_THRESHOLD 时，switched net 自动视为 off

### Power Analysis 中调度 Mode

```tcl
# 指定 custom label（对应具体电压/频率对）
set_power -instance -dynamic_switch_pattern { R1 H1 W1 }
# 指定 mode name（自动选择最近电压对）
```

混合多 mode（带/不带 RON/off nets）的 switch pattern 行为：
- 列表中第一个可用的 custom label 被使用
- 若某 mode 含 RON/off nets，排在其**之前**的纯 mode 优先使用
- 可指定多个 label 构成多周期 pattern，如 `{R1 W1 H1}`

### 时间平均(DC) PGV 示例

```tcl
CURRENT_CHARACTERIZATION_METHOD PWL \
  CELL cell2 LEAKAGE_CURRENT { VSS 2p VDD 17n }
  MODE_NAME READ static \
    CONDITIONAL_INPUT = !CEN CONDITIONAL_PIN CLK { RISE }
    CUSTOM_LABEL A1 VOLTAGE { VDD 0.9 VDD_LP 0.9 VSS 0 } \
      CAPACITANCE 10 USER_PWL_FILE pwl_1.txt \
      STATIC_INTERNAL_POWER { VSS 1p VDD 17n VDD_LP 1 } \
      CELL_DECAP_FILE cell_decap_read.txt
  END_MODE
END
```

## 多电压电容表征

```tcl
set_pg_library_mode -enable_multi_voltage_cap_generation true

# 用户自定义电压点
set_advanced_pg_library_mode \
  -stdcell_characterization_voltage_value {1.0 1.2 1.5 2.0 3.3}
```

启用后生成包含电压相关电容表的 PGV。默认生成 10 个电压点（0.1x 到 1.3x VDD）。检查电容表命令：

```tcl
check_pg_library -report_detail_multiple_voltage_cap powergate_stdcells.cl
```

## Decap / Filler / Damping Decap 单元表征

```tcl
# 指定 decap 和 filler cell
set_pg_library_mode -decap_cells <cell_name> -filler_cells <cell_name>

# 指定阻尼去耦单元（含高串联电阻）
set_advanced_pg_library_mode \
  -damping_decap_cell_list {cell1 cell2 ...} \
  -damping_decap_frequency <value>
```

- **Decap cells**：含显式去耦电容，耦合电容存储在 PGV 中用于 top-level IR drop 分析
- **Filler cells**：无 GDS 数据，LEF 几何数据视为完整
- **Damping decap cells**：高串联电阻用于控制谐振频率，默认表征频率 200KHz

## Flip Chip 设计 PG 库生成

### 流程步骤

1. **创建 bump.padfile**：包含 bump 的 MACRO 名称
2. **创建 bump.srcfile**：定义 CELL、NET、PORT 形状
3. **生成 bump PGV**（四种类型）：
   - Tech PGV
   - Standard Cell PGV（P/G pin 独立 pad 名）
   - Standard Cell PGV（P/G pin 共用 pad 名）
   - Standard Cell PGV（指定 pad x,y 位置）
4. **运行 Rail Analysis**：

```tcl
set_power_pads -net VDD -format padcell -file bump.padfile
set_power_pads -net VSS -format padcell -file bump.padfile
```

### Bump PGV 生成的四种类型对比

| 类型 | power_pins 指定 | 额外参数 | 适用场景 |
|------|----------------|---------|---------|
| Tech PGV | `{VDD 0.81}` | 无 | 仅技术视图 |
| Stdcell PGV（独立 pad） | `{VDD 0.81 PAD_VDD}` / `{VSS PAD_VSS}` | 需要 spice 网表 | P/G 使用不同 bump |
| Stdcell PGV（共用 pad） | `{VDD 0.81}` / `{VSS}` | `-common_supply_pins {PAD}` | P/G 共用 bump |
| Stdcell PGV（指定 x,y） | `{VDD 0.81}` / `{VSS}` | `-source_location_file bump.srcfile` | 需精确控制焊点位置 |

### Bump PGV 生成脚本示例

```tcl
read_lib -lef tech.lef BUMP.lef

set_pg_library_mode \
  -celltype techonly \
  -extraction_tech_file cworst.qrcTechFile \
  -lef_layermap lef_layer.map \
  -power_pins {VDD 0.81} \
  -ground_pins {VSS} \
  -cell_list_file bump.list

set_advanced_pg_library_mode \
  -source_location_file bump.srcfile \
  -libgen_command_file libgen.inc

generate_pg_library -output fast_bump.ss_0p81v
```

`bump.list` 文件仅包含 bump 名称，与 `bump.padfile` 相同。`libgen.inc` 格式：`cell_common_supply_names cell BUMP nets {PAD}`

## OA 库生成

```tcl
read_lib -oaRef {tech_lib_name cell_lib_name}

set_pg_library_mode \
  -celltype macros \
  -power_pins {VDD 0.9 VDD_LP 0.9} \
  -ground_pins VSS \
  -extraction_tech_file c_worst.tch \
  -lef_layermap lef_layermap.txt \
  -spice_models {spice90.l spice_90g.l.special} \
  -spice_subckts cell1.net \
  -spice_corners {tt tt_sr} \
  -current_distribution {dynamic_simulation input_trigger.txt} \
  -cell_list_file cell.list

set_advanced_pg_library_mode -techgen_dir ../tech
generate_pg_library -output .
```

需在 home 目录保存 `cds.lib` 文件。如果 OA 数据库没有 abstract view（含 LEF ports 信息），则仍需 LEF 文件。

## 检查与报告

```tcl
check_pg_library
```

报告内容：Cell Name、power pins 及电压、电容、生成的视图、PASS/FAIL 状态。Power gate cell 会打印 Ron、Idsat、Ileakage 特征值。

GUI 路径：**Power & Rail > Textual Reports > PowerGrid Library**

## 查看与调试

使用 **Cell Viewer**（GUI：Power & Rail > Library Cell Viewer）查看和调试 PGV。

### 支持的视图类型

| 视图 | 说明 |
|------|------|
| Geometrical View | LEF 几何图（PORT_GEOM / OBS_GEOM / PROMOTED_GEOM / OPTIMIZED_GEOM）|
| Port View | PORT_POWER 视图中的端口和 tap 信息 |
| Capacitance Views | GRID_CAP / DEVICE_CAP（net 级别） |
| Detailed View | DETAILED_POWER 详细网格信息 |
| Tap Current View | TAP_CURRENT（8 色线性滤波器显示） |
| Dynamic Tap Current View | DYN_TAP_CURRENT（每 interval 动态 tap，支持 SimVision 波形查看） |
| Powergate View | POWERGATE 电源开关信息 |
| Collapsed View | TAPCOLLAPSE_POWER 位单元合并后的电流 tap |

## 库验证

```tcl
validate_pg_library \
  -cell pll \
  -liberty ../data/libs/pll.lib \
  -power_grid_library_path ../data/pgv_dir/macro_pgv/macros_pll.cl \
  -extraction_tech_file ../data/qrc/gpdk090_9l.tch \
  -tech_lef_file ../data/lef/gsclib090_tech.lef \
  -output validate_pg_output_static \
  -rail_analysis_type static
```

验证流程：读取 macro PGV 和 Liberty 文件，生成 dummy DEF（单 cell 设计），运行 static/dynamic power 和 rail analysis，检查热点、连通性和电流分布。

### 输出目录结构

- `design_output/` — DEF、LEF、SDC、Verilog 等设计文件
- `power/` — 功耗分析结果（power.rpt、.ptiavg 电流文件）
- `rail/` — Rail 分析结果（各 net 状态目录、GIF 图、summary 报告）
