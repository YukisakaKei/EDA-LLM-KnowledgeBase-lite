---
source: knowledge/Innovus/legacy/jsonl/innovusUG__211.jsonl | entries: [0360, 0361, 0362, 0363, 0364, 0365, 0366, 0367, 0368]
---

# CPF 命令参考

## CPF 概述

CPF（Common Power Format）是 Cadence 提供的通用功率格式，用于在支持低功耗设计流程的 Cadence 工具之间交换数据。CPF 文件捕获所有与设计和工艺相关的功率约束，可在整个设计流程中使用。

### CPF 的主要功能

- 创建功率域并指定其功率/地连接
- 指定时序库（可选；用户也可在 Innovus viewDefinition.tcl 中定义）
- 为每个功率域创建分析视图并定义库集（可选）
- 定义工作条件（可选；用户也可在 Innovus viewDefinition.tcl 中定义）
- 定义低功耗单元
- 创建低功耗规则：隔离规则、电平转换器规则、SRPG 规则、功率开关规则

---

## CPF 版本支持

Innovus 支持以下 CPF 版本：

| 版本 | 说明 |
|------|------|
| CPF 1.0 | 基础版本 |
| CPF 1.0e | 扩展版本 |
| CPF 1.1 | **默认版本** |
| CPF 2.0 | 最新版本 |

---

## CPF 命令速查表

### 核心命令

| 命令 | 功能 |
|------|------|
| `read_power_intent -cpf` | 读取 CPF 文件到 Innovus 进行错误检查 |
| `commit_power_intent` | 在 Innovus 环境中执行（提交）CPF 命令 |
| `write_power_intent -cpf` | 将功率意图写出为 CPF 文件 |

### GUI 入口

- **Power → Multiple Supply Voltage → Load/Commit CPF**

---

## CPF 加载和提交流程

### 基本步骤

1. **读取 CPF 文件**
   ```tcl
   read_power_intent -cpf <cpf_file>
   ```
   - 将 CPF 文件读入 Innovus 进行错误检查
   - 不会立即应用 CPF 命令

2. **提交 CPF**
   ```tcl
   commit_power_intent
   ```
   - 在 Innovus 环境中执行 CPF 命令
   - 应用所有功率约束和配置

3. **写出 CPF 文件**
   ```tcl
   write_power_intent -cpf <output_file>
   ```
   - 将当前功率意图导出为 CPF 格式

---

## 设计初始化（init_design）

### init_design 与 CPF 的交互

`init_design` 命令在处理 CPF 时的行为：

1. **如果存在 viewDefinition.tcl**
   - `init_design` 不会调用特殊的 `read_power_intent -cpf` 重新生成 viewDefinition.tcl
   - viewDefinition.tcl 优先级更高

2. **如果不存在 viewDefinition.tcl**
   - `init_design` 调用特殊的 `read_power_intent -cpf` 基于 CPF 生成 viewDefinition.tcl
   - CPF 必须包含 `create_analysis_view` 命令

3. **同时提供 viewDefinition.tcl 和 CPF**
   - viewDefinition.tcl 优先级更高
   - `init_design` 不调用特殊的 `read_power_intent -cpf`

4. **都不存在时**
   - `init_design` 报错

### 库路径配置

为了提高设计可移植性，可在 TCL 中设置库主路径：

```tcl
set libDir "libs/"
# viewDefinition.tcl 将引用 tcl 变量 (libDir)
# 所有库规范如：create_library_set -library $libDir/ …
```

工艺变更时，只需重新定义库主路径，无需修改其他内容。

### 重要注意事项

- **MMMC 流程**：自 11.1 版本起，Innovus 仅支持 MMMC，低功耗也仅支持 MMMC 流程
- **CPF 与 viewDefinition.tcl 的关系**：
  - 从 14.1 及以上版本推荐：CPF 仅指定功率意图（library-less），所有时序信息在 viewDefinition.tcl 中指定
  - 如果 CPF 没有分析视图且设计没有 viewDefinition.tcl，`commit_power_intent` 报错

---

## 低功耗单元定义

所有低功耗（LP）单元及相关功率引脚信息需在 Liberty 文件中使用 Liberty LP 属性定义。

---

## IEEE 1801 支持

### 概述

IEEE 1801 标准从 13.2 及以上版本支持，用于指定设计的功率意图。

### IEEE 1801 流程

```tcl
init_design
# 使用 "set init_mmmc_file viewDefinition.tcl" 指定 MMMC 设置

read_power_intent -1801 <IEEE1801_file>
commit_power_intent

# IEEE 1801 低功耗流程的其余部分（与 CPF 流程相同）
```

### 时序信息配置

在 Innovus MMMC viewDefinition.tcl 文件中定义时序信息：

```tcl
set init_mmmc_file viewDefinition.tcl
```

**注意**：功率域库绑定必须通过 `update_delay_corner` 命令为每个功率域指定，然后再定义时序信息。

### IEEE 1801 命令支持

Innovus 主要支持 IEEE 1801 2.0 命令和选项的精选集合。为了兼容性，也支持部分 IEEE 1801 1.0 和 2.1 命令。

#### 支持的主要命令

| 命令 | IEEE 版本 |
|------|-----------|
| `add_port_state` | 1.0 |
| `add_power_state` | 2.0 |
| `apply_power_model` | 2.1 |
| `add_pst_state` | 1.0 |
| `associate_supply_set` | 2.0 |
| `begin_power_model` | 2.1 |
| `connect_logic_net` | 2.0 |
| `connect_supply_net` | 1.0 |
| `connect_supply_set` | 2.0 |
| `create_logic_net` | 2.0 |
| `create_logic_port` | 2.0 |
| `create_power_domain` | 1.0, 2.1 |
| `create_power_switch` | 1.0 |
| `create_pst` | 1.0 |
| `create_supply_net` | 1.0 |
| `create_supply_port` | 1.0 |
| `set_isolation_control` | 1.0 |
| `set_level_shifter_strategy` | 1.0 |
| `set_power_switch_control` | 1.0 |
| `set_retention_control` | 1.0 |
| `upf_version` | 1.0 |
| `use_interface_cell` | 2.0 |
| `find_objects` | 2.0 |
| `set_related_supply_net` | SNPS Special |

---

## 最佳实践

### CPF 文件创建建议

1. **版本选择**：默认使用 CPF 1.1，除非有特殊需求
2. **库配置**：从 14.1 版本起，推荐使用 library-less CPF，将时序信息放在 viewDefinition.tcl
3. **分析视图**：如果没有 viewDefinition.tcl，CPF 必须包含 `create_analysis_view`
4. **库路径**：使用 TCL 变量设置库路径以提高可移植性

### CPF 修改

如果在流程中需要进行小的 CPF 修改，可以：
- 执行 CPF ECO（需要 CLP 许可证）
- 或在流程中进行视图相关更新，无需从头运行流程

### 工作流程

```tcl
# 1. 初始化设计
init_design

# 2. 读取 CPF 文件
read_power_intent -cpf design.cpf

# 3. 提交功率意图
commit_power_intent

# 4. 继续设计流程（floorplan, placement, optimization, CTS, routing）
# ...

# 5. 导出功率意图（如需要）
write_power_intent -cpf output.cpf
```

---

## 常见问题排查

| 问题 | 原因 | 解决方案 |
|------|------|---------|
| `commit_power_intent` 报错 | CPF 无分析视图且设计无 viewDefinition.tcl | 在 CPF 中添加 `create_analysis_view` 或提供 viewDefinition.tcl |
| `init_design` 报错 | 缺少必要的配置 | 确保提供 CPF 或 viewDefinition.tcl 之一 |
| 库路径问题 | 工艺变更导致库路径失效 | 使用 TCL 变量设置库路径，重新定义变量即可 |
