---
source: knowledge/Innovus/legacy/json/innovusTCR__211 | chapters: [0012, 0013, 0026, 0035, 0040, 0073]
source: knowledge/Innovus/legacy/json/dbSchema__211 | chapters: [0023, 0027]
---

# Report 脚本指南 — 查找与报告

## 概述

报告类脚本用于查询设计中的 inst、net、pin 等对象，支持按名称模式匹配、属性过滤、连接关系查找等场景。核心命令为 `get_cells`、`get_nets`、`get_pins` 和 `dbGet`。

---

## 核心 API 速查表

### SDC 风格查询命令

```tcl
# 查找 instance（返回 collection）
get_cells [patterns] [-hierarchical] [-filter expr] [-regexp] [-nocase]
get_cells -of_objects [get_pins <pinPattern>]
get_cells -of_objects [get_nets <netPattern>]

# 查找 net（返回 collection）
get_nets [patterns] [-hierarchical] [-filter expr] [-regexp] [-nocase]
get_nets -of_objects [get_cells <cellPattern>]
get_nets -of_objects [get_pins <pinPattern>]

# 查找 pin（返回 collection）
get_pins [patterns] [-hierarchical] [-filter expr] [-regexp] [-nocase] [-leaf]
get_pins -of_objects [get_cells <cellPattern>]
get_pins -of_objects [get_nets <netPattern>]
```

### dbGet 查询语法

```tcl
# 基础查询
dbGet top.insts.name                    ;# 所有 inst 名称
dbGet top.nets.name                     ;# 所有 net 名称
dbGet [dbGet top.insts.name INV*]       ;# 名称匹配 INV* 的 inst 指针

# 层级穿透（-p / -p2 / -p3）
dbGet -p top.insts.cell.name BUFX2      ;# 返回 cell 为 BUFX2 的 inst 指针
dbGet -p2 top.insts.cell.baseClass block ;# 返回 macro 的 inst 指针

# 属性过滤（表达式）
dbGet top.nets {.numTerms > 100}        ;# fanout > 100 的 net
dbGet top.insts {.pStatus == fixed}     ;# placement status 为 fixed 的 inst

# 去重与精确匹配
dbGet -u top.insts.cell.name            ;# 去重的 cell 名称列表
dbGet -e top.insts.name myInst          ;# 精确匹配（不支持通配符）
```

---

## 典型场景 + 代码示例

### 场景 1：按名称模式查找 inst

```tcl
# 使用 get_cells（返回 collection，可传递给其他命令）
set instColl [get_cells "clk_buf_*"]
foreach_in_collection inst $instColl {
    puts [get_property $inst full_name]
}

# 使用 dbGet（返回 Tcl 列表，适合直接遍历）
set instList [dbGet top.insts.name clk_buf_*]
foreach instName $instList {
    puts "  - $instName"
}
```

### 场景 2：按 cell master 查找 inst

```tcl
# 方法 1：dbGet -p 层级穿透
set bufInsts [dbGet -p top.insts.cell.name BUFX4]
foreach instPtr $bufInsts {
    set instName [dbGet $instPtr.name]
    set loc [dbGet $instPtr.pt]
    puts "$instName @ $loc"
}

# 方法 2：get_cells -filter
set bufColl [get_cells * -filter "@ref_lib_cell_name == BUFX4"]
```

### 场景 3：查找所有 macro（hard block）

```tcl
# dbGet -p2 表达式过滤
set macroInsts [dbGet -p2 top.insts.cell.baseClass block]
foreach instPtr $macroInsts {
    set instName [dbGet $instPtr.name]
    set cellName [dbGet $instPtr.cell.name]
    puts "Macro: $instName ($cellName)"
}
```

### 场景 4：查找 fixed 的 inst

```tcl
# 方法 1：dbGet 表达式过滤
set fixedInsts [dbGet top.insts {.pStatus == fixed}]
foreach instPtr $fixedInsts {
    puts [dbGet $instPtr.name]
}

# 方法 2：get_cells -filter
set fixedColl [get_cells * -filter "@physical_status == fixed"]
```

### 场景 5：查找高 fanout net

```tcl
# 查找 fanout > 100 的 net
set highFanoutNets [dbGet top.nets {.numTerms > 100}]
foreach netPtr $highFanoutNets {
    set netName [dbGet $netPtr.name]
    set fanout [dbGet $netPtr.numTerms]
    puts "$netName: fanout = $fanout"
}
```

### 场景 6：查找连接到指定 net 的所有 inst

```tcl
# 使用 get_cells -of_objects
set netColl [get_nets "clk"]
set instColl [get_cells -of_objects $netColl]
foreach_in_collection inst $instColl {
    puts [get_property $inst full_name]
}

# 使用 dbGet 层级穿透
set netPtr [dbGet -p top.nets.name clk]
set instTerms [dbGet $netPtr.instTerms]
foreach termPtr $instTerms {
    set instPtr [dbGet $termPtr.inst]
    puts [dbGet $instPtr.name]
}
```

### 场景 7：查找 inst 的所有输入/输出 pin

```tcl
# 查找 inst 的所有 pin
set instColl [get_cells "myInst"]
set pinColl [get_pins -of_objects $instColl]

# 过滤输入 pin
set inputPins [get_pins -of_objects $instColl -filter "@pin_direction == in"]

# 使用 dbGet 查询
set instPtr [dbGet -p top.insts.name myInst]
set inputTerms [dbGet $instPtr.instTerms {.isInput == 1}]
foreach termPtr $inputTerms {
    puts [dbGet $termPtr.name]
}
```

### 场景 8：查找未连接的 net（floating net）

```tcl
# 查找 numTerms == 0 的 net
set floatingNets [dbGet top.nets {.numTerms == 0}]
foreach netPtr $floatingNets {
    puts [dbGet $netPtr.name]
}
```

### 场景 9：查找指定位置的 inst

```tcl
# 按坐标查找（坐标单位：DBU）
set targetLoc "449000 6803000"
foreach instPtr [dbGet top.insts] {
    set loc [dbGet $instPtr.pt]
    if {$loc == $targetLoc} {
        puts "[dbGet $instPtr.name] is at $loc"
    }
}
```

### 场景 10：查找层次化设计中的 inst

```tcl
# 使用 get_cells -hierarchical
set hierInsts [get_cells -hierarchical "*/FF*"]

# 使用 -hsc 指定层次分隔符
set hierInsts [get_cells -hsc @ "blockA@FF*"]
```

### 场景 11：批量报告 inst 属性

```tcl
# 报告所有 inst 的 placement status
foreach instPtr [dbGet top.insts] {
    set instName [dbGet $instPtr.name]
    set pStatus [dbGet $instPtr.pStatus]
    set cellName [dbGet $instPtr.cell.name]
    puts "$instName | $cellName | $pStatus"
}
```

### 场景 12：查找 clock net（SDC 定义）

```tcl
# 使用 dbGet 表达式过滤
set clockNets [dbGet top.nets {.isClock == 1}]
foreach netPtr $clockNets {
    puts [dbGet $netPtr.name]
}
```

---

## 注意事项 / 常见错误

### 1. get_* 命令返回 collection，需用 foreach_in_collection 遍历

```tcl
# ❌ 错误：直接 foreach 遍历 collection
set coll [get_cells *]
foreach inst $coll { ... }

# ✅ 正确：使用 foreach_in_collection
foreach_in_collection inst $coll {
    puts [get_property $inst full_name]
}
```

### 2. dbGet 返回 Tcl 列表，可直接 foreach 遍历

```tcl
# ✅ 正确：dbGet 返回列表
set instList [dbGet top.insts.name]
foreach instName $instList {
    puts $instName
}
```

### 3. dbGet -p 层级穿透的返回值是指针列表

```tcl
# dbGet -p 返回满足条件的对象指针
set bufInsts [dbGet -p top.insts.cell.name BUFX4]
# $bufInsts 是 inst 指针列表，需用 dbGet 提取属性
foreach instPtr $bufInsts {
    puts [dbGet $instPtr.name]
}
```

### 4. 表达式过滤的语法

```tcl
# ✅ 正确：表达式用 {} 包裹，属性名前加 .
dbGet top.insts {.pStatus == fixed}
dbGet top.nets {.numTerms > 100}

# ❌ 错误：缺少 . 或 {}
dbGet top.insts pStatus == fixed
```

### 5. -filter 与 dbGet 表达式的区别

```tcl
# get_cells -filter：属性名前加 @
get_cells * -filter "@ref_lib_cell_name == BUFX4"

# dbGet 表达式：属性名前加 .
dbGet top.insts {.cell.name == BUFX4}
```

### 6. 精确匹配 vs 模式匹配

```tcl
# 模式匹配（默认，支持 * 和 ?）
dbGet top.insts.name clk_buf_*

# 精确匹配（-e 参数，不支持通配符）
dbGet -e top.insts.name clk_buf_1
```

### 7. 去重查询

```tcl
# 不去重：可能返回重复的 cell 名称
dbGet top.insts.cell.name

# 去重：返回唯一的 cell 名称列表
dbGet -u top.insts.cell.name
```

### 8. 空指针检查

```tcl
# dbGet 查询不到对象时返回 0x0
set netPtr [dbGet -p top.nets.name nonExistNet]
if {$netPtr == "0x0"} {
    puts "Net not found"
}

# 使用 -e 参数避免返回 0x0
set validNets [dbGet -e top.nets]
```

### 9. all_fanin / all_fanout 的端点写法

`all_fanin` / `all_fanout` 是 timing graph traversal。查 reg 的上一级或下一级时，不要把 reg instance 名称或 `get_cells` collection 当作 pin endpoint 直接传入；应使用明确的 reg pin，或用 `<reg_inst>/*` 匹配该 reg 的所有 pin。

```tcl
# 错误：可能不会按预期穿过 reg pins
all_fanin -to $reg_name -startpoints_only -only_cells
all_fanin -to [get_cells $reg_name] -startpoints_only -only_cells

# 正确：使用明确 pin，或匹配该 reg 的所有 pins
all_fanin  -to   "${reg_name}/*" -startpoints_only -only_cells
all_fanout -from "${reg_name}/*" -endpoints_only   -only_cells
```
