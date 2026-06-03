---
source: knowledge/Innovus/legacy/json/innovusUG__211 | chapters: [0623, 0624, 0107, 0108, 0109, 0670, 0671, 0672, 0698, 0700, 0704, 0715]
---

# 布线命令快速参考

## 布线命令序列

### 基本布线流程

```tcl
# 1. Route the design (recommended command)
routeDesign

# 2. PostRoute wire spreading (if not using flowEffort extreme)
setNanoRouteMode -routeWithTimingDriven false
setNanoRouteMode -droutePostRouteSpreadWire true
routeDesign -wireOpt
setNanoRouteMode -droutePostRouteSpreadWire false

# 3. Set double cut via effort
setNanoRouteMode -drouteUseMultiCutViaEffort {low | medium | high}
```

### 其他布线命令

```tcl
# Global routing only
globalRoute

# Detailed routing only
detailRoute

# Global + Detailed routing
globalDetailRoute

# ECO routing
ecoRoute
```

**注意**：`routeDesign` 是所有设计流程推荐使用的超级命令。

## routeDesign 超级命令

### 优势

- 默认运行 SMART 布线（时序驱动 + SI 驱动）
- 自动解除时钟网络固定并优先布线
- 布线前运行布局检查
- 检查 setNanoRouteMode 设置中的冲突
- 简化过孔和线网优化

### 关键选项

```tcl
routeDesign                    # Full routing
routeDesign -viaOpt           # Via optimization after routing
routeDesign -wireOpt          # Wire optimization after routing
routeDesign -noPlacementCheck # Skip placement check
```

### 时钟网络处理

```tcl
# Keep clock nets fixed (default: false)
setNanoRouteMode -routeDesignFixClockNets true

# Don't route clock nets first (default: true)
setNanoRouteMode -routeDesignRouteClockNetsFirst false
```

## NanoRoute 模式参数

### 时序驱动布线

```tcl
# Enable timing-driven routing
setNanoRouteMode -routeWithTimingDriven true

# Enable SI-driven routing
setNanoRouteMode -routeWithSiDriven true

# Both together (recommended for crosstalk prevention)
setNanoRouteMode -routeWithTimingDriven true
setNanoRouteMode -routeWithSiDriven true
globalDetailRoute
```

**注意**：`routeDesign` 默认同时启用两者。

### ECO 布线

```tcl
# Enable ECO mode
setNanoRouteMode -routeWithEco true
globalDetailRoute

# ECO routing after multi-cut via insertion
setNanoRouteMode -routeWithEco true
setNanoRouteMode -drouteUseMultiCutViaEffort low
globalDetailRoute

# Route only specific nets in ECO mode
setAttribute -net @PREROUTED -skip_routing true
setAttribute -net eco_net1 -skip_routing false
setAttribute -net eco_net2 -skip_routing false
```

**限制**：不要在 ECO 模式下使用 `globalRoute`。如果新增线网超过 10%，应运行完整布线。

### 多切割过孔插入

```tcl
# During routing (concurrent insertion)
setNanoRouteMode -drouteUseMultiCutViaEffort {medium | high}
detailRoute

# Postroute via optimization
setNanoRouteMode -drouteUseMultiCutViaEffort {medium | high}
routeDesign -viaOpt
```

## 过孔优化

### 布线后过孔减少

```tcl
# Minimize via count
setNanoRouteMode -drouteMinSlackForWireOptimization <slack>
setNanoRouteMode -routeConcurrentMinimizeViaCountEffort <value>
routeDesign -viaOpt
```

### 单切割到多切割过孔交换

```tcl
# Timing-driven via swapping
setNanoRouteMode -drouteMinSlackForWireOptimization <slack>
setNanoRouteMode -droutePostRouteSwapVia multiCut
routeDesign -viaOpt

# Non-timing-driven via swapping
setNanoRouteMode -routeWithTimingDriven false
setNanoRouteMode -droutePostRouteSwapVia multiCut
routeDesign -viaOpt

# With via priority weighting
setNanoRouteMode -routeWithTimingDriven false
setNanoRouteMode -dbViaWeight "viaName viaWeight"
setNanoRouteMode -droutePostRouteSwapVia multiCut
routeDesign -viaOpt
```

**过孔替换顺序**：
1. 加宽双切割过孔
2. 普通双切割过孔
3. 加宽单切割过孔

**前提条件**：
- LEF 中定义或自动生成双切割和加宽过孔
- 设计完全布线（全局 + 详细）
- 无 DRC 违规

### 优化选定网络中的过孔

```tcl
# Skip all nets except selected ones
setAttribute -net * -skip_routing true
setAttribute -net <net_name> -skip_routing false
globalDetailRoute
```

## 布线后提取

```tcl
# Set extraction engine to postRoute
setExtractRCMode -engine postRoute

# Set effort level
setExtractRCMode -effortLevel {low | medium | high | signoff}
```

**努力级别**：
- `low`：原生详细提取（无需 Quantus 许可证）
- `medium`：TQuantus 提取（无需 Quantus 许可证，支持分布式处理）
- `high`：IQuantus 提取（需要 Quantus 许可证，最适合 ECO）
- `signoff`：独立 Quantus（需要 Quantus 许可证，最高精度）

## 金属填充命令

### 添加金属填充

```tcl
# Set metal fill parameters
setMetalFill -layer <layer_list> \
             -minDensity <value> \
             -maxDensity <value> \
             -windowSize <x> <y> \
             -windowStep <x> <y>

# Add metal fill
addMetalFill -layer <layer_list> \
             -timingAware <true|false> \
             -area <llx lly urx ury>

# Verify metal density
verifyMetalDensity -report <filename>
```

### 过孔填充

```tcl
# Set via fill parameters
setViaFill -layer <layer_list> \
           -minDensity <value> \
           -maxDensity <value>

# Add via fill
addViaFill -layer <layer_list>

# Verify cut density
verifyCutDensity -report <filename>
```

### 删除金属填充

```tcl
# Delete all metal fill
deleteMetalFill

# Delete metal fill on specific layers
deleteMetalFill -layer <layer_list>

# Delete metal fill in area
deleteMetalFill -area <llx lly urx ury>
```

### 布线后修剪金属填充

```tcl
# Trim fill that causes DRC violations
trimMetalFill
```

## 布线的网络属性

### 常用属性

```tcl
# Skip routing on net
setAttribute -net <net_name> -skip_routing true

# Set net weight (priority)
setAttribute -net <net_name> -weight <value>

# Layer constraints
setAttribute -net <net_name> -bottom_preferred_routing_layer <layer>
setAttribute -net <net_name> -top_preferred_routing_layer <layer>

# Extra spacing for SI prevention
setAttribute -net <net_name> -preferred_extra_space <value>

# Avoid detours (for critical nets)
setAttribute -net <net_name> -avoid_detour true

# SI postroute fix
setAttribute -net <net_name> -si_post_route_fix true

# Shielding
setAttribute -net <net_name> -shield_net <power_net>
```

### 时钟网络属性（自动设置）

时钟网络的默认值：
- Weight：10（普通线网为 2）
- Bottom layer：3
- Top layer：4
- Avoid detour：true

```tcl
# Set all SI prevention attributes at once
setAttribute -net <clock_net> -si_prevention true
# This sets: weight=10, avoid_detour=true, preferred_extra_space=1
```

## 布线检查和调试

### 检查布线

```tcl
# Report routing statistics
reportRoute

# Verify connectivity
verifyConnectivity

# Report wire statistics
reportWire

# Check tracks
check_tracks
```

### 生成优化的轨道

```tcl
# Only needed for non-native DEF files
add_tracks
```

## 布线期间改善时序

### 最佳实践

1. 使用来自代工厂的最新技术 LEF
2. 检查 DEF 中的轨道定义，必要时重新生成：
   ```tcl
   add_tracks
   ```
3. 布线前解决拥塞问题（返回布局/优化阶段）
4. 设置适当的顶层最大布线层
5. 检查非默认规则（NDR）和层约束

### 时序驱动设置

```tcl
# For congested designs
setNanoRouteMode -routeWithTimingDriven true
# Use low timing-driven effort

# For non-congested designs (or severe SI problems)
setNanoRouteMode -routeWithTimingDriven true
# Use high timing-driven effort
```

## 天线修复

```tcl
# Specify diode cells
setNanoRouteMode -routeAntennaCellName <cell_name>

# Force layer changing (skip diode insertion temporarily)
setNanoRouteMode -routeInsertAntennaDiode false
# Route, then reset to true and re-run

# Highlight inserted diodes
# Edit -> Select by Name -> *_antenna_*
```

## 多线程和分布式处理

### 多线程（单机）

```tcl
# Set number of CPUs
setMultiCpuUsage -localCpu <num_cpus>
```

### 超线程（分布式处理）

```tcl
# Set distributed processing
setDistributedProcessing -hosts {host1 host2 host3} \
                         -localCpu <num> \
                         -remoteCpu <num>
```

**要求**：
- 可用的 Innovus 许可证（无需特殊许可证）
- 平台独立（可混合操作系统/硬件）
- 支持 rsh、SSH、LSF、Sun Grid

## 常见布线场景

### 场景 1：标准完整布线

```tcl
# Simple approach
routeDesign

# With via optimization
routeDesign
routeDesign -viaOpt
```

### 场景 2：时序关键设计

```tcl
setNanoRouteMode -routeWithTimingDriven true
setNanoRouteMode -routeWithSiDriven true
routeDesign
```

### 场景 3：优化后的 ECO

```tcl
setNanoRouteMode -routeWithEco true
setNanoRouteMode -drouteUseMultiCutViaEffort low
globalDetailRoute
```

### 场景 4：手动优先布线时钟

```tcl
# Route clocks
setAttribute -net <clock_nets> -weight 10
setAttribute -net <clock_nets> -bottom_preferred_routing_layer 3
setAttribute -net <clock_nets> -top_preferred_routing_layer 4
setAttribute -net <clock_nets> -avoid_detour true
globalDetailRoute -nets <clock_nets>

# Route rest of design
globalDetailRoute
```

### 场景 5：布线后优化流程

```tcl
# 1. Initial routing
routeDesign

# 2. Via optimization
setNanoRouteMode -droutePostRouteSwapVia multiCut
routeDesign -viaOpt

# 3. Wire optimization
setNanoRouteMode -droutePostRouteSpreadWire true
routeDesign -wireOpt

# 4. Add metal fill
setMetalFill -layer {M1 M2 M3 M4 M5} -minDensity 0.2 -maxDensity 0.8
addMetalFill -layer {M1 M2 M3 M4 M5} -timingAware true

# 5. Verify density
verifyMetalDensity -report metal_density.rpt
```

## DRC 违规类型

布线报告中常见的违规缩写：

| 缩写 | 全称 |
|------------|-----------|
| MetSpc | Metal Spacing |
| Notch | Notch Violation |
| Short | Short Circuit |
| NdrSpc | Non-Default Rule Spacing |
| Mar | Minimum Area Rule |
| EolOpp | End-of-Line Opposite |
| AdjCut | Adjacent Cut Spacing |
| Ant | Antenna |

## 相关命令

```tcl
# Display current NanoRoute settings
getNanoRouteMode

# Display net attributes
getAttribute -net <net_name>

# Save routing to DEF
defOut <filename>

# Save parasitics
extractRC
rcOut -spef <filename>
```
