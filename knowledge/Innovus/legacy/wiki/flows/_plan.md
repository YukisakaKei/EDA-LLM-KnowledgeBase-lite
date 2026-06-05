# flows/ 提取计划

JSONL 文件：`knowledge/Innovus/legacy/jsonl/innovusUG__211.jsonl`

**数据来源**：章节号和标题均从 `toc.json` 验证，不含虚构内容。

---

## standard-impl-flow.md

**目标**：RTL-to-GDSII 完整流程、Foundation Flow、各阶段命令序列、时序收敛策略。

**提取章节**：

| chapter | 标题 | 提取重点 |
|---|---|---|
| entry index=0074 | Design Implementation Flow | 设计实现流程总体介绍 |
| entry index=0075 | Introduction | 流程介绍 |
| entry index=0076 | Recommended Timing Closure Flow | 推荐的时序收敛流程 |
| entry index=0078 | Foundation Flow | Foundation Flow 基础流程 |
| entry index=0079 | Data Preparation | 数据准备 |
| entry index=0080 | Data Validation | 数据验证 |
| entry index=0083 | Flow Preparation | 流程准备 |
| entry index=0085 | Extraction | RC 提取 |
| entry index=0086 | Timing Analysis | 时序分析 |
| entry index=0087 | Pre-Placement Optimization | Pre-placement 优化 |
| entry index=0088 | Floorplanning and Initial Placement | 布局规划和初始放置 |
| entry index=0097 | Clock Tree Synthesis | CTS 阶段 |
| entry index=0102 | PostCTS Optimization | PostCTS 优化 |
| entry index=0106 | Detailed Routing | 详细布线 |
| entry index=0111 | PostRoute Optimization | PostRoute 优化 |
| entry index=0117 | Timing Sign Off | 时序签核 |

**输出格式**：
1. RTL-to-GDSII 完整流程图（各阶段输入输出、关键命令）
2. Foundation Flow 命令序列速查（初始化 → floorplan → place → CTS → route → opt）
3. 时序收敛策略和常见问题处理

---

## hierarchical-flow.md

**目标**：分区流程、时序预算、顶层集成、Stylus Hierarchical Database Flow。

**提取章节**：

| chapter | 标题 | 提取重点 |
|---|---|---|
| entry index=0120 | Hierarchical and Prototyping Flow | 分层和 Prototyping 流程总体 |
| entry index=0121 | Hierarchical and Prototyping Flow Overview | 分层流程概述 |
| entry index=0122 | Top-down and Bottom-up Hierarchical Methodologies | 顶层和底层分层方法论 |
| entry index=0123 | Top-down Methodology | 顶层方法论 |
| entry index=0124 | Bottom-up Methodology | 底层方法论 |
| entry index=0126 | Hierarchical Methodologies | 分层方法论详解 |
| entry index=0127 | Hierarchical Partitioning Flow and Capabilities | 分层分区流程和能力 |
| entry index=0128 | Hierarchical Partitioning | 分层分区 |
| entry index=0129 | Chip Planning | 芯片规划 |
| entry index=0130 | FlexModel | FlexModel 模型 |
| entry index=0136 | Using Interface Logic Models (ILM) | ILM 使用 |
| entry index=0137 | Using Flexible Interface Logic Models (FlexILM) | FlexILM 使用 |
| entry index=0139 | Stylus Hierarchical Database Flow | Stylus 分层数据库流程 |
| entry index=0152 | Hierarchical Extraction | 分层提取 |

**输出格式**：
1. 分层流程概述（分区规划 → 块级实现 → 顶层集成）
2. 时序预算分配和传播方法
3. 顶层集成命令速查表

---

## low-power-flow.md

**目标**：CPF/UPF 加载、power domain、isolation/level-shifter 插入、MSV、power switch。

**提取章节**：

| chapter | 标题 | 提取重点 |
|---|---|---|
| entry index=0357 | Low Power Design | 低功耗设计总体 |
| entry index=0359 | Power Domain Shutdown and Scaling | Power Domain 关闭和缩放 |
| entry index=0367 | Low Power Cell Definition | 低功耗单元定义 |
| entry index=0370 | Innovus IEEE1801 Low Power Flow | IEEE1801 低功耗流程 |
| entry index=0373 | Flow Special Handling for Low Power | 低功耗流程特殊处理 |
| entry index=0374 | Low Power Cells and Usage | 低功耗单元和使用 |
| entry index=0376 | The Innovus Low Power Flow | Innovus 低功耗流程 |
| entry index=0377 | Low Power Planning and Routing | 低功耗规划和布线 |
| entry index=0378 | Low Power Optimization | 低功耗优化 |
| entry index=0379 | Low Power Design Verification | 低功耗设计验证 |
| entry index=0380 | Low Power Debugging Commands | 低功耗调试命令 |

**输出格式**：
1. 低功耗流程概述（CPF/UPF 加载 → power domain 定义 → 特殊单元插入）
2. CPF/UPF 命令序列和配置参考
3. MSV 和 power switch 设计指南

---

## eco-flow.md

**目标**：Pre-mask/post-mask ECO、functional ECO、metal-only ECO、交互式编辑。

**提取章节**：

| chapter | 标题 | 提取重点 |
|---|---|---|
| entry index=0341 | Using the ECO Flow for the New Netlist | ECO 流程使用 |
| entry index=0600 | Running MMMC SignOff ECO within Innovus | MMMC SignOff ECO |
| entry index=0612 | Top Down Block ECO flow using Tempus Signoff Timing | 顶层 Block ECO 流程 |
| entry index=0613 | Metal ECO Flow | Metal ECO 流程 |
| entry index=0661 | Running ECO Routing | ECO 布线 |
| entry index=0662 | ECO Limitations | ECO 限制 |
| entry index=0663 | ECO Flow | ECO 流程总体 |

**输出格式**：
1. ECO 流程分类（Pre-mask → Post-mask → Metal-only）
2. ECO 编辑命令速查（functional ECO → metal ECO → 验证）
3. ECO 最佳实践和常见陷阱

---

## prototyping-flow.md

**目标**：Prototyping Flow、Giga-Scale 设计、active-logic reduction、顶层时序收敛。

**提取章节**：

| chapter | 标题 | 提取重点 |
|---|---|---|
| entry index=0120 | Hierarchical and Prototyping Flow | Prototyping 流程总体 |
| entry index=0132 | Prototyping Flow | Prototyping Flow 详解 |
| entry index=0133 | Supporting Giga-Scale Designs in Planning stage | Giga-Scale 设计支持 |
| entry index=0134 | Active-logic Reduction Technology | Active Logic Reduction 技术 |
| entry index=0135 | Top-level Timing Closure | 顶层时序收敛 |

**输出格式**：
1. Prototyping Flow 概述（设计简化 → 快速实现 → 验证）
2. Active Logic Reduction 命令和配置
3. Giga-Scale 设计时序收敛指南
