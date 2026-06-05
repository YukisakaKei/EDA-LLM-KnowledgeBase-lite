---
source: knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl | entries: [0202, 0203, 0204, 0205, 0206, 0207, 0208, 0209, 0210, 0211, 0212, 0213, 0214, 0215, 0216, 0217, 0218, 0219, 0220, 0221]
---

# 封装分析 (Package Analysis)

## 概述

Voltus 支持将封装效应纳入片上 IR drop 分析，以准确模拟从早期设计到 signoff 阶段的 PDN 行为。提供两类封装模型：

- **Simple Lumped RLC Pin 模型**：适用于 block 级别或早期设计阶段的快速评估
- **Fully Distributed Coupled RLCK SPICE 模型**：适用于全芯片 signoff，可由 Sigrity XtractIM 等工具生成

**Voltus-Sigrity Package Analysis (SPA)** 是 Voltus 内嵌 Sigrity 的芯片-封装协同仿真流程，可实现：
- 封装模型提取（调用 XtractIM）
- 含封装模型的片上时间平均/动态 rail 分析
- IC 感知的封装 IR drop 分析（调用 PowerDC）
- 芯片-封装结果协同显示与 cross probing

SPA 许可要求：Voltus-L/XL + Voltus-AA + Voltus-SPA，需安装 Sigrity 2015 QIR3 或更高版本。

---

## 含封装模型的 Rail 分析

### 分析行为差异

- **静态分析**：仅考虑电阻成分，电容视为开路，电感视为短路
- **动态分析**：考虑 R、L、C 全部效应，0V 电压源视为短路，1MOhm 以上电阻忽略

### Simple Lumped RLC Pin Package 模型

通过 TCL 命令设置默认封装参数，适用于所有 power pad：

```tcl
set_package -R <value> -L <value> -C <value>
```

也可在 power pad 位置文件（`.pp` 文件）中为每个 pad 单独指定 RLC 值，通过 `set_power_pads` 命令加载。GUI 中在 Power & Rail - Set Rail Analysis Mode 表单中设置默认值，在 Run Rail Analysis 表单 Advanced 标签页中指定 pad 位置文件。

### Fully Distributed RLCK SPICE Package 模型

指定 SPICE 封装子电路：

```tcl
set_package -spice <model_file> [-mapping <file>] \
    [-offset {x y}] [-rotate <angle>] [-flip {true|false}]
```

- 若模型由 Sigrity XtractIM 提取且包含 die placement 信息（BBOX/Flip/Rotation），则 -mapping/-offset/-rotate/-flip 均可不指定
- 否则需通过 MCP Editor 生成 mapping 文件，或使用上述参数手动指定连接方式

SPICE 封装模型文件（XtractIM 生成）包含：
- Subcircuit node definition
- Sigrity Model Connection Protocol (MCP) header
- RLCKEFGH 元素
- 受控源支持：VCVS、CCCS、VCCS、CCVS

### RDL0 / Off-Chip Package Tracing

用于分析 switched net bump 上的 off-chip package trace 电阻效应。有两种模式：

- **Run without package**：单独创建 RDL0 subcircuit 挂接至 power grid
- **Run with package**：RDL0 subcircuit 内嵌在 package netlist 中

启用命令：

```tcl
set_offchip_package_trace \
    -ploc_file_list <file> \
    -trace_model_names <names> \
    -mapping <file> \
    -rdl0_subckt <spice_file>
```

输出：自动生成 switched net bump 电流/电压波形，位于 `voltus_rail_pad.tran.ptiavg`。

### Package to Die Mapping

Voltus 通过以下方式实现封装到芯片的自动映射：

1. **带 die placement 信息的封装模型**：通过 MCP 头部的 `[BBOX]`、`[Flip]`、`[Rotation]` 关键字描述 die 在封装上的摆放，Voltus 自动确定 die shrink factor 并创建映射
2. **MCP Editor 工具**：当封装模型不含 BBOX 信息时，通过 GUI 或 TCL 命令启动

```tcl
map_die_package -die_mcp_header <file> -package_model <file> \
    -output <dir>
```

MCP Auto Connection 提供多种匹配方式：Auto match、Pin name match、Ckt node name match、Net name match、Coord match。

支持的 mapping 文件格式：MCP (Model Connection Protocol) 和 Voltus-specific 格式。

---

## Voltus-Sigrity Package Analysis (SPA) 流程

### 1. 配置与封装提取

```tcl
set_advanced_package_options \
    -sigrity_tool_path <path_to_xtractim_powerdc_bin> \
    -net_mapping_file <file>
```

```tcl
extract_package \
    -workspace <name.ximx> \
    -domain <name> \
    -die_name <name> \
    -bga_name <name> \
    -output_dir <dir> \
    -ref_net <gnd_net>
```

XtractIM 在后台以 batch 模式运行，输出 SPICE 模型文件，命名格式：`<workspace>_<spd_filename>_Final_PinBaseSPICE.ckt`。

### 2. 含封装模型的 Rail 分析

SPA 流程中 rail analysis 自动选用 `extract_package` 生成的封装模型，无需再通过 `set_package` 指定。

处理未连接 pin 的行为通过以下参数控制：

```tcl
set_rail_analysis_mode -unconnected_die_pkg_pins ignore|error|edit
```

- `ignore`：忽略未连接 pin，继续仿真
- `error`：报错停止
- `edit`：暂停仿真，弹出 MCP Editor GUI 手动连接

Rail Analysis 输出文件：
- `*ploc.ckt`：dummy die model（含 die pins 和 MCP header）
- `*.map`：两列 mapping 文件（die pin -> package pin）
- `*_iv.rpt`：die pin 电流-电压文件，供 PowerDC 用作 die 模型

### 3. 封装 IR Drop 分析

```tcl
analyze_package \
    -workspace <name.pdcx> \
    -domain <name> \
    -die_name <name> \
    -bga_name <name> \
    -output_dir <dir> \
    -result_name <file.xml> \
    -pin_current_file <file>
```

调用 PowerDC 执行封装 IR drop 分析，结果以 2D/3D E-Distribution 形式显示在 PowerDC GUI 中。

### 4. 查看结果

```tcl
view_package_results -workspace <name.pdcx> -result_name <file.xml>
```

### 5. Cross Probing（Voltus <-> PowerDC）

- **Zoom 同步**：一方缩放时另一方自动跟随
- **Bump 同步**：选中 bump 时另一方对应 bump 高亮
- **Net 同步**：使能/禁用 net 时自动同步至对方

### 6. 从 Voltus 访问 Sigrity 工具

通过 `Package -> Sigrity` 菜单可独立启动：
- MCP Editor
- XtractIM
- PowerDC

### 7. 示例脚本框架

```tcl
# Static Rail Analysis Setup
set_pg_nets ...
set_rail_analysis_domain ...
set_rail_analysis_mode ...
set_power_pads ...

# Package Extraction
set_advanced_package_options -sigrity_tool_path ... -net_mapping_file ...
extract_package -workspace ... -domain ... -die_name ... -bga_name ...

# Rail Analysis
set_rail_analysis ... -include_package true

# Package Analysis
analyze_package -workspace ... -result_name ...
view_package_results -workspace ... -result_name ...
```

---

## Die-Model 生成

### 背景

封装走线的电阻导致芯片级电压损失，电感导致动态功耗波动，在低功耗设计中影响显著。Die-model 生成使能：
- 芯片-封装谐振分析
- 封装去耦电容估算
- SiP (System-in-Package) 设计与分析

### Die-Model 类型

- 时间平均 rail 分析后：n-port reduced **R** 模型 + 时间平均电流 profile
- 动态 rail 分析后：n-port reduced **RC** 模型 + 动态开关电流 profile

### 生成流程

1. 执行动态 IR drop 分析，生成 state directory
2. 使用 `create_die_model` 命令增量生成 die-model，无需重新分析 IR drop

```tcl
# 基本用法
create_die_model -output <dir> -domain <name>

# TSV/SiP 设计（多 die）
create_die_model -output <dir> -domain <domain:die>
```

`create_die_model` 是增量命令，新会话中只要有动态 IR drop 分析结果的 state directory 即可使用。需重新定义 `set_pg_nets` 和 `set_rail_analysis_domain`。可通过 `set_multi_cpu_usage -localCpu` 启用多 CPU。

### Time Domain 分析

- 完整 package + 全芯片 transient 仿真代价高且限于少数时钟周期
- 使用 package + die-model 可仿真更长时间，捕捉封装电感效应（L di/dt）
- `-repeat <time_in_ns>` 选项可重复芯片动态电流 profile，延长仿真周期
- 仿真设置保存在输出目录的 `.sp` 文件中，可导入 SPICE 仿真
- 可通过对比 SPICE 仿真中 power pad 电流与 Voltus transient 的 VC_SUM 信号来验证 die-model 精度

### Frequency Domain 分析

片上电容和封装电感在谐振频率处形成高导纳通路，导致电源振荡（通常超过 +/-5-10% 阈值）：

$$F_0 = \frac{1}{2\pi\sqrt{LC}}$$

目标阻抗需在 1Hz-10GHz 宽频范围内满足：

$$Z_{target} = \frac{10\% \times V_{DD}}{I_{peak}}$$

谐振分析可通过 Sigrity SpeedSim 或独立 Spectre 完成。die-model 输出目录包含频域仿真设置文件（`.sp`），也可单独将 die-model（`domain_without_package.sp`）导入 Sigrity 产品进行分析。

### Die-Model 特性

- 支持 n-port die-model 生成
- 支持 TSV/SiP 多 die 设计
- 消除长时间全芯片动态仿真迭代
- 封装设计师可根据 die 上下文优化封装以达到目标阻抗
- 电路设计师可根据封装上下文优化 die（on-chip decap、动态瞬态电流）
- 同时生成 die + package 联合 SPICE 模型用于谐振分析和精度验证
