---
source: knowledge/Innovus/legacy/json/innovusTCR__211 | chapters: [0814, 0815, 0818, 0795, 0797, 0801, 0812, 0832]
---

# ECO 脚本编写指南

Innovus 21.1 ECO（Engineering Change Order）操作的 Tcl 脚本编写参考，覆盖 buffer 插入、cell rebind/upsize、net 连接修改等常见场景。

## 核心 API 速查表

| 命令 | 功能 | 典型用法 |
|------|------|----------|
| `ecoAddRepeater` | 插入 buffer/inverter | `-net <netName> -cell <cellName> [-loc {x y}]` |
| `ecoChangeCell` | Rebind/upsize/downsize cell | `-inst <instName> {-cell <newCell> \| -upsize \| -downsize}` |
| `ecoDeleteRepeater` | 删除 buffer/inverter pair | `-inst <instName>` |
| `addInst` | 添加新 instance | `-cell <cellName> -inst <instName> [-loc {x y}]` |
| `deleteInst` | 删除 instance | `<instName>` |
| `addNet` | 添加新 net | `<netName> [-power \| -ground]` |
| `deleteNet` | 删除 net | `<netName>` |
| `attachTerm` | 连接 terminal 到 net | `<instName> <termName> <netName>` |
| `detachTerm` | 断开 terminal 连接 | `<instName> <termName> [<netName>]` |
| `setEcoMode` | 控制 ECO 行为 | `-refinePlace {true\|false} -batchMode {true\|false}` |

## 场景 1：插入 Buffer

### 基本用法

```tcl
# 在指定 net 上插入 buffer
ecoAddRepeater -net myNet -cell BUFX4

# 在指定位置插入 buffer（坐标单位：microns）
ecoAddRepeater -net myNet -cell BUFX4 -loc {100.5 200.3}

# 插入 inverter pair（自动添加两个 inverter）
ecoAddRepeater -net myNet -cell INVX4

# 插入 inverter pair 并指定两个位置
ecoAddRepeater -net myNet -cell INVX4 -loc {100 200 150 250}
```

### 控制 buffer 位置

```tcl
# 靠近 sink 插入（relativeDistToSink: 0=driver, 1=sink）
ecoAddRepeater -net myNet -cell BUFX4 -relativeDistToSink 0.1

# 靠近 driver 插入
ecoAddRepeater -net myNet -cell BUFX4 -relativeDistToSink 0.9

# 基于 slack 插入
ecoAddRepeater -net myNet -cell INVX4 -offLoadSlack -0.1
```

### 为指定 terminal 插入 buffer

```tcl
# 为 terminal list 插入 buffer
ecoAddRepeater -net n1 -cell BUFX4 -term {i1/i2/in1 i1/i2/in2 i1/i2/in3}
```

### 批量模式（提升性能）

```tcl
# 开启批量模式
setEcoMode -batchMode true

# 批量插入 buffer
ecoAddRepeater -net net1 -cell BUFX4
ecoAddRepeater -net net2 -cell BUFX4
ecoAddRepeater -net net3 -cell BUFX4

# 关闭批量模式（此时才更新 timing）
setEcoMode -batchMode false
```

## 场景 2：Buffer Rebind / Upsize / Downsize

### Upsize / Downsize

```tcl
# Upsize instance（自动选择同 footprint 的更高驱动强度 cell）
ecoChangeCell -inst myInst -upsize

# Downsize instance
ecoChangeCell -inst myInst -downsize
```

### Rebind 到指定 cell

```tcl
# 将 instance 替换为指定 cell
ecoChangeCell -inst myInst -cell BUFX20

# Pin 名称不同时需要 pinMap
ecoChangeCell -inst myInst -cell TXOR2X2 -pinMap A X B Y Y Z
```

### 批量 rebind（遍历 net 的所有 driver）

```tcl
# 示例：将指定 net 的所有 driver rebind 到新 cell
proc rebindNetDrivers {netName newCellName} {
    set netPtr [dbGet -p top.nets.name $netName -i 0]
    if {$netPtr == "0x0"} {
        puts "Error: Net $netName not found"
        return
    }
    
    # 遍历 net 的所有 output terminal（driver）
    foreach term [dbGet ${netPtr}.terms.isOutput 1 -p2] {
        set instPtr [dbGet ${term}.inst]
        set instName [dbGet ${instPtr}.name]
        set cellName [dbGet ${instPtr}.cell.name]
        
        # 检查 footprint 是否匹配
        set oldFP [dbGet ${instPtr}.cell.footPrintName]
        set newFP [dbGet [dbGet -p top.head.libCells.name $newCellName -i 0].footPrintName]
        
        if {$oldFP == $newFP && $cellName != $newCellName} {
            puts "Rebinding $instName: $cellName -> $newCellName"
            ecoChangeCell -inst $instName -cell $newCellName
        } else {
            puts "Skipping $instName (footprint mismatch or same cell)"
        }
    }
}

# 使用示例
rebindNetDrivers myNet BUFX8
```

## 场景 3：Net 连接修改

### 基本连接操作

```tcl
# 创建新 net
addNet newNet

# 将 terminal 连接到 net（如已连接到其他 net，会自动 detach）
attachTerm inst1 pinA newNet

# 断开 terminal 连接
detachTerm inst1 pinA oldNet
```

### 完整示例：重新连接 net

```tcl
# 场景：将 inst1/pinA 从 oldNet 改接到 newNet
proc reconnectTerm {instName termName oldNetName newNetName} {
    # 检查 newNet 是否存在，不存在则创建
    set netPtr [dbGet -p top.nets.name $newNetName -i 0]
    if {$netPtr == "0x0"} {
        puts "Creating net: $newNetName"
        addNet $newNetName
    }
    
    # attachTerm 会自动 detach 旧连接
    puts "Attaching $instName/$termName to $newNetName"
    attachTerm $instName $termName $newNetName
}

# 使用示例
reconnectTerm inst1 pinA oldNet newNet
```

### 批量重连（将 net 的所有 fanout 改接到新 net）

```tcl
proc reconnectAllFanouts {oldNetName newNetName} {
    set oldNetPtr [dbGet -p top.nets.name $oldNetName -i 0]
    if {$oldNetPtr == "0x0"} {
        puts "Error: Net $oldNetName not found"
        return
    }
    
    # 创建新 net（如不存在）
    set newNetPtr [dbGet -p top.nets.name $newNetName -i 0]
    if {$newNetPtr == "0x0"} {
        addNet $newNetName
    }
    
    # 遍历所有 input terminal（fanout）
    foreach term [dbGet ${oldNetPtr}.terms.isInput 1 -p2] {
        set instName [dbGet ${term}.inst.name]
        set termName [dbGet ${term}.name]
        puts "Reconnecting $instName/$termName to $newNetName"
        attachTerm $instName $termName $newNetName
    }
}

# 使用示例
reconnectAllFanouts oldNet newNet
```

## 场景 4：手动插入 Buffer（低层 API）

当 `ecoAddRepeater` 不满足需求时，可使用 `addInst` + `attachTerm` 手动插入：

```tcl
proc manualInsertBuffer {netName bufCellName bufInstName bufLoc} {
    # 1. 创建 buffer instance
    addInst -cell $bufCellName -inst $bufInstName -loc $bufLoc
    
    # 2. 创建新 net（buffer 输出）
    set newNetName "${netName}_buf"
    addNet $newNetName
    
    # 3. 连接 buffer 输入到原 net
    attachTerm $bufInstName I $netName
    
    # 4. 连接 buffer 输出到新 net
    attachTerm $bufInstName Z $newNetName
    
    # 5. 将原 net 的 fanout 改接到新 net（需根据实际需求选择）
    # reconnectAllFanouts $netName $newNetName
    
    puts "Buffer $bufInstName inserted on net $netName"
}

# 使用示例
manualInsertBuffer myNet BUFX4 myBuf {100 200}
```

## 场景 5：删除 Buffer

```tcl
# 删除 buffer（自动合并 wire）
ecoDeleteRepeater -inst bufInst

# 删除 inverter pair（自动查找 back-to-back 的另一个 inverter）
ecoDeleteRepeater -inst inv1

# 批量删除
ecoDeleteRepeater -inst {buf1 buf2 buf3}

# 指定 inverter pair 删除
ecoDeleteRepeater -invPair {{inv1 inv2} {inv3 inv4}}
```

## 场景 6：ECO 模式控制

### 常用 setEcoMode 选项

```tcl
# 禁用自动 refine place（提升性能）
setEcoMode -refinePlace false

# 允许修改 fixed instance
setEcoMode -honorFixedStatus false

# 允许修改 dont_touch net/instance
setEcoMode -honorDontTouch false

# 允许修改 dont_use cell
setEcoMode -honorDontUse false

# 禁用 LEQ 检查（允许 buffer 改为 inverter，会改变逻辑）
setEcoMode -LEQCheck false

# 禁用 timing 更新（批量操作后手动更新）
setEcoMode -updateTiming false

# 重置所有选项为默认值
setEcoMode -reset
```

### 典型工作流

```tcl
# 1. 配置 ECO 模式
setEcoMode -refinePlace false
setEcoMode -batchMode true

# 2. 执行 ECO 操作
ecoAddRepeater -net net1 -cell BUFX4
ecoChangeCell -inst inst1 -upsize
ecoDeleteRepeater -inst buf1

# 3. 退出批量模式（触发 timing 更新）
setEcoMode -batchMode false

# 4. 恢复默认设置
setEcoMode -reset
```

## 注意事项

### 1. 坐标单位

- `ecoAddRepeater -loc`、`addInst -loc`：单位为 **microns**
- `dbGet $inst.pt`：返回 **DBU**（需用 `dbDBUToMicrons` 转换）

### 2. 批量模式性能优化

批量 ECO 操作时务必使用 `-batchMode`：

```tcl
setEcoMode -batchMode true
# ... 大量 ECO 操作 ...
setEcoMode -batchMode false  # 此时才更新 timing
```

### 3. Fixed Instance 处理

默认情况下 `ecoChangeCell` 不能修改 fixed instance，需先设置：

```tcl
setEcoMode -honorFixedStatus false
ecoChangeCell -inst fixedInst -upsize
```

### 4. Inverter Pair 自动插入

当 `-cell` 指定为 inverter 时，`ecoAddRepeater` 默认插入 **一对 inverter**（保持逻辑等价）。如需插入单个 inverter（改变逻辑），需先设置：

```tcl
setEcoMode -LEQCheck false
ecoAddRepeater -net myNet -cell INVX4  # 只插入一个 inverter
```

### 5. Post-Mask ECO 限制

Post-mask ECO 中不能使用以下命令（需用 `loadECO -postMask` 替代）：

- `ecoAddRepeater`（除非使用 `-noPlace` + `ecoSwapSpareCell`）
- `ecoChangeCell`
- `ecoDeleteRepeater`
- `addInst`（除非使用 `-noPlace` + `ecoSwapSpareCell`）
- `deleteInst`

### 6. 层次化设计中的 Buffer 插入

跨 partition 插入 buffer 时，需使用 `-hinstGuide` 指定层次：

```tcl
setEcoMode -batchMode true
ecoAddRepeater -net myNet -cell BUFX4 -name myBuf -hinstGuide partition1
setEcoMode -batchMode false
```

### 7. dbGet 查询 Driver/Fanout

```tcl
# 查询 net 的所有 driver（output terminal）
set drivers [dbGet $netPtr.terms.isOutput 1 -p2]

# 查询 net 的所有 fanout（input terminal）
set fanouts [dbGet $netPtr.terms.isInput 1 -p2]

# 查询 instance 的 cell 名称
set cellName [dbGet $instPtr.cell.name]

# 查询 cell 的 footprint
set footprint [dbGet $instPtr.cell.footPrintName]
```
