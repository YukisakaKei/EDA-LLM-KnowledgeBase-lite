# Voltus UG (211) Wiki 生成计划

## 约定

- **source**: `knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl`
- 每个 wiki 目标 ~300 行，不超过 500 行
- 生成 agent 应按 JSONL entry index 定位；单个 entry 过大时分段阅读，单批不超过 150KB，避免上下文爆炸
- 标注 `⚠ 大文件` 的章节，agent 可只抽取关键要点，不必全文翻译

---

## Wiki 清单

### 01-introduction.md
**内容**: Voltus 手册说明、文档组织方式、约定、相关文档、产品与许可信息（Voltus IC Power Integrity Solution 产品概述、产品选项、许可类型、许可检出）
**预计行数**: ~150
**source**: `knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl` | entries: [0001, 0002, 0003, 0004, 0005, 0006, 0007, 0008, 0009, 0010, 0011, 0012, 0013, 0014, 0015, 0016, 0017]
**JSONL 参考大小**: ~39 KB

### 02-getting-started.md
**内容**: Voltus 启动方式（产品与安装信息、运行时环境设置、临时文件位置、启动控制台、Tab 补全、命令行编辑、偏好设置、启动软件、访问文档和帮助）、数据准备（功率和 IR Drop 分析所需数据）
**预计行数**: ~250
**source**: `knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl` | entries: [0018, 0019, 0020, 0021, 0022, 0023, 0024, 0025, 0026, 0027, 0028, 0029]
**JSONL 参考大小**: ~147 KB

### 03-gui-and-design-import.md
**内容**: 图形用户界面使用（主窗口、菜单栏、标签页、工具栏、各菜单项功能）、设计导入（导入 Innovus 数据库、导入第三方设计、OpenAccess 数据库操作、导入大型层次化设计、层次化数据库操作、导入 CPF）
**预计行数**: ~300
**source**: `knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl` | entries: [0030, 0031, 0032, 0033, 0034, 0035, 0036, 0037, 0038, 0039, 0040, 0041, 0042, 0043, 0044, 0045, 0046, 0047, 0048, 0049, 0050]
**JSONL 参考大小**: ~101 KB
**注意**: ch0045-ch0048 均来自 `import.html`，文本重叠率高达 57-90%，共有的内容（层次化设计导入流程、save_design/read_design 命令模板、specify_def 用法等）只读取一次，写入 wiki 的设计导入部分作为通用流程，然后各章独有的导入方法差异分别补充。ch0045 内容最全（163 行），以其为主，ch0046-0048 只取差异部分。

### 04-processing-modes.md
**内容**: 分布式处理（概述、设置、多 CPU 模式下的功率分析、独立分布式功率分析、异构分布式处理、多 CPU 模式下的库生成、IR Drop 分析）、Voltus-XP 大规模并行处理（介绍、关键特性、云环境、分区数据库、使用模型、数据隔离、输出目录、弹性资源、GUI 性能、日志、XP 模式 Rail 分析、动态功率和 Rail 分析设置、输出目录结构、分布式 GUI）
**预计行数**: ~300
**source**: `knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl` | entries: [0051, 0052, 0053, 0054, 0055, 0056, 0057, 0058, 0059, 0060, 0061, 0062, 0063, 0064, 0065, 0066, 0067, 0068, 0069, 0070, 0071, 0072, 0073]
**JSONL 参考大小**: ~87 KB

### 05-design-check-and-early-analysis.md
**内容**: 设计健全性检查（Check Design、各种检查命令和流程）、早期功率网格分析（概述、流程、设置、运行、结果查看）
**预计行数**: ~300
**source**: `knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl` | entries: [0074, 0075, 0076, 0077, 0078, 0079, 0080, 0081, 0082, 0083, 0084, 0085, 0086, 0087, 0088, 0089, 0090, 0091, 0092, 0093, 0094, 0095, 0096, 0097, 0098, 0099, 0100]
**JSONL 参考大小**: ~76 KB

### 06a-power-grid-library-basics.md
**内容**: 功率网格库生成基础 — 概述、输入、输出、功率网格库类型、Power-Grid View 类型、生成技术库、生成标准单元功率网格库、为宏单元创建 Power-Grid View
**预计行数**: ~300
**source**: `knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl` | entries: [0101, 0102, 0103, 0104, 0105, 0106, 0107, 0108, 0109]
**JSONL 参考大小**: ~107 KB

### 06b-power-grid-library-characterization.md
**内容**: 功率网格库表征与高级流程 — 宏单元 EM View 电流波形表征、各种 Trigger 文件格式（仿真向量类、用户定义 PWL、FSDB、Datasheet、Spice Deck、Dotlib）、库生成输出报告、从 PGDB/xDSPF 生成 PG View 的流程、多模式 PG View 生成、多电压电容表征、Decap/Filler/Damping Decap 单元表征、Flip Chip 设计 PG 库生成、OA 库生成、检查和报告、查看和调试、库验证
**预计行数**: ~400
**⚠ 大文件**: [0110] 56KB, [0111] 40KB, [0112] 38KB, [0113] 30KB — 每文件只提炼关键命令和流程步骤
**source**: `knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl` | entries: [0110, 0111, 0112, 0113, 0114, 0115, 0116, 0117, 0118, 0119, 0120, 0121, 0122, 0123, 0124, 0125, 0126, 0127]
**JSONL 参考大小**: ~259 KB

### 07a-static-power-calculation.md
**内容**: 静态功耗计算 — 概述、基于向量的平均功耗计算、基于传播的平均功耗计算、静态功耗分析流程、Pre-CTS 网表功耗估算、热分析功耗地图文件、Voltus 热模型生成、查看静态功耗分析结果、功耗数据交互查询、调试实例功耗、保存和恢复功耗数据库、生成独立功耗报告
**预计行数**: ~350
**⚠ 大文件**: [0129] 64KB, [0130] 64KB, [0131] 46KB, [0132] 44KB, [0133] 37KB — 每文件只提炼核心概念和关键命令
**source**: `knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl` | entries: [0128, 0129, 0130, 0131, 0132, 0133, 0134, 0135, 0136, 0137, 0138, 0139, 0140, 0141]
**JSONL 参考大小**: ~323 KB

### 07b-static-rail-em-analysis.md
**内容**: 静态 Rail 和 EM 分析 — 电阻分析（设置、运行、报告、查看）、静态 Rail/EM 分析概述、Rail 分析设置与运行、查看 Rail 分析结果、生成文本报告、功率网格完整性报告、基于层的 IR Drop 报告、HTML 报告、恒流源 IR 分析、Hotspot Debugger
**预计行数**: ~350
**⚠ 大文件**: [0147] 95KB, [0148] 95KB, [0149] 37KB, [0150] 29KB — 前两个文件为核心概述，密切相关的概念可合并提炼，不必逐段翻译
**source**: `knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl` | entries: [0142, 0143, 0144, 0145, 0146, 0147, 0148, 0149, 0150, 0151, 0152, 0153, 0154, 0155, 0156]
**JSONL 参考大小**: ~352 KB

### 08-dynamic-power-analysis.md
**内容**: 动态功耗和 IR Drop 分析 — 概述、动态功耗分析、Vectorless 方法（概率类和状态传播类）、向量驱动方法、向量分析（Profiling、与功耗分析结合、功耗密度感知 Profiling）、动态 Vectorless 功耗分析流程、查看动态电流波形、动态向量类功耗分析流程、查看 Profiling 数据库、Scan Mode 分析、用户自定义 Mode 电流波形生成、动态 Rail 分析（概述、设置运行、并行运行功耗和 Rail 分析、图表和波形、片上电压调节器、使用表征电流 PGV）、动态混合模式分析、噪声容限计算
**预计行数**: ~400
**⚠ 大文件**: [0163] 33KB, [0164] 31KB, [0165] 28KB, [0166] 27KB, [0167] 25KB, [0174] 24KB — 每个提炼关键流程步骤和命令
**source**: `knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl` | entries: [0157, 0158, 0159, 0160, 0161, 0162, 0163, 0164, 0165, 0166, 0167, 0168, 0169, 0170, 0171, 0172, 0173, 0174, 0175, 0176, 0177, 0178, 0179, 0180, 0181, 0182, 0183]
**JSONL 参考大小**: ~308 KB

### 09-extreme-modeling-and-esd.md
**内容**: 使用 Extreme Modeling 进行层次化功率完整性分析（概述、建模方法、分析流程）、ESD 分析（概述、ESD 检查、分析设置与运行、结果查看）
**预计行数**: ~250
**source**: `knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl` | entries: [0184, 0185, 0186, 0187, 0188, 0189, 0190, 0191, 0192, 0193, 0194, 0195, 0196, 0197, 0198, 0199, 0200, 0201]
**JSONL 参考大小**: ~105 KB

### 10-package-analysis.md
**内容**: 封装分析 — 概述、包含封装模型的静态/动态 Rail 分析、简单集总 RLC Pin 封装模型、全分布式耦合 RLCK SPICE 模型、RDL0/Off-Chip 封装走线、封装到芯片映射、Voltus-Sigrity 封装分析流程、封装提取、包含封装模型的 Rail 分析、封装模型分析、查看封装分析结果、从 Voltus 访问 Sigrity 工具、示例脚本、Die-Model 生成（需求、特性、流程）、封装和 Die-Model 的时域/频域分析
**预计行数**: ~300
**source**: `knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl` | entries: [0202, 0203, 0204, 0205, 0206, 0207, 0208, 0209, 0210, 0211, 0212, 0213, 0214, 0215, 0216, 0217, 0218, 0219, 0220, 0221]
**JSONL 参考大小**: ~140 KB

### 11-whatif-and-power-gate.md
**内容**: What-If Rail 分析（概述、场景设置、快速评估）、Power Gate 分析（概述、Power Gate 类型、Power Gate 分析流程、Power Gate 库表征、细粒度存储器表征、稳态分析、CPF 使用、稳态功率/Rail 分析、Native Power-up 分析、GUI 设置 Native Power-up 分析）
**预计行数**: ~300
**source**: `knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl` | entries: [0222, 0223, 0224, 0225, 0226, 0227, 0228, 0229, 0230, 0231, 0232, 0233, 0234, 0235, 0236, 0237, 0238, 0239, 0240]
**JSONL 参考大小**: ~141 KB

### 12-tsv-timing-and-tempus.md
**内容**: Through-Silicon Via 和 System-in-Package（概述、TSV 建模、SiP 分析）、IR Drop 对时序的影响（介绍、Voltus/Tempus 基本流程、IR Drop 对延迟的影响、库设置、MMMC 设置、Skew 分析、Jitter 分析、IR Drop 感知关键路径 Spice 分析、时钟 Jitter Spice 分析、示例脚本）、Tempus Power Integrity 分析（概述、Tempus PI 设置与运行、结果分析）
**预计行数**: ~300
**source**: `knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl` | entries: [0241, 0242, 0243, 0244, 0245, 0246, 0247, 0248, 0249, 0250, 0251, 0252, 0253, 0254, 0255, 0256, 0257, 0258, 0259, 0260, 0261, 0262, 0263, 0264, 0265, 0266, 0267, 0268, 0269, 0270, 0271]
**JSONL 参考大小**: ~113 KB

### 13-ir-aware-eco.md
**内容**: IR 感知 ECO 技术 — IR Drop 感知布局（概述、数据需求、布局流程、调试、示例脚本）、时序感知 IR Drop 修复（IR-aware ECO 流程、Hotspot Debugger 和 ECO 分析、IR Drop 重检查和结果分析、示例脚本）
**预计行数**: ~300
**source**: `knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl` | entries: [0272, 0273, 0274, 0275, 0276, 0277, 0278, 0279, 0280, 0281, 0282, 0283]
**JSONL 参考大小**: ~78 KB

### 14-signal-em.md
**内容**: 信号电迁移分析 — AC 信号 EM（概述、Irms/Ipeak/Iavg 波形计算、有效频率计算、每段布线 Irms/Ipeak/Iavg 计算、AC 电流限制检查、AC 信号 EM 违规预防与修复、示例脚本、Top Scope 分析、结果查看、报告格式）、DC 信号 EM（概述、基于 maxCap/maxTran 限制的分析、Liberty 中基于频率的单元 EM 限制、DC 信号 EM 违规修复、示例脚本）
**预计行数**: ~450
**⚠ 大文件**: [0285] 40KB, [0286] 40KB, [0287] 38KB, [0288] 37KB, [0289] 34KB, [0290] 32KB, [0291] 30KB — AC 信号 EM 的前 7 个文件为各计算步骤详解，每文件提炼计算公式和关键阈值即可
**source**: `knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl` | entries: [0284, 0285, 0286, 0287, 0288, 0289, 0290, 0291, 0292, 0293, 0294, 0295, 0296, 0297, 0298, 0299, 0300, 0301, 0302, 0303, 0304]
**JSONL 参考大小**: ~382 KB

### 15-self-heating-and-seb.md
**内容**: 自热效应分析（概述、FEOL 自热、BEOL 自热、数据需求、分析流程、示例脚本、查看 SHE 分析图表、Delta 温度文件格式）、统计电迁移预算（SEB 介绍、SEB 流程、TCL 命令参数、FIT 计算设置与运行、输出报告、查看 FIT GUI 图）
**预计行数**: ~250
**source**: `knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl` | entries: [0305, 0306, 0307, 0308, 0309, 0310, 0311, 0312, 0313, 0314, 0315, 0316, 0317, 0318, 0319, 0320]
**JSONL 参考大小**: ~50 KB

### 16-body-bias-leakage-rtl.md
**内容**: Body Bias 分析（概述、偏置类型、分析设置与运行）、Leakage Power Scaling（使用 Liberate 库文件进行漏电功耗缩放）、RTL Activity 文件在静态功耗计算中的使用流程
**预计行数**: ~200
**source**: `knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl` | entries: [0321, 0322, 0323, 0324, 0325, 0326, 0327, 0328, 0329]
**JSONL 参考大小**: ~24 KB

### 17-file-formats.md
**内容**: 文件格式参考 — 库生成相关文件格式、功耗分析相关文件格式、Rail 分析相关文件格式（含各种输入输出文件格式说明）
**预计行数**: ~300
**⚠ 大文件**: [0331] 39KB, [0333] 43KB — 以表格形式列出文件格式、关键字段和用途即可
**source**: `knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl` | entries: [0330, 0331, 0332, 0333]
**JSONL 参考大小**: ~108 KB

### 18-gds2def-layermap.md
**内容**: GDS2DEF 工具（用途、使用方法、参数说明）、为 TRIM Metals 层自定义 GDS Layermap 和 XTC Command File
**预计行数**: ~150
**source**: `knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl` | entries: [0334, 0335, 0336, 0337, 0338, 0339, 0340]
**JSONL 参考大小**: ~10 KB

### 19-glossary.md
**内容**: Voltus 术语表，解释工具中使用的关键术语和缩写
**预计行数**: ~250
**source**: `knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl` | entries: [0341]
**JSONL 参考大小**: ~36 KB
