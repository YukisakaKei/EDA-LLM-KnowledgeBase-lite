---
source: knowledge/Innovus/legacy/jsonl/innovusTCR__211.jsonl | entries: [0073, 0074, 0276, 0727, 0797, 1937, 2084]
source: knowledge/Innovus/legacy/jsonl/dbSchema__211.jsonl | entries: [0034]
---

# Net/Wire 操作脚本指南

## 概述

本指南覆盖 Innovus 中 net 和 wire 的常见操作场景，包括 net 属性查询与修改、NDR（Non-Default Rule）创建、tie-off cell 插入、wire 删除等。所有命令均来自 Innovus 21.1 TCR。

## 核心 API 速查表

### Net 操作命令

| 命令 | 功能 | 典型用法 |
|------|------|----------|
| `addNet` | 创建新 net | `addNet myNet` |
| `deleteNet` | 删除 net（逻辑） | `deleteNet -net myNet` |
| `setNet` | 设置 net 类型（regular/special） | `setNet -net myNet -type special` |
| `dbGet` | 查询 net 属性 | `dbGet top.nets.name` |
| `dbSet` | 修改 net 属性 | `dbSet $netPtr.skipRouting 1` |

### Wire 操作命令

| 命令 | 功能 | 典型用法 |
|------|------|----------|
| `editDelete` | 删除 wire/via（物理） | `editDelete -net myNet` |

### NDR 操作命令

| 命令 | 功能 | 典型用法 |
|------|------|----------|
| `add_ndr` | 创建 NDR 规则 | `add_ndr -name wide2x -width {metal1:metal4 0.20}` |
| `modify_ndr` | 修改已有 NDR | `modify_ndr -name wide2x -spacing {metal1 0.3}` |

### Tie-off 操作命令

| 命令 | 功能 | 典型用法 |
|------|------|----------|
| `addTieHiLo` | 插入 tie-off cell | `addTieHiLo -cell "TIEHI TIELO"` |
| `setTieHiLoMode` | 配置 tie-off 模式 | `setTieHiLoMode -cell TIEOFF` |
| `deleteTieHiLo` | 删除 tie-off cell | `deleteTieHiLo` |

---

## 典型场景与代码示例

### 场景 1：查询与修改 Net 属性

#### 查询 net 基本信息

```tcl
# 获取所有 net 名称
set allNets [dbGet top.nets.name]

# 获取特定 net 的指针
set targetNet [dbGet top.nets "myNet" -p]

# 查询 net 是否为 clock
set isClock [dbGet $targetNet.isClock]

# 查询 net 是否为 special net
set isSpecial [dbGet $targetNet.isSpecial]

# 查询 net 的 fanout 数量
set numTerms [dbGet $targetNet.numTerms]
set numInputs [dbGet $targetNet.numInputTerms]
set numOutputs [dbGet $targetNet.numOutputTerms]

# 查询 net 的 NDR 规则
set ndrRule [dbGet $targetNet.rule.name]
```

#### 修改 net 属性

```tcl
# 设置 net 跳过布线
dbSet $netPtr.skipRouting 1

# 设置 net 为 don't touch
dbSet $netPtr.dontTouch true

# 设置 net 的 preferred routing layer
set layer [lindex [dbGet head.layers.name M3 -p] 0]
dbSet $netPtr.bottomPreferredLayer $layer

# 设置 net 的 routing weight（优先级）
dbSet $netPtr.weight 10

# 设置 net 的额外间距
dbSet $netPtr.preferredExtraSpace 2
```

### 场景 2：创建与删除 Net

#### 创建新 net

```tcl
# 创建普通 signal net
addNet myNewNet

# 创建 power net
addNet VDD_NEW -power

# 创建 ground net
addNet VSS_NEW -ground

# 创建 bus net
addNet dataBus -bus 0:7
```

#### 删除 net

```tcl
# 删除单个 net（逻辑删除，包括连接）
deleteNet -net myNet

# 删除多个 net
deleteNet -net {net1 net2 net3}

# 使用通配符删除
deleteNet -net temp*
```

### 场景 3：设置 Net 类型（Regular/Special）

```tcl
# 将 net 标记为 special（不被 NanoRoute 布线）
setNet -net analogNet -type special -setTermSpecial

# 将 special net 改回 regular
setNet -net analogNet -type regular

# 批量设置多个 net 为 special
foreach net {net1 net2 net3} {
    setNet -net $net -type special -setTermSpecial
}

# 从文件读取 net 列表并设置为 special
# 文件格式：每行一个 net 名称
setNet -file special_nets.txt -type special
```

### 场景 4：删除 Wire（物理布线）

#### 删除指定 net 的所有 wire

```tcl
# 删除单个 net 的所有 wire 和 via
editDelete -net myNet

# 删除多个 net 的 wire
editDelete -net {net1 net2 net3}

# 删除 net 及其 shield wire
editDelete -net clockNet -shield
```

#### 按条件删除 wire

```tcl
# 删除指定 layer 上的所有 wire
editDelete -layer {M1 M2}

# 删除指定区域内的 wire
editDelete -area {100 100 500 500}

# 删除指定 layer 和 net 的 wire
editDelete -net myNet -layer M3

# 删除 horizontal wire
editDelete -net myNet -direction H

# 删除 special wire
editDelete -type Special

# 删除 floating via
editDelete -floating_via
```

#### 删除所有 signal net 的 wire

```tcl
# 遍历所有 net 并删除 wire（保留 power/ground）
foreach net [dbGet top.nets] {
    set netName [dbGet $net.name]
    # 跳过 power/ground net
    if {[dbGet $net.isPwrOrGnd] == 1} {
        continue
    }
    editDelete -net $netName
}
```

### 场景 5：创建 NDR（Non-Default Rule）

#### 创建基本 NDR

```tcl
# 创建 2x 宽度的 NDR
add_ndr -name wide2x \
        -width {metal1:metal4 0.20} \
        -generate_via

# 创建 2x spacing 的 NDR
add_ndr -name space2x \
        -spacing {metal1:metal4 0.2 metal5:metal6 0.4}

# 创建宽线 + 大间距的 NDR
add_ndr -name wide_space2x \
        -width {metal1:metal4 0.20} \
        -spacing {metal1:metal4 0.3} \
        -generate_via
```

#### 使用 width/spacing multiplier

```tcl
# 使用倍数因子创建 NDR（相对于 default rule）
add_ndr -name wide2x_mult \
        -width_multiplier {metal1:metal6 2.0} \
        -spacing_multiplier {metal1:metal6 2.0} \
        -generate_via
```

#### 创建带 min_cut 约束的 NDR

```tcl
# 基于已有 NDR，增加 via cut 数量约束
add_ndr -name wide2x_2cut \
        -init wide2x \
        -min_cut {via1:via3 2}
```

#### 应用 NDR 到 net

```tcl
# 通过 setAttribute 应用 NDR
setAttribute -net clockNet -non_default_rule wide2x

# 或使用 dbSet（需先获取 rule 指针）
set rulePtr [dbGet head.rules "wide2x" -p]
set netPtr [dbGet top.nets "clockNet" -p]
dbSet $netPtr.rule $rulePtr
```

### 场景 6：插入 Tie-off Cell

#### 基本 tie-off 插入

```tcl
# 使用单个 tie-off cell（同时提供 tie-high 和 tie-low）
addTieHiLo -cell TIEOFF -prefix tieOff

# 使用分离的 tie-high 和 tie-low cell
addTieHiLo -cell "TIEHI TIELO"

# 为特定 power domain 插入 tie-off
addTieHiLo -cell "TIEHI TIELO" -powerDomain PD1
```

#### 配置 tie-off 模式

```tcl
# 先配置全局模式
setTieHiLoMode -cell "TIEHI TIELO" \
               -maxFanout 10 \
               -maxDistance 50

# 然后插入（使用全局配置）
addTieHiLo
```

#### 选择性 tie-off

```tcl
# 仅对特定 cell pin 插入 tie-off
addTieHiLo -cellPin "MUX:S NOR:A"

# 从文件读取需要 tie-off 的 instance pin
# 文件格式：每行一个 instanceName/pinName
addTieHiLo -instancePin tie_pins.txt

# 排除特定 pin
addTieHiLo -excludePin exclude_pins.txt
```

#### 跨层次 tie-off

```tcl
# 允许跨层次边界连接 tie-off cell
addTieHiLo -cell TIEOFF \
           -createHierPort true \
           -reportHierPort true
```

#### 删除 tie-off cell

```tcl
# 删除所有 tie-off cell
deleteTieHiLo

# 删除特定 prefix 的 tie-off cell
deleteTieHiLo -prefix tieOff
```

### 场景 7：遍历 Net 的所有连接

```tcl
# 获取 net 的所有 terminal 连接
set netPtr [dbGet top.nets "myNet" -p]
set allTerms [dbGet $netPtr.allTerms]

foreach term $allTerms {
    set termName [dbGet $term.name]
    puts "Terminal: $termName"
}

# 分别获取 instTerm 和 term
set instTerms [dbGet $netPtr.instTerms]
set terms [dbGet $netPtr.terms]

# 遍历 instTerm（instance 连接）
foreach iTerm $instTerms {
    set instName [dbGet $iTerm.inst.name]
    set pinName [dbGet $iTerm.name]
    puts "Instance: $instName, Pin: $pinName"
}

# 遍历 term（top-level port 连接）
foreach term $terms {
    set portName [dbGet $term.name]
    puts "Port: $portName"
}
```

### 场景 8：查询 Net 的布线信息

```tcl
set netPtr [dbGet top.nets "myNet" -p]

# 查询 net 的 bounding box
set bbox [dbGet $netPtr.box]
set llx [dbGet $netPtr.box_llx]
set lly [dbGet $netPtr.box_lly]
set urx [dbGet $netPtr.box_urx]
set ury [dbGet $netPtr.box_ury]

# 查询 net 的 wire 列表
set wires [dbGet $netPtr.wires]
puts "Net has [llength $wires] wire segments"

# 查询 net 的 via 列表
set vias [dbGet $netPtr.vias]
puts "Net has [llength $vias] vias"

# 查询 special net 的 wire
set sWires [dbGet $netPtr.sWires]
set sVias [dbGet $netPtr.sVias]
```

---

## 注意事项与常见错误

### 1. Net 删除的区别

- **`deleteNet`**：逻辑删除，删除 net 及其所有连接关系
- **`editDelete -net`**：物理删除，仅删除 wire 和 via，保留逻辑连接

### 2. Special Net vs Regular Net

- **Special Net**：不被 NanoRoute 自动布线，通常用于 analog net、手动布线的 net
- 使用 `setNet -type special` 标记后，需手动布线或使用 `addSpecialRoute`

### 3. NDR 使用建议

- 宽线 NDR 必须使用 `-generate_via` 自动生成匹配的 via
- NDR 应用到 net 后，需重新布线才能生效
- 使用 `modify_ndr` 修改已有 NDR，避免重复创建

### 4. Tie-off Cell 插入时机

- 应在 placement 之后、CTS 之前插入
- 多 power domain 设计需为每个 domain 分别插入
- 使用 `-keepExisting true` 可增量插入，避免删除已有 tie-off

### 5. dbGet/dbSet 使用注意

- `dbGet` 返回的 net 指针可能为 `0x0`（NULL），使用前需检查
- `dbSet` 修改的属性必须是 `Edit: Yes` 的属性（参考 dbSchema）
- 使用 `-p` 参数可回溯查找：`dbGet top.nets.name myNet -p` 返回匹配的 net 指针

### 6. Wire 删除的性能优化

- 大量删除 wire 前，使用 `setEditMode -drc_on false` 禁用 DRC 标记清理
- 删除完成后再运行 `verifyConnectivity` 和 `verify_drc`

### 7. 常见错误

```tcl
# ❌ 错误：直接使用 net 名称作为指针
dbSet myNet.skipRouting 1

# ✓ 正确：先获取 net 指针
set netPtr [dbGet top.nets "myNet" -p]
dbSet $netPtr.skipRouting 1

# ❌ 错误：修改只读属性
dbSet $netPtr.isClock 1  # isClock 是只读属性

# ✓ 正确：使用可写属性
dbSet $netPtr.isCTSClock 1  # isCTSClock 可写
```

---

## 完整示例：批量处理 Clock Net

```tcl
# 场景：为所有 clock net 应用 NDR 并设置 don't touch

# 1. 创建 clock 专用 NDR
add_ndr -name clock_2x \
        -width_multiplier {metal1:metal6 2.0} \
        -spacing_multiplier {metal1:metal6 2.0} \
        -generate_via

# 2. 获取 NDR rule 指针
set rulePtr [dbGet head.rules "clock_2x" -p]

# 3. 遍历所有 clock net 并应用 NDR
set clockNets [dbGet top.nets.isClock 1 -p2]
foreach net $clockNets {
    set netName [dbGet $net.name]
    puts "Processing clock net: $netName"
    
    # 应用 NDR
    dbSet $net.rule $rulePtr
    
    # 设置 don't touch
    dbSet $net.dontTouch true
    
    # 设置高优先级
    dbSet $net.weight 10
    
    # 设置额外间距
    dbSet $net.preferredExtraSpace 2
}

puts "Applied NDR to [llength $clockNets] clock nets"
```
