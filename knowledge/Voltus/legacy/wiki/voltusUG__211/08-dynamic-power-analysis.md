---
source: knowledge/Voltus/legacy/json/voltusUG__211 | chapters: [0157, 0158, 0159, 0160, 0161, 0162, 0163, 0164, 0165, 0166, 0167, 0168, 0169, 0170, 0171, 0172, 0173, 0174, 0175, 0176, 0177, 0178, 0179, 0180, 0181, 0182, 0183]
---

# 动态功耗与 IR Drop 分析

> **术语说明**：本文中与 dynamic 对立的 "static" 均指**时间平均分析方法**。Voltus 原文定义："Rather than averaging currents as static analysis does, dynamic analysis uses peak currents"——static 对电流取时间平均，dynamic 用时变峰值电流。非 leakage 分析。

## 概述

Voltus 提供 sign-off 质量的动态功耗与 IR Drop 分析。动态（瞬态）分析在 gate-level 检测 power integrity 问题，确定去耦电容的最优数量和位置，评估封装、bond wire、C4 bump 的 RLC 对瞬态 IR Drop 的影响。

主要特性：

- 支持 RDL 和 full-chip GDS 进行 power grid 提取
- XD（基于 LEF）和 HD（基于 GDS）两种精度模式
- 交互式 power grid 分析图：IRdrop、电阻电流、device tap current、instance 电压、grid capacitance 等
- CPF 支持（power domain 定义、工作条件、off power-switch net）
- 封装分析与 die-model 生成
- Power switch 设计的动态 IR Drop 分析（稳态 on/off、rush current、Power-switch ECO）
- SimVision 波形查看器查看动态 IR Drop 波形
- 动态 IR Drop movie
- 面向 Tempus 关键路径分析的动态 IR Drop 波形
- Violation browser、交互式查询、HTML 报告

## 动态功耗分析方法

动态功耗计算基于时间维度，分析指定时间段（如一个时钟周期）内电路的电流和电压。Voltus 使用两种方法：

| | 向量驱动 | Vectorless |
|---|---|---|
| **哪些信号翻转** | VCD 文件 | 用户指定 activity + activity propagation |
| **何时翻转** | VCD 文件 | TWF 文件（timing windows） |
| **如何翻转** | .lib + characterization | .lib + characterization |

### Vectorless 方法

无需仿真向量，利用 timing arrival window 信息确定实例翻转时间，产生 realistic 但不 overly pessimistic 的动态功耗 profile。

#### 概率类方法

- 使用 STA 工具（如 Tempus）生成的 timing 数据库或 TWF 文件确定翻转时间
- TWF 包含每个 instance pin 的 arrival time 窗口，通过 Monte Carlo 算法在窗口内调度具体翻转时刻
- 使用 activity propagation + 用户指定的 activity 确定翻转频率
- 使用 output load 和 slew，基于 .lib 中的 power arc 创建加权平均电流波形
- TWF 方式精度低于 VCD，但运行速度更快，适合 full-chip 分析

#### 状态传播方法

通过 `set_power_analysis_mode -method dynamic_vectorless -enable_state_propagation true` 启用。

**用户定义 Activity 模式：**
- 基于 clock source、primary input、sequential output、macro output 的用户 activity 设置调度
- 支持可配置参数：clock domain frequency（快时钟优先）、fanout（高 fanout 优先）、user-defined activity
- 生成切换场景文件 `voltus_power.stateprop.switchsrc`，格式为：`<时间> <flop名> <输出pin> <r/f>`

**用户定义 Power Target 模式（仅 XP 模式）：**
- 通过 `-enable_power_target_flow true` 启用
- 使用 `set_power` 指定 full-chip/block/net 的功耗目标值
- 工具自动迭代调整 clock gate ratio、input activity、macro activity 等参数以匹配目标
- 通过 `-keep_clock_gate_ratio_in_iterations`、`-adjust_input_activity_in_iterations`、`-adjust_macro_activity_in_iterations` 控制哪些参数固定

### 向量驱动方法

使用 gate-level 仿真的 VCD 输出，获取所有 net 的翻转活动信息。

- 相比时间平均分析，动态分析处理全 VCD 不现实，建议通过 Vector Profiling 先识别功耗高峰窗口
- VCD 窗口（start/stop time）不宜超过 dominant clock 的 5 个周期
- 优点：对给定向量数据精确；可用于验证 vectorless 方法；方法成熟

## Vector Profiling（向量分析）

识别 VCD/FSDB 中最大 activity/power 的窗口，用于驱动后续动态向量功耗分析。

### Event-Based Profiling

- 计算每个 net 上每个事件的功耗
- 推荐 step size = 2x fastest clock，默认 100 个 step
- 内部功耗 = Rise/Fall Energy（来自 .lib）

### 结合 Vector Profiling 与功耗分析

1. 运行 Vector Profiling 识别最差活动窗口
2. 结果存储在 `$worst_power_window_start` 和 `$worst_power_window_end` 变量中
3. 在 `read_activity_file` 的 `-start -end` 参数中使用这些变量进行详细分析
4. 通过 `-worst_window_count` 支持多窗口分析

### Power Density Aware Profiling

- 将芯片物理划分为 tile 网格，计算每个 tile 在每个 time step 的功率密度
- 跟踪哪些 tile 在 VCD profile 期间具有最差功率密度
- 按最差功率密度排序向量
- 使用 `-power_density_tiles_row_col { row col }` 指定 tile 数

三种 Profiling 模式：

| 模式 | 命令 | 输出 |
|---|---|---|
| Average | `-vector_profile_mode {average}`（默认） | 各分量平均功耗报告，最差窗口报告后缀 `.avgpower` |
| Activity | `-vector_profile_mode {activity}` | 最差 activity 报告 |
| Power Density | `-vector_profile_mode {power_density}` | 按 tiling 的报告，默认 10x10 tiles |

## 动态 Vectorless 功耗分析流程

### 输入文件

- 设计数据：LEF、netlist（Verilog）、DEF
- CPF 文件（power domain 信息）
- Timing/Power Libraries (.lib)
- SDC 或 TWF
- SPEF（信号线寄生参数）

> 先运行时间平均功耗分析并解决所有相关问题，再进行动态分析。

### 关键步骤

```
# 1. 加载设计
read_lib -lef $lefs
read_view_definition ../design/viewDefinition.tcl
read_verilog ../design/postRouteOpt.enc.dat/super_filter.v.gz
set_top_module super_filter -ignore_undefined_cell
read_def ../design/super_filter.def.gz

# 2. 加载 CPF
read_power_domain -cpf ../design/super_filter.cpf

# 3. 加载 SPEF
read_spef -rc_corner RC_wc_125 -decoupled ../design/postRouteOpt_RC_wc_125.spef.gz

# 4. 设置输出目录
set_power_output_dir dynVecLessPowerResults

# 5. 设置功耗分析模式（关键：-method dynamic_vectorless）
set_power_analysis_mode -reset
set_power_analysis_mode \
    -analysis_view AV_wc_on \
    -disable_static false \
    -write_static_currents true \
    -binary_db_name dynvectorlessPower.db \
    -create_binary_db true \
    -method dynamic_vectorless

# 6. （可选）为实例定义 PWL 电流波形
set_power -pg_net VDD_AO -pwl -instance instA \
    { 0ns 0mA 0.075ns 0mA 0.175ns 45mA 0.225ns 15mA 0.425ns 0mA } -sticky

# 7. （可选）设置仿真周期和分辨率
set_dynamic_power_simulation -resolution 50ps

# 8. 运行功耗分析
report_power -outfile dyn.rpt
```

### 输出文件

| 文件 | 说明 |
|---|---|
| `<binary_database>.db` | 二进制功耗数据库，可在 GUI 中加载查看各类功耗图 |
| `<power_report>.rpt` | 按 group/clock domain/power net 汇总的功耗报告 |
| `static_<net_name>.ptiavg` | 每个 net 的时间平均电流文件（用于 rail analysis） |
| `dynamic_<net_name>.ptiavg` | 每个 net 的动态电流文件 |

## 动态向量类功耗分析流程

```
# 1-3. 同 Vectorless 流程，加载设计、CPF、SPEF
# 4. 设置输出目录
set_power_output_dir dynVectorbasedPowerResults

# 5. 读取 activity 文件
read_activity_file -format VCD -scope FIR_TB.Unit \
    -start {} -end {} -block {} ../design/ncsim.vcd

# 6. 设置 Vector Profiling 模式
set_power_analysis_mode -reset
set_power_analysis_mode \
    -analysis_view AV_wc_on \
    -method vector_profile \
    -worst_step_size 2ns \
    -write_profiling_db true \
    -worst_window_count 2
report_power -nworst 5 -outfile eventbased_profiler.rpt -time_based_report

# 7. 基于最差窗口运行动态向量功耗分析
set_power_analysis_mode -reset
set_power_analysis_mode -method dynamic_vectorbased
read_activity_file -format SHM ADDER.trn -scope adder_tb_e/u1 \
    -start ${worst_power_window_start} -end ${worst_power_window_end}
report_power
```

### 多 VCD/FSDB 文件支持

- 可多次调用 `read_activity_file` 读取多个 VCD 文件
- 默认所有信号对齐到 t=0，可通过 `set_power_analysis_mode -start_time_alignment false` 禁用
- 使用 `-start_time_shift` 参数可对不同 block 的 VCD 设置不同起始时间

## 查看动态电流波形

Voltus 内嵌 SimVision 波形查看器，可查看 instance、hierarchy、clock domain 级别的动态电流波形。

**GUI 路径：** Power Rail -> Dynamic Results -> Waveforms

**关键 TCL 命令：**

```tcl
# 查看实例电流波形
view_dynamic_waveform \
    -waveform_type current \
    -waveform_files dynamic_vss.ptiavg \
    -instance inst1

# 查看总电流波形
view_dynamic_waveform \
    -waveform_type current \
    -waveform_files dynamic_vss.ptiavg \
    -composite_waveform_type total_current

# 查看时钟域复合波形
view_dynamic_waveform \
    -waveform_type current \
    -waveform_files dynamic_vss.ptiavg \
    -power_db power.db \
    -composite_waveform_type clock \
    -composite_waveform_name clk

# 查看层次化模块波形
view_dynamic_waveform \
    -waveform_type current \
    -waveform_files dynamic_vss.ptiavg \
    -composite_waveform_type hierarchy \
    -composite_waveform_name ethernet_mac_2

# 查看 Profiling Database
view_dynamic_waveform -type profile \
    -waveform_files {vectorprofile.report.trn}
```

支持 multi-threading 加速实例搜索，需先设置 `set_multi_cpu_usage -localCpu <n>`。

## Scan Mode 分析

用于 DFT 测试中的 scan chain 功耗/IR Drop 分析。通过 `set_power_analysis_mode -scan_control_file <filename>` 启用。

支持两种模式：
- **Shift 模式（SHIFT）：** 需提供 scan flop 初始状态和 chain 顺序，按 scan clock 频率逐级 shift 状态
- **Vectorless 模式（VECTORLESS）：** 需提供 chain 顺序和 % activity，工具自动生成 scan pattern

Scan Control File 格式包含 MODE、SCAN_PATTERN、chain name、initial_state 等信息。

## 用户自定义 Mode 电流波形生成

使用 `set_power -custom_macro_pwl` 指定 trigger 文件，基于 master cell 的 PWL 波形自动按 NLPM 能量表比例缩放生成 companion cell 的 PWL 波形。

- Vector-based 分析中，用户定义 PWL 覆盖 .lib 模型
- Vectorless 模式中需配合 `set_power -dynamic_switch_pattern` 使用
- 缩放因子报告保存在 `scale_factor_report_<master_cell_name>.txt`

## 动态 Rail 分析

动态 Rail 分析使用峰值电流而非平均电流，能够看到电流在时钟周期内的精细时变特性，并包含封装电感的影响。

### 动态 IR Drop 关键概念

- **功耗类型：** Switching power（互容充放电）、Internal power（内部电容 + 馈通电流）、Leakage power（非翻转时的漏电）
- **去耦电容来源：** 寄生电容、器件去耦（扩散/栅电容）、分立去耦电容、信号 net 自然去耦电容、阱电容
- **动态 IR Drop：** 局部同时翻转的高功耗 driver 从 power rail 抽取电流，导致瞬态电压下降
- **封装寄生参数：** 130nm 及以下工艺，封装的 RLC 对瞬态 IR Drop 影响显著

### 动态 Rail Analysis 流程

```
# 1. 设置 Rail 分析模式
set_rail_analysis_mode \
    -method dynamic \
    -analysis_view AV_wc_on \
    -generate_movies true \
    -save_voltage_waveforms true \
    -accuracy hd \
    -temperature 125 \
    -power_grid_library {
        ../data/pgv_dir/tech_pgv/techonly.cl
        ../data/pgv_dir/stdcell_pgv/stdcells.cl
        ../data/pgv_dir/macro_pgv/macros_pll.cl
    }

# 2. （未使用 CPF 时）定义 power net 和 domain
set_pg_nets -net VDD_AO -voltage 0.9 -threshold 0.85
set_pg_nets -net VSS -voltage 0.0 -threshold 0.05
set_rail_analysis_domain -name PD_AO -pwrnets VDD_AO -gndnets VSS -threshold 0.10

# 3. 定义电压源位置
set_power_pads -net VDD_AO -format xy -file ../design/VDD_AO.pp

# 4. 指定动态电流文件
set_power_data -format current {
    dynVecLessPowerResults/dynamic_VDD_AO.ptiavg
    dynVecLessPowerResults/dynamic_VSS.ptiavg
}

# 5. 运行 Rail 分析
analyze_rail -output ./dynVecLessRailResults -type domain
```

### 并行运行动态功耗与 Rail 分析

设置 `-report_power_in_parallel true`，移除 `report_power` 命令，`analyze_rail` 将同时触发功耗和 Rail 分析。

### 动态 Rail 分析图表与结果

动态分析特有图表类型：

| 类型 | 启用条件 |
|---|---|
| Power gate current/voltage (pi/pv) | Power gate 连接到被分析 net 时自动启用 |
| 封装模型电压 (vu) | 提供封装数据时自动启用 |
| Instance 有效电阻 (rlrp) | `-enable_rlrp_analysis true` |
| 电阻电流 (rc) | `-enable_rc_analysis true` |
| Via 压降 (vv) | `-enable_voltage_across_vias true` |

动态 IR Drop movie 可通过 `view_dynamic_movie -type ir -movies_directory VDD/movies_directory` 查看。

### 片上电压调节器（Vreg）分析

SoC 中的电压调节器用于稳定供电和 DVFS。通过 `set_voltage_regulator_module` 命令启用，需指定 Vreg 名称、SPICE netlist、pin mapping、组件列表等。

分析过程中工具创建 input/output/ground 的 reduced grid RC netlist，捕获 Vreg 输出端的噪声并用于 Rail 分析。

## 使用表征电流 PGV

Voltus 支持在 vectorless 和 vector-based 分析中使用 PGV 中预定义的动态电流数据：

- Vector-based 分析：工具自动匹配 VCD 中的 trigger condition 调度 current mode
- Vectorless 模式：通过 `set_power -dynamic_switching_pattern` 控制 trigger 场景

若 PGV 库无 trigger time，动态电流从 t=0 开始，可通过 `set_rail_analysis_mode -dynamic_trigger_file <filename>` 偏移。

## 动态混合模式分析

使用 `-method dynamic_mixed_mode` 结合 vector-based 和 state-propagation-based vectorless 分析。

适用场景：
- **Case 1：** Full-chip 设计中某些 block 无可用向量，使用 vectorless 补全
- **Case 2：** 有向量的 block 中存在未标注的组合逻辑，通过 state propagation 补全

**注意事项：**
- 全局 activity 用于未标注 flop 和 primary input 的选择
- TWF 与 vector 文件时钟频率不一致时，TWF 优先级更高
- 多 block 向量需为同一类型和格式（VCD/FSDB/PHY/SHM），不支持混用

输出额外文件：`voltus_power.stateprop.switchsrc`（flop 切换信息）和 `voltus_power.stateprop.stats`（toggle coverage 统计）。

## 噪声容限计算

Voltus 使用 Effective Instance Voltage（EIV）方法计算噪声容限，仅在 driver-receiver 对中 flop 为 receiver 时计算。

### 计算公式

- NMH (Margin_High) = (Voh - Vih) - signal_noise - guardband > 0
- NML (Margin_Low) = (Vil - Vol) - signal_noise - guardband > 0

### 流程

1. **Power Analysis：** 设置 `-create_driver_db true`，生成 driver-receiver pairs 数据库
2. **Rail Analysis：** 自动检测 driver-receiver 数据库并执行 EIV 分析
3. **计算：** 使用 `calculate_noise_margin` 命令，指定 noise limit 文件、state directory 和 power directory

Noise Limit 文件格式：
```
default_noise_limit <value>
default_signal_noise <value>
default_guard_band <value>
<cell_name> <noise_limit> <signal_noise> <guardband>
```

输出文件为 `<powernet>_<groundnet>.noise_margin`，包含 Margin_High、Margin_Low、NMh、NMl 及各电压值和噪声参数。
