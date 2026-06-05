---
source: knowledge/Innovus/legacy/jsonl/innovusTCR__211.jsonl | entries: [0187, 0158, 0129, 1607]
source: knowledge/Innovus/legacy/jsonl/innovusUG__211.jsonl | entries: [0485]
source: knowledge/Innovus/legacy/jsonl/dbSchema__211.jsonl | entries: [0026, 0034]
---

# Skew 与时钟树属性脚本指南

Innovus 21.1 中通过 CCOpt 属性系统和 SDC 约束控制时钟树 skew、插入延迟和 ICG 时序。

> **完整 CCOpt Property 参考**：`knowledge/Innovus/legacy/jsonl/innovusUG__211.jsonl` entry index=1320（仅在需要查询特定 property 时打开）

---

## 概述

时钟树综合（CTS）后的 skew 控制主要通过以下机制实现：

1. **CCOpt 属性系统** — `set_ccopt_property` / `get_ccopt_property` 设置时钟树、skew group、实例级属性
2. **Skew group 创建** — `create_ccopt_skew_group` 定义需要平衡的 sink 集合
3. **SDC 时钟约束** — `set_clock_latency` 为 ICG 等特殊场景设置局部延迟

---

## 核心 API 速查表

### CCOpt 属性操作

```tcl
# 设置全局属性
set_ccopt_property <property_name> <value>

# 设置时钟树属性
set_ccopt_property -clock_tree <ct_name> <property_name> <value>

# 设置 skew group 属性
set_ccopt_property -skew_group <sg_name> <property_name> <value>

# 设置实例属性
set_ccopt_property -inst <inst_name> <property_name> <value>

# 设置 pin 属性
set_ccopt_property -pin <pin_name> <property_name> <value>

# 读取属性
get_ccopt_property <property_name>
get_ccopt_property -clock_tree <ct_name> <property_name>
```

### Skew Group 管理

```tcl
# 创建 skew group
create_ccopt_skew_group -name <sg_name> \
    -sources <pin_list> \
    -exclusive_sinks <pin_list> \
    [-target_skew <value>] \
    [-target_insertion_delay <value>]

# 查询 skew group
get_ccopt_skew_groups [pattern]
get_ccopt_skew_group_delay -skew_group <sg_name>

# 删除 skew group
delete_ccopt_skew_groups -skew_group <sg_name>
```

### SDC 时钟延迟约束

```tcl
# 设置网络延迟（network latency）
set_clock_latency <latency> [get_pins <pin_pattern>]

# 设置源延迟（source latency）
set_clock_latency -source <latency> [get_clocks <clock_name>]

# 设置 early/late 延迟
set_clock_latency -early <latency> [get_pins <pin_pattern>]
set_clock_latency -late <latency> [get_pins <pin_pattern>]

# 清除延迟约束
reset_clock_latency [get_pins <pin_pattern>]
```

---

## 典型场景 + 代码示例

### 场景 1：设置时钟树目标 skew

```tcl
# 为特定时钟树设置全局目标 skew（通过 skew group）
# 假设已有 skew group "clk_main_sg"
set_ccopt_property -skew_group clk_main_sg target_skew 0.05

# 为特定 delay corner 设置不同的 skew 目标
set_ccopt_property -skew_group clk_main_sg -delay_corner max target_skew 0.08
set_ccopt_property -skew_group clk_main_sg -delay_corner min target_skew 0.03
```

### 场景 2：创建 skew group 并设置目标延迟

```tcl
# 为特定模块的时钟 sink 创建独立 skew group
create_ccopt_skew_group -name sg_module_A \
    -sources [get_ports clk] \
    -exclusive_sinks [get_pins module_A/*/CK] \
    -target_skew 0.05 \
    -target_insertion_delay 0.3

# 查询 skew group 的实际延迟
set actual_delay [get_ccopt_skew_group_delay -skew_group sg_module_A]
puts "Module A skew group delay: $actual_delay"
```

### 场景 3：为 ICG 时钟 pin 设置局部延迟补偿

**背景**：ICG（Integrated Clock Gating）对 CTS 透明，导致 ICG 时钟 pin 比 enable pin 更快到达，需要补偿 skew。

**方法 1：使用 SDC `set_clock_latency`**

```tcl
# 假设 CTS 后 enable pin 的 WNS 为 -0.3ns
set enable_wns -0.3

# 为所有 ICG 时钟 pin 设置延迟补偿
set icg_clk_pins [get_pins -hierarchical -filter {is_clock_gating_clock == true}]

foreach_in_collection pin $icg_clk_pins {
    set pin_name [get_property $pin full_name]
    set icg_inst [file dirname $pin_name]
    
    # 为 ICG 时钟 pin 设置延迟（补偿 enable skew）
    set_clock_latency [expr abs($enable_wns)] [get_pins $pin_name]
    
    # 为 ICG 输出 pin 设置 0 延迟（恢复原始时序）
    set icg_out_pin [get_pins -of_objects [get_cells $icg_inst] -filter {direction == out}]
    set_clock_latency 0 $icg_out_pin
}

puts "Applied clock latency to [sizeof_collection $icg_clk_pins] ICG clock pins"
```

**方法 2：使用 CCOpt property `insertion_delay`**

```tcl
# 假设 CTS 后 enable pin 的 WNS 为 -0.3ns
set enable_wns -0.3

# 注意：insertion_delay 与 set_clock_latency 的关系为：
# insertion_delay = clock_latency - pin_latency
# 因此 insertion_delay 需要设置为负值（表示 pin 下方的延迟减少）
set compensation_delay [expr -1 * abs($enable_wns)]

# 为所有 ICG 时钟 pin 设置插入延迟
set icg_clk_pins [get_pins -hierarchical -filter {is_clock_gating_clock == true}]

foreach_in_collection pin $icg_clk_pins {
    set pin_name [get_property $pin full_name]
    set icg_inst [file dirname $pin_name]
    
    # 为 ICG 时钟 pin 设置插入延迟（支持 early/late 分别设置）
    # 负值表示减少该 pin 下方的延迟，等效于增加到达该 pin 的延迟
    set_ccopt_property insertion_delay $compensation_delay -pin $pin_name -late
    set_ccopt_property insertion_delay $compensation_delay -pin $pin_name -early
    
    # 为 ICG 输出 pin 设置 0 延迟（恢复默认）
    set icg_out_pin [get_pins -of_objects [get_cells $icg_inst] -filter {direction == out}]
    set icg_out_name [get_property $icg_out_pin full_name]
    set_ccopt_property insertion_delay 0 -pin $icg_out_name -late
    set_ccopt_property insertion_delay 0 -pin $icg_out_name -early
}

puts "Applied insertion_delay to [sizeof_collection $icg_clk_pins] ICG clock pins"
```

**两种方法对比**：
- `set_clock_latency` — SDC 标准约束，正值表示增加到达延迟
- `insertion_delay` — CCOpt 专用属性，表示 pin 下方的内部延迟（`insertion_delay = clock_latency - pin_latency`），支持 early/late 分别设置

### 场景 4：查询并报告 skew group 状态

```tcl
# 获取所有 skew group
set all_sgs [get_ccopt_skew_groups *]

puts "Total skew groups: [llength $all_sgs]"
puts ""

foreach sg $all_sgs {
    # 查询 skew group 属性
    set target_skew [get_ccopt_property -skew_group $sg target_skew]
    set target_delay [get_ccopt_property -skew_group $sg target_insertion_delay]
    
    # 查询实际延迟
    set actual_delay [get_ccopt_skew_group_delay -skew_group $sg]
    
    puts "Skew Group: $sg"
    puts "  Target Skew: $target_skew"
    puts "  Target Insertion Delay: $target_delay"
    puts "  Actual Delay: $actual_delay"
    puts ""
}
```

### 场景 5：为特定实例设置最大插入延迟

```tcl
# 限制某个层级实例下方的最大插入延迟
set_ccopt_property -inst top/module_B maximum_insertion_delay 0.5

# 批量设置多个实例
set critical_insts [dbGet top.insts.name "top/critical_*"]
foreach inst $critical_insts {
    set inst_name [dbGet $inst.name]
    set_ccopt_property -inst $inst_name maximum_insertion_delay 0.4
}
```

### 场景 6：设置不同 net type 的 slew 目标

```tcl
# 为 trunk net 设置更严格的 slew 目标
set_ccopt_property -clock_tree clk_main -net_type trunk target_max_trans 0.1

# 为 leaf net 设置宽松的 slew 目标
set_ccopt_property -clock_tree clk_main -net_type leaf target_max_trans 0.15

# 为 top net 设置最严格的 slew 目标
set_ccopt_property -clock_tree clk_main -net_type top target_max_trans 0.08
```

### 场景 7：平衡多个 skew group

```tcl
# 创建两个独立的 skew group
create_ccopt_skew_group -name sg_domain_A \
    -sources [get_ports clk] \
    -exclusive_sinks [get_pins domain_A/*/CK] \
    -target_skew 0.05

create_ccopt_skew_group -name sg_domain_B \
    -sources [get_ports clk] \
    -exclusive_sinks [get_pins domain_B/*/CK] \
    -target_skew 0.05

# 创建合并的 skew group 以平衡两个 domain
create_ccopt_skew_group -name sg_balanced \
    -balance_skew_groups {sg_domain_A sg_domain_B} \
    -target_skew 0.03
```

---

## 注意事项 / 常见错误

### 1. CCOpt 属性的作用域

```tcl
# 错误：尝试在全局设置 target_skew（target_skew 必须通过 skew_group 设置）
set_ccopt_property target_skew 0.05  # 错误！

# 正确：通过 skew_group 设置
set_ccopt_property -skew_group <sg_name> target_skew 0.05
```

### 2. set_clock_latency 的覆盖规则

- 对于 ideal clock，路径上**最后一个** `set_clock_latency` 生效
- Pin 级别的 latency 会覆盖 clock 级别的 latency
- 使用 `-clock_gate` 参数可以覆盖 clock gating cell 的 latency

```tcl
# 为 ICG 时钟 pin 设置延迟时，需要使用 -clock_gate 参数
set_clock_latency -clock_gate 0.3 [get_pins icg_inst/CK]
```

### 3. Skew group 的 rank 机制

- **Shared skew group** (`-shared_sinks`) 的 rank 为 0
- **Exclusive skew group** (`-exclusive_sinks`) 的 rank > 0
- Pin 只在**最高 rank** 的 skew group 中作为 active sink

```tcl
# 创建层级化的 skew group
create_ccopt_skew_group -name sg_all -sources top -shared_sinks [get_pins */CK]
# sg_all rank = 0，所有 CK pin 都是 active sink

create_ccopt_skew_group -name sg_module_X -sources top -exclusive_sinks [get_pins module_X/*/CK]
# sg_module_X rank = 1，module_X 的 CK pin 只在 sg_module_X 中是 active sink
```

### 4. 单位转换

- `set_clock_latency` 的延迟值单位为 **library units**（通常为 ns）
- CCOpt 属性的延迟值单位也为 **library units**
- 确保单位一致性，避免混用 ns 和 ps

```tcl
# 正确：统一使用 ns
set_clock_latency 0.3 [get_pins icg/CK]
set_ccopt_property -skew_group sg1 target_insertion_delay 0.3
```

### 5. ICG 延迟补偿的时机

- ICG 延迟补偿应在 **CTS 之后、timing optimization 之前**应用
- 补偿值通常为 enable pin 的 WNS（取绝对值）
- 需要同时设置 ICG 输出 pin 的延迟为 0，恢复下游 flop 的时序

```tcl
# 典型流程
ccopt_design              ;# CTS
report_timing -to [get_pins */icg*/EN]  ;# 查询 enable pin WNS
# 根据 WNS 设置 ICG 延迟补偿
set_clock_latency <wns_abs> [get_pins */icg*/CK]
set_clock_latency 0 [get_pins */icg*/GCLK]
optDesign -postCTS        ;# 时序优化
```

### 6. 属性查询的返回值

- `get_ccopt_property` 返回字符串或数值
- 对于未设置的属性，可能返回空字符串或默认值
- 使用前应检查返回值是否有效

```tcl
set target_skew [get_ccopt_property -skew_group sg1 target_skew]
if {$target_skew == "" || $target_skew == "default"} {
    puts "Warning: target_skew not set for sg1"
} else {
    puts "Target skew: $target_skew"
}
```

### 7. Skew group 的约束阶段

- 使用 `-constrains` 参数控制 skew group 在哪个阶段生效
- 可选值：`cts` | `ccopt_initial` | `ccopt` | `all` | `none`

```tcl
# 仅在 CTS 阶段约束
create_ccopt_skew_group -name sg1 -sources top -exclusive_sinks [get_pins */CK] \
    -constrains cts

# 在所有阶段约束
create_ccopt_skew_group -name sg2 -sources top -exclusive_sinks [get_pins */CK] \
    -constrains all
```
