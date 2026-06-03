---
source: knowledge/Innovus/cui/json | chapters: [0036, 0038, 0042]
---

# dbGet 到 get_db 的转换指南

## 概述

Innovus 从 Legacy 的 `dbGet` 命令迁移到 Common UI 的 `get_db` 命令。两者都用于访问数据库对象，但语法和对象模型有显著差异。

## 数据结构查询

### CUI 数据结构

查询 CUI 的具体数据结构定义和属性说明，请参考：
- **路径**：`knowledge/Innovus/cui/json/DBcom__211/`
- **内容**：包含所有 CUI 对象类型的完整定义、属性列表、类型说明和默认值
- **查询方式**：按对象类型名称查找对应的 chapter 文件，例如查询 `inst` 对象的属性可搜索相关章节

### Legacy 数据结构

查询 Legacy 的具体数据结构定义和属性说明，请参考：
- **路径**：`knowledge/Innovus/legacy/json/dbSchema__211/`
- **内容**：包含所有 Legacy 对象类型的完整定义、属性列表、类型说明和默认值
- **查询方式**：按对象类型名称查找对应的 chapter 文件

## 核心差异

### 1. 访问方式

**Legacy dbGet：**
- 对象特定的命令
- 使用 `-p1` 获取对象指针
- 需要链式访问（通过 top 或 head 对象）
- 返回值为指针格式 `0x...` 或 NULL
- 过滤使用大括号条件语法

**Common UI get_db：**
- 统一的命令接口
- 可直接从根访问大多数对象类型
- 支持字符串模式匹配
- 返回值为 DPO 格式 `obj_type:path` 或空字符串
- 过滤使用 `-if` 选项

**返回值格式对比：**

```tcl
# Legacy 返回 pointer (0x...)
set inst [dbGet top.insts.name myInst -p]
# 结果: 0x12345678

# CUI 返回 DPO (design path object)
set inst [get_db insts myInst]
# 结果: inst:mydesign/myInst
```

**空值返回差异：**

```tcl
# Legacy - 返回 NULL 指针或 0x0
set result [dbGet $inst.nonexistent_attr]
# 结果: NULL 或 0x0

# CUI - 返回空字符串 ""
set result [get_db $inst .nonexistent_attr]
# 结果: ""
```

在编写脚本时需要注意这个差异，特别是在进行空值检查时：

```tcl
# Legacy 风格检查
if {$result == "NULL" || $result == "0x0"} {
    puts "属性为空"
}

# CUI 风格检查
if {$result == ""} {
    puts "属性为空"
}
```

**过滤语法差异：**

```tcl
# Legacy - 使用大括号和条件
set filtered [dbGet [dbGet top.insts] {.pStatus == placed}]

# CUI - 使用 -if 选项
set filtered [get_db insts -if {.place_status == placed}]
```

### 2. 对象名称变化

主要对象名称从驼峰式改为小写加下划线：

| Legacy dbGet | Common UI get_db | 说明 |
|---|---|---|
| `topCell` | `design` | 顶层设计（顶层 Verilog 模块） |
| `head` | `<无>` | 不再使用，属性直接从根访问 |
| `fplan` | `<无>` | 不再使用，属性直接在 design 对象中 |
| `libCell` | `base_cell` | 库单元 |
| `term(libCell)` | `base_pin` | 库单元上的逻辑引脚 |
| `term(topCell)` | `port` | 设计上的逻辑端口 |
| `instTerm` | `pin` | 实例上的逻辑引脚 |
| `hinstTerm` | `hpin` | 层级实例外部的逻辑引脚 |
| `hTerm` | `hport` | 层级实例内部的逻辑端口 |
| `viaRuleGenerate` | `via_def_rule` | Via 定义规则 |
| `via` | `via_def` | Via 定义 |
| `viaInst` | `via` | Via 实例 |
| `sViaInst` | `special_via` | 特殊 Via 实例 |

## 转换示例

### 基本查询

**查找实例：**
```tcl
# Legacy
dbFindInstsByName i1/*
dbGet -p1 top.insts.name i1/*

# Common UI
get_db insts i1/*
```

**查询网络组：**
```tcl
# Legacy
dbGet -p1 top.fplan.netGroups my_grp

# Common UI
get_db net_groups my_grp
```

### 链式访问

**获取层的宽度：**
```tcl
# Legacy
dbGet [dbGet -p1 head.layers.name metal1] .width

# Common UI
get_db [get_db layers metal1] .width
```

**获取引脚的时序属性：**
```tcl
# Legacy
get_property [get_pins i1/p1] arrival_max_fall

# Common UI
get_db [get_db pins i1/p1] .arrival_max_fall
```

**获取时钟树属性：**
```tcl
# Legacy
get_ccopt_property target_max_trans -clock_tree clk1 -early

# Common UI
get_db [get_db clock_trees clk1] .cts_target_max_transition_time_early
```

### 属性访问

**直接访问自定义属性：**
```tcl
# Legacy
dbGet [dbGet -p1 $inst.props.name my_prop_name].value

# Common UI
get_db $inst .my_prop_name
```

## 常见属性对照

### Net 对象属性

| 说明 | Legacy dbGet | Common UI get_db |
|------|---|---|
| 所有连接 | `.allTerms` | `.connections` |
| 所有 instance pins | `.instTerms` | `.pins` |
| Driver pins | - | `.driver_pins` |
| Load pins | - | `.load_pins` |
| 连接数量 | `.numTerms` | `.num_connections` |
| 是否为 clock | `.isClock` | `.is_clock` |
| 是否为 power | `.isPwr` | `.is_power` |
| 是否为 ground | `.isGnd` | `.is_ground` |
| Bounding box | `.box` | `.bbox` |

### Instance 对象属性

| 说明 | Legacy dbGet | Common UI get_db |
|------|---|---|
| 位置 | `.pt` | `.location` |
| 擺放状态 | `.pStatus` | `.place_status` |
| 方向 | `.orient` | `.orient` |
| Cell 名称 | `.cellName` / `.cell.name` | `.base_cell.name` |
| Instance pins | `.instTerms` | `.pins` |
| 面积 | `.area` | `.area` |
| Bounding box | `.box` | `.bbox` |
| 是否为 buffer | `.cell.isBuffer` | `.is_buffer` |
| 是否为 inverter | `.cell.isInverter` | `.is_inverter` |
| 是否为 sequential | - | `.is_sequential` |
| 是否为 macro | - | `.is_macro` |
| Don't touch | `.dontTouch` | `.dont_touch` |

### Pin (InstTerm) 对象属性

| 说明 | Legacy dbGet | Common UI get_db |
|------|---|---|
| 所属 instance | `.inst` | `.inst` |
| 连接的 net | `.net` | `.net` |
| 对应的 cell pin | `.cellTerm` | `.base_pin` |
| 方向 | `.isInput` / `.isOutput` | `.direction` |
| 位置 | `.pt` | `.location` |
| Fanout | - | `.fanout` |
| Fanin | - | `.fanin` |
| Slack | - | `.slack` |