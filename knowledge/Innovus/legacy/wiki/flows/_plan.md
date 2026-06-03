# flows/ 提取计划

JSON 根目录：`knowledge/Innovus/legacy/json/innovusUG__211/`

**数据来源**：章节号和标题均从 `toc.json` 验证，不含虚构内容。

---

## standard-impl-flow.md

**目标**：RTL-to-GDSII 完整流程、Foundation Flow、各阶段命令序列、时序收敛策略。

**提取章节**：

| chapter | 标题 | 提取重点 |
|---|---|---|
| chapter_0074.json | Design Implementation Flow | 设计实现流程总体介绍 |
| chapter_0075.json | Introduction | 流程介绍 |
| chapter_0076.json | Recommended Timing Closure Flow | 推荐的时序收敛流程 |
| chapter_0078.json | Foundation Flow | Foundation Flow 基础流程 |
| chapter_0079.json | Data Preparation | 数据准备 |
| chapter_0080.json | Data Validation | 数据验证 |
| chapter_0083.json | Flow Preparation | 流程准备 |
| chapter_0085.json | Extraction | RC 提取 |
| chapter_0086.json | Timing Analysis | 时序分析 |
| chapter_0087.json | Pre-Placement Optimization | Pre-placement 优化 |
| chapter_0088.json | Floorplanning and Initial Placement | 布局规划和初始放置 |
| chapter_0097.json | Clock Tree Synthesis | CTS 阶段 |
| chapter_0102.json | PostCTS Optimization | PostCTS 优化 |
| chapter_0106.json | Detailed Routing | 详细布线 |
| chapter_0111.json | PostRoute Optimization | PostRoute 优化 |
| chapter_0117.json | Timing Sign Off | 时序签核 |

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
| chapter_0120.json | Hierarchical and Prototyping Flow | 分层和 Prototyping 流程总体 |
| chapter_0121.json | Hierarchical and Prototyping Flow Overview | 分层流程概述 |
| chapter_0122.json | Top-down and Bottom-up Hierarchical Methodologies | 顶层和底层分层方法论 |
| chapter_0123.json | Top-down Methodology | 顶层方法论 |
| chapter_0124.json | Bottom-up Methodology | 底层方法论 |
| chapter_0126.json | Hierarchical Methodologies | 分层方法论详解 |
| chapter_0127.json | Hierarchical Partitioning Flow and Capabilities | 分层分区流程和能力 |
| chapter_0128.json | Hierarchical Partitioning | 分层分区 |
| chapter_0129.json | Chip Planning | 芯片规划 |
| chapter_0130.json | FlexModel | FlexModel 模型 |
| chapter_0136.json | Using Interface Logic Models (ILM) | ILM 使用 |
| chapter_0137.json | Using Flexible Interface Logic Models (FlexILM) | FlexILM 使用 |
| chapter_0139.json | Stylus Hierarchical Database Flow | Stylus 分层数据库流程 |
| chapter_0152.json | Hierarchical Extraction | 分层提取 |

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
| chapter_0357.json | Low Power Design | 低功耗设计总体 |
| chapter_0359.json | Power Domain Shutdown and Scaling | Power Domain 关闭和缩放 |
| chapter_0367.json | Low Power Cell Definition | 低功耗单元定义 |
| chapter_0370.json | Innovus IEEE1801 Low Power Flow | IEEE1801 低功耗流程 |
| chapter_0373.json | Flow Special Handling for Low Power | 低功耗流程特殊处理 |
| chapter_0374.json | Low Power Cells and Usage | 低功耗单元和使用 |
| chapter_0376.json | The Innovus Low Power Flow | Innovus 低功耗流程 |
| chapter_0377.json | Low Power Planning and Routing | 低功耗规划和布线 |
| chapter_0378.json | Low Power Optimization | 低功耗优化 |
| chapter_0379.json | Low Power Design Verification | 低功耗设计验证 |
| chapter_0380.json | Low Power Debugging Commands | 低功耗调试命令 |

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
| chapter_0341.json | Using the ECO Flow for the New Netlist | ECO 流程使用 |
| chapter_0600.json | Running MMMC SignOff ECO within Innovus | MMMC SignOff ECO |
| chapter_0612.json | Top Down Block ECO flow using Tempus Signoff Timing | 顶层 Block ECO 流程 |
| chapter_0613.json | Metal ECO Flow | Metal ECO 流程 |
| chapter_0661.json | Running ECO Routing | ECO 布线 |
| chapter_0662.json | ECO Limitations | ECO 限制 |
| chapter_0663.json | ECO Flow | ECO 流程总体 |

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
| chapter_0120.json | Hierarchical and Prototyping Flow | Prototyping 流程总体 |
| chapter_0132.json | Prototyping Flow | Prototyping Flow 详解 |
| chapter_0133.json | Supporting Giga-Scale Designs in Planning stage | Giga-Scale 设计支持 |
| chapter_0134.json | Active-logic Reduction Technology | Active Logic Reduction 技术 |
| chapter_0135.json | Top-level Timing Closure | 顶层时序收敛 |

**输出格式**：
1. Prototyping Flow 概述（设计简化 → 快速实现 → 验证）
2. Active Logic Reduction 命令和配置
3. Giga-Scale 设计时序收敛指南
