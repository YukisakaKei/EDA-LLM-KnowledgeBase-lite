---
source: knowledge/Voltus/legacy/json/voltusUG__211 | chapters: [0272, 0273, 0274, 0275, 0276, 0277, 0278, 0279, 0280, 0281, 0282, 0283]
---

# IR-aware ECO 技术

## 概述

先进工艺节点下 power grid 电阻增大，加上高频工作导致功耗上升，IR drop 问题日益严重：

- **IR drop > 5%-10% 有效供电电压**：可能引起 timing 问题
- **IR drop > 20%-30% 有效供电电压**：可能导致功能失效

传统修复手段各有局限：
- 向热点区域添加 power pad（受封装设计限制）
- 在 aggressor 附近加 decap cell（先进节点下串联电阻增大，效果降低）
- 加 power strap（需要足够的绕线资源）

本文介绍两种基于 ECO 的 IR drop 修复技术：**IR Drop Aware Placement**（通过移动 aggressor instance 分散热点电流）和 **Timing-aware IR Drop Fixing**（通过 Tempus ECO 调整单元尺寸）。

---

## IR Drop Aware Placement

### 数据需求

| 阶段 | 所需数据 |
|------|----------|
| 加载设计 | Post-CTS 或 post-routed Innovus 数据库、Timing Libraries、Verilog、SDC、LEF + DEF |
| Rail Analysis | DEF、Power-grid Views、Dynamic Power Files、Power Pad Location Files、Power Domain 及其 Power Nets |
| Placement | Hotspot Debugger 报告（Rail Analysis 后生成） |

### 核心流程

三步基本流程：

1. **加载设计**：`restoreDesign`
2. **设置功耗和 Rail 分析环境**：
   ```
   set_power_output_dir <dir>
   set_power_analysis_mode ...
   set_default_switching_activity ...
   set_dynamic_power_simulation ...
   set_rail_analysis_mode ...
   set_pg_nets ...
   set_rail_analysis_domain ...
   set_power_pads ...
   ```
3. **执行 IR aware placement**：
   ```
   setPlaceMode ...
   refinePlace ...
   ecoRoute
   ```

`refinePlace` 命令集成了功耗分析、Rail 分析和热点识别功能，无需单独调用 `report_power`、`analyze_rail` 和 `debug_irdrop`。

### Hotspot Debugger

`debug_irdrop` 命令将设计划分为多个区域，识别各区域中的高电流 aggressor instances。关键参数：

- **`-nregion`**（默认 3）：设计划分的区域数。值越大，热点区域越集中，修复效率越高
- **`-nworst_instances`**（默认 10）：每个区域报告的 worst instance 数量。值越大，移动的 instance 越多

热点区域报告位于 `VoltusDebugIRdropResults/report.rpt`，包含各 region 的 IR drop 根因分析、layer-based 和 net-based IR drop 值。

### IR Aware Placement

在 Innovus 中执行，将高 IR drop instance 从热点区域移开。垂直移动效率高于水平移动。

关键命令：
```
setPlaceMode -place_detail_irdrop_aware_effort {none | low | medium | high}
```

- **none**：关闭（默认）
- **low**：将 aggressor 移到邻近 row，legalization 时与其他 instance 优先级相同
- **medium**：移到邻近 row，legalization 时 aggressor 优先级更高
- **high**：移到邻近 row，legalization 时规则更严格

**Post-routed 数据库**需先设 `setPlaceMode -place_detail_preserve_routing true` 再执行 `refinePlace`。

`refinePlace` 执行后在当前目录生成 4 个目录：
- `VoltusPowerAnalysisResults`
- `VoltusRailAnalysisResults`
- `VoltusDebugIRdropResults`
- `work`

### 迭代与重检查

- 多次运行 `refinePlace` 进行迭代
- 最终迭代后必须运行 `analyze_rail` 做最终 Rail 分析
- 建议在所有 `refinePlace` 迭代完成后再执行 `ecoRoute`（每轮都做会增加 turnaround time）
- 每轮迭代后建议 `saveDesign <name>.enc`

### 调试

在 GUI 中查看热点区域后，可用命令绘制矩形标示：
```
add_gui_shape -rect {x1 y1 x2 y2} -layer <layer> -width <value>
```

---

## Timing-aware IR Drop Fixing

利用 **Tempus ECO** 工具，在保持 timing 的前提下通过调整逻辑单元尺寸（sizing）来修复 IR drop 违规。Tempus ECO 基于 sign-off STA 数据（GBA/PBA），配合 Voltus Rail Analysis 提供的 IR drop 热点反馈，自动生成 ECO 变更。

### 流程步骤

1. **执行 STA**
2. **设置功耗和 Rail 分析环境**（命令同 IR Drop Aware Placement 部分）
3. **执行功耗和 Rail 分析**：
   ```
   report_power
   analyze_rail
   ```
4. **运行 Hotspot Debugger**：
   ```
   debug_irdrop
   ```
5. **执行 Tempus ECO 分析**：
   ```
   set_eco_opt_mode ...
   eco_opt_design
   ```
   ECO 流程输出 `eco_innovus.tcl` 文件。

6. **Post-ECO Rail 分析重检查**：
   - 在 Innovus 中 source `eco_innovus.tcl`，然后在 Innovus 内运行 Rail 分析
   - 或从 Innovus 导出 DEF，在 Voltus 中运行 Rail 分析

### Tempus ECO 关键命令参数

| 命令 | 参数 | 说明 |
|------|------|------|
| `set_eco_opt_mode` | `-fix_ir_drop {true\|false}` | 启用/关闭 IR drop 修复 |
| `set_eco_opt_mode` | `-max_slack <> -max_paths <> -nworst <>` | 结合 `-retime` 参数使用 |
| `set_eco_opt_mode` | `-load_irdrop_db <dir>` | 指定 `debug_irdrop` 的输出目录路径 |
| `set_eco_opt_mode` | `-allow_multiple_incremental {true\|false}` | 允许多种 incremental 优化模式 |
| `eco_opt_design` | `-drv` | 触发 ECO 执行 |

### 结果分析

分析 Tempus ECO 前后的改善效果，可通过以下方式：

1. **ivdd map**：GUI 中 `Power & Rail > Power & Rail Plots`，选择 Rail 类型和 ivdd plot 查看电压降分布图
2. **log 文件违规数**：检查 `debug_irdrop` 运行后 log 中的违规数量变化
3. **timing 报告**：确认 timing 未被 degrade
4. **eco.ird 文件**：位于 `<debug_irdrop_output_dir>/eco.ird`，对比 ECO 前后各 instance 的 IR drop 数值

重检查时必须使用与第一轮相同的 activity file 和 switching scenario。
