---
source: knowledge/Innovus/legacy/json/innovusUG__211 | chapters: [0088, 0093, 0094, 0095, 0103, 0104, 0105, 0106, 0107, 0112, 0113, 0114, 0115]
---

# 时序优化命令

## PreCTS 优化

### 布局前优化

**基本布局和优化：**
```tcl
# Prototyping mode (faster, non-legal placement)
setPlaceMode -place_design_floorplan_mode true
place_design

# Legal placement (converging on floorplan)
setPlaceMode -place_design_floorplan_mode false
place_design

# Rapid timing optimization for prototyping
setDesignMode -flowEffort express
place_opt_design
```

### PreCTS 指南

**place_opt_design 前的健全性检查：**
- 检查 `checkDesign -all` 结果
- 检查 SDC 是否干净
- 检查零线负载下的时序：`timeDesign -prePlace`
- 检查 NDR 是否选择合理
- 检查 don't use 报告
- 激活所有必需的视图

**优化过程中的监控：**
- 每个路径组的 WNS/TNS 收敛情况
- 物理更新（最大/平均实例移动、拥塞）
- DRV 修复收敛情况
- 不同阶段的布线拥塞

### PreCTS 命令序列

```tcl
# Incremental optimization after place_opt_design
place_opt_design -incremental

# Rapid prototyping
setDesignMode -flowEffort express
place_opt_design

# Check timing
timeDesign -preCTS -outDir preCTSOptTiming
```

### PreCTS 调试

**检查关键路径：**
```tcl
# Use Global Timing Debug (GTD) to analyze violations
# Check cell/net delay for bad buffering, sizing, weak cells
# Investigate routing issues
```

**常见问题和解决方案：**

| 问题 | 解决方案 |
|-------|----------|
| 网络未被优化 | `reportIgnoredNets -outfile fileName` |
| 优化后时序差 | 检查日志中的 slack 跳变、布线拥塞、缩放因子 |
| 单元带有 dont_touch | `reportFootPrint -dontTouchNUse -outfile fileName` |
| 相似路径失败 | 创建自定义路径组 |
| 关键路径拥塞 | 使用 `specifyCellPad` 或 `specifyInstPad`、密度屏蔽 |
| 时序难以收敛 | 启用 useful skew（默认）或禁用：`setOptMode -usefulSkew false` |

**关键路径上的时钟门控：**
```tcl
# Over-constrain clock gating cells (use with caution)
set clkgate_target_slack 0.15

group_path -name reg2reg -from all_registers \
  -to [filter_collection [all_registers] "is_integrated_clock_gating_cell != true"]
group_path -name clkgate -from [all_registers] \
  -to [filter_collection [all_registers] "is_integrated_clock_gating_cell == true"]

setPathGroupOptions reg2reg -effortLevel high
setPathGroupOptions clkgate -effortLevel high -targetSlack $clkgate_target_slack
```

**高拥塞设计：**
```tcl
# Set weak cells as dont_use
setDontUse cellName(s)

# Adjust setup target and DRV margins
setOptMode -setupTargetSlack -0.2
setOptMode -setupTargetSlack slack -drcMargin value
```

---

## PostCTS 优化

### PostCTS SDC 约束

**CTS 后更新约束：**
```tcl
# Set clocks to propagated (add to SDC)
set_propagated_clock [all_clocks]

# Adjust clock uncertainty to model only jitter
set_clock_uncertainty <jitter_value> [all_clocks]

# Remove/adjust invalid postCTS constraints
# - clock_uncertainty (setup skew portion)
# - clock_latency
# - Adjust IO latencies if needed

# Update constraint mode
update_constraint_mode -name <mode_name> -sdc_files <postCTS_sdc>
```

**RC 角设置：**
```tcl
# Signal nets use preRoute cap
create_rc_corner -name <corner> -preRoute_cap <value>

# Clock nets use postRoute cap
create_rc_corner -name <corner> -postRoute_clkcap <value>
# or -postRoute_cap if postRoute_clkcap not defined
```

### PostCTS 建立时间优化

```tcl
# Check timing
timeDesign -postCTS -outDir postctsTimingReports

# Optimize (for flows not using full CCOpt)
optDesign -postCTS -outDir postctsOptTimingReports
```

**注意：** 完整的 CCOpt 流程通常不需要额外的 postCTS 建立时间优化。

**调试大的 slack 跳变：**
- 检查端点是否为时钟门控单元（现在使用真实偏斜）
- 使用 GTD 分析路径
- 验证时钟是否已传播
- 检查偏斜是否在规格范围内

---

## 保持时间优化

### PostCTS 保持时间修复

```tcl
# Check hold violations
timeDesign -postCTS -hold -outDir postctsHoldTimingReports

# Fix hold violations
optDesign -postCTS -hold -outDir postctsOptHoldTimingReports
```

### 保持时间优化指南

**关键建议：**
- 确保保持时间不确定性是现实的（过大会导致过多的缓冲器插入）
- 允许延迟单元并避免非常弱的缓冲器（对布线绕道和 SI 敏感）
- 对于多 Vth 设计，在保持时间修复前运行泄漏优化
- 在布局期间添加单元填充，在 postCTS 保持时间修复前移除
- 确保建立/保持约束同步（特别是多周期路径）
- 确保良好的时钟偏斜用于保持时间（与建立时间同样重要）

**对于有许多保持时间违例的设计：**
```tcl
# Run hold fixing at postCTS with negative target slack
# Focus on large violations, fix remaining after routing
setOptMode -holdTargetSlack -0.2
optDesign -postCTS -hold

# Print detailed violation reasons
optDesign -hold -holdVioData fileName
```

### 保持时间优化控制

```tcl
# Allow/prevent setup TNS degradation
setOptMode -fixHoldAllowSetupTnsDegrade true | false

# Exclude path groups from hold fixing
setOptMode -ignorePathGroupsForHold {groupA groupB...}

# Control overlap during hold fixing
# auto (default): allow overlaps postCTS, not postRoute
# true: allow overlaps postRoute as well
setOptMode -fixHoldAllowOverlap true

# Control hold margins
# Beyond certain margin, buffer addition increases exponentially

# Try useful skew for RAM and register files
```

---

## PostRoute 优化

### 布线命令序列

```tcl
# Basic routing (timing-driven and SI-driven enabled automatically)
routeDesign

# PostRoute wire spreading (reduces SI impact)
# Enabled by default with: setDesignMode -flowEffort extreme
# Or run separately:
setNanoRouteMode -routeWithTimingDriven false
setNanoRouteMode -droutePostRouteSpreadWire true
routeDesign -wireOpt
setNanoRouteMode -droutePostRouteSpreadWire false

# Double cut via effort
setNanoRouteMode -drouteUseMultiCutViaEffort {low | medium | high}
```

### PostRoute 提取

```tcl
# Set extraction engine
setExtractRCMode -engine postRoute

# Set effort level
setExtractRCMode -effortLevel low | medium | high | signoff
```

**努力级别：**
- `low`: 原生详细提取（与 -engine postRoute 相同）
- `medium`: TQuantus（不需要 Quantus 许可证，支持分布式处理）
- `high`: IQuantus（需要 Quantus 许可证，精度更高，支持分布式处理）
- `signoff`: 独立 Quantus（最高精度，需要 Quantus 许可证）

### PostRoute 时序检查

```tcl
# Check non-SI timing
setDelayCalMode -SIAware false
timeDesign -postRoute -outDir postrouteTimingReports
timeDesign -postRoute -hold -outDir postrouteTimingReports
```

**如果布线后时序跳变：**
- 检查 RC 缩放因子与 signoff 提取器的相关性
- 使用 Ostrich 生成相关因子
- 比较 postCTS 和 postRoute 之间的布线拓扑
- 检查相同路径上负载的大差异

### PostRoute 优化命令

```tcl
# Setup optimization
optDesign -postRoute

# Hold optimization
optDesign -postRoute -hold

# Combined setup and hold (reduces runtime)
optDesign -postRoute -setup -hold
```

### PostRoute 调试和收敛

**对于多 VT 设计（LEF-Safe 优化）：**
```tcl
# Cell swapping only (helps in congested designs)
setOptMode -allowOnlyCellSwapping true
optDesign -postRoute

# Run after normal optDesign -postRoute to close final paths
# Or run before to speed up closure
# Only works for multi-VT libraries
```

**提取相关性：**
```tcl
# For IQuantus, use exact signoff values
setExtractRCMode -capFilterMode relAndCoup
```

**SI 收敛建议：**
- 在 preRoute 中添加悲观性（增加时钟不确定性）
- 对于深度很大的路径（>40），仅在这些路径中的网络上添加悲观性
- 检查全局最大转换时间
- 在详细布线期间启用线展开

**对于深度非常大的时序路径（>40）：**
- 长路径上小的 SI 推出总和导致大的时序惩罚
- 解决方案：仅在大深度路径的网络上添加悲观性

---

## 信号完整性优化

### SI 数据准备

```tcl
# Enable OCV mode with CPPR
setAnalysisMode -analysisType onChipVariation -cppr both

# Enable SI CPPR (default)
set_global timing_enable_si_cppr true

# Enable SI-driven routing (automatic with routeDesign)
setNanoRouteMode -routeWithTimingDriven true
setNanoRouteMode -routeWithSiDriven true
```

**SI 收敛技术：**
- 在平面规划期间和详细布线后关注布线拥塞
- 在 preRoute 阶段运行 `congRepair` 以消除局部热点
- 修复转换时间违例（optDesign -postRoute 自动执行）
- 慢转换引入更大的延迟惩罚，更容易受到 SI 干扰源的影响

---

## 使用第三方 SPEF 的 Signoff ECO

### 使用外部 SPEF 优化

```tcl
# Import SPEF for each RC corner
spefIn rc_corner1.spef -rc_corner rc_corner1
spefIn rc_corner2.spef -rc_corner rc_corner2

# Optimize using SPEF
optDesign -postRoute -outDir spefFlowTimingReports

# With hold fixing
optDesign -postRoute -hold -outDir spefFlowTimingReports
```

**重要：** 确保 Innovus 和第三方工具之间的相关性：
- 在 Innovus 中正确设置 RC 缩放因子
- 一致地应用 SDC 约束
- 延迟计算和时序分析结果相关

---

## 建立/保持时间优化参数

### setOptMode 关键选项

| 选项 | 描述 | 用法 |
|--------|-------------|-------|
| `-setupTargetSlack` | 建立时间优化的目标 slack | `setOptMode -setupTargetSlack -0.2` |
| `-holdTargetSlack` | 保持时间优化的目标 slack | `setOptMode -holdTargetSlack -0.2` |
| `-drcMargin` | DRV 修复的裕量 | `setOptMode -drcMargin value` |
| `-usefulSkew` | 启用/禁用 useful skew | `setOptMode -usefulSkew true\|false` |
| `-fixHoldAllowSetupTnsDegrade` | 保持时间修复期间允许建立时间 TNS 退化 | `setOptMode -fixHoldAllowSetupTnsDegrade false` |
| `-fixHoldAllowOverlap` | 保持时间修复期间允许重叠 | `setOptMode -fixHoldAllowOverlap true` |
| `-ignorePathGroupsForHold` | 从保持时间修复中排除路径组 | `setOptMode -ignorePathGroupsForHold {list}` |
| `-allowOnlyCellSwapping` | LEF-safe 优化（仅单元交换） | `setOptMode -allowOnlyCellSwapping true` |

### 路径组优化

```tcl
# Create custom path groups
group_path -name <group_name> -from <startpoints> -to <endpoints>

# Set path group options
setPathGroupOptions <group_name> -effortLevel high
setPathGroupOptions <group_name> -targetSlack <value>
```

---

## 功耗优化

### 泄漏优化

```tcl
# Run before hold fixing for multi-Vth designs
optDesign -postCTS
# or
optPower
```

**注意：** 泄漏减少可改善保持时间。

---

## 快速参考：optDesign 阶段

| 阶段 | 命令 | 目的 |
|-------|---------|---------|
| PreCTS | `place_opt_design` | 布局和 preCTS 优化 |
| PreCTS 增量 | `place_opt_design -incremental` | 增量 preCTS 优化 |
| PostCTS 建立时间 | `optDesign -postCTS` | PostCTS 建立时间优化 |
| PostCTS 保持时间 | `optDesign -postCTS -hold` | PostCTS 保持时间修复 |
| PostRoute 建立时间 | `optDesign -postRoute` | PostRoute 建立时间优化 |
| PostRoute 保持时间 | `optDesign -postRoute -hold` | PostRoute 保持时间修复 |
| PostRoute 组合 | `optDesign -postRoute -setup -hold` | 组合建立/保持时间优化 |

---

## 时序分析命令

| 阶段 | 建立时间检查 | 保持时间检查 |
|-------|-------------|------------|
| PrePlace | `timeDesign -prePlace` | N/A |
| PreCTS | `timeDesign -preCTS -outDir <dir>` | N/A |
| PostCTS | `timeDesign -postCTS -outDir <dir>` | `timeDesign -postCTS -hold -outDir <dir>` |
| PostRoute | `timeDesign -postRoute -outDir <dir>` | `timeDesign -postRoute -hold -outDir <dir>` |
