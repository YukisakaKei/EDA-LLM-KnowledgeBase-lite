---
source: knowledge/Innovus/legacy/jsonl/innovusTCR__211.jsonl | entries: [0073, 0076, 0582]
source: knowledge/Innovus/legacy/jsonl/dbSchema__211.jsonl | entries: [0026, 0034]
---

# 通用 Tcl 脚本模式

Innovus 脚本编写中的常见 Tcl 编程模式和最佳实践。

---

## 概述

本文档覆盖 Innovus Tcl 脚本中的通用编程模式，包括参数解析、单位换算、坐标操作、文件读写、错误处理等。所有示例均使用 TCR 收录的命令和标准 Tcl 语法。

---

## proc 定义与参数解析

### 位置参数模式

```tcl
# 固定参数数量
proc myFixInstances {instPattern} {
    set instList [dbGet top.insts.name $instPattern -p]
    foreach inst $instList {
        dbSet $inst.pStatus fixed
    }
    Puts "Fixed [llength $instList] instances"
}

# 调用
myFixInstances "BUF_*"
```

### 可变参数模式（args）

```tcl
# 使用 args 接收任意数量参数
proc myCreateBlockages {args} {
    # 参数格式：{llx lly urx ury} {llx lly urx ury} ...
    foreach box $args {
        if {[llength $box] != 4} {
            error "Each box must have 4 coordinates: llx lly urx ury"
        }
        set llx [lindex $box 0]
        set lly [lindex $box 1]
        set urx [lindex $box 2]
        set ury [lindex $box 3]
        createPlaceBlockage -box "$llx $lly $urx $ury" -type hard
    }
    Puts "Created [llength $args] blockages"
}

# 调用
myCreateBlockages {10 10 50 50} {100 100 150 150}
```

### 选项参数解析

```tcl
proc myPlaceInsts {args} {
    # 默认值
    set instList {}
    set fixed 0
    set orient "R0"
    
    # 解析参数
    set i 0
    set len [llength $args]
    while {$i < $len} {
        set arg [lindex $args $i]
        if {[string match "-inst" $arg]} {
            incr i
            lappend instList [lindex $args $i]
        } elseif {[string match "-fixed" $arg]} {
            set fixed 1
        } elseif {[string match "-orient" $arg]} {
            incr i
            set orient [lindex $args $i]
        } else {
            error "Unknown option: $arg"
        }
        incr i
    }
    
    # 执行操作
    foreach instName $instList {
        set inst [dbGet top.insts.name $instName -p]
        if {$inst != "0x0"} {
            if {$fixed} {
                dbSet $inst.pStatus fixed
            }
            Puts "Processed instance: $instName"
        }
    }
}

# 调用
myPlaceInsts -inst inst1 -inst inst2 -fixed -orient R90
```

### 帮助信息模式

```tcl
proc myReportNets {args} {
    # 检查帮助选项
    if {[llength $args] == 0 || [string match "-h*" [lindex $args 0]]} {
        Puts "Usage: myReportNets <netPattern>"
        Puts "  Reports information about nets matching the pattern"
        Puts "  Example: myReportNets CLK*"
        return
    }
    
    set netPattern [lindex $args 0]
    set nets [dbGet top.nets.name $netPattern -p]
    Puts "Found [llength $nets] nets matching '$netPattern'"
}
```

### define_proc_arguments + parse_proc_arguments

Innovus 内建参数解析，自动生成 `-help`。**define_args 字段顺序（5 个）：**

```
{arg_name  option_help  value_help  data_type  attributes}
```

```tcl
# 1. 顶层定义（proc 之前）
define_proc_arguments myCmd -info "演示" -define_args {
    {-start  "origin coordinate {x y}"  "x y"   string}
    {-width  "region width"             "0"     float}
    {-dbg    "debug flag"               ""      boolean}
}

# 2. proc 内解析
proc myCmd {args} {
    parse_proc_arguments -args $args opts
    # ⚠️ key 带前导 -，是 $opts(-start) 不是 $opts(start)
    set start_xy $opts(-start)
    set width    $opts(-width)
}
```

**注意事项：**
- `define_proc_arguments` 必须在 proc 定义之前调用
- `parse_proc_arguments` 必须是 proc 内第一条命令
- **array key 包含前导 `-`**：`$opts(-argname)`
- `value_help` 不可为空字符串（boolean 除外），否则 key 可能不被填充
- 传列表参数时用 `{*}` 展开避免被包裹：`-regs [list {*}$regs]` 而非 `-regs [list $regs]`

---

## 单位换算

### DBU 与 Microns 转换

Innovus 内部使用 DBU (Database Units) 存储坐标，用户脚本通常使用 microns。`dbGet` 和 `dbSet` 默认使用 microns，但某些属性需要显式转换。

```tcl
# dbGet 默认返回 microns
set instX [dbGet [lindex [dbGet top.insts.name inst1 -p] 0].pt_x]
Puts "Instance X coordinate: $instX microns"

# 使用 -d 选项获取 DBU 值
set instXDBU [dbGet [lindex [dbGet top.insts.name inst1 -p] 0].pt_x -d]
Puts "Instance X coordinate: $instXDBU DBU"

# dbSet 默认接受 microns
set inst [lindex [dbGet top.insts.name inst1 -p] 0]
dbSet $inst.pt_x 100.5
Puts "Set instance X to 100.5 microns"

# 使用 -d 选项设置 DBU 值
dbSet $inst.pt_x 10000 -d
Puts "Set instance X to 10000 DBU"
```

### 坐标计算示例

```tcl
# 获取 instance 的 bounding box 并计算中心点
proc getInstCenter {instName} {
    set inst [lindex [dbGet top.insts.name $instName -p] 0]
    if {$inst == "0x0"} {
        error "Instance $instName not found"
    }
    
    set box [dbGet $inst.box]
    # box 格式：{llx lly urx ury}
    set llx [lindex $box 0]
    set lly [lindex $box 1]
    set urx [lindex $box 2]
    set ury [lindex $box 3]
    
    set centerX [expr ($llx + $urx) / 2.0]
    set centerY [expr ($lly + $ury) / 2.0]
    
    return [list $centerX $centerY]
}

# 使用示例
set center [getInstCenter "inst1"]
Puts "Instance center: [lindex $center 0], [lindex $center 1]"
```

---

## 坐标与 Box 操作

### Box 解构

```tcl
# dbGet 返回的 box 是 4 元素列表：{llx lly urx ury}
set inst [lindex [dbGet top.insts.name inst1 -p] 0]
set box [dbGet $inst.box]

set llx [lindex $box 0]
set lly [lindex $box 1]
set urx [lindex $box 2]
set ury [lindex $box 3]

Puts "Instance box: ($llx, $lly) to ($urx, $ury)"

# 计算宽度和高度
set width [expr $urx - $llx]
set height [expr $ury - $lly]
Puts "Width: $width, Height: $height"
```

### 传递坐标给命令

```tcl
# 许多 Innovus 命令需要 box 参数格式为 "llx lly urx ury"
set llx 10.0
set lly 20.0
set urx 50.0
set ury 60.0

# 方法 1：直接拼接字符串
createPlaceBlockage -box "$llx $lly $urx $ury" -type hard

# 方法 2：使用 list 构建
set boxList [list $llx $lly $urx $ury]
createPlaceBlockage -box [join $boxList " "] -type hard

# 方法 3：从 dbGet 结果直接使用
set inst [lindex [dbGet top.insts.name macro1 -p] 0]
set box [dbGet $inst.box]
createPlaceBlockage -box [join $box " "] -type hard
```

---

## 文件读写

### 读取文件逐行处理

```tcl
proc processInstListFile {fileName} {
    if {![file exists $fileName]} {
        error "File not found: $fileName"
    }
    
    set fp [open $fileName r]
    set count 0
    
    while {[gets $fp line] >= 0} {
        # 跳过空行和注释
        set line [string trim $line]
        if {$line == "" || [string match "#*" $line]} {
            continue
        }
        
        # 处理每个 instance
        set inst [lindex [dbGet top.insts.name $line -p] 0]
        if {$inst != "0x0"} {
            dbSet $inst.pStatus fixed
            incr count
        } else {
            Puts "Warning: Instance not found: $line"
        }
    }
    
    close $fp
    Puts "Fixed $count instances from $fileName"
}

# 调用
processInstListFile "instances_to_fix.txt"
```

### 写入文件生成脚本

```tcl
proc generateEcoScript {netPattern outputFile} {
    set fp [open $outputFile w]
    
    # 写入文件头
    puts $fp "# Auto-generated ECO script"
    puts $fp "# Date: [clock format [clock seconds]]"
    puts $fp ""
    
    # 查找匹配的 nets
    set nets [dbGet top.nets.name $netPattern -p]
    
    foreach net $nets {
        set netName [dbGet $net.name]
        puts $fp "# Processing net: $netName"
        puts $fp "addNet ${netName}_buf"
        puts $fp "addInst BUFX2 ${netName}_buf_inst"
        puts $fp ""
    }
    
    close $fp
    Puts "Generated ECO script: $outputFile"
}

# 调用
generateEcoScript "CLK*" "eco_clk_buffers.tcl"
```

### 读取配置文件（key-value 格式）

```tcl
proc readConfigFile {fileName} {
    set config [dict create]
    set fp [open $fileName r]
    
    while {[gets $fp line] >= 0} {
        set line [string trim $line]
        if {$line == "" || [string match "#*" $line]} {
            continue
        }
        
        # 解析 key = value 格式
        if {[regexp {^(\S+)\s*=\s*(.+)$} $line match key value]} {
            dict set config $key [string trim $value]
        }
    }
    
    close $fp
    return $config
}

# 使用示例
set config [readConfigFile "settings.cfg"]
set bufferCell [dict get $config "buffer_cell"]
Puts "Buffer cell: $bufferCell"
```

---

## 错误处理

### catch 基本用法

```tcl
# 捕获错误并继续执行
if {[catch {
    set inst [lindex [dbGet top.insts.name nonexistent -p] 0]
    dbSet $inst.pStatus fixed
} errMsg]} {
    Puts "Error occurred: $errMsg"
    Puts "Continuing with next operation..."
}
```

### 带返回值的错误处理

```tcl
proc safeGetInst {instName} {
    set inst [lindex [dbGet top.insts.name $instName -p] 0]
    if {$inst == "0x0"} {
        error "Instance not found: $instName"
    }
    return $inst
}

# 使用 catch 捕获
if {[catch {safeGetInst "inst1"} inst]} {
    Puts "Failed to get instance: $inst"
    return
}

# inst 变量包含返回值
dbSet $inst.pStatus fixed
```

### 参数验证

```tcl
proc validateBox {box} {
    if {[llength $box] != 4} {
        error "Box must have 4 coordinates, got [llength $box]"
    }
    
    set llx [lindex $box 0]
    set lly [lindex $box 1]
    set urx [lindex $box 2]
    set ury [lindex $box 3]
    
    if {$urx <= $llx || $ury <= $lly} {
        error "Invalid box: upper-right must be greater than lower-left"
    }
    
    return 1
}

proc createValidatedBlockage {box} {
    if {[catch {validateBox $box} errMsg]} {
        Puts "Error: $errMsg"
        return
    }
    
    createPlaceBlockage -box [join $box " "] -type hard
    Puts "Created blockage: $box"
}
```

---

## List 操作

### 常用 List 命令

```tcl
# 创建 list
set instList [list inst1 inst2 inst3]
set instList2 {inst4 inst5 inst6}

# 追加元素
lappend instList inst4
Puts "List after append: $instList"

# 获取长度
set len [llength $instList]
Puts "List length: $len"

# 访问元素
set first [lindex $instList 0]
set last [lindex $instList end]
Puts "First: $first, Last: $last"

# 搜索元素
set idx [lsearch $instList "inst2"]
if {$idx >= 0} {
    Puts "Found inst2 at index $idx"
}

# 排序
set sorted [lsort $instList]
Puts "Sorted: $sorted"

# 数值排序
set numbers {10.5 2.3 100.1 5.0}
set sortedNums [lsort -real $numbers]
Puts "Sorted numbers: $sortedNums"

# 合并 list
set combined [concat $instList $instList2]
Puts "Combined list: $combined"

# 去重
set unique [lsort -unique $combined]
Puts "Unique elements: $unique"
```

### 遍历 List

```tcl
# foreach 遍历
set instNames {inst1 inst2 inst3}
foreach name $instNames {
    set inst [lindex [dbGet top.insts.name $name -p] 0]
    if {$inst != "0x0"} {
        dbSet $inst.pStatus fixed
    }
}

# 带索引遍历
set i 0
foreach name $instNames {
    Puts "Processing instance $i: $name"
    incr i
}

# 同时遍历多个 list
set instNames {inst1 inst2 inst3}
set cellNames {BUF INV AND}
foreach inst $instNames cell $cellNames {
    Puts "$inst uses cell $cell"
}
```

---

## 层级名称处理

### 层级分隔符

```tcl
# 获取当前设计的层级分隔符（通常是 '/' 或 '.'）
# 注意：dbgHierChar 不在 TCR 中，这里展示概念
# 实际使用时需要根据设计确定分隔符

# 假设分隔符为 '/'
set delimiter "/"

# 解析层级名称
set hierInstName "top/block1/inst1"
set parts [split $hierInstName $delimiter]
set topLevel [lindex $parts 0]
set blockLevel [lindex $parts 1]
set instLevel [lindex $parts 2]

Puts "Top: $topLevel, Block: $blockLevel, Inst: $instLevel"

# 构建层级名称
set parentPath "top/block1"
set instName "inst2"
set fullPath [join [list $parentPath $instName] $delimiter]
Puts "Full path: $fullPath"
```

---

## 字符串操作

### 常用字符串命令

```tcl
# 模式匹配
set instName "BUF_CLK_1"
if {[string match "BUF*" $instName]} {
    Puts "$instName is a buffer"
}

# 大小写转换
set upper [string toupper $instName]
set lower [string tolower $instName]
Puts "Upper: $upper, Lower: $lower"

# 字符串长度
set len [string length $instName]
Puts "Length: $len"

# 子串提取
set sub [string range $instName 0 2]
Puts "First 3 chars: $sub"

# 查找子串
set idx [string first "CLK" $instName]
if {$idx >= 0} {
    Puts "Found CLK at position $idx"
}

# 替换
set newName [string map {"BUF" "INV"} $instName]
Puts "Replaced: $newName"

# 去除空白
set trimmed [string trim "  inst1  "]
Puts "Trimmed: '$trimmed'"
```

### 正则表达式

```tcl
# 匹配模式
set instName "inst_123"
if {[regexp {^inst_[0-9]+$} $instName]} {
    Puts "$instName matches pattern"
}

# 提取匹配内容
set netName "net_clk_div2"
if {[regexp {_div([0-9]+)$} $netName match divider]} {
    Puts "Clock divider: $divider"
}
```

---

## 数值计算

### expr 表达式

```tcl
# 基本运算
set a 10
set b 3
set sum [expr $a + $b]
set diff [expr $a - $b]
set prod [expr $a * $b]
set quot [expr $a / $b]
set remain [expr $a % $b]

Puts "Sum: $sum, Diff: $diff, Prod: $prod, Quot: $quot, Remain: $remain"

# 浮点运算
set x 10.5
set y 3.2
set result [expr $x / $y]
Puts "Result: $result"

# 数学函数
set sqrt_val [expr sqrt(16)]
set ceil_val [expr ceil(3.2)]
set floor_val [expr floor(3.8)]
set round_val [expr round(3.5)]

Puts "sqrt(16): $sqrt_val"
Puts "ceil(3.2): $ceil_val"
Puts "floor(3.8): $floor_val"
Puts "round(3.5): $round_val"

# 比较运算
set max [expr $a > $b ? $a : $b]
Puts "Max of $a and $b: $max"
```

---

## 完整示例：批量处理脚本

```tcl
proc batchFixInstancesFromFile {fileName} {
    # 参数验证
    if {![file exists $fileName]} {
        error "File not found: $fileName"
    }
    
    # 打开文件
    set fp [open $fileName r]
    set fixedCount 0
    set notFoundCount 0
    set errorList {}
    
    Puts "Processing instances from $fileName..."
    
    # 逐行读取
    while {[gets $fp line] >= 0} {
        # 跳过空行和注释
        set line [string trim $line]
        if {$line == "" || [string match "#*" $line]} {
            continue
        }
        
        # 尝试处理每个 instance
        if {[catch {
            set inst [lindex [dbGet top.insts.name $line -p] 0]
            if {$inst == "0x0"} {
                incr notFoundCount
                lappend errorList "Not found: $line"
            } else {
                dbSet $inst.pStatus fixed
                incr fixedCount
            }
        } errMsg]} {
            lappend errorList "Error processing $line: $errMsg"
        }
    }
    
    close $fp
    
    # 报告结果
    Puts "========================================="
    Puts "Batch Fix Summary:"
    Puts "  Fixed: $fixedCount instances"
    Puts "  Not found: $notFoundCount instances"
    Puts "  Errors: [llength $errorList]"
    
    if {[llength $errorList] > 0} {
        Puts ""
        Puts "Error details:"
        foreach err $errorList {
            Puts "  $err"
        }
    }
    Puts "========================================="
}

# 使用示例
batchFixInstancesFromFile "instances_to_fix.txt"
```

---

## 注意事项

1. **NULL 指针检查**：`dbGet` 返回 `0x0` 表示未找到对象，使用前必须检查
2. **单位一致性**：混用 microns 和 DBU 时容易出错，建议统一使用 microns
3. **错误处理**：文件操作和数据库查询应使用 `catch` 捕获错误
4. **性能优化**：避免在循环中重复调用 `dbGet`，尽量一次性获取所有对象
5. **输出信息**：使用 `Puts` 而非 `puts`，确保信息同时输出到终端和日志文件
