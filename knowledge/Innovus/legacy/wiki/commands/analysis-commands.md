---
source: knowledge/Innovus/legacy/jsonl/innovusUG__211.jsonl | entries: [0086, 0111, 0175, 0628, 1030, 1133, 1137, 1142, 1143]
---

# 分析命令

## 时序分析

### 基本时序分析

**timeDesign 命令：**
```tcl
# 在各个阶段运行时序分析
timeDesign -prePlace
timeDesign -preCTS
timeDesign -postCTS
timeDesign -postRoute

# 输出时序报告到指定目录
timeDesign -postRoute -outDir postRouteTimingReports
```

**使用 Global Timing Debug (GTD)：**
- GTD 提供图形界面和表单来查看时序问题
- 推荐使用 GTD GUI 分析和调试时序违例
- 参考 Global Timing Debug Rapid Adoption Kit (RAK) 学习 GTD 功能

---

## RC 提取

### 提取类型概述

| 提取类型 | 使用场景 | 是否需要 Quantus 许可证 |
|---------|---------|----------------------|
| PreRoute | 在布局和时钟树综合前后的优化阶段使用 | 否 |
| PostRoute - Native Detailed | 在旧工艺节点的 postRoute 和 SI 优化流程中使用 | 否 |
| PostRoute - TQuantus | 在新工艺节点的 postRoute 优化流程中使用 | 否 |
| PostRoute - IQuantus | 在 ECO 后和接近 signoff 时使用 | 是（需要 Quantus XL 许可证）|
| PostRoute - Standalone Quantus | 在芯片组装和时序 signoff 流程中使用 | 是 |

### 提取引擎设置

**选择提取引擎：**
```tcl
# TQuantus (medium effort)
setExtractRCMode -engine postRoute -effortLevel medium

# IQuantus (high effort)
setExtractRCMode -engine postRoute -effortLevel high

# Standalone Quantus (signoff)
setExtractRCMode -engine postRoute -effortLevel signoff
```

**工艺节点建议：**
- 65nm 及以上：默认使用 PostRoute 提取
- 65nm 及以下：如果有 Quantus QRC 技术文件，默认使用 TQuantus
- 推荐使用 TQuantus 和 IQuantus 以获得与 signoff 提取的更好相关性
- IQuantus 在实现流程中提供最高精度，特别推荐用于 ECO 的增量提取

### RC 提取过滤器

**设置提取过滤器：**
```tcl
# 设置工艺节点（自动设置默认过滤器值）
setDesignMode -process process_node

# 手动调整耦合电容过滤器
setExtractRCMode -total_c_th value      # 总电容阈值（fF）
setExtractRCMode -coupling_c_th value   # 耦合电容阈值（fF）
setExtractRCMode -relative_c_th value   # 相对电容阈值（百分比）
```

**过滤器参数说明：**
- `-total_c_th`：当网络总电容小于此值时，将耦合电容接地
- `-coupling_c_th`：当两个网络间的耦合电容小于此值时，将其接地
- `-relative_c_th`：当耦合电容占总电容的比例小于此值时，将其接地

### RC 缩放因子

**设置 RC 缩放因子：**
```tcl
# 在 Edit RC Corner 表单中设置缩放因子
# 例如：电容缩放因子 1.1 会将提取值增加 10%
```

**缩放因子使用建议：**
- 推荐用于 preRoute 和 native detailed 提取引擎
- TQuantus 可选使用
- IQuantus 可选用于与第三方 signoff 提取器的精细调优
- effortLevel 设置为 signoff 时不支持缩放

### 提取结果

**生成的文件：**
- 二进制 RC 数据库（RCDB）：包含每个工艺角的寄生参数
- ASCII SPEF 文件：可从寄生参数数据库生成（如需要）

---

## 串扰分析

### SI 分析输入文件

**必需文件：**
- Netlist（网表）
- SDC（时序信息）
- Routed Innovus database 或 DEF 文件（布局和布线信息）
- LEF 文件（物理库）
- Liberty library (.lib)
- Innovus extended capacitance table file
- XILM data（用于层次化设计）

**可选文件（提高精度）：**
- .cdB noise library（用于 AAE 时序分析工具）
- Quantus QRC standalone extraction technology file and library

### SI 分析设置

**RC 提取设置：**
```tcl
# 选择提取引擎（见 RC 提取章节）
setExtractRCMode -engine postRoute -effortLevel medium

# 设置提取过滤器
setDesignMode -process process_node
```

**噪声分析设置：**
```tcl
# 启用 SI 分析
setDelayCalMode -SIAware true

# 启用 OCV 模式和 CPPR
setAnalysisMode -analysisType onChipVariation -cppr both

# 启用 SI CPPR（默认启用）
set_global timing_enable_si_cppr true
```

### 串扰预防

**预防串扰违例的建议：**
```tcl
# 设置合理的最大转换时间阈值，并在详细布线前修复
# 积极修复时钟树上的转换时间违例
# 屏蔽时钟树根部以防止 Clock SI

# 启用时序和信号完整性驱动的布线
setNanoRouteMode -routeWithTimingDriven true
setNanoRouteMode -routeWithSiDriven true
routeDesign
```

### 串扰修复

**修复 Setup 违例（含串扰效应）：**
```tcl
# 默认同时修复 base timing 和 SI timing
optDesign -postRoute

# 仅运行 base timing 优化（不含串扰增量延迟）
setDelayCalMode -SIAware false

# 关闭 SI Glitch 优化
setOptMode -fixGlitch false

# 启用 SI Slew 优化
setOptMode -fixSISlew true
```

**修复 Hold 违例（含串扰效应）：**
```tcl
# 默认同时修复 hold base 和 SI timing
optDesign -postRoute -hold

# 仅运行 base hold timing 优化（不含串扰增量延迟）
setDelayCalMode -SIAware false
```

**修复转换时间违例（含串扰效应）：**
```tcl
# 修复 SI 引起的最大转换时间违例
setOptMode -fixSISlew true
optDesign -postRoute
```

### 使用外部工具的 RC 数据

**加载外部 SPEF：**
```tcl
# 为每个 RC corner 加载 SPEF
spefIn rc_corner1.spef -rc_corner rc_corner1
spefIn rc_corner2.spef -rc_corner rc_corner2

# 基于 SPEF 进行优化
optDesign -postRoute [-hold] -outDir spefFlowTimingReports
```

### 使用外部工具的 SDF 数据

**加载外部 SDF 进行 Setup 修复：**
```tcl
# 为每个 view 加载两个 SDF：一个仅含 base timing，另一个含 base + SI timing
setDelayCalMode -SIAware false
read_sdf -view viewname1 -overwrite_incremental_delay view1.sdf
read_sdf -view viewname2 -overwrite_incremental_delay view2.sdf

# 启用基于外部 SDF 的 SI setup 修复流程
optDesign -postRoute -useSDF
```

### XILM-Based SI 分析

**XILM 数据要求：**
- 从每个 I/O 引脚到第一个 latch 或 flip-flop 的单元和 RC 网络（包括交叉耦合数据）
- eXtended Timing Window Format (XTWF) 文件：包含块内非 ILM 时序路径的时序窗口和 slew 信息

---

## 物理检查

### 单元、引脚和过孔检查

**检查布局问题：**
```tcl
# 检查单元重叠
checkPlace

# 检查设计完整性
checkDesign -all
```

**常见问题：**
- 电源和地引脚：确保 DEF 文件 SPECIALNETS 部分的所有电源和地引脚标记为 `+ USE POWER` 或 `+ USE GROUND`
- 单元重叠：使用 `checkPlace` 命令检查重叠，重叠会导致引脚短路和 metal1 违例
- 电源布线下的引脚：引脚在电源布线下方会导致不可访问，造成 metal1 和 metal2 违例
- 缺少旋转过孔：旋转过孔有助于减少设计规则违例，使引脚可访问

---

## PostRoute 优化中的 SI 分析

### SI 分析数据准备

**必需设置：**
```tcl
# 确保为每个延迟角提供 ECSM/CCS 噪声模型或 cdB 库
# 启用 OCV 模式和 CPPR
setAnalysisMode -analysisType onChipVariation -cppr both

# 启用 SI CPPR
set_global timing_enable_si_cppr true
```

**改善 SI 收敛的技术：**
- 在 floorplanning 和详细布线后关注布线拥塞
- 在 preRoute 阶段运行 `congRepair` 命令消除局部热点
- 使用 NanoRoute 高级时序和 SI 驱动的布线选项（运行 `routeDesign` 时自动启用）
- 修复转换时间违例（运行 `optDesign -postRoute` 时自动完成第一步）

### PostRoute 优化命令序列

**修复 postRoute setup 和 hold 违例：**
```tcl
# Setup 优化
optDesign -postRoute

# Hold 优化
optDesign -postRoute -hold

# 同时进行 setup 和 hold 优化（减少运行时间）
optDesign -postRoute -setup -hold
```

### PostRoute 优化结果分析和调试

**使用 Global Timing Debug 调试剩余违例：**
```tcl
# 如果违例仍然存在，考虑以下建议：

# 对于 multi-VT 设计，仅通过单元交换进行 LEF-Safe 优化
setOptMode -allowOnlyCellSwapping true
optDesign -postRoute

# 确保提取过滤器与 signoff 分析工具相关联
# 检查全局最大转换时间，确保详细布线期间启用了 wire spreading
```

**SI 预防技术（preRoute 流程）：**
```tcl
# 为数据路径增加更多悲观度，强制优化更努力工作
# 可通过增加时钟不确定性实现（选择合理值以避免过度修复）

# 对于深度很大的时序路径（> 40）应用针对性方法
# 仅在大深度路径的网络上添加悲观度

# 检查全局最大转换时间，确保详细布线期间启用 wire spreading
```

---

## 提取设置指南

### RC 提取设置指南

**性能 vs 精度权衡：**
- Native detailed 提取引擎速度最快，但牺牲精度换取性能
- TQuantus 比 IQuantus 快约 30%
- TQuantus 和 IQuantus 都支持分布式处理，强烈推荐使用以抵消较长的运行时间
- IQuantus 引擎在 SI 优化流程中利用增量提取能力，减少后续循环的运行时间

**过滤器设置建议：**
- 确保 Innovus 中用于 SI 修复的过滤器与 SI signoff 分析中使用的过滤器相同
- 强烈推荐使用基于工艺节点的默认过滤器值，并与 signoff 提取器的 RC 进行相关性验证
- 设置过滤器阈值时，确保保留小的耦合电容，因为 AAE-SI 分析会将这些电容聚合成单个虚拟攻击者模型
- 设置低值过滤器时要谨慎，因为这会显著增加运行时间

---

## 分析命令速查表

### 时序分析命令

| 命令 | 用途 |
|------|------|
| `timeDesign -prePlace` | 布局前时序分析 |
| `timeDesign -preCTS` | CTS 前时序分析 |
| `timeDesign -postCTS` | CTS 后时序分析 |
| `timeDesign -postRoute` | 布线后时序分析 |

### RC 提取命令

| 命令 | 用途 |
|------|------|
| `setExtractRCMode -engine postRoute -effortLevel medium` | 使用 TQuantus 提取 |
| `setExtractRCMode -engine postRoute -effortLevel high` | 使用 IQuantus 提取 |
| `setExtractRCMode -engine postRoute -effortLevel signoff` | 使用 Standalone Quantus 提取 |
| `spefIn file.spef -rc_corner corner_name` | 加载外部 SPEF 文件 |

### SI 分析命令

| 命令 | 用途 |
|------|------|
| `setDelayCalMode -SIAware true` | 启用 SI 感知延迟计算 |
| `setDelayCalMode -SIAware false` | 禁用 SI 感知延迟计算 |
| `setAnalysisMode -analysisType onChipVariation -cppr both` | 启用 OCV 和 CPPR |
| `set_global timing_enable_si_cppr true` | 启用 SI CPPR |
| `setOptMode -fixGlitch false` | 关闭 SI Glitch 优化 |
| `setOptMode -fixSISlew true` | 启用 SI Slew 优化 |
| `setNanoRouteMode -routeWithSiDriven true` | 启用 SI 驱动的布线 |

### 物理检查命令

| 命令 | 用途 |
|------|------|
| `checkPlace` | 检查单元重叠 |
| `checkDesign -all` | 检查设计完整性 |
| `congRepair` | 修复布线拥塞 |
