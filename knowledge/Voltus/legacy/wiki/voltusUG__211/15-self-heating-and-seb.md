---
source: knowledge/Voltus/legacy/json/voltusUG__211 | chapters: [0305, 0306, 0307, 0308, 0309, 0310, 0311, 0312, 0313, 0314, 0315, 0316, 0317, 0318, 0319, 0320]
---

# 自热效应分析与统计电迁移预算

## 一、Self-Heating Effect (SHE) 分析

### 1.1 概述

在 FinFET 工艺节点下，自热效应变得显著，需要纳入 device modeling 和电路仿真。SHE 由两部分组成：

- **FEOL Self-Heat (delta T FEOL)**：由晶体管开关产生。温升是 fin 数、finger 数及功耗的函数。需基于 instance 计算，thermal resistance 取决于 cell type（core vs IO）。
- **BEOL Self-Heat (delta T RMS)**：由互连导线中的 RMS 电流产生。温升是 Irms 和金属宽度的函数。

最终 BEOL 上的 delta T 同时考虑 RMS 电流贡献和 FEOL 的耦合效应。

### 1.2 数据需求

SHE 分析所需输入数据：

| 数据 | 说明 |
|------|------|
| Timing Libraries | Synopsys .lib 及 PVT corner |
| Verilog | 网表 |
| SDC | 时序约束 |
| VCD/TCF | 基于向量的 activity 文件 |
| LEF | Technology LEF、标准单元、IO、memory、IP LEF |
| DEF | 顶层及模块 DEF |
| SPEF | Flattened 或多份 SPEF |
| Spice Subckts | 所有 cell 的 Spice 网表及模型（建议 macro/memory/IO 提供 device X/Y location） |
| GDS | IO、memory、IP 的 GDS |
| Extraction tech file | Quantus 或工艺文件 |
| EM rules | 每层的电流限制，含 Irms 方程 |
| Alpha parameter | 各 metal layer 效应系数 |
| Beta parameter | 热耦合效应系数 |
| Instance Power File | 实例名 + 总功耗的 2 列文件（查 SHE 表用一半功耗） |
| Thermal Resistance File | 实例名、finger 数、fin 数（FEOL delta T 计算用） |

### 1.3 分析流程

SHE 分析基本流程：

1. **Load design** — 读入 LEF/DEF/Verilog/Timing Libs/SDC
2. **Specify activity** — 提供 TCF/VCD/FSDB
3. **Run `report_power`** — 计算 instance-based static power 及 dynamic currents
4. **Run `analyze_self_heat`** — 指定 tiles 数、alpha/beta 系数及 cell fin/finger 信息
   - 计算 signal wires 上的 RMS 电流
   - 计算 power network wires 上的 RMS 电流
   - 生成三种 Delta Temperature 文件：ddt（Detail）、idt（Instance）、tdt（Tile）

若只需分析 BEOL self-heat（仅 delta T RMS，不含 FEOL 及耦合效应），可使用 `analyze_joule_heat` 替代。

### 1.4 关键命令

**analyze_self_heat**（完整 SHE 分析，含 FEOL + BEOL + coupling）：

```tcl
analyze_self_heat -domain ALL \
    -alpha_parameters {{M1 <alpha_factor1> <alpha_factor2>} ...} \
    -beta_parameters {<beta_factor1> <beta_factor2> <beta_factor3>} \
    -cell_thermal_resistance_file TRF.txt \
    -instance_power_file ./static_db/static_power.rpt \
    -instance_delta_temperature_file Inst_Delta_Temp_Report.txt \
    -tile_delta_temperature_file sh_ttm.txt \
    -tiles {10 10} \
    -detail_delta_temperature_file power_detail.rpt \
    -report_conn_pin_wire self_heat.rpt
```

**analyze_joule_heat**（仅 BEOL Joule-heat 分析）：

```tcl
analyze_joule_heat -domain ALL \
    -tile_delta_temperature_file joule_ttm.txt \
    -tiles {10 10} \
    -detail_delta_temperature_file joule_heat_detail.rpt \
    -report_conn_pin_wire joule_heat.rpt
```

### 1.5 查看 SHE 图表

**命令行方式**：
1. 用 `read_power_rail_results` 加载 delta T 文件：
   - `-detail_delta_temperature_file`
   - `-instance_delta_temperature_file`
   - `-tile_delta_temperature_file`
2. 用 `set_power_rail_display -plot {ddt|idt|tdt}` 指定图表类型

**GUI 方式**：
1. 选择 Power & Rail > Power & Rail Plots
2. 点击 DB Setup，加载 Rail Database
3. 在 Instance Files 栏加载对应 delta T 文件
4. 选择 Rail 标签，从下拉列表选择 ddt/idt/tdt
5. 温度地图将显示在 Layout 标签中

### 1.6 Delta Temperature 文件格式

**Detail Delta Temperature File (ddt) — SHE 分析**：
```
# LayerName I_rms(mA) Alpha Beta T_FEOL T_RMS T_BEOL ll_x ll_y ur_x ur_y
# Net: <net_name>
M2 0.0002 0.8000 0.8429 0.2363 0.0000 0.1594 (4939.380 1177.008) (4939.397 1177.040)
```

**Detail Delta Temperature File (ddt) — Joule Heat 分析**：
```
# LayerName I_rms(mA) dT_RMS ll_x ll_y ur_x ur_y
M2 0.0380 0.0511 (144.684 118.310) (144.720 118.330)
```

**Instance Delta Temperature File (idt)**：
```
# deltaT_FEOL instance_name
2.174284e-03 inst1
2.157267e-03 inst2
```

**Tile Delta Temperature File (tdt)**：使用 DIE_STACK_TEMPERATURE_MAP 格式，包含 DIE_AREA、NUMBER_OF_LAYERS、LAYER 及每个 tile 的温度值矩阵。

---

## 二、Statistical Electromigration Budgeting (SEB)

### 2.1 概述

SEB 基于 EM 可靠性的统计特性，对设计规则违规进行 EM 风险评估。仅需要修复那些显著增加风险的违规，减少验证时间并确保满足 chip-level 可靠性目标。

**FIT (Failures in Time)**：表征芯片失效率的指标。
- 1 FIT = 1 次故障每 10^9 产品小时
- = 1000 个产品运行 10^6 小时发生 1 次故障
- = 10^5 个产品运行 10^4 小时发生 1 次故障

Voltus 为每条 metal/via resistor 计算 FIT 值，计算公式基于 foundry EM 定义，涉及 Median Time to Failure (MTF)、激活能 Ea、电流密度指数 n、Boltzmann 常数 k 等参数。

### 2.2 SEB 流程

1. **Load design** — 读入 LEF/DEF/Verilog/Libs/SDC，设置 signal EM 参数
2. **Power analysis** — 执行 static/dynamic power analysis（若已有 instance power file 可跳过 static）
3. **Self-heat analysis** — 评估 BEOL/FEOL 自热及耦合效应，或仅 Joule-heat 计算 delta T_RMS
   - 注意：VIA 层无 RMS EM rules，其 delta T 由相邻上下 metal 层的最大 delta T 决定
4. **SEB FIT calculation** — 基于最终 BEOL 温升计算，生成 power 和 signal SEB report

### 2.3 SEB 相关 TCL 命令参数

通过 `set_rail_analysis_mode`（PG SEB）或 `set_signal_em_analysis_mode`（Signal SEB）设置：

| 参数 | 说明 |
|------|------|
| `-check_thermal_aware_em` | 开启 thermal-aware EM 检查 |
| `-enable_seb` | 开启 SEB FIT 计算 |
| `-env_temperature` | 环境温度 |
| `-read_detail_delta_temperature_file` | 读入 ddt 文件 |
| `-seb_lifetime` | 目标产品寿命（小时） |
| `-seb_table` | SEB 查表文件（foundry 提供） |
| `-seb_temperature` | SEB 计算用温度 |
| `-use_rms_delta_t` | 使用 RMS delta T |

### 2.4 Power/Signal EM 的 FIT 计算流程

**Power FIT 分析**：

```tcl
set_rail_analysis_mode \
    -method static \
    -accuracy hd \
    -temperature 125 \
    -power_grid_library <pgv> \
    -enable_seb true \
    -seb_table seb_table.txt \
    -env_temperature 85 \
    -em_threshold 0.0 \
    -check_thermal_aware_em true \
    -read_detail_delta_temperature_file power_detail.rpt \
    -ict_em_models <ictem>

analyze_rail -type domain -output static_rail core
```

**Signal FIT 分析**：

```tcl
set_signal_em_analysis_mode \
    -method {avg} \
    -avgRecovery 0 \
    -detailed \
    -useQrcTech \
    -use_db_freq \
    -report seb_reduce.rpt \
    -enable_seb \
    -seb_table seb_table.txt \
    -env_temperature 85 \
    -seb_lifetime 43800 \
    -check_thermal_aware_em \
    -read_detail_delta_temperature_file power_detail.rpt \
    -ict_em_models <ictem>

verify_AC_limit
```

### 2.5 输出报告

**Power SEB Report**：位于 rail 输出目录下，格式为 `<domain>_<temp>_<mode>_<X>/Reports/<net>/<net>.rj.<mode>.rpt`。报告头部显示总 FIT 值。每条记录包含：
- I/Ilimit、Layer、Location、Width、Via Area/Cuts、ShortLength
- DT_FEOL / DT_RMS / EM_Temperature / SEB_Temperature
- Sdc（DC EM severity ratio）
- MTF（Median Time to Failure，基于 seb_temperature 计算）
- FIT（各 resistor 的 failure in time）
- Benefit Factor（满足 `L>3W<0.4` 条件时 EM limit 可倍增）

**Signal SEB Report**：默认输出到当前工作目录。
- `<filename>.rpt` — 按电流/限值比降序排列的违规列表
- `<filename>.detailed.rpt` — 详细报告（需 `-detailed` 参数）

设计级总 FIT 的主要贡献来自 PG nets，signal nets 的贡献通常可忽略。

### 2.6 查看 FIT GUI 图

1. 加载设计数据（`read_lib`、`read_verilog`、`read_def` 等）
2. 加载 rail 数据：`read_power_rail_results -rail_directory <输出目录>`
3. 设置显示：`set_power_rail_display -plot fit`
4. 或在 GUI 中：Power & Rail > Power Rail Plots > DB Setup > 选择 Rail Database > 选择 fit 类型

FIT 图将叠加在版图上显示。
