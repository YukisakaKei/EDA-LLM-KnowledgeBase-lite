---
source: knowledge/Innovus/legacy/json/innovusUG__211 | chapters: [1299, 1301, 1309, 1310, 1311, 1313, 1314, 1316]
---

# 3D IC 和 TSV 设计

## 概述

3D IC 系统通过堆叠多个芯片实现三维互连。与传统 IC 不同，3D IC 在芯片背面引入了重分布层（RDL）和通硅孔（TSV），使得 Bump 可以放置在芯片正面和背面。

### 3D IC 的核心组件

- **Back Side Metal (MB)** — 芯片背面的重分布层，用于背面互连
- **Through Silicon Via (TSV)** — 穿过硅基体的孔，连接正面金属和背面 RDL
- **Micro Bump** — 相邻芯片间的对齐 Bump，构成跨芯片数据通路
- **Flip Chip Bump** — 芯片与封装基体间的 Bump

### Innovus 中的 3D IC 支持

Innovus 将 3D IC 的所有芯片分为多个 Tier，每个 Tier 包含多个芯片。设计者可以：
- 指定多芯片系统配置（芯片间互连、相对位置）
- 操作 TSV 和 Bump
- 执行共同设计和接口同步

---

## TSV/Bump/背面金属建模

### LEF 文件定义

所有物理信息在 LEF 文件中定义（LEF 57 或更高版本）：

- **MB（背面金属）** — 建模为 ROUTING 层，位于第一个正常金属层之前，标记 `BACKSIDE` 属性
- **TSV** — 建模为 CUT 层，标记 `TYPE TSV` 属性
- **Bump** — 建模为单元，包含与 Bump 焊盘相同形状和层的引脚

### LEF 示例

```
PROPERTYDEFINITIONS
  LAYER LEF58_BACKSIDE STRING ;
  LAYER LEF58_TYPE STRING ;
END PROPERTYDEFINITIONS

LAYER MB
  TYPE ROUTING ;
  PROPERTY LEF58_BACKSIDE "TRUE" ;
END MB

LAYER TSV_CUT
  TYPE CUT ;
  PROPERTY LEF58_TYPE "TSV" ;
END TSV_CUT
```

### Bump 分类

- **Front Bump** — 位于顶部金属层的 Bump
- **Back Bump** — 位于背面金属层的 Bump
- **Micro Bump** — 相邻芯片间的对齐 Bump（可为正面或背面）

---

## TSV/Bump 操作

### TSV/Bump 生成

#### 方法 1：根据相邻芯片的 Bump 创建

如果相邻芯片已固定 Micro Bump，可导出相邻芯片的 Bump 文件并导入到当前芯片：

```tcl
# 导出相邻芯片的 Bump 位置
writeBumpLocation -file adjacent_bump.txt

# 在当前芯片导入并创建对应的 Bump 和 TSV
readBumpLocation -file adjacent_bump.txt \
  -frontBump FRONT_BUMP_CELL \
  -backBump BACK_BUMP_CELL \
  -tsvViaName TSV_CELL
```

#### 方法 2：通过命令在当前芯片创建

如果相邻芯片未固定 Micro Bump，使用 `addTSV` 命令创建 TSV/Bump 阵列：

```tcl
addTSV -addTSV \
  -frontBump FRONT_BUMP_CELL \
  -backBump BACK_BUMP_CELL \
  -lowerLeftLoc {x1 y1} \
  -pitchxy {pitch_x pitch_y} \
  -upperRightLoc {x2 y2}
```

### TSV/Bump 放置指导

- 将 TSV 和背面 Bump 放置在靠近与相邻芯片互连的 IO/Block 的位置
- 保持 TSV 在核心区域外，除非 TSV 必须连接到核心内的 Block（TSV 会破坏 Follow Pin）
- 优先考虑信号完整性和功耗分布

### TSV/Bump 分配

#### 自动分配（基于相邻芯片 Bump）

```tcl
readBumpLocation -file adjacent_bump.txt \
  -frontBump FRONT_BUMP_CELL \
  -backBump BACK_BUMP_CELL \
  -tsvViaName TSV_CELL
```

#### 手动分配（使用 assignTSV）

```tcl
# 分配正面 Bump 与 IO 引脚
assignTSV -frontBump -net {net1 net2 ...}

# 分配背面 Bump 和 TSV
assignTSV -backBump -net {net1 net2 ...}

# 分配指定的 TSV 单元
assignTSV -tsvViaName TSV_CELL -net {net1 net2 ...}
```

---

## TSV/Bump 布线

### TSV 到 IO Pad 布线

使用 `fcroute` 命令的 `aio` 模式：

```tcl
fcroute -type signal \
  -designStyle aio \
  -connectTsvToPad \
  -routeWidth 3 \
  -layerChangeTopLayer METAL4 \
  -layerChangeBotLayer METAL1
```

### TSV 到 Bump 布线

Innovus 无法同时布线正面和背面 Bump，需要分别处理。

#### 背面 Bump 布线

```tcl
# backside.extraConf 文件内容
srouteExcludeBumpType FRONT_BUMP

# 布线命令
fcroute -type signal \
  -designStyle aio \
  -routeWidth 8 \
  -layerChangeTopLayer MB \
  -layerChangeBotLayer MB \
  -connectTsvToBump \
  -extraConfig ./conf/backside.extraConf
```

#### 正面 Bump 布线

```tcl
# frontside.extraConf 文件内容
srouteExcludeBumpType BACK_BUMP

# 布线命令
fcroute -type signal \
  -designStyle aio \
  -routeWidth 8 \
  -layerChangeTopLayer METAL4 \
  -layerChangeBotLayer METAL1 \
  -connectTsvToBump \
  -extraConfig ./conf/frontside.extraConf
```

### TSV 到电源条纹布线

```tcl
fcroute -type power \
  -connectTsvToRingStripe \
  -routeWidth 6 \
  -layerChangeTopLayer METAL2 \
  -layerChangeBotLayer METAL1
```

### Bump 到 Bump 布线

#### 正面 Bump 到正面 Bump（中介层设计）

中介层设计无实例，需要正面 Bump 直接连接到正面 Bump：

```tcl
setNanoRouteMode -routeSelectedNetOnly true
setNanoRouteMode -routeConnectToBump true
routeDesign
```

#### 总线布线（HBM 到 SoC）

在中介层设计中连接 HBM 和 SoC 芯片时，通常需要总线布线以确保信号传输性能。

**步骤 1：创建非默认规则（NDR）和总线约束**

```tcl
# 定义 NDR（宽度 2um，间距 3um）
add_ndr -width {METAL2 2.0 METAL4 2.0} \
  -spacing {METAL2 3 METAL2 3} \
  -name bus_ndr

# 定义总线约束
setIntegRouteConstraint -type bus \
  -topLayer METAL2 \
  -bottomLayer METAL2 \
  -rule bus_ndr \
  -net {bus_net_1 bus_net_2 ...}
```

**步骤 2：设置层间屏蔽约束**

```tcl
# 定义屏蔽线偏移（2.8um）
setNanoRouteMode -interposerInterlayerShieldingOffsets {METAL1 2.8 METAL3 2.8}

# 定义屏蔽线宽度（2um）
setNanoRouteMode -interposerInterlayerShieldingWidths {METAL1 2.0 METAL3 2.0}

# 定义屏蔽线位置（M2 和 M4 下方）
setNanoRouteMode -interposerInterlayerShieldingLayers {METAL2 bottom METAL4 bottom}

# 定义屏蔽网名称
setNanoRouteMode -interposerInterlayerShieldingNets {METAL1:METAL4 VSS}
```

**步骤 3：设置同层交错屏蔽约束**

创建 `fc_shield.const` 文件：

```
SHIELDWIDTH 1.0
SHIELDGAP 2.0
SHIELDSTYLE c
SHIELDNET VSS
```

应用约束：

```tcl
setFlipChipMode -constraintFile fc_shield.const
```

**步骤 4：创建 PG 条纹和布线**

```tcl
routeDesign -bump
```

### TSV/Bump 到实例引脚布线

在 3D 堆叠芯片设计中，有时没有 IO Pad，TSV 和正面 Bump 直接连接到实例引脚：

```tcl
setNanoRouteMode -routeSelectedNetOnly true
setNanoRouteMode -routeConnectToBump true
routeDesign
```

### TSV-Bump 单元到 Pad 布线

使用 `fcroute` 的 `connect_bump_to_pad` 模式，支持从正面 Bump 到 TSV-Bump 的布线：

```tcl
# fc.const 文件内容
BUMP_AS_PAD
  TSV_BUMP_CELL_NAME
END BUMP_AS_PAD

# 布线命令
fcroute -type connect_bump_to_pad \
  -connectTsvToBump \
  -layerChangeTopLayer METAL4 \
  -layerChangeBotLayer METAL1 \
  -constraintFile fc.const \
  -nets "net1 net2 ..."
```

---

## 3D 设计约束和配置

### 嵌入式 TSV

嵌入式 TSV 建模为背面金属上的引脚，`fcroute` 命令会自动识别并处理。

### 多层布线配置

- **顶层** — 通常为正面金属层（METAL4）
- **底层** — 通常为背面金属层（MB）或第一层金属（METAL1）
- **中间层** — 根据设计需求选择

### 性能优化

- 最小化 TSV 数量以降低成本
- 优化 TSV 放置以减少布线拥塞
- 使用屏蔽线降低串扰
- 平衡功耗分布，避免热点

---

## 常见命令速查

| 命令 | 功能 |
|---|---|
| `writeBumpLocation` | 导出 Bump 位置文件 |
| `readBumpLocation` | 导入 Bump 位置并创建 TSV/Bump |
| `addTSV` | 创建 TSV/Bump 阵列 |
| `assignTSV` | 分配网络到 TSV/Bump |
| `fcroute` | Flip Chip 布线（支持 TSV/Bump） |
| `setNanoRouteMode` | 配置 Nano Route 模式 |
| `setIntegRouteConstraint` | 设置集成布线约束 |
| `setFlipChipMode` | 设置 Flip Chip 模式 |
| `routeDesign` | 执行布线 |
