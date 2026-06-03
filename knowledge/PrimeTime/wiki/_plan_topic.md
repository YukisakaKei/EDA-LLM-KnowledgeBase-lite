# PrimeTime htmlView_20 Topic Wiki 生成计划

## 约定

- **source**: `knowledge/PrimeTime/json/htmlView_20/topic`
- 每个 wiki 目标 ~300 行，不超过 500 行
- 生成 agent 应分批读取 JSON，单批不超过 150KB，避免上下文爆炸
- 总计 17 个条目，总大小 ~50 KB，整体规模很小，无需特殊处理大文件

---

## Wiki 清单

### 01-collections-and-wildcards.md
**内容**: PrimeTime 核心概念 — Collections（数据库对象集合的定义、同质/异质集合、生命周期管理、遍历方法 foreach_in_collection、集合操作命令 add_to_collection/remove_from_collection/filter_collection/sort_collection 等、过滤表达式语法与关系运算符、隐式查询机制）、Wildcards（通配符 * 和 ? 的用法、支持通配符的命令列表、通配符转义方法）
**预计行数**: ~200
**source**: `knowledge/PrimeTime/json/htmlView_20/topic` | entries: [0009, 0017]
**JSON 总大小**: ~16 KB

### 02-check-violations.md
**内容**: PrimeTime 检查违规类型完整参考 — 涵盖全部 15 种违规类型：auto_fixable_violations（可自动修复违规概述）、non_auto_fixable_violations（不可自动修复违规概述）、boundary_ideal_network_violations（边界理想网络违规）、boundary_logic_value_violations（边界逻辑值冲突违规）、clock_latency_violations（时钟延迟违规）、clock_mapping_violations（时钟映射违规）、clock_relations_violations（时钟关系违规）、clock_skew_with_uncertainty_violations（带不确定度的时钟偏斜违规）、clock_uncertainty_violations（时钟不确定度违规）、data_arrival_violations（数据到达违规）、env_variables_violations（环境变量违规）、global_timing_derate_violations（全局时序降额违规）、input_slews_violations（输入斜率违规）、library_mapping_violations（库映射违规）、operating_conditions_violations（工作条件违规）。每种违规说明其含义、触发条件和修复建议。
**预计行数**: ~350
**source**: `knowledge/PrimeTime/json/htmlView_20/topic` | entries: [0001, 0002, 0003, 0004, 0005, 0006, 0007, 0008, 0010, 0011, 0012, 0013, 0014, 0015, 0016]
**JSON 总大小**: ~33 KB
