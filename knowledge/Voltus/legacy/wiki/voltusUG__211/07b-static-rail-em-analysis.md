---
source: knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl | entries: [0142, 0143, 0144, 0145, 0146, 0147, 0148, 0149, 0150, 0151, 0152, 0153, 0154, 0155, 0156]
---

# 时间平均 Rail 和 EM 分析（Static Rail/EM Analysis）

> 与功耗分析一样，Voltus 中的 "Static Rail" 指**时间平均分析**——使用 `report_power` 生成的平均电流（`.ptiavg`）作为激励源，求解电阻网络得到平均 IR Drop 和平均电流密度。它分析的是电路的长期平均行为，而非瞬态峰值。动态 Rail 分析（`-method dynamic`）则使用时变电流波形，捕捉峰值 IR Drop。Cadence 建议**先做时间平均分析排查结构性缺陷，再做动态分析捕捉瞬态问题**。

## IR Drop 与 Ground Bounce 基本概念

- **IR Drop** — 电流流过 power grid 的寄生电阻导致的 VDD 电压下降。实际 power grid 存在非零电阻，cell 从 VDD pad 取电流时沿线产生压降，到达 cell 时电压低于理想值
- **Ground Bounce** — 电流流过接地网络寄生电阻导致的 VSS/GND 电压抬升，同样降低 cell 的有效工作电压
- 两者都会导致 cell 工作电压下降，可能引发时序问题甚至功能失效
- **峰值 IR Drop** — 多个 cell 同时切换时瞬时电流叠加产生，可远大于平均 IR Drop；随着 block 面积增大，同时切换概率降低，峰值/平均值之比趋近 1.0
- IR Drop 具有**全局性**：一个 cell 的取电也会影响其它 cell 的供电电压

## 时间平均 Rail 分析适用场景

- 130nm 及以上工艺：用于验证 power grid 的基本健壮性
- Cadence 建议**先做时间平均分析，再做动态分析**。时间平均分析能准确暴露 open circuit、missing via、高电流密度、power strap 不足、走线宽度不够等问题
- 时间平均 EM 分析是首选方法，因为它模拟芯片长期运行的平均电流效应，计算平均电压降
- 典型目标 IR Drop 限制为 2%-5%

## 电迁移 (EM) 基本概念

- **Electromigration** — 电子在金属导线中移动时与金属原子碰撞，长期作用下原子沿电子流方向迁移，可能导致断路（open）或短路（fusing）
- **Wearout** — 长期磨损机制，以 MTTF（Mean Time To Failure）衡量。采用 Black's Equation 计算
- **Joule Heating** — 交流电流导致导线局部过热，加速 EM 失效
- EM 风险通过电流密度比 `J/Jmax` 衡量，比值 < 1.0 为合格
- EM 模型通过 `set_rail_analysis_mode -em_models <file>` 指定，也可从 QRC 技术文件中读取

### 关键 EM 模型参数

| 参数 | 说明 |
|------|------|
| `jmax_dc_avg` | DC 平均电流密度限值 |
| `jmax_dc_rms` | DC RMS 电流密度限值 |
| `jmax_dc_peak` | DC 峰值电流密度限值 |
| `TC1 / TC2 / TREF` | 温度系数与参考温度 |
| `via_range` | 基于通孔数量的电流限值分段 |
| `jmax_lifetime` | 不同寿命期的电流密度缩放因子 |
| `current_direction` | 电流方向（up/down/both）相关 EM 规则 |

支持单值、PWL 插值表、EQU 方程三种方式定义 Jmax。支持 **Blech length** 效应（短导线允许更高电流密度）。

## 电阻分析 (Resistance Analysis)

`analyze_resistance` 命令用于计算 power grid 的有效电阻，可在不进行功耗计算和 IR Drop 分析的情况下独立运行。

### 三种分析模式

| 模式 | 命令参数 | 说明 |
|------|----------|------|
| Domain-based | `-domain ALL` | 计算 domain 内所有 net 的 Rvdd+Rvss 总和及占比 |
| Net-based node-to-pad | `-net <name> -node_list` | 计算指定节点到所有 voltage source 的电阻 |
| Net-based node-to-node | `-net <name> -node_pair_list` | 计算两点之间的 point-to-point 电阻 |

### 命令示例

```tcl
# 基本设置
set_pg_nets -net VSS -voltage 0 -threshold 0.5
set_power_pads -net VSS -format xy -file ../design/VSS.pp

# Domain 分析
analyze_resistance -domain ALL -output_dir Reff_domain

# Net-based node-to-pad
analyze_resistance -net VSS -output_dir Reff_VSS_node \
  -node_list {{15.968 287.7695 Metal1 n1} {137.117 214.088 Metal5 n2}}

# Net-based node-to-node (point-to-point)
analyze_resistance -net VSS -output_dir Reff_VSS_n2n \
  -node_pair_list {{75.4795 318.9425 Metal1 61.31 272.183 Metal4 n1}}

# Instance-level 分析
analyze_resistance -instance_list {{INV11 VDD} {INV21 VDD}} -net VDD

# Cell-level 分析
analyze_resistance -net VDD -cell CKBD8
```

### 输出

- Net-based 输出 `effr.rpt`，domain-based 输出 `domain_effr.rpt`，包含总有效电阻值和各 net 占比
- Net-based 额外生成 `effr.gif`

## 时间平均 Rail 分析设置与运行

### 两种精度模式

| 模式 | 用途 | PGV 类型 | Via Clustering |
|------|------|----------|----------------|
| **XD** (Accelerated Definition) | 早期实现阶段 IR/EM 分析 | Early | 25x25 |
| **HD** (High Definition) | 最终签核阶段 IR/EM 分析 | IR/EM | 4x4 |

### 必备输入文件

- 设计数据（LEF、netlist、DEF）
- CPF 文件（定义 power domain）
- Power-grid 库文件（`.cl`）
- 时间平均功耗计算生成的 power database 和 binary current 文件

### 完整流程

```tcl
# 1. 加载设计
read_lib -lef $lefs
read_view_definition ../design/viewDefinition.tcl
read_verilog ../design/postRouteOpt.enc.dat/super_filter.v.gz
set_top_module super_filter -ignore_undefined_cell

# 2. 指定 CPF
read_power_domain -cpf ../design/super_filter.cpf

# 3. 设置 Rail 分析模式
set_rail_analysis_mode \
  -method static \
  -accuracy xd \
  -analysis_view AV_wc_on \
  -power_grid_library { \
    ../data/pgv_dir/tech_pgv/techonly.cl \
    ../data/pgv_dir/stdcell_pgv/stdcells.cl \
    ../data/pgv_dir/macro_pgv/macros_pll.cl \
  } \
  -use_em_view_list ../data/voltus/em_view.list \
  -enable_rlrp_analysis true \
  -verbosity true \
  -temperature 125

# 4. 若未使用 CPF，手动定义 power net 和 domain
set_pg_nets -net VDD_AO -voltage 0.9 -threshold 0.85
set_pg_nets -net VSS -voltage 0.0 -threshold 0.05
set_rail_analysis_domain -name PD_AO -pwrnets VDD_AO -gndnets VSS -threshold 0.10

# 5. 定义 voltage source 位置
set_power_pads -net VDD_AO -format xy -file ../design/VDD_AO.pp
set_power_pads -net VSS -format xy -file ../design/VSS.pp

# 6. 指定电流文件
set_power_data -format current { \
  staticPowerResults/static_VDD_AO.ptiavg \
  staticPowerResults/static_VSS.ptiavg \
}

# 7. 运行 Rail 分析
analyze_rail -output ./staticRailResults -type domain ALL
```

### 输出目录结构

- `analyze_rail` 生成的输出目录默认为 `<domainName>_<temperature>_avg_<X>`
- 每个 net 的 state directory 下包含 `results`（摘要）、`Reports`（完整报告文件夹）、GIF 图像
- 启用 `-def_based_hierarchical_reports true` 可为每个 DEF hierarchy 生成独立报告

## 查看 Rail 分析结果

### GUI 流程

1. 加载设计后通过 `read_power_rail_results` 导入 rail 结果
2. 打开 **Power & Rail Plots** 窗口，点击 **DB Setup** 指定 power database 和 rail directory
3. 通过 **Layers/Nets** 控制层和 net 显示
4. 选择 Rail 分析类型进行图形化查看

### 主要 Rail Plot 类型

| Plot | 命令 | 说明 |
|------|------|------|
| IR Drop | `-plot ir` | 显示 power grid 各段电压降 |
| Grid Resistance | `-plot res` | 显示各段电阻，独立于活动向量，早期评估 power grid 弱点 |
| Instance LRP | `-plot rlrp` | 实例到电压源的最优电阻路径。需 `-enable_rlrp_analysis true` |
| Resistor Current | `-plot rc` | 显示电流流动路径和趋势 |
| Tap Current | `-plot tc` | 显示单元内部电流分布 |
| Current Density | `-plot rj` | 显示 `J/Jmax` 比值，标识 EM 违例区域。需指定 EM 模型 |
| Instance Voltage (Net-based) | `-plot ivdn` | 各 net 的实例电压降 |
| Instance Voltage (Domain-based) | `-plot ivdd` | 各 power-ground pair 的实例电压降 |
| Power-Gate Current | `-plot pi` | power gate 电流与 Idsat 比值。需 power-gated design |
| Power-Gate Voltage | `-plot pv` | power switch 上的压降 |
| Resistor Sensitivity | `-plot rs` | 灵敏度 `d(V)/d(R)`，指导 power grid 优化。需 `-enable_sensitivity_analysis true` |

### RLRP（Least Resistance Path）交互调试

- 选中实例或电阻后点击 **Trace**，高亮从该对象到最近 voltage source 的最优电阻路径
- Resistance Path 窗口显示每段电阻的详细信息，包括 layer name、坐标、累计电阻和累计压降
- 支持 Auto Zoom、Show Single Path、Enable Multi Segments Selection 等功能

## 生成文本报告

两种报告生成方式：

| 方式 | 命令 | 用途 |
|------|------|------|
| Power 报告 | `report_power` | 支持按 hierarchy、cell type、instance、clock domain、power domain 等分类的详细功耗分布 |
| Rail 报告 | `report_power_rail_results` | 生成全局 power/activity/frequency 报告，显示 worst-case 值 |

示例 TCL 流程：

```tcl
read_power_rail_results -power_db staticPowerResults/staticPower.db \
  -rail_directory staticRailResults/ALL_125C_avg_1
report_power_rail_results -plot ir        # IR drop 报告
report_power_rail_results -plot rj        # 电流密度（EM）违例报告
report_power_rail_results -plot rlrp -threshold 0.001  # LRP 报告
```

## Power-Grid Integrity 报告

Rail 分析自动生成统一的 power-grid integrity 报告，格式为 `<net_name>.pg_integrity.rpt`（文本）和 `.html`，检测内容包括：

- **Missing Cell PG Views** — 缺少 power-grid view 的 leaf cell
- **Physically Disconnected Instances** — 与 power grid 完全断开的实例
- **Floating Power Pins** — 部分 power pin 未连接
- **Disconnected Wire Segments** — 未连接到 voltage source 的走线段
- **Weakly Connected Metal Segments** — 未通过 via 连接到上层金属的线段
- **Dropped Voltage Sources** — 由于坐标错误或缺少 geometry 而未能插入的 voltage source
- **Unmapped Package Terminals** — 未映射到 grid 或 top-level pin 的封装端子

## Layer-Based IR Drop 报告

- 自动生成于 `<output_dir>/<state_dir>/Reports/<net_name>/<net_name>.layerbased_ir.rpt`
- 报告每层金属的最高和最低 IR drop、节点电压范围、节点数
- 用于逐层调试 IR drop 的分布和贡献

## HTML 报告

- 自动生成于 state directory 下的 `Reports/` 目录
- 主入口文件 `dma_mac.main.html`，通过 **Tools -> Report** 菜单查看
- 包含 IR Drop Analysis Report、Layer-Based IR Drop Report 等子报告链接

## 恒流源 IR 分析

当设计中使用了 voltage regulator（确保恒定电流输出）时，Voltus 支持将 power pad 连接为电流源而非电压源进行 IR drop 分析。

```tcl
# 1. 准备 xyiv 格式的 power pad 文件，标记 I（电流源）或 V（参考电压源）
#    I ISR1 12.5 0 M3 100
#    V VSRC1 16.401 18.432 M1 0.8

# 2. 启用恒流源分析
set_rail_analysis_mode -enable_ccs_analysis true

# 3. 加载 pad 文件（xy 格式）
set_power_pads -net VDD -format xy -file power_pads.xy

# 4. 加载 xyiv 文件（指定恒流源和参考电压源）
set_power_pads -net VDD -format xyiv -file power_pads.xyiv

# 5. 运行正常 rail 分析
analyze_rail -output ./ccs_rail_results -type net VDD
```

- `xyiv` 文件格式：`<I/V> <SourceName> <X Y> <Layer> <Value>`（I 的单位 mA，V 的单位 V）
- 至少需要一个 reference voltage source（V 类型）

## Hotspot Debugger

Hotspot Debugger 自动识别设计中的 IR drop 和 EM 违例热点区域，提供根因分析信息，帮助判断 hotspot 成因。

`debug_irdrop` 命令在 `analyze_rail` 之后执行，报告内容包括：

- Hotspot Region Coordinate
- Timing Library Analysis
- Power-Grid View Analysis
- Power-Grid Integrity Analysis
- IR-Drop Composition
- Root Cause Analysis

常见 hotspot 成因：data error、weak power grid / missing via、高平均功率密度、同时切换、decap 密度不足、power gate 数量不足、bump 不足、package 效应。
