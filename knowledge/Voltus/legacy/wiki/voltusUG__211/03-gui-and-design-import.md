---
source: knowledge/Voltus/legacy/json/voltusUG__211 | chapters: [0030, 0031, 0032, 0033, 0034, 0035, 0036, 0037, 0038, 0039, 0040, 0041, 0042, 0043, 0044, 0045, 0046, 0047, 0048, 0049, 0050]
source: knowledge/Voltus/legacy/json/voltusUG__211 | chapters: [0070, 0071, 0072, 0073]
source: knowledge/Voltus/legacy/json/voltusUG__211 | chapters: [0137]
---

# GUI 与设计导入（Voltus）

## 1. 适用范围与定位

本篇聚焦两类高频操作：

- **GUI 使用**：主窗口、菜单体系、常用入口与命令映射
- **设计导入**：Innovus/第三方/OA/层次化设计/HDB/CPF 的核心流程

目标是帮助物理设计与电源完整性工程师快速建立一套“可复用导入模板”。

---

## 2. GUI 总览

## 2.1 主窗口结构

主窗口主要由以下部分组成：

- **Menu Bar**：按流程组织命令
- **Tabs 区域**：承载 Layout、Setup、Schematics 等工作视图
- **Toolbar Widgets**：快捷操作入口

默认打开 **Layout** 视图；可通过 `+` 增加其他标签页。

常见可打开标签页：

- Layout
- Setup
- Schematics
- Design Browser
- Layout Viewer
- Violation Browser

## 2.2 菜单启用规则

- 菜单项会随流程阶段动态灰显/激活
- 仅激活项可执行
- 部分菜单支持热键触发（菜单文字下划线对应快捷键）

> `ECO`、`Clock`、`Timing & SI` 菜单依赖 Tempus 许可。

---

## 3. 菜单到命令的关键映射

> 只保留工程上常用、与 PI 分析链路关联度高的映射。

## 3.1 File 菜单（导入与约束入口）

| GUI 菜单项 | 常用 Tcl 命令 | 典型用途 |
|---|---|---|
| Read Design | `read_design` | 读取设计数据库 |
| Save Design | `save_design` | 保存会话数据库 |
| Read SDC | `read_sdc` | 导入时序约束 |
| Read SPEF | `read_spef` | 导入寄生参数 |
| Load/Commit CPF | `read_power_domain` | 导入功耗域定义 |
| Check Design | `check_design` | 设计完整性检查 |

## 3.2 Power & Rail 菜单（PI 主流程入口）

| GUI 菜单项 | 常用 Tcl 命令 | 典型用途 |
|---|---|---|
| Set PG Library Mode | `set_pg_library_mode` | PG library 生成模式 |
| Generate PowerGrid Library | `generate_pg_library` | 生成 PG library |
| Set Power Analysis Mode | `set_power_analysis_mode` | 配置功耗分析 |
| Run Power Analysis | `report_power` 等 | 功耗计算与报告 |
| Set Rail Analysis Mode | `set_rail_analysis_mode` | 配置 rail analysis |
| Run Rail Analysis | `analyze_rail` | 执行 IR/rail 分析 |
| Run Resistance Analysis | `analyze_resistance` | 电阻网络分析 |

## 3.3 Verify / Package / Flows 菜单

- **Verify**
  - `verify_connectivity`：连通性检查
  - `verify_power_via`：电源过孔检查
- **Package**
  - `set_advanced_package_options`
  - `extract_package`
  - `analyze_package`
  - `view_package_results`
  - `map_die_package`
- **Flows**
  - `write_flow_template`：生成流程模板

`View`、`Tools`、`Windows`、`Help` 主要用于界面操作与辅助导航。

---

## 4. 设计导入：统一思路

Voltus 导入可归纳为三层：

1. **逻辑/物理基础数据**：LEF、Verilog、DEF、SPEF、SDC、Lib
2. **电源语义**：CPF 或手工 power-domain/net 电压定义
3. **分析上下文**：模式、角点、活动率、封装与输出目录

建议先做“最小可运行导入”，再逐步叠加复杂设置。

---

## 5. 导入 Innovus 数据库

## 5.1 必要输入

- 设计数据：LEF / netlist / DEF
- CPF（推荐）
- SPEF

## 5.2 基本流程

1. 读入设计数据库
2. 导入 CPF（或手工定义电源电压）
3. 导入 SPEF（按 RC corner）

示例（紧凑模板）：

```tcl
# 方式A：直接读取保存数据库
read_design -physical_data <enc_dat> <top_module>

# 方式B：分步读取
read_lib -lef <tech_lef> <cell_lef_list>
read_verilog <netlist>
set_top_module <top_module> -ignore_undefined_cell
read_def <def_file>

# 电源域（CPF优先）
read_power_domain -cpf <cpf_file>

# 无CPF时可手工设定电源/地电压
set_dc_sources <pwr_net> -power  -voltage <vdd> -force
set_dc_sources <gnd_net> -ground

# 寄生
read_spef -rc_corner <corner> -decoupled <spef_file>
```

---

## 6. 导入第三方设计（非 Innovus 原生库）

## 6.1 GUI 路径

在 `Setup` 标签页填写或加载 Tcl setup 后执行 `Apply`。

## 6.2 Tcl 模板

```tcl
read_lib -lef <tech_lef> <allcells_lef>
read_lib -min <min_lib_list>
read_lib -max <max_lib_list>
read_verilog <design_v>
set_top_module <top>
read_sdc <design_sdc>
read_def <design_def>
read_spef <design_spef>
read_power_domain -cpf <design_cpf>
```

性能建议：

```tcl
read_def -skip_signal <design_def>
```

用于导入阶段跳过 signal net，降低内存与时延，后续可按需补读。

---

## 7. OpenAccess (OA) 数据库操作

## 7.1 OA 导入

GUI 核心信息：`Library / Cell / View`，并启用 `Read Physical Data`。

```tcl
read_design -cellview "<lib> <cell> <view>" -physical_data
```

若直接复用 OA 参考库中的 LEF：

```tcl
read_lib -oaRef <library_name>
```

## 7.2 OA 保存与恢复

```tcl
save_design -cellview {<lib> <cell> <view>}
restore_oa_design <lib> <cell> <view> -physical_data
```

注意：若最初依赖 LEF 而非 OA reference library，Verilog 设计不能直接按 OA 方式保存。

---

## 8. 大规模层次化设计导入（重点）

## 8.1 Hierarchy Flattener 场景

适用于多层 DEF/SPEF 的大设计，将层次结构展平到内存数据库用于分析。

关键原则：

- 多 DEF 导入建议 `-skip_signal`
- `read_lib -lef` 仅放 primitive 单元 LEF（stdcell/IO/memory）
- 不要混入 block partition 的 LEF 定义

示例：

```tcl
read_lib -lef <tech_lef> <primitive_lef_list>
read_lib -min <min_lib_list>
read_lib -max <max_lib_list>
read_verilog <top_v> <block_v_list>
set_top_module <top>
read_sdc <top_sdc>
read_def -skip_signal <top_def> <block_def_list>
read_spef <top_spef> <block_spef_list>
```

## 8.2 保存与恢复（Voltus/Innovus 闭环）

```tcl
save_design -rc <save_tag>

# 新会话恢复
read_design -physical_data <save_tag>.dat <top_cell>
```

`save_design` 会保存 power constraints 状态，便于跨会话保持一致分析语义。

## 8.3 不创建物理数据库直接分析（超大设计常用）

当组件规模很大时，可不构建完整物理 DB，直接把 DEF 输入分析引擎：

```tcl
specify_def <top_def> <block_def_list>
specify_spef <top_spef> <block_spef_list>
```

分析后若要在版图上下文调试，再补读：

```tcl
read_def -skip_signal <top_def> <block_def_list>
```

## 8.4 不加载设计直接做动态分析

该模式面向超大规模设计，减少前端处理开销；通常需要外部 TWF。

动态功耗示意：

```tcl
read_lib -min <min_lib_list>
read_lib -max <max_lib_list>
read_twf <twf_file>
specify_def <def_file>
specify_spef <spef_file>
set_power_analysis_mode -method dynamic_vectorless
report_power
```

后续 rail analysis 由功耗结果驱动：

```tcl
set_rail_analysis_mode -method <static_or_dynamic>
set_power_data -format <format>
analyze_rail -type domain <domain>
```

已知限制（该模式下）：

- `set_power` / `set_switching_activity` 不支持 `get*` 对象列表
- `report_power -view` 不支持
- `set_power_analysis_mode -analysis_view` 不支持
- `write_tcf`、`dump_unannotated_nets` 不支持
- `set_rail_analysis_mode -analysis_view` 不支持

---

## 9. RC 寄生读取策略

功耗计算可选三类 RC 数据接入方式：

1. `read_spef`
   - SPEF 必须在 DEF 之后读取
   - 若耦合电容导致内存压力，建议 `-decoupled`
2. `write_rcdb` + `read_rcdb`
   - 二进制 RCDB，通常性能更优
3. 按 RC corner 读取

```tcl
set_analysis_view -setup <view> -hold <view>
read_spef -rc_corner <corner> <spef_file>
```

---

## 10. Hierarchical Database (HDB) 工作流

HDB 让 GUI 同时支持：

- 顶层 flatten 视角
- 实例级层次视角（push-down / pull-up）

## 10.1 创建与保存

```tcl
read_lib -lef <tech_lef> <allcells_lef>
init_hier_design -defs <hier_def_list> -skip_signal
save_hier_design <hdb_name>
```

## 10.2 恢复与结果联动

```tcl
read_hier_design <hdb_name> <top>
read_power_rail_results -rail_directory <rail_dir> \
    -instance_voltage_window {timing whole} \
    -instance_voltage_method {avg worst}
start_gui
```

在 GUI 中可针对单实例设置不同层次显示深度，适合局部热点追踪。

---

## 11. CPF 导入与无 CPF 备选

## 11.1 CPF 标准导入

```tcl
read_power_domain -cpf <design.cpf>
```

CPF 用于提供 power domain 语义与约束，建议作为主路径。

## 11.2 无 CPF 时的等效定义

```tcl
set_pg_nets ...
set_rail_analysis_domain ...
set_cell_power_domain ...
```

若无 CPF，需显式定义 net/domain/cell-domain 与 operating voltage，避免后续 rail analysis 语义不完整。

---

## 12. 推荐导入脚本骨架（可直接复用）

```tcl
# 1) 基础数据
read_lib -lef <tech_lef> <primitive_lef_list>
read_lib -min <min_lib_list>
read_lib -max <max_lib_list>
read_verilog <netlist_list>
set_top_module <top>
read_sdc <sdc_file>

# 2) 物理与寄生
read_def -skip_signal <def_list>
read_spef -rc_corner <corner> -decoupled <spef_list>

# 3) 电源语义
read_power_domain -cpf <cpf_file>
# 或 set_dc_sources / set_pg_nets / set_cell_power_domain

# 4) 分析准备
set_power_analysis_mode ...
set_rail_analysis_mode ...

# 5) 执行
report_power
analyze_rail -type domain <domain>

# 6) 保存现场
save_design -rc <save_tag>
```

---

## 13. 实战要点（Checklist）

- 优先先跑通“最小链路”：`read_* -> report_power -> analyze_rail`
- 大设计优先使用 `-skip_signal` 与 `specify_def` 模式
- CPF 缺失时必须补全 domain/net/voltage 定义
- SPEF 顺序要正确（通常在 DEF 后）
- 需要跨会话复现时，及时 `save_design`
- 要做层次化可视化调试时，优先构建 HDB

以上流程可覆盖大多数 Voltus GUI + 设计导入场景，并能平滑衔接后续 power/rail/EM 分析。

---

## 14. 分析结果持久化与恢复：跑完存档，后续直接取数据

`analyze_rail` 跑一次耗时很长（大设计可能数小时甚至数天），正常使用模式是：**跑一次 → 结果持久化到磁盘 → 后续会话直接加载结果查看/出报告，不再重跑分析**。

Voltus 提供三层持久化机制：

| 层级 | 命令 | 持久化内容 | 适用场景 |
|------|------|-----------|---------|
| 设计级 | `save_design` / `read_design` | 物理 DB + RC + power constraints | 跨会话恢复完整设计状态 |
| HDB 级 | `save_hier_design` / `read_hier_design` | 层次化 DB 快照 | 大设计的层次化 GUI 调试（见第 10 节） |
| 结果级 | `analyze_rail -output <dir>` + `read_power_rail_results` | rail/power/EM 分析结果 | **仅加载结果，不加载完整设计**（推荐） |

### 14.1 save_design / restore

跑完分析后保存完整现场，后续直接恢复：

```tcl
# 会话 1：跑分析 + 存档
# ... 导入设计 + power/rail 分析（参考第 12 节骨架） ...
save_design -rc <save_tag>

# 会话 2：恢复现场
read_design -physical_data <save_tag>.dat <top_cell>
# 设计、RC、power constraints 均已恢复，可直接 GUI 操作或出增量报告
```

> `save_design -rc` 会自动生成 `<topcell>_power_constraints.tcl`，restore 时自动 source，确保 power 语义一致。

### 14.2 XP 模式：State Directory 机制

XP 模式下 `analyze_rail -output <dir>` 生成的 state directory 是**自包含的持久化结果目录**，包含所有报告、GIF、日志、电气数据。

```
<output_dir>/
├── latest -> core_25C_dynamic_1       # 符号链接指向最新 state
├── core_25C_dynamic_1/
│   ├── gui/                           # GUI JSON 数据
│   ├── pgdb/                          # 电气数据（节点/元件/实例/电压源）
│   ├── reports/
│   │   ├── em/                        # EM 报告
│   │   └── rail/<net>/                # 各 net 的 GIF + rail 报告
│   ├── logs/                          # 各步骤日志
│   └── results/                       # 各步骤结果文件
```

### 14.3 read_power_rail_results：核心取数据入口

最常用的"取数据"方式。**不需要 `read_design` 恢复完整物理数据库**，只要设计几何信息已加载，直接指到 state directory 即可。

**关键区分 — 两种互斥路径：**

| 参数 | 指向 | 适用 |
|------|------|------|
| `-rail_directory` | XP/分布式 state directory | 加载 power + rail + EM 全部结果（推荐） |
| `-power_db` | 独立 power 数据库文件 | 非 XP 模式的静态功耗结果，**不与 `-rail_directory` 混用** |

```tcl
# 轻量加载设计 + 读结果（不读 SPEF，不跑分析！）
read_lib -lef <tech_lef> <primitive_lef_list>
read_verilog <netlist>
set_top_module <top>
read_def -skip_signal <def_list>

# XP 模式：-rail_directory 指向 state directory
read_power_rail_results \
  -rail_directory dynamic_rail/core_25C_dynamic_1 \
  -instance_voltage_window {timing whole} \
  -instance_voltage_method {avg worst}

# 非 XP 模式：-power_db 加载独立 power 数据库
read_power_rail_results -power_db staticPowerResults/staticPower.db
```

### 14.4 XP 断点续跑

XP 的 Sub-Flow Data Isolation 天然支持断点续跑：

| 参数 | 作用 |
|------|------|
| `-xp_resume` | 从上次失败的步骤续跑 |
| `-xp_reuse_extraction_directory` | 复用已有 extraction 结果 |
| `-xp_reuse_power_directory` | 复用已有功耗计算结果 |
| `-xp_purge` | 清除 XP 输出目录 |

```tcl
# 续跑示例：复用已完成步骤
set_rail_analysis_mode ... -enable_xp true \
  -xp_reuse_extraction_directory <dir> -xp_reuse_power_directory <dir> -xp_resume
analyze_rail -type domain -output dynamic_rail core
```

### 14.5 完整工作流（跑→存→取）

```tcl
# === 会话 1：跑分析 + 输出到 state directory ===
# ... 导入设计（参考第 12 节骨架） ...
set_power_analysis_mode -method dynamic_vectorless ...
report_power
set_rail_analysis_mode -method dynamic ... -enable_xp true
analyze_rail -type domain -output dynamic_rail core
save_design -rc <save_tag>    # 可选：保存完整设计现场

# === 会话 2（数天后）：取结果，不重跑 ===
# 方式A：只看结果 → 轻量加载 + read_power_rail_results
read_lib -lef $lefs; read_verilog <netlist>; set_top_module <top>
specify_def <def>             # 甚至不需要完整 read_def
read_power_rail_results -rail_directory dynamic_rail/core_25C_dynamic_1
report_power_rail_results -region {0 0 100 100}

# 方式B：需要 layout 交互 → 恢复完整设计
read_design -physical_data <save_tag>.dat <top>
read_power_rail_results -rail_directory dynamic_rail/core_25C_dynamic_1
start_gui
```

### 14.6 关键要点

- **XP 模式下 `analyze_rail -output` 的输出目录就是持久化结果**，不需额外 "save results"
- `read_power_rail_results` 是取数据主入口：XP 用 `-rail_directory`，非 XP 用 `-power_db`，**两者不混用**
- 只出报告/看 GUI 时：**不需要 `read_spef`、不需要重跑 `report_power`**，设计几何 + `read_power_rail_results` 即可
- 需要跨会话保持完整设计状态（含 RC、constraints）才用 `save_design -rc`