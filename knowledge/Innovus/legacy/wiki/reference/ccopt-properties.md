---
source: knowledge/Innovus/legacy/jsonl/innovusUG__211.jsonl | entries: [0470, 0471, 0472, 0473, 0474, 0475, 0476, 1320]
---

# CCOpt 属性系统

## 概述

CCOpt（Clock Concurrent Optimization）的配置通过属性系统和时钟树规范相结合完成。属性系统提供了灵活的全局、时钟树级、网络类型级和对象级的配置方式。

### 属性操作命令

**设置属性：**
```tcl
set_ccopt_property [-object_type <object>] <property_name> <property_value>
```

**获取属性：**
```tcl
get_ccopt_property [-<object_type> <object>] <property_name>
```

**查看属性帮助：**
```tcl
get_ccopt_property -help <property_name>
get_ccopt_property -help *  # 列出所有可用属性
```

### 属性适用范围

- **全局属性** — 无需指定对象类型
- **时钟树属性** — 使用 `-clock_tree <name>` 指定
- **网络类型属性** — 使用 `-net_type <name>` 指定（leaf/trunk/top）
- **引脚属性** — 使用 `-pin <name>` 指定
- **偏斜组属性** — 使用 `-skew_group <name>` 指定
- **延迟角属性** — 使用 `-delay_corner <name>` 指定

---

## 库单元配置

### buffer_cells / inverter_cells / clock_gating_cells

**功能：** 指定 CTS 使用的缓冲、反相器和时钟门控单元

**设置语法：**
```tcl
set_ccopt_property buffer_cells {bufA bufB bufC}
set_ccopt_property inverter_cells {invA invB invC}
set_ccopt_property clock_gating_cells {PREICGX12 PREICGX8 PREICGX6}
```

**按时钟树配置：**
```tcl
set_ccopt_property buffer_cells {bufX bufY} -clock_tree clk
```

**按时钟树和电源域配置：**
```tcl
set_ccopt_property buffer_cells {bufX bufY} -clock_tree clk -power_domain pd
```

**默认值：** {} （自动选择）

**建议：**
- 始终显式配置缓冲、反相器和时钟门控单元
- 使用低阈值（LVT）单元以降低插入延迟
- 在许多工艺中，反相器比缓冲具有更低的插入延迟和功耗
- 限制每种单元类型不超过 5 个，以减少运行时间
- 避免使用过小的单元（如 X3 及以下），因为跨角落缩放特性差
- 在多电源域设计中，包含 always-on 缓冲和反相器

### logic_cells

**功能：** 指定 CTS 可用的逻辑单元

**说明：** 如果未指定逻辑单元，CTS 将使用任何具有相同逻辑功能且未标记为 dont_use 的库单元来调整现有逻辑单元实例

**默认值：** {} （自动选择）

### use_inverters

**功能：** 指定 CTS 优先使用反相器而非缓冲

**设置语法：**
```tcl
set_ccopt_property use_inverters true
```

**默认值：** false

---

## 转换时间目标

### target_max_trans

**功能：** 指定 CCOpt 的最大转换时间目标

**设置语法：**
```tcl
set_ccopt_property target_max_trans 100ps
set_ccopt_property target_max_trans 100  # 库单位
```

**按网络类型配置：**
```tcl
set_ccopt_property -net_type trunk target_max_trans 150ps
set_ccopt_property -net_type leaf target_max_trans 100ps
```

**按电源域配置：**
```tcl
set_ccopt_property target_max_trans 100ps -power_domain pd
```

**按延迟角配置：**
```tcl
set_ccopt_property target_max_trans 100ps -delay_corner corner_name
```

**默认值：** 自动生成

**说明：**
- 转换时间目标可按网络类型、时钟树和电源域指定
- 叶网络（leaf）通常需要更紧的转换目标以改善触发器 CK->Q 弧时序
- 干线网络（trunk）可放松转换目标以减少时钟面积和功耗
- 如果未指定目标，CCOpt 将检查 SDC 约束中的 target_max_trans_sdc 属性
- 建议显式设置转换目标，除非有意使用 SDC 约束中的设置

**电源域处理：**
- CTS 处理电源上下文（位置电源域 + 有效电源域的组合）
- 转换目标应用于有效电源域
- 当多个电源上下文共享同一有效域时，使用所有相关电源上下文中的最大目标

---

## 偏斜目标配置

### target_skew

**功能：** 设置全局偏斜目标

**设置语法：**
```tcl
set_ccopt_property target_skew 50ps
```

**按偏斜组配置：**
```tcl
set_ccopt_property -skew_group ck200m/func target_skew 0.1ns
```

**按延迟角配置：**
```tcl
set_ccopt_property -skew_group ck200m/func target_skew 0.1ns -delay_corner corner_name
```

**默认值：** 自动生成

**说明：**
- 全局偏斜目标应用于主 CTS 延迟角
- 可按偏斜组和延迟角分别设置偏斜目标
- 自动生成的偏斜目标可能不是最优的
- 极限工作量（extreme-effort）CTS 将忽略偏斜目标，除非偏斜组已显式配置为限制 useful skew

---

## 网络类型和布线配置

### 网络类型定义

**叶网络（Leaf Nets）**
- 连接到一个或多个时钟树汇点的网络
- 默认情况下，CCOpt 会插入缓冲以确保没有缓冲同时驱动汇点和内部节点

**干线网络（Trunk Nets）**
- 不是叶网络的任何网络
- 默认情况下为干线网络

**顶网络（Top Nets）**
- 当配置 `routing_top_min_fanout` 属性时，具有高于配置阈值的瞬态扇出汇点计数的干线网络
- 例如，如果设置为 10,000，则任何在 10,000 个或更多汇点上方的干线网络将成为顶网络

### routing_top_min_fanout

**功能：** 配置顶网络的汇点计数阈值

**设置语法：**
```tcl
set_ccopt_property -clock_tree clk500m routing_top_min_fanout 10000
```

**默认值：** 未设置（所有干线网络）

**说明：** 每个时钟树汇点默认计数为 1

### routing_top_fanout_count

**功能：** 为宏时钟输入引脚配置自定义汇点计数

**设置语法：**
```tcl
set_ccopt_property -pin mem0/clkin routing_top_fanout_count 1000
```

**说明：** 用于表示内部状态元素数量的宏时钟输入引脚

### route_type

**功能：** 为网络类型指定布线类型

**设置语法：**
```tcl
set_ccopt_property -net_type trunk route_type trunk_type
set_ccopt_property -net_type leaf route_type leaf_type
```

**布线类型创建示例：**
```tcl
create_route_type -name trunk_type \
  -non_default_rule CTS_2W2S \
  -top_preferred_layer M7 \
  -bottom_preferred_layer M6 \
  -shield_net VSS
```

**布线规则建议：**

**干线网络：**
- 使用双宽双间距和屏蔽
- 优先选择中层到高层（受电源网格模式限制）
- 双宽用于降低电阻并允许使用条形通孔
- 双间距用于减少屏蔽的电容影响
- 屏蔽对避免干扰影响时钟干线网络至关重要

**叶网络：**
- 使用双宽，优先选择中层
- 双宽用于降低电阻
- 额外间距是可取的，但可能消耗过多布线资源

**通用建议：**
- 每种网络类型（叶、干线、顶）使用单一层对（一水平一竖直）
- 相同的间距、宽度和间距可提高布线估计的相关性

---

## 时钟树规范

### create_ccopt_clock_tree_spec

**功能：** 生成时钟树规范

**设置语法：**
```tcl
create_ccopt_clock_tree_spec
create_ccopt_clock_tree_spec -file ccopt.spec
source ccopt.spec
```

**说明：**
- 分析所有活跃的建立和保持分析视图的时序图
- 生成的规范文件记录约束设置的原因
- 不指定 `-file` 参数时，不存储约束设置的原因信息
- 规范包含 clock_tree、skew_group 和属性设置

---

## 配置检查

### ccopt_design -check_prerequisites

**功能：** 执行设置、库和设计验证检查，不运行 CTS

**设置语法：**
```tcl
ccopt_design -check_prerequisites
```

**检查内容：**
- 设计配置问题
- 时钟树配置问题
- 库配置问题

**常见问题示例：**
- 源到汇网络长度过小
- 一个或多个时钟树具有配置问题
- 过多时钟树实例被锁定
- 最大转换时间目标过低
- 选定的驱动器过弱

---

## Useful Skew 工作量控制

### setOptMode -usefulSkewCCOpt

**功能：** 指定 ccopt_design 或 optDesign -postCTS 命令中应用的 useful skew 工作量级别

**设置语法：**
```tcl
setOptMode -usefulSkewCCOpt none
setOptMode -usefulSkewCCOpt standard
setOptMode -usefulSkewCCOpt extreme
```

**工作量级别：**

| 级别 | 说明 |
|------|------|
| none | 不允许 useful skew |
| standard | 允许在 post-CTS 优化期间对时钟树网络进行本地修改（默认值，当 setDesignMode -flowEffort 为 standard 时） |
| extreme | 启用时钟树和数据路径的并发优化以改善建立时间，除了标准工作量修改外（仅在 ccopt_design 中可用，当 setDesignMode -flowEffort 为 extreme 时为默认值） |

**注意：**
- 极限工作量（extreme）仅在 ccopt_design 命令中可用
- 极限工作量将显著增加总体运行时间
- 在调用极限工作量前，确保已获得良好的理想模式时序结果
- 建议在调用极限工作量前部署早期时钟流

---

## 常见配置示例

### 基础配置

```tcl
# 指定库单元
set_ccopt_property buffer_cells {BUFX4 BUFX2}
set_ccopt_property inverter_cells {INVX4 INVX2}
set_ccopt_property clock_gating_cells {PREICGX12 PREICGX8 PREICGX6}

# 优先使用反相器
set_ccopt_property use_inverters true

# 设置转换时间目标
set_ccopt_property target_max_trans 100ps

# 设置偏斜目标（仅用于 CCOpt-CTS）
set_ccopt_property target_skew 50ps

# 创建时钟树规范
create_ccopt_clock_tree_spec

# 运行 CCOpt
ccopt_design
```

### 按网络类型配置

```tcl
# 干线网络：放松转换目标以减少面积和功耗
set_ccopt_property -net_type trunk target_max_trans 150ps

# 叶网络：紧转换目标以改善时序
set_ccopt_property -net_type leaf target_max_trans 100ps

# 配置布线类型
set_ccopt_property -net_type trunk route_type trunk_type
set_ccopt_property -net_type leaf route_type leaf_type
```

### 多时钟树配置

```tcl
# 为特定时钟树配置缓冲单元
set_ccopt_property buffer_cells {bufX bufY} -clock_tree clk500m

# 为特定时钟树设置偏斜目标
set_ccopt_property -clock_tree clk500m -skew_group ck500m/func target_skew 0.1ns

# 配置顶网络阈值
set_ccopt_property -clock_tree clk500m routing_top_min_fanout 10000
```

### 多电源域配置

```tcl
# 为特定电源域配置缓冲单元
set_ccopt_property buffer_cells {bufX bufY} -clock_tree clk -power_domain pd

# 为特定电源域设置转换目标
set_ccopt_property target_max_trans 100ps -power_domain pd

# 包含 always-on 缓冲和反相器
set_ccopt_property buffer_cells {bufX bufY bufAON}
set_ccopt_property inverter_cells {invX invY invAON}
```

---

## 最佳实践

### 库单元选择

1. **始终显式配置** — 不要依赖自动选择，显式指定缓冲、反相器和时钟门控单元
2. **使用 LVT 单元** — 低阈值单元具有更低的插入延迟，减少 OCV 时序降级的影响
3. **技术相关选择** — 在某些工艺中反相器更优，在其他工艺中缓冲更优
4. **避免极端单元** — 不要使用过大的单元（电磁迁移问题）或过小的单元（跨角落缩放差）
5. **限制单元数量** — 每种单元类型不超过 5 个以减少运行时间
6. **库单元预筛选** — Innovus 16.2+ 版本在 CTS 开始时预筛选库单元列表，仅使用驱动强度和面积特性最佳的单元

### 转换时间目标

1. **分层配置** — 叶网络使用紧目标（100ps），干线网络使用放松目标（150ps）
2. **屏蔽和间距** — 干线网络使用屏蔽和额外间距以进一步降低时钟功耗
3. **显式设置** — 建议显式设置转换目标，除非有意使用 SDC 约束
4. **电源域感知** — 在多电源域设计中，转换目标应用于有效电源域

### 布线规则

1. **干线网络** — 双宽双间距 + 屏蔽 + 中高层
2. **叶网络** — 双宽 + 中层 + 可选额外间距
3. **层对一致性** — 每种网络类型使用单一层对，相同的间距和宽度
4. **信号完整性** — 屏蔽对避免干扰影响至关重要

### 时钟树规范

1. **多模式约束** — 使用多模式 SDC 约束以获得完整的时钟树网络
2. **规范文件** — 将规范写入文件以便检查和调试
3. **早期验证** — 在早期设计阶段使用 create_ccopt_clock_tree_spec 进行可行性检查

### Useful Skew 优化

1. **标准工作量** — 默认设置，适合大多数设计
2. **极限工作量** — 仅在理想模式时序良好且需要额外优化时使用
3. **早期时钟流** — 在调用极限工作量前部署早期时钟流
4. **运行时权衡** — 极限工作量显著增加运行时间

---

## 属性查询和调试

### 查看所有属性

```tcl
get_ccopt_property -help *
```

### 查看特定属性帮助

```tcl
get_ccopt_property -help buffer_cells
get_ccopt_property -help target_max_trans
```

### 获取当前属性值

```tcl
get_ccopt_property cell_density
get_ccopt_property buffer_cells
get_ccopt_property -clock_tree clk500m buffer_cells
```

### 配置检查

```tcl
ccopt_design -check_prerequisites
```

---

## 相关命令

| 命令 | 功能 |
|------|------|
| set_ccopt_property | 设置 CCOpt 属性 |
| get_ccopt_property | 获取 CCOpt 属性值 |
| create_ccopt_clock_tree_spec | 生成时钟树规范 |
| ccopt_design | 运行完整 CCOpt |
| ccopt_design -cts | 运行独立 CTS |
| report_ccopt_clock_trees | 报告时钟树统计 |
| report_ccopt_skew_groups | 报告偏斜组信息 |
| ctd_win | 打开时钟树调试器 |
| create_route_type | 创建布线类型 |
| add_ndr | 添加非默认布线规则 |
