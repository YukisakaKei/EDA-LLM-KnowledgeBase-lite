---
source: knowledge/Innovus/legacy/jsonl/innovusUG__211.jsonl | entries: [0089, 0091, 0093, 0428, 0429, 0433, 0434, 0436, 0437, 0450, 0451, 0452]
---

# Innovus 布局命令快速参考

## 布局流程概览

```
Floorplan → place_opt_design → Well-Tap → End-Cap → Spare Cells → Filler
```

## 1. 布局规划与布局准备

### 布局前检查

```tcl
# 检查设计完整性
checkDesign -all

# 检查零线载时序
timeDesign -prePlace

# 检查布局违规
checkPlace
# 或
checkDesign -place
```

### 布局阻塞

```tcl
# 创建布局阻塞
createPlaceBlockage -box {x1 y1 x2 y2} -type <hard|soft|partial>

# 阻塞类型：
# - hard: 完全不能用于布局
# - soft: 布局期间不能使用，但可在优化/CTS/ECO 期间使用
# - partial: 设置可用区域百分比（例如，允许 75% 密度）
```

### 可布线性指南

确保可布线性的关键考虑因素：
- 选择合适的布局规划风格（periphery、island、doughnut）
- 保持宏单元深度为 1-2 以获得最佳 CTS 和优化结果
- 在预放置模块之间留出足够空间
- 谨慎使用模块引导来控制布局密度
- 重新排序扫描链以消除虚假拥塞热点

## 2. 布局命令

### place_opt_design（推荐流程）

```tcl
# 标准布局与优化
place_opt_design

# 初始布局后的增量优化
place_opt_design -incremental

# 快速原型设计的 Express 模式
setDesignMode -flowEffort express
place_opt_design
```

`place_opt_design` 替代了旧的 `place_design + optDesign -preCTS` 流程。

### GigaPlace 特性

- 时序裕量驱动的全局布局
- 拥塞驱动算法
- 交错的 preCTS 优化
- 自动缓冲树移除和重建
- 在整个流程中保持线长和拥塞

### 布局模式设置

```tcl
# 高拥塞努力度
setPlaceMode -place_global_cong_effort high

# 将预布线网络视为障碍物
setPlaceMode -place_detail_preroute_as_obs true
```

### 拥塞修复

```tcl
# 独立拥塞修复（谨慎使用）
congRepair
```

注意：`congRepair` 使用 globalRoute + 增量布局，可能会显著影响时序。

## 3. 布局分析

### 拥塞分析

- 查看日志文件中的溢出值（通常应 <1%）
- 打开拥塞图以分析热点
- 使用部分布局阻塞来降低拥塞区域的密度
- 在布局前读取时钟布线约束（NDR、间距、屏蔽）

### 路径组优化

```tcl
# 创建路径组
group_path -name <path_group_name> -from <from_list> -to <to_list> -through <through_list>

# 设置路径组选项
setPathGroupOptions -name <path_group_name> -effort <high|low> -slackAdjustment <value> -priority <value>

# 运行布局
place_opt_design
```

注意：
- 如果未定义路径组，`place_opt_design` 会创建临时高努力度组（reg2reg、reg2cgate）
- 高努力度路径组会获得更高的优化关注
- 过多的路径组可能影响运行时间和 TNS 收敛

## 4. Well-Tap 单元插入

### 时机

在布局规划固定且硬模块已放置之后，但在放置标准单元之前添加 well-tap。

### 命令

```tcl
# 添加 well-tap 单元
addWellTap -cell <cell_name> -cellInterval <distance> -prefix <prefix>

# 控制 well-tap 之间的距离
addWellTap -cellInterval <distance>
# -cellInterval: 同一行中 well-tap 单元中心到中心的距离
# 默认最小距离：指定最大值的 45%

# MSV 设计：指定电源域
addWellTap -powerDomain <domain_name> -cell <cell_name> -cellInterval <distance>

# 删除 well-tap 单元
deleteFiller -cell <well_tap_cell>
deleteFiller -area {x1 y1 x2 y2}
```

### Well-Tap 特性

- 仅物理填充单元
- 某些工艺需要用于限制电源/地与衬底阱之间的电阻
- 以预放置状态放置（不会被后续布局命令移动）
- 可以在站点行中交错放置

## 5. End-Cap 单元插入

### 时机

在放置任何标准单元之前，但在硬模块放置之后添加 end-cap 单元。

### 命令

```tcl
# 在插入前配置 end-cap 模式
setEndCapMode -leftEdge <cell_list> -rightEdge <cell_list>
setEndCapMode -leftBottomCorner <cell> -rightBottomCorner <cell>
setEndCapMode -leftTopCorner <cell> -rightTopCorner <cell>

# 添加 end-cap 单元
addEndCap -prefix <prefix>

# MSV 设计：指定电源域
addEndCap -powerDomain <domain_name>

# 删除 end-cap 单元
deleteFiller -cell <endcap_cell>
```

### setEndCapMode 选项

用于在核心区域、布局阻塞和硬宏周围形成封闭的 end-cap 环：

**边缘选项：**
- `-leftEdgeEven` / `-leftEdgeOdd`
- `-rightEdgeEven` / `-rightEdgeOdd`
- `-topEdgeEven` / `-topEdgeOdd`
- `-bottomEdgeEven` / `-bottomEdgeOdd`

**角落选项：**
- `-leftBottomCornerEven` / `-leftBottomCornerOdd`
- `-leftTopCornerEven` / `-leftTopCornerOdd`
- `-rightBottomCornerEven` / `-rightBottomCornerOdd`
- `-rightTopCornerEven` / `-rightTopCornerOdd`

### End-Cap 类型

**单高度单元：**
- 左/右边界的 A 类型和 B 类型
- 奇数站点数：AB 或 BA end cap
- 偶数站点数：AA 或 BB end cap

**双高度单元：**
- 在核心或阻塞的内角处需要
- 电源轨类型：VSS-VDD-VSS、VDD-VSS-VDD
- 4 种类型：A(VSS-VDD-VSS)、A(VDD-VSS-VDD)、B(VSS-VDD-VSS)、B(VDD-VSS-VDD)
- 必须在 LEF 中预定义

### End-Cap 特性

- 设计规则所需的仅物理单元
- 放置在站点行的末端
- 在某些工艺中用于电源分配
- 支持在核心区域、阻塞和宏周围形成封闭环
- 以预放置状态放置

## 6. 备用单元放置

### 目的

备用单元为硅后 ECO 提供灵活性，无需更改金属层。

### 命令

```tcl
# 放置备用单元（不在网表中）
placeSpareCell -cell <cell_list> -count <number> -prefix <prefix>

# 放置已在网表中的备用单元
# （具有未连接引脚或绑定输入的单元）
# 这些在 place_opt_design 期间自动放置
```

### 备用单元管理

- 备用单元可以均匀分布在整个设计中
- 可以指定备用单元放置的区域
- 网表中的备用单元在布局期间被视为常规单元
- 对未来的设计更改有用，无需完全重新实现

## 7. 填充单元插入

### 时机

在布线完成后添加填充单元。

### 命令

```tcl
# 添加填充单元
addFiller -cell <filler_cell_list> -prefix <prefix>

# 指定填充插入区域
addFiller -cell <filler_cell_list> -area {x1 y1 x2 y2}

# MSV 设计：指定电源域
addFiller -powerDomain <domain_name> -cell <filler_cell_list>
# 如果未指定 -powerDomain，addFiller 会尝试向所有电源域添加填充

# 删除填充单元
deleteFiller -cell <filler_cell>
deleteFiller -prefix <prefix>
deleteFiller -area {x1 y1 x2 y2}
```

### 填充单元特性

- 填充标准单元之间的间隙
- 确保 N 阱和 P 阱的连续性
- 提供电源/地的连续性
- 通常在布线后添加
- 使用多种填充单元尺寸（从最大到最小）

### 多线程支持

`place_opt_design` 和 `addFiller` 支持多线程，可在多处理器机器上加速。

## 8. PreCTS 优化指南

### place_opt_design 前的完整性检查

- 查看 `checkDesign -all` 结果
- 检查 SDC 是否干净
- 检查零线载时序是否满足（`timeDesign -prePlace`）
- 检查 NDR 是否选择得当（过多的 NDR 会减慢优化速度）
- 检查 don't use 报告
- 激活所有必需的视图
- 针对特定场景调整设置（高性能、高拥塞、高利用率）

### 优化期间的监控

- 跟踪每个活动路径组的 WNS/TNS 收敛情况
- 检查物理更新（最大/平均实例移动、布线拥塞）
- 检查 DRV 修复收敛情况
- 监控不同阶段的布线拥塞

### PreCTS 命令序列

```tcl
# 标准流程
place_opt_design

# 增量优化
place_opt_design -incremental

# 用于原型设计的 Express 模式
setDesignMode -flowEffort express
place_opt_design

# 控制优化行为
setOptMode -<options>
```

## 9. 布局验证

```tcl
# 检查布局质量
checkPlace

# 分析拥塞
# - 查看日志中的溢出值
# - 检查拥塞图中的热点
# - 验证全局拥塞 <1%

# 时序分析
timeDesign -preCTS
```

## 常见布局问题及解决方案

| 问题 | 解决方案 |
|-------|----------|
| 高拥塞 | 使用 `setPlaceMode -place_global_cong_effort high`，添加部分阻塞 |
| 时序违规 | 使用路径组，调整裕量，运行 `place_opt_design -incremental` |
| 宏放置问题 | 检查连接性，调整 halo，使用模块引导 |
| 扫描链拥塞 | 在布局前重新排序扫描链 |
| 时钟布线拥塞 | 在布局前读取 CTS 规范和 NDR |

## 相关命令

- `refinePlace` - 合法化布局
- `ecoPlace` - ECO 布局
- `timeDesign` - 时序分析
- `reportCongestion` - 拥塞报告
- `setOptMode` - 控制优化行为
- `setDesignMode` - 控制设计流程设置
