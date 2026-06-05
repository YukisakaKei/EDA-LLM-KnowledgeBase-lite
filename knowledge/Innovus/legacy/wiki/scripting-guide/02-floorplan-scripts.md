---
source: knowledge/Innovus/legacy/jsonl/innovusTCR__211.jsonl | entries: [0282, 0316, 0318, 0335]
source: knowledge/Innovus/legacy/jsonl/dbSchema__211.jsonl | entries: [0026, 0036, 0050]
---

# Floorplan 脚本指南

## 概述

Floorplan 脚本用于创建和管理布图规划对象，包括 placement blockage（布局阻塞）、route blockage（布线阻塞）、halo（光晕）等。这些对象控制标准单元和布线的放置区域，减少拥塞并优化设计质量。

## 核心 API 速查表

### Placement Blockage

```tcl
# 创建布局阻塞
createPlaceBlockage -box {x1 y1 x2 y2} -type {hard|soft|partial|macroOnly}
createPlaceBlockage -box {x1 y1 x2 y2} -type partial -density 75
createPlaceBlockage -inst <instName> -cover
createPlaceBlockage -allMacro -cover

# 删除布局阻塞
deletePlaceBlockage -name <blockageName>
deletePlaceBlockage -all
```

### Route Blockage

```tcl
# 创建布线阻塞
createRouteBlk -box {x1 y1 x2 y2} -layer {metal1 metal3}
createRouteBlk -box {x1 y1 x2 y2} -layer all
createRouteBlk -inst <instName> -cover -layer {metal2 metal3}
createRouteBlk -box {x1 y1 x2 y2} -exceptpgnet  # 仅阻塞信号线
createRouteBlk -box {x1 y1 x2 y2} -pgnetonly    # 仅阻塞电源线

# 删除布线阻塞
deleteRouteBlk -name <blockageName>
deleteRouteBlk -all
```

### Halo

```tcl
# 添加 halo
addHaloToBlock <left> <bottom> <right> <top> <instName>
addHaloToBlock <left> <bottom> <right> <top> -allMacro
addHaloToBlock <left> <bottom> <right> <top> -allBlock
addHaloToBlock <left> <bottom> <right> <top> -cell <cellName>

# 删除 halo
deleteHaloFromBlock <instName>
deleteHaloFromBlock -allMacro
deleteHaloFromBlock -allBlock
```

## 典型场景 + 代码示例

### 场景 1：为所有 hard macro 创建 route blockage

```tcl
# 遍历所有 hard macro，在其上方创建布线阻塞
foreach inst [dbGet -p2 top.insts.cell.baseClass block] {
    set box [dbGet $inst.box]
    # dbGet 返回的 box 是列表格式，需要用 join 展开
    eval "createRouteBlk -box [join $box] -layer {metal2 metal3}"
}
```

**说明**：
- `dbGet -p2 top.insts.cell.baseClass block` 返回所有 hard macro 的 inst 指针列表
- `dbGet $inst.box` 返回 inst 的边界框坐标 `{x1 y1 x2 y2}`
- `join` 将列表展开为空格分隔的字符串
- `eval` 执行拼接后的命令字符串

### 场景 2：创建 partial blockage 控制密度

```tcl
# 在指定区域创建 75% 密度的 partial blockage
createPlaceBlockage -box {100 200 500 600} -type partial -density 75

# 创建 soft blockage，排除 flop 放置
createPlaceBlockage -box {100 200 500 600} -type soft -density 50 -excludeFlops
```

**说明**：
- `-type partial` 允许部分布局，`-density 75` 表示最多允许 75% 的布局密度
- `-excludeFlops` 禁止在该区域放置 flop 和 latch
- `-density` 和 `-excludeFlops` 仅适用于 `partial` 或 `soft` 类型

### 场景 3：为所有 macro 添加 halo

```tcl
# 为所有 macro 添加四周各 10 微米的 halo
addHaloToBlock 10 10 10 10 -allMacro

# 为特定 cell 类型的所有实例添加 halo
addHaloToBlock 5 5 5 5 -cell SRAM_CELL

# 为单个 inst 添加 halo
addHaloToBlock 10 20 30 40 my_macro_inst
```

**说明**：
- halo 值单位为微米（microns）
- halo 值基于 R0 方向定义，对于非 R0 方向的 inst，halo 会自动旋转/翻转
- 例如：对于 MY 方向的 inst，left halo 实际应用于 floorplan 中的右侧边缘

### 场景 4：在 macro 上方创建覆盖型 blockage

```tcl
# 在 macro 上方创建完全覆盖的 hard blockage
createPlaceBlockage -inst my_macro -cover -type hard

# 在所有 macro 上方创建覆盖型 route blockage
foreach inst [dbGet -p2 top.insts.cell.baseClass block] {
    set instName [dbGet $inst.name]
    createRouteBlk -inst $instName -cover -layer {metal1 metal2}
}
```

**说明**：
- `-cover` 创建与 inst 相同大小的 blockage
- 必须与 `-inst` 参数配合使用

### 场景 5：创建信号线专用 route blockage

```tcl
# 仅阻塞信号线，允许电源线通过
createRouteBlk -box {1000 1000 2000 2000} -layer {metal2 metal3} -exceptpgnet

# 仅阻塞电源线，允许信号线通过
createRouteBlk -box {1000 1000 2000 2000} -layer metal1 -pgnetonly
```

**说明**：
- `-exceptpgnet` 用于避免信号线噪声，但保留电源连接通道
- `-pgnetonly` 用于限制电源布线区域

### 场景 6：基于 inst 坐标批量创建 blockage

```tcl
# 为所有 macro 周围创建扩展的 route blockage
foreach inst [dbGet -p2 top.insts.cell.baseClass block] {
    set box [dbGet $inst.box]
    lassign $box x1 y1 x2 y2
    
    # 扩展 5 微米
    set x1 [expr $x1 - 5]
    set y1 [expr $y1 - 5]
    set x2 [expr $x2 + 5]
    set y2 [expr $y2 + 5]
    
    createRouteBlk -box "$x1 $y1 $x2 $y2" -layer metal2
}
```

**说明**：
- `lassign` 将列表元素分配给变量
- 坐标单位为微米
- 可通过算术运算扩展或收缩区域

### 场景 7：删除和重建 blockage

```tcl
# 删除所有 placement blockage
deletePlaceBlockage -all

# 删除所有 route blockage
deleteRouteBlk -all

# 删除所有 macro 的 halo
deleteHaloFromBlock -allMacro

# 重新创建
addHaloToBlock 15 15 15 15 -allMacro
createPlaceBlockage -allMacro -cover -type hard
```

## 注意事项 / 常见错误

### 1. 坐标单位

- `createPlaceBlockage` / `createRouteBlk` 的 `-box` 参数单位为**微米**
- `dbGet $inst.box` 返回的坐标单位为**微米**
- `addHaloToBlock` 的 halo 值单位为**微米**

### 2. box 参数格式

```tcl
# 正确：列表格式
createPlaceBlockage -box {100 200 300 400}

# 正确：字符串格式（需要引号）
createPlaceBlockage -box "100 200 300 400"

# 错误：直接传递 dbGet 返回的列表（需要 join）
set box [dbGet $inst.box]
createRouteBlk -box $box  # ❌ 错误

# 正确：使用 eval + join
eval "createRouteBlk -box [join $box]"  # ✓ 正确
```

### 3. halo 方向性

halo 值基于 inst 的 R0 方向定义，对于非 R0 方向的 inst 会自动旋转：

```tcl
# 对于 R0 方向的 inst
addHaloToBlock 10 20 30 40 my_inst
# left=10, bottom=20, right=30, top=40

# 对于 MY 方向的 inst（水平翻转）
addHaloToBlock 10 20 30 40 my_inst
# 实际 floorplan 中：left=30, bottom=20, right=10, top=40
```

### 4. partial blockage 密度限制

```tcl
# 密度值必须是 5 的倍数，范围 5-100
createPlaceBlockage -box {0 0 100 100} -type partial -density 75   # ✓ 正确
createPlaceBlockage -box {0 0 100 100} -type partial -density 73   # ❌ 错误
```

### 5. 避免重复创建

```tcl
# 在循环创建前先清理
deleteRouteBlk -all

foreach inst [dbGet -p2 top.insts.cell.baseClass block] {
    # 创建 blockage
}
```

### 6. layer 参数

```tcl
# 单层
createRouteBlk -box {0 0 100 100} -layer metal2

# 多层（列表格式）
createRouteBlk -box {0 0 100 100} -layer {metal1 metal3 metal5}

# 所有层
createRouteBlk -box {0 0 100 100} -layer all
```

### 7. 查询现有 blockage

```tcl
# 查询所有 placement blockage
dbGet top.fPlan.pBlkgs.name

# 查询所有 route blockage
dbGet top.fPlan.rBlkgs.name

# 查询 inst 的 halo
dbGet [dbGet -p top.insts.name my_inst].halo
```
