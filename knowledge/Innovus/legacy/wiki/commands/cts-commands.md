---
source: knowledge/Innovus/legacy/jsonl/innovusUG__211.jsonl | entries: [0098, 0099, 0100, 0101, 0102, 0103, 0104, 0105]
---

# 时钟树综合 (CTS) 命令

## CTS 流程概览

### 完整 CTS 命令序列

```tcl
# 1. 配置 CCOpt
create_route_type -name <route_type_name> ...
set_ccopt_property route_type <route_type_name>
set_ccopt_property target_max_trans <value>
set_ccopt_property target_skew <value>
set_ccopt_property buffer_cells <cell_list>
set_ccopt_property inverter_cells <cell_list>
set_ccopt_property clock_gating_cells <cell_list>
set_ccopt_property use_inverters <true|false>

# 2. 创建时钟树规格
create_ccopt_clock_tree_spec

# 3. 运行 CCOpt
ccopt_design -cts          # CCOpt-CTS (仅全局偏斜平衡)
# 或
ccopt_design               # 完整 CCOpt (CTS + 并发优化)

# 4. 报告时序和时钟树
timeDesign -postCTS -outDir postctsTimingReports
report_ccopt_clock_trees -file clock_trees.rpt
report_ccopt_skew_groups -file skew_groups.rpt

# 5. PostCTS 优化 (如需要)
optDesign -postCTS -outDir postctsOptTimingReports

# 6. 保持时间优化
timeDesign -postCTS -hold -outDir postctsHoldTimingReports
optDesign -postCTS -hold -outDir postctsOptHoldTimingReports
```

---

## CCOpt 配置命令

### 布线类型配置

```tcl
# 创建非默认布线规则 (NDRs)
create_route_type -name <route_type_name> \
  -top_preferred_layer <layer> \
  -bottom_preferred_layer <layer> \
  -shield_net <net_name> \
  -non_default_rule <ndr_name>

# 将布线类型分配给 CCOpt
set_ccopt_property route_type <route_type_name>
```

### 目标规格

```tcl
# 设置最大转换时间
set_ccopt_property target_max_trans <value>

# 设置目标偏斜 (仅 CCOpt-CTS)
set_ccopt_property target_skew <value>
```

### 单元选择

```tcl
# 指定用于 CTS 的缓冲单元
set_ccopt_property buffer_cells {buf1 buf2 buf3}

# 指定反相器单元
set_ccopt_property inverter_cells {inv1 inv2 inv3}

# 指定时钟门控单元
set_ccopt_property clock_gating_cells {icg1 icg2}

# 启用/禁用反相器使用
set_ccopt_property use_inverters true
```

### 时钟树规格

```tcl
# 从时序约束创建时钟树规格
create_ccopt_clock_tree_spec

# 规格会自动从活动的时序约束生成
```

---

## 运行 CCOpt

### CCOpt-CTS (全局偏斜平衡)

```tcl
ccopt_design -cts
```

**自动操作：**
- 使用 NanoRoute 详细布线时钟网络
- 将时序时钟切换到传播模式
- 更新源延迟以确保正确的 I/O 和时钟间时序

### 完整 CCOpt (CTS + 并发优化)

```tcl
ccopt_design
```

**自动操作：**
- 执行带并发优化的 CTS
- 详细布线时钟网络
- 更新时序模式和延迟

**注意：** 在 `ccopt_design` 之后无需使用 `update_io_latency`。

---

## 报告命令

### 时序报告

```tcl
# PostCTS 时序分析
timeDesign -postCTS -outDir postctsTimingReports

# 带前缀
timeDesign -postCTS -prefix postcts -outDir reports

# 保持时间时序
timeDesign -postCTS -hold -outDir postctsHoldTimingReports
```

### 时钟树报告

```tcl
# 报告时钟树
report_ccopt_clock_trees -file clock_trees.rpt

# 报告偏斜组
report_ccopt_skew_groups -file skew_groups.rpt
```

---

## 时钟树可视化

### CCOpt 时钟树调试器 (CTD)

**GUI 访问：**
- Clock 菜单 → CCOpt Clock Tree Debugger

**功能：**
- 图形化时钟树表示
- 插入延迟比例可视化
- 路径高亮
- 与布局视图交叉探测

---

## PostCTS 优化

### SDC 约束更新

```tcl
# 将时钟设置为传播模式
set_propagated_clock [all_clocks]

# 调整时钟不确定性 (仅抖动)
set_clock_uncertainty <jitter_value> [get_clocks <clock_name>]

# 调整 I/O 时序的源延迟
set_clock_latency -source <value> [get_clocks <clock_name>]

# 更新约束模式
update_constraint_mode -name <mode_name> \
  -sdc_files <postcts_sdc_file>
```

### RC 角更新

```tcl
# 信号网络使用布线前电容
create_rc_corner -name <corner> -preRoute_cap <factor>

# 时钟网络使用布线后电容
create_rc_corner -name <corner> \
  -postRoute_clkcap <factor> \
  -postRoute_cap <factor>

# 更新现有角
update_rc_corner -name <corner> -postRoute_clkcap <factor>
```

### PostCTS 建立时间优化

```tcl
# 检查时序
timeDesign -postCTS -outDir postctsTimingReports

# 优化建立时间时序
optDesign -postCTS -outDir postctsOptTimingReports
```

**注意：** 对于完整 CCOpt 流程，通常不需要额外的 postCTS 建立时间优化。

**Useful Skew：** PostCTS 优化默认使用 useful skew (Innovus 16.1+)。

---

## 保持时间优化

### 基本保持时间修复

```tcl
# 报告保持时间违例
timeDesign -postCTS -hold -outDir postctsHoldTimingReports

# 修复保持时间违例
optDesign -postCTS -hold -outDir postctsOptHoldTimingReports
```

### 保持时间优化选项

```tcl
# 设置保持时间目标裕量 (负值以关注大违例)
setOptMode -holdTargetSlack -0.2

# 在保持时间修复期间允许建立时间 TNS 退化
setOptMode -fixHoldAllowSetupTnsDegrade true

# 从保持时间修复中排除路径组
setOptMode -ignorePathGroupsForHold {groupA groupB}

# 在保持时间修复期间允许重叠
setOptMode -fixHoldAllowOverlap true    # 默认: auto

# 生成详细的保持时间违例报告
optDesign -hold -holdVioData hold_violations.rpt
```

### 保持时间修复建议

1. **时序不确定性：** 确保保持时间不确定性是现实的（过大会导致过多的缓冲器插入）

2. **延迟单元：** 允许延迟单元并避免弱缓冲器（对布线绕道和 SI 敏感）

3. **多 Vth 设计：** 在保持时间修复之前运行漏电优化：
   ```tcl
   optDesign -postCTS -leakageToDynamicRatio <ratio>
   # 或
   optPower
   ```

4. **单元填充：** 在布局期间添加填充，在 postCTS 保持时间修复之前移除

5. **约束同步：** 确保建立时间和保持时间约束一致（特别是多周期路径）

6. **时钟偏斜：** 良好的保持时间偏斜与建立时间偏斜同样重要

7. **分阶段方法：** 对于有许多保持时间违例的设计：
   - 在 postCTS 修复大违例（使用负目标裕量）
   - 在 postRoute 修复剩余违例

### 保持时间违例分析

`innovus.logv` 文件包含详细的保持时间修复报告，分类说明为什么网络未被缓冲：

```
======================================================================
剩余保持时间违例的原因
======================================================================
*info: 总共 1 个网络有保持时间时序裕量违例。
*info: 1 个网络：无法修复，因为违例端点的网络被标记为 IPO 忽略。
```

---

## PostCTS 时序调试

### 时序比较

如果 postCTS 时序与 preCTS 显著不同：

1. **检查时钟门控单元：** 真实偏斜可能导致 ICG 端点的裕量跳变

2. **验证偏斜达成：** CTS 是否能够满足偏斜约束？

3. **检查时钟不确定性：** 不确定性是否已调整为仅建模抖动？

4. **使用全局时序调试 (GTD)：** 分析关键路径

5. **验证传播时钟：** 确保时钟处于传播模式

### 时序分析命令

```tcl
# 检查时序是否与 preCTS 相似
timeDesign -postCTS -outDir postctsTimingReports

# 与 preCTS 结果比较
# 如果发生大的裕量跳变，调查：
# - 时钟门控单元端点
# - 偏斜规格
# - 时钟不确定性设置
```

---

## 关键注意事项

1. **CCOpt vs CCOpt-CTS：**
   - CCOpt-CTS：仅全局偏斜平衡（`-cts` 标志）
   - 完整 CCOpt：CTS + 并发优化（无标志）

2. **自动延迟更新：** CCOpt 自动更新源延迟；不要手动运行 `update_io_latency`

3. **PostCTS 约束：** 在运行 CCOpt 之前加载 postCTS SDC（推荐流程）

4. **保持时间修复时机：** 
   - PostCTS：更容易修复，推荐用于许多违例
   - PostRoute：用于布线后的剩余违例

5. **有用偏斜：** 在 postCTS 优化中默认启用（Innovus 16.1+）
