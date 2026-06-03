# concepts/ 提取计划

JSON 根目录：`knowledge/Innovus/legacy/json/innovusUG__211/`

**数据来源**：从 toc.json 验证的真实章节号和标题

---

## timing-concepts.md

**目标**：时序分析核心概念，覆盖 MMMC、OCV、CPPR、path exception、时序分析模式、调试方法。

**提取章节**：

| 章节号 | 标题 | 提取重点 |
|---|---|---|
| 1358 | Preparing Timing Libraries | 时序库准备和配置 |
| 1374 | Preparing Timing Constraints | 时序约束准备 |
| 1582 | Adding a Power Domain Definition to a Delay Calculation Corner | 功率域时序配置 |
| 1702 | Saving and Restoring Timing Graph | 时序图保存和恢复 |
| 2942 | Timing Information | 时序信息概述 |
| 968 | AOCV Derating Mode | AOCV 降额模式 |
| 970 | Points to be Considered for Block Level AOCV Run | 块级 AOCV 考虑因素 |
| 974 | Extracted Timing Models with Noise (SI) Effect | 噪声效应时序模型 |
| 975 | Merging Timing Models | 时序模型合并 |
| 979 | Validation Flow - MMMC Designs | MMMC 设计验证流程 |
| 1008 | What-If Timing Analysis | What-If 时序分析 |
| 1012 | Using the What-If Timing Commands | What-If 时序命令使用 |
| 1013 | Fast Slack Timing Analysis | 快速 Slack 时序分析 |
| 1014 | Fast Slack Timing Analysis Overview | 快速 Slack 分析概述 |

**输出格式**：
1. 时序分析基础概念（MMMC → OCV/CPPR → 约束 → 库）
2. 时序模式和降额方法（AOCV → SI 效应 → 模型合并）
3. 时序调试和验证（What-If 分析 → Fast Slack → 图保存恢复）

---

## power-concepts.md

**目标**：低功耗设计核心概念，覆盖 Power domain、isolation cell、level shifter、CPF vs UPF、MSV。

**提取章节**：

| 章节号 | 标题 | 提取重点 |
|---|---|---|
| 357 | Low Power Design | 低功耗设计总章节 |
| 358 | Overview | 低功耗设计概述 |
| 359 | Power Domain Shutdown and Scaling | 功率域关闭和缩放 |
| 360 | Support for the Common Power Format (CPF) | CPF 支持 |
| 361 | CPF Version Support | CPF 版本支持 |
| 362 | Innovus Commands Supporting CPF | 支持 CPF 的 Innovus 命令 |
| 363 | Loading and Committing a CPF File | CPF 文件加载和提交 |
| 364 | Load the design (init_design) | 设计加载 |
| 365 | CPF Documentation | CPF 文档 |
| 366 | Support for IEEE1801 | IEEE1801 支持 |
| 367 | Low Power Cell Definition | 低功耗单元定义 |
| 368 | Timing Information | 时序信息 |
| 369 | Load the Design for IEEE1801 Using the init_design Command | IEEE1801 设计加载 |
| 370 | Innovus IEEE1801 Low Power Flow | IEEE1801 低功耗流程 |
| 371 | Innovus IEEE1801 Command Set Support | IEEE1801 命令集支持 |
| 372 | IEEE1801 Documentation | IEEE1801 文档 |
| 411 | Power Domain Parameters and Specification | 功率域参数和规范 |
| 412 | Options Summary - Switch and Power Domain | 开关和功率域选项总结 |

**输出格式**：
1. 低功耗设计基础（功率域 → 关闭策略 → 缩放）
2. CPF 和 IEEE1801 标准（版本对比 → 命令支持 → 文件加载）
3. 低功耗单元和时序（单元定义 → 时序处理 → 验证）

---

## hierarchy-concepts.md

**目标**：分层设计核心概念，覆盖 Top-down vs bottom-up、partition、black box、feedthrough、ETM、时序预算。

**提取章节**：

| 章节号 | 标题 | 提取重点 |
|---|---|---|
| 126 | Hierarchical Methodologies | 分层方法论 |
| 127 | Hierarchical Partitioning Flow and Capabilities | 分层分区流程和能力 |
| 128 | Hierarchical Partitioning | 分层分区 |
| 129 | Chip Planning | 芯片规划 |
| 130 | FlexModel | FlexModel 模型 |
| 131 | Timing Net Delay Model with Pico-second Per Micron (psPM) | psPM 时序延迟模型 |
| 136 | Using Interface Logic Models (ILM) | ILM 接口逻辑模型 |
| 137 | Using Flexible Interface Logic Models (FlexILM) | FlexILM 灵活接口逻辑模型 |
| 138 | Chip Assembly | 芯片组装 |
| 139 | Stylus Hierarchical Database Flow | Stylus 分层数据库流程 |
| 140 | Overview | 概述 |
| 141 | Stylus Hierarchical Database Flow: Examples | Stylus 分层数据库流程示例 |
| 142 | Stylus Hierarchical Database Repository Management | Stylus 分层数据库仓库管理 |
| 1926 | Adding Logical Hierarchy Without Creating Additional Hierarchy | 添加逻辑分层 |
| 1934 | Logical Hierarchy Manipulation | 逻辑分层操作 |

**输出格式**：
1. 分层设计方法论（Top-down → Bottom-up → 分区策略）
2. 分层模型和接口（ILM → FlexILM → FlexModel → psPM）
3. 分层数据库和芯片规划（Stylus HDB → 芯片规划 → 逻辑分层）

---

## placement-concepts.md

**目标**：布局核心概念，覆盖 GigaPlace、Mixed Placer、blockage、halo、padding、well-tap、end-cap、filler。

**提取章节**：

| 章节号 | 标题 | 提取重点 |
|---|---|---|
| 340 | Using the GigaPlace Placer | GigaPlace 布局器 |
| 341 | GigaPlace Placer Overview | GigaPlace 概述 |
| 342 | GigaPlace Placer Capabilities | GigaPlace 能力 |
| 343 | GigaPlace Placer Limitations | GigaPlace 限制 |
| 344 | Using the Mixed Placer | Mixed Placer 混合布局器 |
| 345 | Mixed Placer Overview | Mixed Placer 概述 |
| 346 | Mixed Placer Capabilities | Mixed Placer 能力 |
| 347 | Mixed Placer Limitations | Mixed Placer 限制 |
| 348 | Macro Orientation Constraints | 宏方向约束 |
| 349 | Maximum Stacking Length | 最大堆叠长度 |
| 350 | Fixed Macro Location | 固定宏位置 |
| 351 | I/O Pin Keep-out | I/O 引脚禁区 |
| 352 | Macro Placement Halo | 宏布局光晕 |
| 353 | Mixed Place Constraints Support List | Mixed Place 约束支持列表 |
| 3406 | Guiding Placement With Blockages | 使用阻挡指导布局 |
| 3414 | Placement Treatment of Preroutes | 预布线的布局处理 |
| 3510 | Spare Cell Placement Behavior | 备用单元布局行为 |
| 3518 | Running Hierarchy-Aware Spare Cell Placement | 分层感知备用单元布局 |

**输出格式**：
1. 布局器选择和配置（GigaPlace → Mixed Placer → 能力对比）
2. 布局约束和指导（Blockage → Halo → 宏约束 → 预布线处理）
3. 特殊单元和优化（Well-tap → End-cap → Filler → 备用单元）

---

## routing-concepts.md

**目标**：布线核心概念，覆盖 NanoRoute、global route vs detail route、track assignment、metal fill、via 优化。

**提取章节**：

| 章节号 | 标题 | 提取重点 |
|---|---|---|
| 846 | Detailed Routing | 详细布线 |
| 854 | Routing Command Sequence | 布线命令序列 |
| 862 | Improving Timing during Routing | 布线中改进时序 |
| 756 | Power Routing | 电源布线 |
| 757 | ECO Routing | ECO 布线 |
| 762 | Two-Layer RDL Routing | 两层 RDL 布线 |
| 763 | Routing Bumps in the eWLB Process | eWLB 工艺中的 Bump 布线 |
| 765 | fcroute Bus Routing for DDR3 | DDR3 总线布线 |
| 677 | Performing Shielded Routing Using Text Commands | 屏蔽布线 |
| 679 | Routing Wide Wires | 宽线布线 |
| 685 | Deleting and Rerouting Nets with Violations | 删除和重新布线违反的网络 |
| 795 | Inserting Routing Feedthroughs | 插入布线馈通 |
| 807 | Estimating the Routing Channel Width | 估计布线通道宽度 |

**输出格式**：
1. 布线基础（NanoRoute 概述 → Global Route → Detail Route → 命令序列）
2. 布线优化和特殊处理（时序改进 → 屏蔽布线 → 宽线处理 → 馈通）
3. 特殊布线应用（电源布线 → ECO 布线 → RDL → Bump 布线）

---

## 验证清单

创建 wiki 文件前，需验证：

- [ ] 所有章节号从 toc.json 确认无误
- [ ] 每个文件的章节号范围合理（无重复、无遗漏）
- [ ] 章节标题准确反映内容主题
- [ ] 提取重点与 wiki 文件目标对齐
- [ ] 输出格式清晰、逻辑递进
