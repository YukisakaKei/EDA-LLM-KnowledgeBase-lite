---
source: knowledge/Innovus/legacy/jsonl/innovusUG__211.jsonl | entries: [106, 107, 108, 624, 677, 679, 685, 756, 757, 762, 763, 765, 795, 807]
---

# 布线概念

## 布线基础

### 详细布线（Detailed Routing）

详细布线是 postCTS 优化后的关键步骤，目标包括：

- 在无 DRC 或 LVS 违规的情况下完成布线
- 避免降低时序或产生信号完整性违规
- 使用 DFM 技术（多切割孔插入、线宽加宽、线间距优化）提高良率

**NanoRoute 引擎**特性：
- 并发执行时序驱动和 SI 驱动布线
- 对关键信号进行适当屏蔽以最小化交叉耦合
- 支持多切割孔插入、线宽加宽和间距优化

### 布线命令序列

基本布线流程：

```
routeDesign
```

关键配置：
- 若加载了时序信息，`routeDesign` 自动启用 `setNanoRouteMode -routeWithTimingDriven true`
- 自动解除时钟网固定（`setNanoRouteMode -routeDesignFixClockNets false`），以便 ECO 布线和 DRC 修复
- PostRoute 线扩展默认在 `setDesignMode -flowEffort extreme` 时启用，可显著降低 SI 影响

多切割孔配置：
```
setNanoRouteMode -drouteUseMultiCutViaEffort {low | medium | high}
```

### 布线时序改进

布线阶段的时序优化建议：

- 使用最新的工艺 LEF 文件（向工艺库或代工厂确认）
- 检查 DEF 文件中的 track 定义，必要时用 `add_tracks` 重新生成
- 若存在局部或全局拥塞，返回 placement、optimization 和 postCTS 优化阶段进一步优化
- 确保设置合适的最大布线层
- 检查 NonDefaultRules (NDRs)、屏蔽和层约束

**PostRoute 提取**：
- 设置提取模式：`setExtractRCMode -engine postRoute`
- 配置提取精度级别：
  - `low` — 原生详细提取引擎
  - `medium` — TQuantus 模式（性能和精度介于原生和 IQuantus 之间）
  - `high` — IQuantus 引擎（最高精度，推荐用于 ECO）
  - `signoff` — Standalone Quantus 引擎（最高精度）

---

## 布线优化和特殊处理

### 屏蔽布线（Shielded Routing）

使用文本命令进行屏蔽布线：

```
setAttribute -net net1 -shield_net vss
globalDetailRoute
```

多网屏蔽示例：
```
setAttribute -net net1 -shield_net abc_gnd
setAttribute -net net2 -shield_net abc_gnd
```

### 宽线布线（Routing Wide Wires）

NanoRoute 自动在连接到引脚时对宽线进行锥形处理，锥形部分使用最小宽度。

禁用输出引脚锥形处理：
```
setNanoRouteMode -drouteNoTaperOnOutputPin true
```

**非默认规则（Non-Default Rules）**：
- NanoRoute 默认将 NDR 间距视为软约束（资源充足时遵守，拥塞时可违反）
- 支持最多 254 条非默认规则
- 强制遵守 NDR：
  ```
  setNanoRouteMode -routeStrictlyHonorNonDefaultRule true
  ```

### 违规网删除和重布线

当设计有超过 100 个 DRC 违规且使用 LEF 5.4 或更高版本时，布线器自动删除并重布线具有工艺天线违规的线网。

### 馈通插入（Routing Feedthroughs）

布线馈通为分区预留空间供顶层使用，用于：
- 在分区栅栏内预留布线通道
- 支持顶层布线穿过分区

创建馈通步骤：
1. 使用 Create Physical Feedthrough 工具创建馈通
2. 在 Attribute Editor 中指定金属层
3. 运行 Partition 命令自动生成布线和放置阻挡

---

## 特殊布线应用

### 电源布线（Power Routing）

电源布线用于 Flip Chip 设计中的电源分配网络。

### ECO 布线（ECO Routing）

ECO（Engineering Change Order）布线用于设计修改后的增量布线，支持时钟网的 ECO 修复。

### 两层 RDL 布线（Two-Layer RDL Routing）

复杂 Flip Chip 设计可能需要两层 RDL 布线。支持混合策略：IO 区域使用两层，核心区域使用单层。

**层变换控制**：

1. 使用 `PIOLAYERCHANGE PAD` 约束和 `srouteLayerChangeExcludeRegion` 配置：
   ```
   srouteLayerChangeExcludeRegion "llx1 lly1 urx1 ury1 llx2 lly2 urx2 ury2"
   ```
   - `"0 0 0 0"` 表示整个芯片允许层变换
   - 默认区域为核心区域

2. 添加布线阻挡控制层变换位置（fcroute 严格遵守阻挡）

### eWLB 工艺中的 Bump 布线（Routing Bumps in eWLB）

在嵌入式晶圆级球栅阵列（eWLB）工艺中，某些 bump 位于芯片外，需连接到 IO 引脚。

使用 `srouteFcDieAreaOffset` 扩展允许布线的区域：
```
srouteFcDieAreaOffset "left bottom right top"
```

参数说明：
- `left`, `bottom`, `right`, `top` — 从芯片各边扩展的距离（微米）
- fcroute 在扩展区域内完成布线，超出扩展区域的 bump 保持开路

### DDR3 总线布线（fcroute Bus Routing for DDR3）

长布线路径可能导致 DDR3 信号间的串扰。解决方案：在信号网间添加 P/G 网，并以总线模式一起布线。

**总线布线特点**：
- 信号和 P/G 网以相同模式长距离布线
- 屏蔽 P/G 网浮动（不连接到 bump 或 pad）
- 可为每条网定义不同的宽度和间距

**NETGROUP 约束格式**：
```
NETGROUP
  BUSGUIDE net_group_name
  SHIELDNET/BUMP name WIDTH value SPACING value
  ...
END NETGROUP
```

**配置步骤**：
1. 在约束文件中定义 NETGROUP 约束
2. 在 fcroute 配置文件中添加 `sroutePioBusRoute true`
3. 使用 `createNetGroup` 创建线网组
4. 用 `addNetToNetGroup` 添加线网到线网组
5. 为线网组创建总线指引（bus guide）
6. 运行 `fcroute -selected_bump` 指定要布线的 bump

### 布线通道宽度估计（Estimating Routing Channel Width）

用于评估分区间所需的布线空间。

**估计考虑因素**：
- 当前引脚分配（已分配分区）
- 拓扑约束：块间边界、距离、顺序、对齐、宽高比、网权重、块 halo
- 块与核心边界的距离

**输出报告包含**：
- 分区、黑盒和硬宏之间的估计所需间距
- 基于引脚的每个分区周围的估计间距
- 块与核心边界的估计距离
