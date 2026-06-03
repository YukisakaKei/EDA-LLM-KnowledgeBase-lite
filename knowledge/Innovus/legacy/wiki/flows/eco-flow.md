---
source: knowledge/Innovus/legacy/json/innovusUG__211 | chapters: [0341, 0600, 0612, 0613, 0661, 0662, 0663]
---

# ECO 流程完全指南

## 概述

ECO（Engineering Change Order）流程用于在芯片设计完成后进行最小化修改，包括功能修复、时序优化、金属层修改等。Innovus 支持多种 ECO 流程，从功能性 ECO 到金属层专用 ECO。

---

## ECO 流程分类

### 1. 功能性 ECO（Pre-mask ECO）

功能性 ECO 用于修复逻辑功能或时序问题，涉及门级网表修改。

**主要应用场景：**
- 新网表导入后的最小化修改
- Setup/Hold 时序违反修复
- DRV（Design Rule Violation）修复
- 缓冲器插入和门尺寸调整

**关键命令：**
- `signoffTimeDesign` — 使用 Tempus 进行 signoff 时序分析，生成 ECO Timing DB
- `signoffOptDesign` — 基于 signoff 时序进行优化
- `optDesign` — 标准时序优化
- `ecoRoute` — ECO 布线

**工作流程：**
```tcl
# 1. 生成 signoff 时序数据库
signoffTimeDesign

# 2. 执行 ECO 优化（Setup 修复）
signoffOptDesign -setup

# 3. 执行 ECO 优化（Hold 修复）
signoffOptDesign -hold

# 4. ECO 布线
ecoRoute
```

### 2. Signoff ECO（MMMC 多模式多角 ECO）

使用 Tempus signoff 时序进行 ECO 优化，确保与 signoff 工具的时序相关性。

**特点：**
- 集成 Quantus 寄生参数提取
- 集成 Tempus signoff 时序分析
- 支持 DMMMC（Distributed MMMC）基础设施
- 自动生成 ECO Timing DB

**配置示例：**
```tcl
# 设置 signoff 优化模式
setSignoffOptMode -preStaTcl preStaTcl.tcl \
                  -retime path_slew_propagation \
                  -checktype both \
                  -pbaEffort high \
                  -maxSlack 10 \
                  -maxPaths 10000000 \
                  -nworst 50 \
                  -deleteInst true \
                  -saveEcoOptDb ECO-DB-PBA

# 生成 signoff 时序报告
signoffTimeDesign -reportOnly -outDir RPT-PBA-init

# 执行 signoff ECO 优化
setSignoffOptDesign -loadEcoOptDb ECO-DB-PBA
signoffOptDesign -noEcoRoute -power
```

### 3. 时钟偏斜优化（Clock Skewing）

Tempus ECO 支持时钟路径优化以修复 Setup 时序违反。

**关键特性：**
- 高级时钟树操作，提供更大的偏斜灵活性
- 多级尺寸调整和缓冲
- 并发数据路径和时钟路径优化
- 支持最大偏斜级别限制

**配置示例：**
```tcl
# 指定允许的时钟单元
setSignoffOptMode -clock_cell_list {CKBUFX1 CKBUFX4}

# 启用时钟偏斜
setSignoffOptMode -allowSkewing true

# 执行 Setup 修复（包含时钟偏斜）
signoffOptDesign -setup
```

### 4. 金属层 ECO（Post-mask Metal ECO）

金属层 ECO 用于在掩膜后进行修改，仅允许在现有 Gate Array 单元位置进行修改。

**启用方式：**
```tcl
setSignoffOptMode -postMask true
```

**支持的网表修改：**
- 在现有 Gate Array 填充单元位置插入缓冲器或反相器对
- 将常规单元调整为 Gate Array 单元
- 删除常规单元
- 自动识别 Gate Array 单元（通过 SITE 名称匹配）

**配置示例：**
```tcl
# 启用金属 ECO 模式
setSignoffOptMode -postMask true

# 指定 Gate Array 填充单元列表
setSignoffOptMode -useGaFillerList {GFILL1BWP GFILL2BWP GFILL4BWP GFILL10BWP}

# 配置 Tie 单元（用于连接悬空输入）
setTieHiLoMode -cell {tieLo_name tieHi_name}

# 执行 Hold 修复（金属 ECO 模式）
signoffOptDesign -hold
```

**限制：**
- 仅支持 DRV、Setup 和 Hold 修复
- 必须预先定义 Gate Array 填充单元
- 100% 布局密度要求

---

## ECO 编辑命令速查

### 功能性 ECO 命令前缀

| 前缀 | 描述 | 来源命令 |
|------|------|---------|
| FE_MDBC | 多驱动网缓冲插入的实例 | optDesign |
| FE_MDBN | 多驱动网缓冲插入的网络 | optDesign |
| FE_OCP_RBC | 重缓冲插入的实例 | optDesign |
| FE_OCP_RBN | 重缓冲插入的网络 | optDesign |
| FE_OCPC | 预布线关键路径优化的实例 | optDesign |
| FE_OCPN | 预布线关键路径优化的网络 | optDesign |
| FE_OFC | 预布线 DRV 修复的缓冲实例 | addRepeaterByRule / optDesign |
| FE_OFN | 预布线 DRV 修复的缓冲网络 | addRepeaterByRule / optDesign |
| FE_PHC | Hold 时间修复的实例 | optDesign |
| FE_PHN | Hold 时间修复的网络 | optDesign |
| FE_PSBC | 后布线缓冲插入的实例 | optDesign |
| FE_PSBN | 后布线缓冲插入的网络 | optDesign |
| FE_PSRC | 后布线重构的实例 | optDesign |
| FE_PSRN | 后布线重构的网络 | optDesign |
| FE_PSC | 后布线 Setup 修复的实例 | optDesign |
| FE_PSN | 后布线 Setup 修复的网络 | optDesign |
| FE_PDC | 后布线 DRV 修复的实例 | optDesign |
| FE_PDN | 后布线 DRV 修复的网络 | optDesign |
| FE_RC | 网表重构的实例 | optDesign |
| FE_RN | 网表重构的网络 | optDesign |
| FE_USKC | useful skew 优化的实例 | optDesign / skewClock |
| FE_USKN | useful skew 优化的网络 | optDesign / skewClock |
| FE_ARRC | addRepeaterByRule 添加的实例 | addRepeaterByRule |
| FE_ARRN | addRepeaterByRule 添加的网络 | addRepeaterByRule |

---

## ECO 布线

### 基本 ECO 布线流程

ECO 布线用于完成新增逻辑的部分布线，同时保持现有布线尽可能不变。

**应用场景：**
- 新网表导入后的最小化修改
- Setup/Hold 修复后的缓冲器布线
- 手工编辑后的布线更新
- 金属填充后的布线调整
- 天线二极管插入后的布线

**基本命令：**
```tcl
# 启用 ECO 布线模式
setNanoRouteMode -routeWithEco true

# 执行全局详细布线
globalDetailRoute
```

### ECO 布线行为

- **重布线部分布线和无布线线网** — 保持自动预布线线网（如 clock net）不变，但可能进行微小调整以提高可布线性
- **保留完全预布线线网** — 保持 pin-to-pin 路径不变
- **使用悬空路径** — 可能使用悬空路径完成布线，但会移除全局布线后的悬空线
- **保持边界框内连接** — 不约束层或位置

### 指定 ECO 布线线网

```tcl
# 指定要布线的线网
setNanoRouteMode -routeWithEco true -ecoRouteNets {net1 net2}

# 指定要保留的线网
setNanoRouteMode -routeWithEco true -ecoPreserveNets {clk_net}
```

---

## 最佳实践

### 时序相关性

- 使用 Tempus signoff 时序进行 ECO 优化
- 定期与 signoff 工具同步时序数据
- 验证 Innovus 和 signoff 工具的时序相关性

### 流程规划

- 在设计完成前规划 ECO 策略
- 预留 ECO 空间（如 Gate Array 填充单元）
- 维护清晰的 ECO 历史记录

### 时钟偏斜优化

- 启用时钟偏斜以获得更大的优化空间
- 设置合理的最大偏斜限制
- 验证时钟树的可实现性

### 金属 ECO 模式

- 预先定义 Gate Array 填充单元
- 确保 100% 布局密度
- 验证 Tie 单元的正确配置

### 线网选择

- 优先布线关键路径线网
- 避免不必要的线网重布线
- 保留时钟和电源线网

---

## 常见陷阱

### 1. 时序相关性差

**问题：** Innovus ECO 优化后，signoff 工具显示不同的时序结果

**解决方案：**
- 使用 signoff 时序进行 ECO 优化
- 验证 RC 提取参数的一致性
- 检查库文件版本是否匹配

### 2. ECO 布线失败

**问题：** ECO 布线无法完成新增线网的布线

**解决方案：**
- 检查设计中是否有足够的布线资源
- 增加布线层数或调整布线规则
- 考虑重新放置新增单元

### 3. 金属 ECO 模式下的单元插入失败

**问题：** Gate Array 填充单元未正确识别

**解决方案：**
- 验证 Gate Array 单元的 SITE 名称与填充单元匹配
- 确保 Gate Array 单元在库中定义
- 检查 `setSignoffOptMode -useGaFillerList` 配置

### 4. Hold 修复后的 Setup 恶化

**问题：** Hold 修复引入新的 Setup 违反

**解决方案：**
- 使用并发的数据路径和时钟路径优化
- 启用时钟偏斜优化
- 运行多次迭代的 Setup/Hold 修复

### 5. 提取相关性问题

**问题：** ECO 优化后的时序与预期不符

**解决方案：**
- 重新提取 RC 参数
- 使用高精度提取工具（IQuantus 或 Quantus）
- 重用已提取的寄生参数

---

## 调试和验证

### 生成 ECO 报告

```tcl
# 时序报告
report_timing -path_type full_clock -delay_type max -nworst 10

# 功耗报告
report_power

# 面积报告
report_area

# 时钟树报告
report_clock_tree
```

### 验证 ECO 修改

```tcl
# 检查新增单元
query_objects [get_cells FE_*]

# 检查修改的线网
query_objects [get_nets FE_*]

# 验证连接性
check_connectivity
```

### 性能分析

```tcl
# 报告 ECO 优化统计
report_opt_design_summary

# 检查布线拥塞
report_congestion
```

---

## 参考资源

- **Innovus ECO 命令** — 参考 Interactive ECO 章节获取完整命令列表
- **Tempus Signoff 时序** — 使用 Tempus 进行精确的 signoff 时序分析
- **NanoRoute 布线器** — 详见 Using the NanoRoute Router 章节
