# advanced-topics/ 提取计划

JSON 根目录：`knowledge/Innovus/legacy/json/innovusUG__211/`

**数据来源**：从 toc.json 验证的真实章节号和标题

---

## flip-chip-design.md

**目标**：Flip Chip 设计方法论和流程，覆盖 SiP Bump Flow、Area/Peripheral I/O、bump 创建、RDL 布线等。

**提取章节**：

| 章节号 | 标题 | 提取重点 |
|---|---|---|
| 725 | Flip Chip Methodologies | Flip Chip 总体方法论和概念 |
| 731 | Flip Chip Flow in Innovus | Innovus 中的 Flip Chip 流程 |
| 732 | Introduction to Flip Chip Methodology | Flip Chip 基础概念和术语 |
| 733 | SiP Bump Flow | SiP Bump 流程 |
| 734 | Area I/O Flow | Area I/O 流程 |
| 735 | Peripheral I/O Flow | Peripheral I/O 流程 |
| 740 | Flip Chip Floorplanning | Flip Chip 布局规划 |
| 741 | Bump Creation and Assignment | Bump 创建和分配 |
| 742 | Bump Assignment Optimization | Bump 分配优化 |
| 743 | Viewing Flip Chip Flightlines | Flightline 查看和分析 |

**输出格式**：
1. Flip Chip 设计流程概述（方法论 → Innovus 流程 → 关键步骤）
2. Flip Chip 布局规划和 Bump 操作命令速查
3. Flip Chip 设计最佳实践

---

## 3d-ic-tsv.md

**目标**：3D IC 和 TSV 设计方法论，覆盖 TSV 定义与放置、3D 布局规划、3D 布线、3D 时序与功耗分析。

**提取章节**：

| 章节号 | 标题 | 提取重点 |
|---|---|---|
| 1299 | Design Methodology for 3D IC with Through Silicon Via | 3D IC 和 TSV 总体方法论 |
| 1301 | TSV/Bump/Back Side Metal Modeling in Innovus | TSV/Bump 建模和后侧金属 |
| 1309 | TSV and Bump Manipulation | TSV 和 Bump 操作命令 |
| 1310 | TSV/Bump Generation | TSV/Bump 生成命令 |
| 1311 | TSV/Bump Assignment | TSV/Bump 分配策略 |
| 1313 | TSV and Bump Routing | TSV 和 Bump 布线 |
| 1314 | TSV to IO Pads/ Bumps/ PG Stripes Routing | TSV 到 IO/电源条纹布线 |
| 1316 | TSV/Bump to Instance Pin Routing | TSV/Bump 到实例引脚布线 |

**输出格式**：
1. 3D IC 设计流程概述（TSV 规划 → 布局 → 布线 → 验证）
2. TSV/Bump 操作命令速查表（生成 → 分配 → 布线）
3. 3D 设计约束和配置参考

---

## multi-cpu-processing.md

**目标**：多线程和分布式处理配置，覆盖多 CPU 模式、性能优化、许可证管理。

**提取章节**：

| 章节号 | 标题 | 提取重点 |
|---|---|---|
| 21 | Multi-CPU Matrix | 多 CPU 矩阵和许可证管理 |
| 69 | Limiting the Multi-CPU License Search to Specific Products | 许可证搜索限制 |
| 72 | Where to Find More Information on Multi-CPU Licensing | 许可证信息参考 |
| 445 | Running Placement in Multi-CPU Mode | placement 多 CPU 模式 |
| 1058 | Generating a Capacitance Table in Multi-CPU Mode | 多 CPU 模式下的电容表生成 |

**输出格式**：
1. 多 CPU 配置指南（许可证 → 模式设置 → 性能优化）
2. 各阶段多 CPU 命令速查（placement → routing → analysis）
3. 多 CPU 性能调优参考

---

## signoff-integration.md

**目标**：Signoff 工具集成（Tempus、Quantus、Voltus），覆盖时序签核、寄生参数提取、功耗分析、ECO 流程。

**提取章节**：

| 章节号 | 标题 | 提取重点 |
|---|---|---|
| 118 | Final Timing Analysis and Optimization using Tempus/Quantus | Tempus/Quantus 时序分析和优化 |
| 599 | Using Signoff Timing Analysis to Optimize Timing and Power | Signoff 时序分析 |
| 600 | Running MMMC SignOff ECO within Innovus | Signoff ECO 流程 |
| 602 | Signoff Timing Analysis in Innovus using Timing Debug | Signoff 时序调试 |
| 612 | Top Down Block ECO flow using Tempus Signoff Timing | 顶层 ECO 流程 |
| 688 | Creating RC Model Data in TQuantus Model File | TQuantus 模型文件创建 |
| 689 | Use model for TQuantus Model File | TQuantus 模型使用 |
| 715 | Signoff Fill - Pegasus Hierarchical Metal Fill | Signoff Metal Fill |
| 1039 | TQuantus Extraction | TQuantus 提取命令 |
| 1040 | TQuantus versus IQuantus | TQuantus 和 IQuantus 对比 |
| 1041 | Standalone Quantus for Signoff Extraction | 独立 Quantus 提取 |
| 1049 | Reading a Quantus Techfile | Quantus Techfile 读取 |
| 1120 | Signoff-Rail Analysis | Voltus 功耗和电源分析 |
| 1122 | Innovus and Voltus Menu Differences | Innovus 和 Voltus 菜单差异 |

**输出格式**：
1. Signoff 工具集成流程（Tempus 时序 → Quantus 寄生 → Voltus 功耗）
2. Signoff ECO 命令序列（时序修复 → 功耗优化 → 验证）
3. Tempus/Quantus/Voltus 命令速查表
