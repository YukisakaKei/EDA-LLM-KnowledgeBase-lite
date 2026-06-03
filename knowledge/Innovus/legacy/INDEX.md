# Innovus 知识库索引

## JSON 切片内容（完整参考）

### innovusUG__211
Innovus 用户指南，涵盖安装配置、设计流程、工具使用等完整内容。

### innovusTCR__211
Innovus Tcl 命令参考 ，包含所有可用的 Tcl 命令及其语法说明。

### innovusDBAref__211
Innovus 数据库 API 参考，提供数据库查询和修改的 API 接口文档。

### dbSchema__211
Innovus 数据库架构，描述数据库对象结构和属性定义。

---

## Wiki 快速参考（优先阅读）

### scripting-guide（脚本编写指南）
- **00-db-api-primer.md** — DB API 核心速查，`dbGet` 和 `dbSet` 命令
- **01-eco-scripts.md** — ECO 流程脚本编写示例
- **02-floorplan-scripts.md** — 芯片规划脚本编写示例
- **03-placement-scripts.md** — 放置脚本编写示例
- **04-net-wire-scripts.md** — 网络和布线脚本编写示例
- **05-report-scripts.md** — 查询和报告脚本，使用 `get_cells`、`get_nets`、`get_pins` 等命令
- **06-skew-scripts.md** — 时钟树 skew 和 CCOpt 属性脚本指南
- **07-common-patterns.md** — 通用 Tcl 脚本模式和最佳实践

### commands（命令参考）
- **analysis-commands.md** — 时序分析、功耗分析等分析命令
- **cts-commands.md** — 时钟树综合相关命令
- **placement-commands.md** — 放置相关命令
- **power-commands.md** — 功耗管理命令
- **routing-commands.md** — 布线相关命令
- **timing-opt-commands.md** — PreCTS 和 PostCTS 时序优化命令

### concepts（概念说明）
- **hierarchy-concepts.md** — 层级设计概念
- **placement-concepts.md** — 放置相关概念
- **power-concepts.md** — 功耗管理概念
- **routing-concepts.md** — 布线相关概念
- **timing-concepts.md** — MMMC 时序模型和时序分析基础

### flows（设计流程）
- **eco-flow.md** — ECO（工程变更单）流程
- **hierarchical-flow.md** — 分层设计流程
- **low-power-flow.md** — 低功耗设计流程
- **prototyping-flow.md** — 原型设计流程
- **standard-impl-flow.md** — 标准实现流程，包括布局、优化、CTS、布线等完整步骤

### advanced-topics（高级主题）
- **3d-ic-tsv.md** — 3D IC 和通硅孔（TSV）设计
- **flip-chip-design.md** — 倒装芯片设计
- **multi-cpu-processing.md** — 多处理器设计
- **optDesign-vs-timeDesign-timing-diff.md** — optDesign -postRoute 与时序签核工具时序差异诊断
- **signoff-integration.md** — 签核集成

### reference（参考资料）
- **ccopt-properties.md** — 时钟树优化属性
- **constraint-syntax.md** — 约束语法
- **cpf-commands.md** — CPF（通用功耗格式）命令
- **file-formats.md** — 支持的文件格式
