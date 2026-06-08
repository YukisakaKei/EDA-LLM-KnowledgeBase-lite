---
source: knowledge/Innovus/legacy/wiki/scripting-guide/dbget-dbset-properties.jsonl
source: knowledge/Innovus/legacy/wiki/scripting-guide/get-property-properties.jsonl
---

# DB API 核心速查

Innovus 数据库查询和修改的核心命令：`dbGet` 和 `dbSet`。

## 属性查询参考

| 命令 | 属性定义位置 | 说明 |
|------|-----------|------|
| `dbGet` / `dbSet` | `knowledge/Innovus/legacy/wiki/scripting-guide/dbget-dbset-properties.jsonl` | 一行一个数据库对象属性，含对象类型、属性名、类型、是否可编辑和枚举值 |
| `get_property` | `knowledge/Innovus/legacy/wiki/scripting-guide/get-property-properties.jsonl` | 一行一个 collection 属性，含对象类型、属性名、返回类型和适用 collection 命令 |

---

## 概述

Innovus 提供 `dbGet` 和 `dbSet` 两个核心命令用于查询和修改数据库对象属性。

---

## 两个指针系统的交互

Innovus 中存在两个独立的指针系统，它们返回的指针**不通用**，需要通过对象名字进行转换。

### 系统对比

| 特性 | `get_*` 系统 | `dbGet`/`dbSet` 系统 |
|------|------------|------------------|
| 命令 | `get_cells`, `get_nets`, `get_pins`, `all_fanout` 等 | `dbGet`, `dbSet` |
| 返回类型 | Collection（集合） | Tcl 列表或指针 |
| 遍历方式 | `foreach_in_collection` | `foreach` |
| 属性提取 | `get_property` | `dbGet` 直接访问 |
| 指针互通 | ❌ 不能直接用于 `dbGet` | ❌ 不能直接用于 `get_property` |

### 转换方法

两个系统之间的交互**必须通过对象名字**进行转换：

#### 从 get_* 系统转向 dbGet 系统

```tcl
# 从 get_* 系统获取所有 buffer instance（使用 -filter 过滤）
set bufColl [get_cells * -filter "is_buffer == true"]

# 使用 get_property 提取名字
set bufNames [get_property $bufColl full_name]

# 通过名字用 dbGet 获取指针
foreach bufName $bufNames {
    set bufPtr [dbGet top.insts.name $bufName -p]
    # 现在 bufPtr 是 dbGet 系统的指针，可用于 dbGet/dbSet 操作
}
```

#### 从 dbGet 系统转向 get_* 系统

```tcl
# 从 dbGet 系统获取所有 buffer instance 指针（通过 cell.isBuffer 过滤）
set instPtrs [dbGet top.insts.cell.isBuffer 1 -p2]

# 提取名字列表
set instNames [dbGet $instPtrs.name]

# 通过名字用 get_cells 获取 collection
set instColl [get_cells $instNames]
# 现在 instColl 是 get_* 系统的 collection，可用于 get_property 等操作
```


### 关键要点

1. **不能混用指针**：`get_*` 系统的指针不能直接传给 `dbGet`，反之亦然
2. **名字是桥梁**：通过 `get_property` 或 `dbGet` 提取对象名字，再用名字在另一个系统中查询
3. **性能考虑**：避免频繁的系统转换，尽量在一个系统中完成操作

---

## dbGet — 查询对象属性

**语法**
```tcl
dbGet [-p num] [-u] [-regexp] [-d] [-e] [-i num] \
      {obj | objList | head | top | selected} \
      [.objType]...[.attrName | .? | .?? | .?h] \
      [pattern] [expression] [-v]
```

**常用参数**
- `-p` / `-p1` / `-p2` / `-p3`：层级穿透，返回上 N 层对象指针
- `-e`：过滤 NULL (0x0) 结果
- `-u`：去重（返回唯一值列表）
- `-d`：返回 DBU 单位（默认返回 microns）
- `-i num`：选择列表中第 num 个元素（从 0 开始）
- `pattern`：通配符匹配（支持 `*` / `?`）
- `-regexp`：正则表达式匹配

**层级穿透示例**
```tcl
# 获取所有 instance 的 master cell 名称
dbGet top.insts.cell.name

# 获取名称匹配 "BUF*" 的 cell 的所有 instance 指针（-p2 回溯 2 层）
dbGet -p2 top.insts.cell.name BUF*

# 获取 pStatus 为 fixed 的所有 instance 指针
dbGet -p top.insts.pStatus fixed
```

**表达式过滤**
```tcl
# 查询所有无布线的 net（wires 和 vias 均为 0x0）
set netsWithNoRouting [dbGet top.nets {.wires == 0x0 && .vias == 0x0}]

# 查询所有无 DEF SPECIALNETS 布线的 net
set netsNoSpecial [dbGet top.nets {.sWires == 0x0 && .sVias == 0x0}]
```

**查询对象结构**
```tcl
# 查询对象可用属性（仅列出名称）
dbGet selected.?

# 查询对象属性及其值
dbGet selected.??

# 查询对象属性及帮助信息（含 settable 标记）
dbGet selected.?h
```

**性能优化**
- 最小化 dbGet 调用次数，尤其是访问 DEF SPECIALNETS 数据时（内部初始化开销大）
- 优先使用表达式过滤，而非循环中多次调用 dbGet

---

## dbSet — 修改对象属性

**语法**
```tcl
dbSet [-d] {objList | head | top | selected} \
      [.objType]*.attrName attrValue
```

**参数**
- `-d`：值以 DBU 单位指定（默认 microns）
- `attrValue`：新属性值

**可修改属性查询**
```tcl
# 查询 inst 的可修改属性（带 "settable" 标记）
dbGet selected.?h pt*
# 输出：
#   pt(settable): pt, location of the instance
#   pt_x(settable): x coordinate of location of the instance
#   pt_y(settable): y coordinate of location of the instance
```

**典型示例**
```tcl
# Fix 所有 instance
dbSet top.insts.pStatus fixed

# Fix 所有 macro（baseClass 为 block 的 cell）
dbSet [dbGet -p2 top.insts.cell.baseClass block].pStatus fixed

# 修改 via 的 cutMask
dbSet $via.cutMasks $mask
```

**注意**：`dbSet` 不能创建或删除对象，仅修改已有对象的属性。

---

## 常用对象属性速查

### inst 对象

| 属性 | 类型 | 可写 | 说明 |
|------|------|------|------|
| `name` | string | No | Instance 全路径名 |
| `cell` | obj(libCell) | No | 指向 master cell 的指针 |
| `pStatus` | enum | Yes | Placement status: `cover` / `fixed` / `placed` / `softFixed` / `unplaced` |
| `pStatusCTS` | enum | Yes | CTS placement status: `fixed` / `softFixed` / `unset` |
| `orient` | enum | Yes | 方向: `R0` / `R90` / `R180` / `R270` / `MX` / `MY` / `MXR90` / `MYR90` |
| `pt` | pt | Yes | 位置坐标 (x, y) |
| `pt_x` | coord | Yes | X 坐标 |
| `pt_y` | coord | Yes | Y 坐标 |
| `box` | rect | No | Bounding box |
| `box_llx` / `box_lly` | coord | No | 左下角坐标 |
| `box_urx` / `box_ury` | coord | No | 右上角坐标 |
| `instTerms` | objList(instTerm) | No | Instance 的所有 terminal 列表 |
| `pgTerms` | objList(pgInstTerm) | No | Power/Ground terminal 列表 |
| `hInst` | obj(hInst) | No | 父层级 instance |
| `dontTouch` | enum | Yes | 优化保护状态 |

### net 对象

| 属性 | 类型 | 可写 | 说明 |
|------|------|------|------|
| `name` | string | No | Net 名称 |
| `instTerms` | objList(instTerm) | No | 连接的 instTerm 列表 |
| `terms` | objList(term) | No | 连接的 term 列表（top-level port） |
| `allTerms` | objList(instTerm, term) | No | 所有连接（instTerm + term） |
| `wires` | objList(wire) | No | DEF NETS 布线 |
| `vias` | objList(viaInst) | No | DEF NETS via |
| `sWires` | objList(sWire) | No | DEF SPECIALNETS 布线 |
| `sVias` | objList(sViaInst) | No | DEF SPECIALNETS via |
| `box` | rect | No | Bounding box |
| `isClock` | bool | No | 是否为时钟 net |
| `isSpecial` | bool | No | 是否为 special net (P/G) |
| `dontTouch` | enum | Yes | 优化保护状态 |
| `weight` | int | Yes | 布线权重（>2 优先布线） |

### libCell 对象

| 属性 | 类型 | 可写 | 说明 |
|------|------|------|------|
| `name` | string | No | Cell 名称 |
| `baseClass` | enum | No | `block` / `core` / `pad` / `cover` / `ring` / `none` |
| `subClass` | enum | No | `blackbox` / `core` / `feedthru` / ... |
| `padding` | int | Yes | Cell padding（M2 pitch 单位） |
| `insts` | objList(inst) | No | 该 cell 的所有 instance |

---

## 典型场景示例

### 场景 1：查找并 fix 所有 macro

```tcl
# 使用 dbGet -p2 + baseClass 过滤
dbSet [dbGet -p2 top.insts.cell.baseClass block].pStatus fixed
```

### 场景 2：查找指定 net 的所有 fanout

```tcl
# 获取 net 指针（需先通过 pattern 匹配或其他方式获取）
set netPtr [dbGet -p top.nets.name "CLK"]

# 获取所有 input term（fanout）
set fanoutTerms [dbGet $netPtr.instTerms]

# 遍历 fanout
foreach term $fanoutTerms {
    set instName [dbGet $term.inst.name]
    set pinName [dbGet $term.name]
    puts "$instName/$pinName"
}
```

### 场景 3：查询无布线的 net

```tcl
# 高效方法：单次 dbGet + 表达式过滤
set netsWithNoRouting [dbGet top.nets {.wires == 0x0 && .vias == 0x0 && .sWires == 0x0 && .sVias == 0x0}]

foreach net $netsWithNoRouting {
    puts "Net [dbGet $net.name] has no wiring"
}
```

### 场景 4：批量修改 instance 属性

```tcl
# 获取所有名称匹配 "BUF_*" 的 instance
set bufInsts [dbGet -p2 top.insts.name "BUF_*"]

# 批量 fix
dbSet $bufInsts.pStatus fixed

# 或使用 foreach 逐个处理
foreach inst $bufInsts {
    dbSet $inst.pStatus fixed
    puts "Fixed [dbGet $inst.name]"
}
```

---

## 注意事项 / 常见错误

### 1. 层级穿透 `-p` 的使用

```tcl
# 错误：返回 cell 指针列表，而非 inst 指针
set cells [dbGet top.insts.cell.name BUF*]

# 正确：使用 -p2 回溯到 inst 层级
set insts [dbGet -p2 top.insts.cell.name BUF*]
```

### 2. NULL 指针处理

```tcl
# 使用 -e 过滤 NULL 结果
set fixedInsts [dbGet -e -p top.insts.pStatus fixed]

# 或手动检查
if {$ptr != "0x0"} {
    # 处理有效指针
}
```

### 3. 单位转换

- `dbGet` 默认返回 **microns**，使用 `-d` 返回 **DBU**
- `dbSet` 默认接受 **microns**，使用 `-d` 接受 **DBU**
- 坐标计算时注意单位一致性

```tcl
# 错误：混用单位
set llx [dbGet $inst.box_llx]        # microns
set offset 10                         # 假设为 DBU
set newLLX [expr $llx + $offset]      # 单位不一致！

# 正确：统一单位
set llxDBU [dbGet -d $inst.box_llx]   # DBU
set offset 10                          # DBU
set newLLX [expr $llxDBU + $offset]   # DBU
```

### 4. 性能优化

- **最小化 dbGet 调用**：尤其是访问 DEF SPECIALNETS 数据（`.sWires` / `.sVias`）时
- **优先使用表达式过滤**：`dbGet top.nets {.wires == 0x0}` 比循环中多次 dbGet 快得多
- **缓存常用查询结果**：避免重复查询相同数据

### 5. 遍历对象列表

```tcl
# 获取对象列表
set allInsts [dbGet top.insts]

# 使用 foreach 遍历
foreach inst $allInsts {
    set instName [dbGet $inst.name]
    set cellName [dbGet $inst.cell.name]
    puts "$instName -> $cellName"
}
```
