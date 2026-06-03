# Voltus 知识库索引

## JSON 切片内容（完整参考）

### voltusKPNS__211
Voltus 已知问题与解决方案文档，描述 Voltus IC Power Integrity Solution 的重要 Cadence Change Requests (CCRs)，并提供问题解决方案和变通方法。

### voltustxtcmdref__211
Voltus 文本命令参考手册，描述 Voltus IC Power Integrity Solution 的全芯片、单元级功率签核工具的文本命令语法，按功能分类，每章内按字母顺序列出命令。

### voltusUG__211
Voltus 用户指南，描述如何使用 Voltus IC Power Integrity Solution 工具对 ASIC 设计进行门级功率网格分析，以确定功率网格是否充分。

---

## Wiki 快速参考（优先阅读）

### voltusUG__211

- [01-introduction](wiki/voltusUG__211/01-introduction.md) — Voltus 产品概述、文档组织方式、许可类型与版本信息
- [02-getting-started](wiki/voltusUG__211/02-getting-started.md) — 启动方式、运行时环境设置、数据准备与输入文件要求
- [03-gui-and-design-import](wiki/voltusUG__211/03-gui-and-design-import.md) — GUI 界面使用、从 Innovus/第三方导入设计、层次化数据库操作
- [04-processing-modes](wiki/voltusUG__211/04-processing-modes.md) — 分布式多 CPU 处理、Voltus-XP 大规模并行处理与云环境
- [05-design-check-and-early-analysis](wiki/voltusUG__211/05-design-check-and-early-analysis.md) — 设计健全性检查（Check Design）、早期功率网格分析（ERA）
- [06a-power-grid-library-basics](wiki/voltusUG__211/06a-power-grid-library-basics.md) — PG 库生成基础：PGV 类型、技术库/标准单元/宏单元的库生成
- [06b-power-grid-library-characterization](wiki/voltusUG__211/06b-power-grid-library-characterization.md) — PG 库表征与高级流程：EM View 电流表征、Trigger 文件格式、多模式 PGV、Flip Chip 等
- [07a-static-power-calculation](wiki/voltusUG__211/07a-static-power-calculation.md) — 静态功耗计算：Vector-based/Propagation-based 方法、Pre-CTS 估算、热分析
- [07b-static-rail-em-analysis](wiki/voltusUG__211/07b-static-rail-em-analysis.md) — 静态 Rail/EM 分析：电阻分析、IR Drop/Ground Bounce、Hotspot Debugger
- [08-dynamic-power-analysis](wiki/voltusUG__211/08-dynamic-power-analysis.md) — 动态功耗与 IR Drop 分析：Vectorless/Vector-Driven 方法、动态 Rail、噪声容限
- [09-extreme-modeling-and-esd](wiki/voltusUG__211/09-extreme-modeling-and-esd.md) — Extreme Modeling (xPGV) 层次化 PI 分析与 ESD 检查
- [10-package-analysis](wiki/voltusUG__211/10-package-analysis.md) — 封装分析：封装模型、Voltus-Sigrity 流程、Die-Model 生成
- [11-whatif-and-power-gate](wiki/voltusUG__211/11-whatif-and-power-gate.md) — What-If Rail 快速评估与 Power Gate 分析（含稳态/Native Power-up）
- [12-tsv-timing-and-tempus](wiki/voltusUG__211/12-tsv-timing-and-tempus.md) — TSV/SiP 分析、IR Drop 对时序影响（Skew/Jitter/SPICE）与 Tempus PI
- [13-ir-aware-eco](wiki/voltusUG__211/13-ir-aware-eco.md) — IR 感知布局与 Timing-aware IR Drop ECO 修复流程
- [14-signal-em](wiki/voltusUG__211/14-signal-em.md) — 信号 EM 分析：AC 信号 EM（Irms/Ipeak/Iavg）与 DC 信号 EM（maxCap/maxTran）
- [15-self-heating-and-seb](wiki/voltusUG__211/15-self-heating-and-seb.md) — 自热效应（SHE）分析与统计电迁移预算（SEB/FIT）
- [16-body-bias-leakage-rtl](wiki/voltusUG__211/16-body-bias-leakage-rtl.md) — Body Bias 分析、Leakage Power Scaling 与 RTL Activity 文件流程
- [17-file-formats](wiki/voltusUG__211/17-file-formats.md) — 文件格式参考：库生成、功耗分析、Rail 分析相关格式汇总
- [18-gds2def-layermap](wiki/voltusUG__211/18-gds2def-layermap.md) — GDS2DEF 转换工具与 TRIM Metals 层的自定义 Layermap/XTC 配置
- [19-glossary](wiki/voltusUG__211/19-glossary.md) — Voltus 术语表，涵盖电源完整性、EM/IR、PGV、时序等关键概念
