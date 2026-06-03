---
source: knowledge/Innovus/legacy/json/innovusUG__211 | chapters: [0118, 0599, 0600, 0602, 0612, 0688, 0689, 0715, 1039, 1040, 1041, 1049, 1120, 1122]
---

# Signoff 工具集成

Signoff 工具集成涵盖 Tempus（时序分析）、Quantus（寄生参数提取）、Voltus（功耗分析）等工具与 Innovus 的协作流程，实现从时序签核、ECO 修复到功耗验证的完整设计闭环。

## 工具集成流程概述

### Tempus/Quantus 时序分析与优化

Innovus 提供 signoff 模式时序分析，但与独立 signoff 工具存在差异：

- **实现工具** — 使用线性斜率模型、图形化 AOCV
- **Signoff 工具** — 使用完整波形传播、路径级 AOCV

为确保设计质量接近 signoff 标准，使用以下命令在 Innovus 中集成 Tempus/Quantus：

| 命令 | 功能 |
|---|---|
| `signoffTimeDesign` | 调用 Quantus 和 Tempus 进行 signoff STA，生成 ECO Timing DB |
| `signoffOptDesign` | 基于 signoff 时序进行时序和功耗优化 |

**工作流程**：
1. `signoffTimeDesign` 使用 DMMMC 基础设施运行 Quantus 和 Tempus
2. 为每个工艺角生成 ECO Timing DB
3. `signoffOptDesign` 自动调用 `signoffTimeDesign`（如果 ECO DB 不存在）
4. 在 Innovus 中进行时序修复和功耗优化

### Quantus 寄生参数提取

#### TQuantus 提取引擎

TQuantus 是高级提取引擎，默认用于 postRoute 中等工作量级别：

```tcl
setExtractRCMode -engine postRoute -effortLevel medium
```

**特点**：
- 与 NanoRoute 紧密集成
- 驱动轨道分配型时序和 SI 优化
- 支持时序驱动布线
- 生成简化 RC 模型（相比 Quantus techfile 更简洁）

**支持参数**：
- `-capFilterMode relAndCoup`
- `-relative_c_th`, `-total_c_th`, `-coupling_c_th`
- `-extraCmdFile`, `-coupled`

**不支持参数**：
- `-hardBlockObs`, `-lefTechFileMap`

#### TQuantus 模型文件创建

创建 TQuantus 模型文件前，确保以下数据可用：
- QRC techfiles
- 工艺 LEF 文件中的 pitch 信息
- RC corners

**创建和使用流程**：

```tcl
# 1. 生成 TQuantus 模型文件
createTQuantusModelFile -file tQuantus_model.bin

# 2. 配置提取模式
setSIMode –reset
setExtractRCMode -engine postRoute -effortLevel medium \
  -tQuantusModelFile tQuantus_model.bin

# 3. 验证模型文件一致性
checkTQuantusModelFile

# 4. 用于轨道分配型优化
setDelayCalMode -SIAware true
setAnalysisMode -analysisType onChipVariation -cppr both
routeDesign –trackOpt

# 5. 用于 postRoute 优化
optDesign -postRoute
timeDesign -postRoute
```

**注意**：使用 `-trackOpt` 时，必须设置 `setDelayCalMode -SIAware true`，否则工具报错。

#### TQuantus vs IQuantus

| 特性 | TQuantus | IQuantus |
|---|---|---|
| 集成度 | 与 NanoRoute 紧密集成 | 独立提取 |
| 模型复杂度 | 简化 RC 模型 | 完整 RC 表 |
| 精度 | 中等 | 高 |
| 运行时间 | 快 | 较慢 |
| 应用场景 | 实现阶段优化 | Signoff 提取 |

### Voltus 功耗和电源分析

#### Early Rail Analysis (ERA)

ERA 用于早期电源网络分析，支持静态和动态分析。

**设置步骤**：

1. 选择分析阶段：Early
2. 选择分析方法：Static 或 Dynamic
3. 指定精度模式：XD（默认）或 HD
4. 提供功率网格库或提取工艺文件
5. 如使用 CPF，选择分析视图
6. 对于功率门控设计，指定关闭网络
7. 可选：指定电迁移分析模型

**高级选项**：
- 生成边界电压文件（分层视图）
- 指定 GDS（Flip-chip RDL 或全芯片）
- 创建电流区域（静态/动态分析）
- 功率门控文件
- 层映射文件
- 虚拟通孔插入配置
- 制造工艺效应

**运行 ERA**：

```tcl
set_rail_analysis_mode -analysis_stage early \
  -analysis_method static \
  -accuracy_mode xd

# 运行分析
run_rail_analysis -net_based \
  -power_net VDD -ground_net VSS
```

#### Voltus 菜单与 Innovus 差异

Voltus 提供专用功耗分析菜单，与 Innovus 菜单结构不同。主要功能包括：

- Rail Analysis Setup
- Rail Analysis Execution
- Power Grid Library Generation
- Power Report Generation
- Dynamic Analysis Results

## Signoff ECO 流程

### MMMC Signoff ECO

ECO（Engineering Change Order）流程用于在 signoff 阶段进行设计修复。

**ECO 命令序列**：

```tcl
# 1. 运行 signoff 时序分析
signoffTimeDesign

# 2. 基于 signoff 时序进行优化
signoffOptDesign -setup      # 时序修复
signoffOptDesign -hold       # 保持时间修复
signoffOptDesign -power      # 功耗优化

# 3. 验证修复结果
signoffTimeDesign            # 重新分析
```

### Metal ECO 流程

Metal ECO 用于后掩膜阶段的修复，支持 Gate Array 单元替换。

**配置**：

```tcl
# 启用 Metal ECO 模式
setSignoffOptMode -postMask true

# 指定 Gate Array 填充单元
setSignoffOptMode -useGaFillerList {GFILL1BWP GFILL2BWP GFILL4BWP GFILL10BWP}

# 配置 Tie 单元
setTieHiLoMode -cell {tieLo_name tieHi_name}

# 执行 Hold 修复
signoffOptDesign -hold
```

**Metal ECO 支持的修复类型**：
- DRV（驱动强度）修复
- Setup 时序修复
- Hold 时序修复

**自动修改**：
- 用 Gate Array 缓冲或反相器对替换现有填充单元
- 调整单元大小为 Gate Array 单元
- 删除常规单元
- 插入 Tie 单元连接悬空引脚

## Signoff 命令速查表

### 时序分析命令

| 命令 | 功能 | 参数 |
|---|---|---|
| `signoffTimeDesign` | Signoff STA 分析 | `-setup`, `-hold`, `-power` |
| `signoffOptDesign` | Signoff 优化 | `-setup`, `-hold`, `-power`, `-postRoute` |
| `timeDesign -postRoute` | PostRoute 时序分析 | `-idealClock` |
| `optDesign -postRoute` | PostRoute 优化 | `-setup`, `-hold`, `-power` |

### 提取命令

| 命令 | 功能 |
|---|---|
| `setExtractRCMode` | 配置提取模式和引擎 |
| `createTQuantusModelFile` | 生成 TQuantus 模型文件 |
| `checkTQuantusModelFile` | 验证 TQuantus 模型一致性 |
| `extractRC` | 执行 RC 提取 |

### 功耗分析命令

| 命令 | 功能 |
|---|---|
| `set_rail_analysis_mode` | 配置电源网络分析 |
| `run_rail_analysis` | 执行电源网络分析 |
| `set_power_data` | 指定功率数据 |

### ECO 命令

| 命令 | 功能 |
|---|---|
| `setSignoffOptMode` | 配置 ECO 模式 |
| `setTieHiLoMode` | 配置 Tie 单元 |
| `signoffOptDesign -hold` | Hold 时间修复 |
| `signoffOptDesign -setup` | Setup 时间修复 |

## Signoff 优化最佳实践

### 时序闭环策略

1. **早期 Signoff 分析** — 在 placement 后运行 `signoffTimeDesign` 获得准确的时序预测
2. **增量优化** — 使用 `signoffOptDesign` 进行增量修复，避免大规模重新优化
3. **多角分析** — 利用 DMMMC 覆盖所有工艺角和工作条件
4. **功耗-时序权衡** — 在 `signoffOptDesign -power` 中平衡功耗和时序

### 提取精度优化

1. **TQuantus 模型验证** — 使用 `checkTQuantusModelFile` 确保模型一致性
2. **SI 感知优化** — 启用 `setDelayCalMode -SIAware true` 考虑串扰效应
3. **轨道分配优化** — 使用 `routeDesign -trackOpt` 进行精确的轨道级优化

### 功耗分析流程

1. **早期 ERA** — 在 placement 后运行 ERA 识别功耗热点
2. **电流分布** — 使用 `-era_current_region_file` 精确指定电流分布
3. **电迁移检查** — 启用 EM 分析验证金属条纹可靠性
4. **虚拟通孔优化** — 配置虚拟通孔插入策略改善功耗分布

### ECO 修复优先级

1. **Setup 修复** — 优先修复 setup 违规（影响最大频率）
2. **Hold 修复** — 其次修复 hold 违规（影响可靠性）
3. **功耗优化** — 最后进行功耗优化（在时序满足后）
4. **Metal ECO** — 后掩膜阶段使用 Metal ECO 进行最小化修改

## 工具集成配置参考

### DMMMC 配置示例

```tcl
# 定义工艺角
create_library_set -name lib_ss -libraries {lib_ss.lib}
create_library_set -name lib_ff -libraries {lib_ff.lib}

# 定义延迟角
create_delay_corner -name delay_ss -library_set lib_ss
create_delay_corner -name delay_ff -library_set lib_ff

# 定义工作条件
create_rc_corner -name rc_typical -cap_table cap.table
create_rc_corner -name rc_worst -cap_table cap_worst.table

# 创建分析视图
create_analysis_view -name view_ss -delay_corner delay_ss -rc_corner rc_typical
create_analysis_view -name view_ff -delay_corner delay_ff -rc_corner rc_worst
```

### Signoff 优化配置示例

```tcl
# 配置 Signoff 时序分析
signoffTimeDesign -setup -hold

# 配置 Signoff 优化
setSignoffOptMode -setup true -hold true -power true
setSignoffOptMode -postMask false

# 运行优化
signoffOptDesign -setup -hold -power
```

### Voltus 集成配置示例

```tcl
# 配置电源分析
set_rail_analysis_mode -analysis_stage early \
  -analysis_method dynamic \
  -accuracy_mode xd \
  -power_grid_library pgl.lib

# 运行分析
run_rail_analysis -net_based \
  -power_net VDD -ground_net VSS \
  -power_data_type uti \
  -power_data_file power.uti
```
