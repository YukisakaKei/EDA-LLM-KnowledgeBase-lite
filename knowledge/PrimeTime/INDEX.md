# PrimeTime 知识库索引

## JSON 切片内容（完整参考）

### htmlView_20

PrimeTime htmlView 格式手册，包含命令、属性、变量、消息等完整参考文档。

#### command（命令参考）
769 个 PrimeTime 命令条目，包含命令语法、参数说明、使用示例等。每个命令对应一个独立的 JSON 文件（如 `create_clock`、`set_input_delay`、`report_timing` 等）。

#### attribute（属性列表）
35 个属性列表条目，描述 PrimeTime 对象的可查询属性（如 `cell_attributes`、`pin_attributes`、`net_attributes` 等）。

#### variable（变量说明）
513 个变量条目，说明 PrimeTime 环境变量的用途和取值（如 `timing_report_fields`、`case_analysis_propagate_through_icg` 等）。

#### topic（概念主题）
17 个概念主题条目，介绍 PrimeTime 的核心概念和工作原理（如 `collections`、`timing_paths`、`clock_gating` 等）。

#### shell（Shell 命令）
2 个 Shell 命令条目，说明 PrimeTime 可执行文件的启动参数和选项（`primetime`、`pt_shell`）。

#### message（错误和警告消息）
6430 个消息条目，按类别组织（ADES、AOCVM、CPPR、DFT、LBDB、MWUI、OPT、PTE、TIM、UI、XTALK 等），每个消息包含消息编号、严重级别、原因和解决方法。

---

## Wiki 快速参考（优先阅读）

### topic（概念主题）

- [01-collections-and-wildcards](wiki/01-collections-and-wildcards.md) — Collections 集合系统（生命周期、遍历、操作、过滤、排序、隐式查询）与 Wildcards 通配符用法
- [02-check-violations](wiki/02-check-violations.md) — HyperScale 全部 15 种检查违规类型参考：含时钟/边界/时序/约束四类，每个违规说明含义、触发条件与修复方案
