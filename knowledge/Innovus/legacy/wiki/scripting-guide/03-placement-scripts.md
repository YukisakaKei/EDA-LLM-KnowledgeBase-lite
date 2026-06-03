---
source: knowledge/Innovus/legacy/json/innovusTCR__211 | chapters: [0074, 1029, 1057, 1086, 1102, 1127]
source: knowledge/Innovus/legacy/json/dbSchema__211 | chapters: [0026, 0032]
---

# Placement 脚本指南

## 概述

Placement 脚本用于控制实例的放置状态（fixed/placed/unplaced）、设置 cell padding（布局间距）以及批量操作 macro 和 sequential cell 的放置属性。这些操作在 floorplan 后、placement 前后以及 ECO 流程中频繁使用。

## 核心 API 速查表

### Placement Status 控制

```tcl
# 通过 dbSet 修改 inst.pStatus 属性
dbGet $instPtr.pStatus                    # 查询 placement status
dbSet $instPtr.pStatus fixed              # fix inst（锁定位置）
dbSet $instPtr.pStatus placed             # unfix inst（恢复为 placed）
dbSet $instPtr.pStatus unplaced           # 标记为未放置

# inst.pStatus 合法值（enum）
# - cover      : 覆盖型放置
# - fixed      : 固定位置，placer 不会移动
# - placed     : 已放置但可优化移动
# - softFixed  : 软固定，优化时可微调
# - unplaced   : 未放置

# CTS 专用 placement status
dbGet $instPtr.pStatusCTS                 # 查询 CTS placement status
dbSet $instPtr.pStatusCTS fixed           # CTS 阶段固定
dbSet $instPtr.pStatusCTS softFixed       # CTS 阶段软固定
dbSet $instPtr.pStatusCTS unset           # 取消 CTS 固定

# inst.pStatusCTS 合法值（enum）
# - fixed      : CTS 阶段固定
# - softFixed  : CTS 阶段软固定
# - unset      : 未设置（默认值）

# 查询有效 placement status（考虑 pStatus、pStatusCTS 和 parent hinst）
dbGet $instPtr.pStatusEffective
```

### 放置实例

```tcl
# 放置实例到指定坐标（坐标单位：微米）
placeInstance <instName> <x> <y> [<orientation>] [-fixed | -placed | -softFixed]

# orientation 可选值：R0, R90, R180, R270, MX, MX90, MY, MY90
# 默认：R0
# 默认 status：-fixed
```

### Cell Padding 控制

```tcl
# 为 cell 设置 padding（单位：site 数量）
specifyCellPad <cellName> <padding>
specifyCellPad <cellName> -left <L> -right <R> -top <T> -bottom <B>

# 删除所有 cell padding
deleteAllCellPad

# 查询 cell padding
reportCellPad                             # 打印 padding 统计
reportCellPad -cell <cellName>            # 查询特定 cell
reportCellPad -file <fileName>            # 导出到文件
dbGet [dbGet -p top.insts.cell.name <cellName>].cell.padding  # 通过 dbGet 查询
```

## 典型场景 + 代码示例

### 场景 1：Fix 所有 hard macro

```tcl
# 遍历所有 hard macro（baseClass == block），设置为 fixed
foreach inst [dbGet -p2 top.insts.cell.baseClass block] {
    dbSet $inst.pStatus fixed
}

# 验证结果
puts "Fixed [llength [dbGet -p2 top.insts.cell.baseClass block]] macros"
```

**说明**：
- `dbGet -p2 top.insts.cell.baseClass block` 返回所有 baseClass 为 block 的 inst 指针列表
- `dbSet $inst.pStatus fixed` 将 inst 的 placement status 设置为 fixed
- placer 和 optimizer 不会移动 fixed 状态的 inst

### 场景 2：Unfix 所有 standard cell

```tcl
# 遍历所有 standard cell（baseClass == core），恢复为 placed
foreach inst [dbGet -p2 top.insts.cell.baseClass core] {
    if {[dbGet $inst.pStatus] == "fixed"} {
        dbSet $inst.pStatus placed
    }
}
```

**说明**：
- `baseClass == core` 表示 standard cell
- 先检查 `pStatus == fixed` 再修改，避免不必要的操作
- `placed` 状态允许 placer 和 optimizer 移动 inst

### 场景 3：Fix 所有 sequential cell

```tcl
# 遍历所有 sequential cell（isSequential == 1），设置为 fixed
foreach inst [dbGet -p2 top.insts.cell.isSequential 1] {
    dbSet $inst.pStatus fixed
}

# 统计数量
set seq_count [llength [dbGet -p2 top.insts.cell.isSequential 1]]
puts "Fixed $seq_count sequential cells"
```

**说明**：
- `cell.isSequential` 是 libCell 的布尔属性，1 表示 sequential cell（flop/latch）
- `-p2` 表示两级属性穿透：`top.insts` → `inst.cell` → `cell.isSequential`
- 返回满足条件的 inst 指针列表

### 场景 4：为所有 sequential cell 设置 cell padding

```tcl
# 获取所有 sequential cell 的 cell name（去重）
set seq_cells [lsort -unique [dbGet -p2 top.insts.cell.isSequential 1 -v .cell.name]]

# 为每个 cell 设置 padding（2 个 site）
foreach cellName $seq_cells {
    specifyCellPad $cellName 2
}

puts "Applied padding to [llength $seq_cells] sequential cell types"
```

**说明**：
- `dbGet -p2 ... -v .cell.name` 返回属性值列表（cell name）
- `lsort -unique` 去重，避免重复设置同一 cell
- `specifyCellPad` 的 padding 单位是 site 数量（left/right）或 row 数量（top/bottom）

### 场景 5：按 cell 宽度比例设置 padding

```tcl
# 为所有 sequential cell 按宽度设置 padding（宽度 > 5um 的设置 3 个 site，否则 2 个）
set seq_cells [lsort -unique [dbGet -p2 top.insts.cell.isSequential 1 -v .cell.name]]

foreach cellName $seq_cells {
    set cellPtr [dbGet -p top.insts.cell.name $cellName]
    set width [dbGet $cellPtr.box_sizex]
    
    if {$width > 5.0} {
        specifyCellPad $cellName 3
    } else {
        specifyCellPad $cellName 2
    }
}
```

**说明**：
- `dbGet -p top.insts.cell.name $cellName` 返回第一个匹配的 cell 指针
- `box_sizex` 返回 cell 宽度（单位：微米）
- 可根据 cell 宽度、高度或其他属性动态设置 padding

### 场景 6：放置 macro 到指定位置并 fix

```tcl
# 放置 macro 到坐标 (100, 200)，方向 R0，状态 fixed
placeInstance my_macro_inst 100 200 R0 -fixed

# 放置多个 macro（从列表读取坐标）
set macro_list {
    {macro1 100.0 200.0 R0}
    {macro2 300.0 400.0 MY}
    {macro3 500.0 600.0 R180}
}

foreach entry $macro_list {
    lassign $entry instName x y orient
    placeInstance $instName $x $y $orient -fixed
}
```

**说明**：
- `placeInstance` 坐标单位为微米
- inst 会自动 snap 到最近的 site
- 默认 status 为 `-fixed`，可指定 `-placed` 或 `-softFixed`

### 场景 7：批量 unplace 特定区域的 inst

```tcl
# 使用 dbQuery 查询区域内的所有 inst（默认返回 overlap/abut/enclosed 的 inst）
foreach inst [dbQuery -objType inst -areas {100 200 500 600}] {
    dbSet $inst.pStatus unplaced
}

# 仅处理完全包含在区域内的 inst
foreach inst [dbQuery -objType inst -areas {100 200 500 600} -enclosed_only] {
    dbSet $inst.pStatus unplaced
}

# 多区域查询
foreach inst [dbQuery -objType inst -areas {{100 200 500 600} {800 900 1000 1100}}] {
    dbSet $inst.pStatus unplaced
}
```

**说明**：
- `dbQuery -objType inst -areas {llx lly urx ury}` 直接返回区域内的 inst 指针列表，坐标单位为微米
- 默认返回 overlap、abut、enclosed 三种关系的 inst
- `-enclosed_only` 仅返回完全包含在区域内的 inst
- `-overlap_only` 仅返回部分重叠的 inst
- `-abut_only` 仅返回与区域边界相接的 inst
- 相比遍历所有 inst 再判断坐标，`dbQuery` 内部使用空间索引，性能更高
- `unplaced` 状态的 inst 会在下次 placement 时重新放置

### 场景 8：查询和报告 cell padding

```tcl
# 报告所有有 padding 的 cell
reportCellPad

# 导出 padding 信息到文件
reportCellPad -file cell_padding.rpt

# 查询特定 cell 的 padding
reportCellPad -cell DFFHQX1

# 通过 dbGet 查询 cell padding
set cellPtr [dbGet -p top.insts.cell.name DFFHQX1]
set padding [dbGet $cellPtr.padding]
puts "DFFHQX1 padding: $padding"
```

**说明**：
- `reportCellPad` 输出格式：`cellName padding`
- `cell.padding` 返回 padding 值（整数，单位：site 数量）
- 如果 cell 没有设置 padding，返回空字符串或 0

### 场景 9：删除所有 padding 并重新设置

```tcl
# 删除所有 cell padding
deleteAllCellPad

# 重新为 sequential cell 设置 padding
set seq_cells [lsort -unique [dbGet -p2 top.insts.cell.isSequential 1 -v .cell.name]]
foreach cellName $seq_cells {
    specifyCellPad $cellName 2
}
```

**说明**：
- `deleteAllCellPad` 删除所有通过 `specifyCellPad` 设置的 padding
- 删除后需要重新运行 `checkPlace` 以更新 utilization 计算

### 场景 10：CTS 前 fix sequential cell，CTS 后 unfix

```tcl
# CTS 前：fix 所有 sequential cell
foreach inst [dbGet -p2 top.insts.cell.isSequential 1] {
    dbSet $inst.pStatusCTS fixed
}

# 运行 CTS
ccopt_design

# CTS 后：unfix sequential cell
foreach inst [dbGet -p2 top.insts.cell.isSequential 1] {
    dbSet $inst.pStatusCTS unset
}
```

**说明**：
- `pStatusCTS` 专用于 CTS 阶段的 placement 控制
- `pStatusCTS fixed` 防止 CTS 移动 flop
- CTS 后设置为 `unset` 允许后续优化移动

## 注意事项 / 常见错误

### 1. pStatus vs pStatusCTS

- `pStatus` 是通用 placement status，影响所有 placement 和 optimization 阶段
- `pStatusCTS` 是 CTS 专用 placement status，仅影响 CTS 阶段
- placer 会取两者中更严格的值（`fixed` > `softFixed` > `placed`）
- `pStatusEffective` 返回考虑 parent hinst 的有效 placement status

```tcl
# 示例：pStatus = placed，pStatusCTS = fixed
# 在 CTS 阶段，inst 实际为 fixed
# 在 post-CTS optimization 阶段，inst 为 placed（如果 pStatusCTS 设置为 unset）
```

### 2. dbGet -p vs -p2 vs -p3

```tcl
# -p：一级属性穿透
dbGet -p top.insts.name my_inst          # 返回 name == "my_inst" 的 inst 指针

# -p2：两级属性穿透
dbGet -p2 top.insts.cell.baseClass block # 返回 cell.baseClass == "block" 的 inst 指针列表

# -p3：三级属性穿透
dbGet -p3 top.insts.instTerms.net.name clk  # 返回连接到 net "clk" 的 inst 指针列表
```

### 3. placeInstance 坐标单位

- `placeInstance` 的坐标单位是**微米**，不是 DBU
- inst 会自动 snap 到最近的 site
- 如果坐标在 core box 外，inst 会 snap 到最近的合法 site

```tcl
# 正确：坐标单位为微米
placeInstance my_inst 100.5 200.3 R0 -fixed

# 错误：使用 DBU（需要先转换）
# placeInstance my_inst 1005000 2003000 R0 -fixed  # ❌ 错误
```

### 4. specifyCellPad 单位

- left/right padding 单位：**site 数量**
- top/bottom padding 单位：**row 数量**
- padding 值必须是整数，范围 0-500

```tcl
# 正确：padding 为整数
specifyCellPad DFFHQX1 2                  # ✓ 正确

# 错误：padding 为浮点数
# specifyCellPad DFFHQX1 2.5              # ❌ 错误

# 分别设置四个方向的 padding
specifyCellPad DFFHQX1 -left 2 -right 2 -top 1 -bottom 1
```

### 5. 批量操作前先查询

```tcl
# 错误：直接批量修改，可能影响不应修改的 inst
# foreach inst [dbGet top.insts] {
#     dbSet $inst.pStatus fixed
# }

# 正确：先过滤，再修改
foreach inst [dbGet -p2 top.insts.cell.baseClass block] {
    dbSet $inst.pStatus fixed
}
```

### 6. 查询 cell 属性时使用 -p

```tcl
# 错误：直接查询 inst.isSequential（inst 没有此属性）
# dbGet $inst.isSequential                # ❌ 错误

# 正确：通过 inst.cell 查询 libCell 属性
dbGet $inst.cell.isSequential             # ✓ 正确

# 或使用 -p2 批量查询
dbGet -p2 top.insts.cell.isSequential 1   # ✓ 正确
```

### 7. lsort -unique 去重

```tcl
# 错误：重复设置同一 cell 的 padding
# foreach inst [dbGet -p2 top.insts.cell.isSequential 1] {
#     set cellName [dbGet $inst.cell.name]
#     specifyCellPad $cellName 2
# }

# 正确：先去重 cell name，再设置 padding
set seq_cells [lsort -unique [dbGet -p2 top.insts.cell.isSequential 1 -v .cell.name]]
foreach cellName $seq_cells {
    specifyCellPad $cellName 2
}
```

### 8. 验证 placement status

```tcl
# 修改后验证结果
set fixed_count 0
foreach inst [dbGet -p2 top.insts.cell.baseClass block] {
    if {[dbGet $inst.pStatus] == "fixed"} {
        incr fixed_count
    }
}
puts "Fixed $fixed_count macros"
```

### 9. 避免修改 physical-only cell

```tcl
# 过滤掉 physical-only cell（filler、tap、endcap 等）
foreach inst [dbGet -p2 top.insts.cell.baseClass core] {
    if {[dbGet $inst.isPhysOnly] == 0} {
        # 仅操作非 physical-only cell
        dbSet $inst.pStatus placed
    }
}
```

### 10. 查询 inst 的 box 和 pt

```tcl
# inst.box 返回边界框 {llx lly urx ury}（微米）
set box [dbGet $inst.box]
lassign $box llx lly urx ury

# inst.pt 返回左下角坐标 {x y}（微米）
set pt [dbGet $inst.pt]
lassign $pt x y

# 或直接查询 x/y
set x [dbGet $inst.pt_x]
set y [dbGet $inst.pt_y]
```
