# commands/ 提取计划

JSON 根目录：`knowledge/Innovus/legacy/json/innovusUG__211/`

**数据来源**：从 toc.json 验证的真实章节号和标题

---

## placement-commands.md

**目标**：Placement 阶段的命令速查表，覆盖 floorplan、place_design、well-tap、end-cap、filler、spare cell 等操作。

**提取章节**：

| 章节号 | 标题 | 提取重点 |
|---|---|---|
| 89 | Floorplanning and Initial Placement | Floorplan 命令和策略 |
| 91 | Validating the Floorplan | Floorplan 验证命令 |
| 93 | Placement Analysis | Placement 分析命令 |
| 428 | Adding Well-Tap Cells | Well-tap 插入命令 |
| 429 | Controlling the Distance Between Well-Tap Cells | Well-tap 距离控制 |
| 433 | Adding End Cap Cells to MSV Designs | End-cap 插入命令 |
| 434 | Adding Different Kinds of End Cap Cells | End-cap 类型和参数 |
| 436 | Placing Spare Cells and Spare Modules | Spare cell 放置命令 |
| 437 | Placing Spare Cells That Are Included in the Netlist | Spare cell 管理 |
| 450 | Adding Filler Cells | Filler cell 插入命令 |
| 451 | Adding Fillers to MSV Designs | Filler 多电压域支持 |
| 452 | Deleting Filler Cells | Filler cell 删除命令 |

**输出格式**：
1. Placement 命令序列（floorplan → place_design → well-tap/end-cap/filler）
2. Placement 参数速查表（GigaPlace、Mixed Placer 参数）
3. Placement 检查和调试命令

---

## cts-commands.md

**目标**：Clock Tree Synthesis (CTS) 和 CCOpt 命令速查，覆盖 CTS 流程、CCOpt 配置、clock tree specification、postCTS 优化。

**提取章节**：

| 章节号 | 标题 | 提取重点 |
|---|---|---|
| 98 | Clock Tree Synthesis | CTS 总体流程和命令 |
| 99 | Configuring CCOpt-CTS or CCOpt | CCOpt 配置和参数 |
| 100 | Running CCOpt-CTS or CCOpt | CCOpt 运行命令 |
| 101 | Reporting after CCOpt-CTS or CCOpt | CCOpt 报告命令 |
| 102 | Visualization of Clock Trees after CCOpt-CTS or CCOpt | Clock tree 可视化 |
| 103 | PostCTS Optimization | PostCTS 优化命令 |
| 104 | PostCTS SDC Constraints | PostCTS 约束定义 |
| 105 | PostCTS Setup Optimization Command Sequences | PostCTS setup 优化 |

**输出格式**：
1. CTS 命令序列（specifyClockTree → ccOpt → postCTS 优化）
2. CCOpt 参数和属性速查表
3. Clock tree 调试和验证命令

---

## routing-commands.md

**目标**：Routing 阶段的命令速查表，覆盖 routeDesign、NanoRoute 参数、ECO routing、via 优化、metal fill。

**提取章节**：

| 章节号 | 标题 | 提取重点 |
|---|---|---|
| 623 | Global Routing | Global route 命令和参数 |
| 624 | Detailed Routing | Detail route 命令和参数 |
| 107 | Detailed Routing | Routing 详细步骤 |
| 108 | Routing Command Sequence | Routing 命令序列 |
| 109 | Improving Timing during Routing | Timing-driven routing 命令 |
| 670 | Concurrent Routing and Multi-Cut Via Insertion | 并发 routing 和 via 插入 |
| 671 | Postroute Via Optimization | Via 优化命令 |
| 672 | Optimizing Vias in Selected Nets | 选择性 via 优化 |
| 698 | Adding Metal Fill in the Multiple-CPU Processing Mode | Metal fill 命令 |
| 700 | Metal Fill Features | Metal fill 特性 |
| 704 | Specifying Metal Fill Parameters | Metal fill 参数 |
| 715 | Signoff Fill - Pegasus Hierarchical Metal Fill | Signoff metal fill |

**输出格式**：
1. Routing 命令序列（routeDesign → via 优化 → metal fill）
2. NanoRoute 参数速查表
3. Routing 检查和调试命令

---

## timing-opt-commands.md

**目标**：Timing Optimization 命令速查，覆盖 optDesign 各阶段、setup/hold 优化、功耗优化、signoff ECO。

**提取章节**：

| 章节号 | 标题 | 提取重点 |
|---|---|---|
| 88 | Pre-Placement Optimization | Pre-placement 优化命令 |
| 94 | Guidelines for PreCTS Optimization | PreCTS 优化指南 |
| 95 | PreCTS optDesign Command Sequences | PreCTS optDesign 命令 |
| 103 | PostCTS Optimization | PostCTS 优化命令 |
| 105 | PostCTS Setup Optimization Command Sequences | PostCTS setup 优化 |
| 106 | Hold Optimization | Hold 优化命令 |
| 112 | PostRoute Optimization | PostRoute 优化命令 |
| 114 | PostRoute Optimization Command Sequences | PostRoute 命令序列 |
| 115 | Analysis and Debug of PostRoute Optimization Results | PostRoute 调试命令 |

**输出格式**：
1. Timing opt 命令序列（optDesign 各阶段）
2. Setup/Hold 优化参数速查表
3. 功耗优化和 signoff ECO 命令

---

## analysis-commands.md

**目标**：Analysis 命令速查表，覆盖 RC 提取、时序分析、功耗分析、串扰分析、物理分析。

**提取章节**：

| 章节号 | 标题 | 提取重点 |
|---|---|---|
| 86 | Timing Analysis | 时序分析命令 |
| 111 | Checking Timing | 时序检查命令 |
| 1030 | RC Extraction | RC 提取命令和参数 |
| 1137 | RC Extraction Settings | RC 提取参数设置 |
| 175 | Preparing Data for Crosstalk Analysis | 串扰分析准备 |
| 1133 | Analyzing and Repairing Crosstalk | 串扰分析和修复命令 |
| 1142 | Preventing Crosstalk Violations | 串扰预防命令 |
| 1143 | Fixing Crosstalk Violations | 串扰修复命令 |
| 628 | Checking for Problems with Cells, Pins, and Vias | 物理检查命令 |

**输出格式**：
1. Analysis 命令序列（RC 提取 → 时序分析 → 功耗分析）
2. Analysis 参数和选项速查表
3. Analysis 结果查看和调试命令

---

## power-commands.md

**目标**：Power 相关命令速查表，覆盖 CPF/UPF 加载、power domain 管理、特殊单元插入、power switch、低功耗验证。

**提取章节**：

| 章节号 | 标题 | 提取重点 |
|---|---|---|
| 357 | Low Power Design | 低功耗设计总体流程 |
| 359 | Power Domain Shutdown and Scaling | Power domain 定义和管理 |
| 360 | Support for the Common Power Format (CPF) | CPF 加载和命令 |
| 361 | CPF Version Support | CPF 版本支持 |
| 362 | Innovus Commands Supporting CPF | CPF 相关命令 |
| 363 | Loading and Committing a CPF File | CPF 文件加载命令 |
| 370 | Innovus IEEE1801 Low Power Flow | UPF 支持和命令 |
| 374 | Low Power Cells and Usage | 低功耗单元定义 |
| 376 | The Innovus Low Power Flow | 低功耗流程 |
| 377 | Low Power Planning and Routing | 低功耗 planning 和 routing |
| 378 | Low Power Optimization | 低功耗优化命令 |
| 379 | Low Power Design Verification | 低功耗验证命令 |
| 407 | Adding Power Switch Rings | Power switch 插入命令 |
| 412 | Options Summary - Switch and Power Domain | Power domain 参数总结 |

**输出格式**：
1. Power domain 管理命令序列（CPF/UPF 加载 → domain 定义 → 特殊单元插入）
2. CPF/UPF 命令和参数速查表
3. 低功耗验证和调试命令
