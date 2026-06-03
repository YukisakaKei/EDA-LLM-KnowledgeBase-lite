---
source: knowledge/Innovus/legacy/json/innovusUG__211 | chapters: [0074, 0075, 0076, 0078, 0079, 0080, 0083, 0085, 0086, 0087, 0088, 0097, 0102, 0106, 0111, 0117]
---

# Innovus 标准实现流程

## 概述

时序收敛是创建满足设计时序规范、无逻辑/物理/设计规则违反的设计实现过程。时序收敛不仅仅是时序优化，而是一个完整的流程，包括布局、时序优化、时钟树综合（CTS）、布线和 SI 修复，每个步骤都必须达到预期目标。

## RTL-to-GDSII 完整流程

### 流程阶段概览

```
数据准备 → 流程准备 → 前置优化 → 布局 → 时序分析 → 
CTS → PostCTS 优化 → 布线 → PostRoute 优化 → 时序签核
```

### 各阶段详细说明

#### 1. 数据准备与验证

**目标**
- 确保 Innovus 拥有完整一致的设计数据
- 确保流程中所有工具对时序约束的解释一致
- 验证逻辑等效单元定义正确
- 关联原型和签核提取工具的寄生参数

**关键数据要求**

| 数据类型 | 要求 | 说明 |
|---------|------|------|
| 时序库 | ECSM/CCS 库 | 推荐使用 ECSM，比 NLDM 可获得 5-10% 时钟周期改进 |
| 物理库 | LEF 文件 | 每个单元需要抽象定义；定义 NDR（非默认规则） |
| 网表 | Verilog | 设置 `init_design_uniquify` 为 1 |
| 时序约束 | SDC 文件 | 每个工作模式需要一个 SDC 文件 |
| 提取技术文件 | Quantus 文件 | 65nm 及以下推荐用于后布线提取 |
| SI 库 | ECSM/CCS 或 cdB | 用于 SI 分析和优化 |

**MMMC 设置**
- 定义多模式多角（MMMC）分析视图
- 为每个工作模式和工艺角创建分析视图
- 设置功耗分析模式（如需要）

**保留约束设置**
```tcl
# 设置 dont_touch 和 dont_use 属性
set_dont_touch i1/i2 true
dbSet [dbGet top.insts.name i1/i2 -p1].dontTouch true

# 查看保留属性
dbSchema * dont*
dbSchema inst place_status*
```

#### 2. 流程准备

**设计模式设置**

```tcl
# 设置工艺和流程努力级别
setDesignMode -process 45 -flowEffort standard
```

| 流程努力级别 | 特点 | 适用场景 |
|------------|------|---------|
| express | 最快周转，良好的 WNS/面积相关性 | 原型设计 |
| standard | 最佳 QOR 和周转时间平衡 | 大多数设计 |
| extreme | 最佳 QOR，增加 CPU 时间 | 时序收敛困难的设计 |

**提取模式配置**

```tcl
# 前布线提取（快速）
setExtractRCMode -engine preRoute -effortLevel low

# 后布线提取（精确）
setExtractRCMode -engine postRoute -effortLevel medium
```

| 努力级别 | 提取器 | 精度 | 许可证 |
|---------|-------|------|--------|
| low | 原生详细提取 | 低 | 无需 |
| medium | TQuantus | 中 | 无需 |
| high | IQuantus | 高 | 需要 |
| signoff | Standalone Quantus | 最高 | 需要 |

**时序分析**

```tcl
# 运行时序分析
timeDesign -outDir timingReports

# 使用 Global Timing Debug (GTD) 分析问题
# 在 Innovus GUI 中选择 Tools → Global Timing Debug
```

#### 3. 前置优化

**目标**
- 改进逻辑结构
- 减少拥塞
- 减少面积
- 改进时序

**关键命令**

```tcl
# 删除缓冲树（默认由 place_opt_design 执行）
deleteBufferTree

# 前置优化
place_opt_design
```

#### 4. 布局和初始布置

**目标**
- 创建多次迭代原型，重点关注可布线性
- 随着可布线性稳定，转向时序驱动布置
- 时序和拥塞收敛后添加电源布线

**原型设计流程**

```tcl
# 快速原型模式（无约束）
setPlaceMode -place_design_floorplan_mode true
placeDesign

# 分析布局质量后，转换为合法布置
setPlaceMode -place_design_floorplan_mode false
placeDesign
```

**确保可布线性**

- 选择合适的 floorplan 风格（外围、岛屿、甜甜圈）
- 保持宏深度为 1-2 层
- 预放置 I/O 和宏
- 在预放置块之间留出足够空间
- 使用模块指南、放置阻挡和栅栏控制单元放置
- 使用软或硬阻挡覆盖标准单元和块之间的间隙

**Floorplan 验证清单**

- [ ] 电源网格已定义（全局网连接正确）
- [ ] 所有块标记为固定
- [ ] 轨道与 I/O 引脚和放置网格对齐
- [ ] 间隙用软/硬阻挡覆盖
- [ ] 特殊网标记为 SPECIALNETS

#### 5. 时序分析

```tcl
# 运行时序分析
timeDesign -outDir timingReports

# 使用 GTD 调试时序问题
# 查看时序路径、违反和关键路径
```

#### 6. RC 提取

**提取策略**

| 阶段 | 引擎 | 努力级别 | 用途 |
|------|------|---------|------|
| 前布线 | preRoute | low | 快速周转，实验不同 floorplan |
| 后布线 | postRoute | medium/high | 精确提取，考虑耦合 |

**关键命令**

```tcl
# 前布线提取
setExtractRCMode -engine preRoute -effortLevel low
extractRC

# 后布线提取
setExtractRCMode -engine postRoute -effortLevel medium
extractRC
```

#### 7. 时钟树综合（CTS）

**CCOpt-CTS 配置**

```tcl
# 创建非默认布线规则
create_route_type -name clk_route -top_preferred_layer M6

# 设置 CTS 属性
set_ccopt_property -buffer_cells {BUF_X1 BUF_X2}
set_ccopt_property -inverter_cells {INV_X1 INV_X2}
set_ccopt_property -target_max_trans 150ps
set_ccopt_property -target_skew 100ps

# 从时序约束创建时钟树规范
create_ccopt_clock_tree_spec
```

**运行 CTS**

```tcl
# 运行 CCOpt-CTS（仅 CTS）
ccopt_design -cts

# 运行 CCOpt（CTS + 并发优化）
ccopt_design

# 时序分析
timeDesign -postCTS -outDir ctsTimingReports

# 报告时钟树
report_ccopt_clock_trees -file clock_trees.rpt
report_ccopt_skew_groups -file skew_groups.rpt
```

**PostCTS 约束调整**

```tcl
# 更新 SDC 文件
update_constraint_mode

# 设置时钟为传播模式
set_propagated_clock [all_clocks]

# 调整时钟不确定性（仅抖动）
set_clock_uncertainty 50ps [all_clocks]

# 调整 I/O 延迟
set_input_delay -clock clk 2ns [all_inputs]
set_output_delay -clock clk 2ns [all_outputs]
```

#### 8. PostCTS 优化

**目标**
- 修复剩余设计规则违反（DRV）
- 优化剩余建立时间违反
- 准备布线

**关键命令**

```tcl
# PostCTS 优化
optDesign -postCTS

# 时序分析
timeDesign -postCTS -outDir postCtsTimingReports
```

#### 9. 详细布线

**关键命令**

```tcl
# 全局布线
globalDetailRoute

# 时序分析
timeDesign -postRoute -outDir postRouteTimingReports
```

#### 10. PostRoute 优化

**目标**
- 修复 SI 问题
- 优化剩余 Hold 时间违反
- 最小化面积增加

**关键命令**

```tcl
# PostRoute 优化
optDesign -postRoute

# 时序分析
timeDesign -postRoute -outDir finalTimingReports
```

#### 11. 时序签核

```tcl
# 最终时序分析
timeDesign -outDir signoffTimingReports

# 生成时序报告
report_timing -path_type full_clock -delay_type max -nworst 100
```

---

## Foundation Flow 命令序列速查

```tcl
# 1. 初始化
init_design
set init_mmmc_file viewDefinition.tcl

# 2. 前置优化
place_opt_design

# 3. 布局
floorPlan -site CoreSite -trackOffset 0 -d 1000 1000 10 10 10 10
placeDesign

# 4. 时序分析
timeDesign -outDir timingReports

# 5. RC 提取
setExtractRCMode -engine preRoute -effortLevel low
extractRC

# 6. CTS
ccopt_design

# 7. PostCTS 优化
optDesign -postCTS

# 8. 布线
globalDetailRoute

# 9. PostRoute 优化
optDesign -postRoute

# 10. 最终时序分析
timeDesign -outDir finalTimingReports
```

---

## 时序收敛策略

### 关键原则

1. **早期关注可布线性** — 在优化前确保设计可布线
2. **增量收敛** — 每个阶段都应该改进时序
3. **平衡优化** — 在时序、面积和功耗之间平衡
4. **验证相关性** — 确保 Innovus 和 signoff 工具的时序相关性

### 时序跳跃诊断

**问题：** 某个阶段的时序突然恶化

**诊断步骤：**
1. 比较前后的时序报告
2. 检查是否有大量新增单元
3. 验证 RC 提取参数的变化
4. 检查是否有新的关键路径

**解决方案：**
- 增加优化迭代次数
- 调整优化模式参数
- 重新提取 RC 参数
- 考虑调整 floorplan

### 常见问题处理

#### 拥塞问题

**症状：** 布线失败或拥塞严重

**解决方案：**
- 增加设计面积
- 调整 floorplan 和宏放置
- 使用 `congRepair` 消除热点
- 增加布线层数

#### SI 问题

**症状：** PostRoute 时序恶化

**解决方案：**
- 启用 SI 感知分析
- 增加缓冲器以减少串扰
- 调整布线规则以减少耦合
- 使用 SI 优化工具

#### 时钟偏斜问题

**症状：** 时钟路径延迟过大

**解决方案：**
- 调整 CTS 目标偏斜
- 增加时钟缓冲器
- 优化时钟树拓扑
- 使用时钟偏斜优化

#### 保持时间问题

**症状：** Hold 时间违反无法修复

**解决方案：**
- 增加缓冲器
- 调整单元尺寸
- 优化布线路径
- 使用 ECO 流程

#### 多 VT 设计

**症状：** 时序收敛困难

**解决方案：**
- 使用 `setOptMode -allowOnlyCellSwapping true` 进行单元交换
- 在正常优化前后运行单元交换
- 验证 VT 分配的合理性

---

## 设计特定建议

### 高性能设计

- 使用 `extreme` 流程努力级别
- 增加 CTS 目标偏斜精度
- 启用 SI 感知分析和优化
- 使用高精度提取（IQuantus 或 Quantus）

### 拥塞设计

- 早期关注可布线性
- 使用 Prototyping Foundation Flow 和 Flex Models
- 增加设计面积或调整 floorplan
- 运行 `congRepair` 消除热点

### 高利用率设计

- 使用 `extreme` 流程努力级别
- 仔细规划 floorplan 和宏放置
- 使用软阻挡控制单元放置
- 增加优化迭代次数
