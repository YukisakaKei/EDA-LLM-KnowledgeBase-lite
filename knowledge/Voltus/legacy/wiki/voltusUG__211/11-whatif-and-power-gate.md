---
source: knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl | entries: [0222, 0223, 0224, 0225, 0226, 0227, 0228, 0229, 0230, 0231, 0232, 0233, 0234, 0235, 0236, 0237, 0238, 0239, 0240]
---

# What-If Rail Analysis 与 Power Gate Analysis

> **术语说明**：What-If 和 Power Gate 分析中的 "static"/"dynamic" 指电流数据类型——static = 时间平均 DC 值，dynamic = 时变 PWL 波形。与物理 leakage 无关。

## What-If Rail Analysis

### 概述

What-If Rail Analysis 用于在现有 power grid 上快速修改电气参数，以预估优化 effort，辅助判断 IR drop 和 EM 违例的修复方向。分析过程**不修改实际版图**，仅通过缩放/虚拟操作模拟效果。

支持的 what-if 能力：
- 缩放 power grid 电阻（Resistance Scaling）
- 缩放时间平均/动态电流（Current Scaling）
- 创建时间平均/动态电流区域（Current Regions）
- 缩放电容（Capacitance Scaling）
- 创建虚拟走线/过孔（Virtual Shapes）

可通过 GUI（Run Rail Analysis > Advanced > What-If Analysis Setup）或 TCL 命令驱动。

### 缩放 Power Grid 电阻

启用 sensitivity analysis (rs) 后可高亮 IR drop 敏感线段。基于 IR drop (ir)、Resistor Sensitivity (rs)、Current Density (rj) 等图，可对指定 LEF layer 或区域缩放电阻。对 power-gated domain 的 IR drop 问题，也可缩放已放置 power gate 的 on-resistance 做快速评估。

```
scale_what_if_resistance -global -net VDD_AO -layer Metal4 -scale 4 -auto_scale_adjacent_via_layers true
```

### 缩放时间平均/动态电流

在无法优化 power grid 的区域，通过缩放电流估算需降低多少 activity / simultaneous switching / placement 密度才能满足 IR drop 和 EM 阈值。可选择不缩放 clock network 相关 instance 的电流。

```
scale_what_if_current -global -scale 10
```

### 创建电流区域

在 routed power grid layer 上指定电流区域，模拟未放置或未做 PGV 的 custom macro 对全局 grid 的影响。动态电流区域需提供 PWL 格式（time, current）及内部/负载电容。

```
create_current_region
```

### 缩放电容

动态分析中缩放电容以观察对 simultaneous switching 引起的动态 IR drop 的影响，可用于估算 decap 优化 effort。支持缩放 loading capacitance 和 power grid capacitance。

### 创建虚拟走线/过孔

在不修改实际版图的前提下创建虚拟走线（what-if wire/via）以修复 voltage drop，支持 early mode 和 signoff mode rail analysis。Signoff 模式下自动在虚拟走线和原设计走线间生成虚拟过孔，可通过 `set_rail_analysis_mode -era_skip_virtual_via_by_type` 跳过自动过孔生成。

### What-If 分析流程

前提条件：
- 设计数据（LEF, netlist, DEF）
- 功率计算后的 power database
- Rail analysis 产生的 state directory

标准步骤：
1. 加载设计数据并完成时间平均 rail analysis
2. 在 Advanced 标签页打开 What-If Analysis Setup 表单
3. 配置所需缩放/虚拟操作（电阻/电流/电容/区域/虚拟形状）
4. 确认设置后重新运行 rail analysis：
   ```
   analyze_rail -output ./staticRailResults/whatif -type domain ALL
   ```
5. 通过 Power & Rail Plots 加载最新 state directory，查看分析结果

---

## Power Gate Analysis

### 概述

随着工艺节点缩小，漏电功耗占比持续上升（130nm 约 10%，65nm 可达 55%）。Power gating 通过 sleep transistor 关断空闲逻辑块以降低漏电。

#### Power Gate 类型

| 类型 | 实现方式 | 优点 | 缺点 |
|------|----------|------|------|
| Coarse-grain | 在逻辑块 power rail 与全局 rail 之间插入 power gate 单元 | 面积小、漏电控制好 | 噪声容限降低、性能难保证、需定制设计 |
| Fine-grain | sleep transistor 集成在标准单元内部 | 性能可保证、每实例精确控制 | 面积大、漏电控制较弱、需专用库 |

两种方式都需要在重新上电时恢复电路状态：coarse-grain 使用外部 input latch cell，fine-grain 使用 SRPG（State Retention Power Gating）cell。

#### Power Gate 分析目标

- **Steady State 分析**：power gate 全部 on 时对 IR drop / EM 的影响，以及全部 off 时的 leakage 节省
- **Power-up 分析（Rush Current）**：power gate 从 off 到 on 的开启时间，以及上电浪涌电流对 always-on grid 的 IR drop 冲击

Voltus 通过两种途径解决上述需求：稳态分析（时间平均/动态功率均可）和 rush current 分析（动态 power-up）。

### Power Gate 库表征

Library generation 过程中，Voltus 表征 power gate 的三个关键参数：
- **Ron**：导通电阻
- **Ileakage**：关断漏电
- **Idsat**：饱和电流

表征输入需求：
- LEF、extraction tech file、layermap
- SPICE netlist（含器件 xy 坐标，用于生成精确 EM view）
- Power gate 的 always-on pin 和 switched pin

若无可用的 SPICE netlist，需手动指定估算参数。

表征步骤（GUI：Power & Rail > Set PowerGrid Library Mode）：
1. Cell Type 设为 Std Cells
2. 指定 SPICE subcircuit netlist
3. 设置 SPICE Model 和 Corners
4. 指定 Extraction Tech File 和 LEF Layermap
5. 设置 Power Pins、Voltages、Ground Pins（always-on 与 switched pin 电压相同）
6. Advanced 标签页勾选 Power Gate Cell Characterization
7. 指定 power gate cell 名称、always-on pin 名、switch pin 名
8. 添加所有 power gate cell 后 OK 进行表征

TCL 示例：
```
set_pg_library_mode -powergate_finegrain_simulation true \
  -powergate_parameters {{block1 vdd vdds1} {block1 vdd vdds2}}
```

库表征完成后可用以下命令生成报告：
```
check_pg_library -output report -report ./pg.cl
```

#### Fine-grain 存储器表征

Fine-grain power gate 中每个单元内部有 switched rail。需设置 `set_pg_library_mode -powergate_finegrain_simulation true`，并通过 `-powergate_parameters` 指定 cell/supply/switched pin 映射。若 switched rail 未标注，需通过 `set_advanced_pg_library_mode -add_port_labels` 手动添加标签。

### Steady State 分析

稳态分析中，Voltus 将 power gate 建模为线性电阻（Ron 值来自库表征）。分析可判断是否放置了足够的 power gate 以满足 switched block 的电流需求，并检测 power gate 是否工作在线性区（非饱和区）——若超出则视为不可靠。

分析完成后生成：
- Power-gate 文本报告（含 ECO 文件供 Innovus 使用）
- 图形式结果：power-gate current I/Idsat (pi)、power-gate voltage (pv)
- `pi.report` 文本文件

#### CPF 使用

CPF（Common Power Format）为低功耗设计提供统一的功耗意图描述。Voltus 用 `read_power_domain -cpf` 加载 CPF，自动关联 timing library、PVT corner、SDC 和各 power domain 状态。

CPF 流程：
- Power analysis：`set_power_analysis_mode -analysis_view view` 自动选取库和 SDC
- Rail analysis：`set_rail_analysis_mode -analysis_view view` 自动推导 domain 定义

无 CPF 时需手动指定 switched net：
- Power analysis：`set_power_analysis_mode -off_pg_nets net_names`
- Rail analysis：`set_rail_analysis_mode -off_rails net_name`
- 同时须用 `set_pg_nets` 和 `set_rail_analysis_domain` 手动定义 power net 电压和 domain

注意：power-gated domain 的 domain 定义中只包含 always-on net 名，switched net 由工具自动追踪。

#### Steady State Power Analysis

分析 power-gated block 关断时的总功耗节省和 leakage。关断 domain 无 switching power，leakage 仅来自 power gate 本身。时间平均/动态功率均可用于稳态分析，流程与常规时间平均/动态功耗分析相同。

```
report_power -leakage
```

#### Steady State Rail Analysis

分析已放置的 power gate 是否满足 switched block 的供电需求。以时间平均或动态电流文件作为输入。

查看结果：
```
report_power_rail_results
```
然后在 GUI 中查看 pi（power-gate current I/Idsat）和 pv（power-gate voltage）图。

### Native Power-up Analysis

传统基于 UltraSim 的 power-up 流程存在仿真时间长、无法考虑 always-on net 寄生效应、需额外 license 等缺点。Voltus 的 Native Power-up 分析将 power gate 建模为 **VCCS（Voltage-Controlled Current Source）**，在工具内部完成 rush current 分析，无需调用 UltraSim。

关键特性：
- Power analysis 阶段计算 power gate enable pin 的 arrival time 和 transition time（需准确的 Liberty 和 SDC）
- Rail analysis 阶段使用 VCCS 模型和 enable pin stimulus 进行 rush current 分析
- 支持两种模式：
  - **Powering-up Nets**：考虑 always-on net 寄生，可同时分析多条 power-up net
  - **Block Power Up Net**：假设 always-on net 理想，一次只分析一条 net
- 多条 powering-up rail 可并行分析（各占一个 CPU）

#### 设置步骤（GUI）

1. 完成 power gate 库表征
2. 设置并运行动态功耗分析
3. Power & Rail > Set Rail Analysis Mode：
   - Analysis Method = Dynamic
   - 指定 Power-grid library
   - 若加载 CPF 则选择 Analysis View
   - 选择 Powering Up Nets（考虑 always-on寄生）或 Block Power Up Net（理想 always-on），两者互斥
   - 可选：EM Analysis Models、Generate Movies（查看时序波形）
   - Advanced 标签页：Boundary Voltage File（层次化设计）、GDS for Flip-chip RDL、decap 参数
4. OK 或 Apply 执行分析

#### 分析输出

分析完成后在每个 power net 的 state 目录 `<net_name>/` 下生成：
- `<powerup_net>_powering_up.report`：文本报告，含 turn-on time、peak rush current、各 power gate 的 firing time
- `dynamic_powerup_<powerup_net>_<always-on_net>.ptiavg`：电流波形文件

查看波形：
- GUI 中 Power & Rail > Report > Dynamic Waveforms > Power Waveforms，加载 `.ptiavg` 文件
- 或在 SimVision 中打开查看 instance 级电流

#### TCL 示例（Powering-up Nets）

```
set_power_analysis_mode -analysis_view VIEW_NAME
set_rail_analysis_mode -powering_up_nets {VDD_SW1 VDD_SW2}
set_rail_analysis_mode -analysis_view VIEW_NAME
analyze_rail -output ./output -type net
```
