---
source: knowledge/Innovus/legacy/json/innovusUG__211 | chapters: [0357, 0359, 0360, 0361, 0362, 0363, 0370, 0374, 0376, 0377, 0378, 0379, 0407, 0412]
---

# 电源命令快速参考

## 概述

Innovus 中的低功耗设计支持：
- **多电源单电压 (MSSV)**：核心逻辑使用单一电压，部分区域隔离在独立电源上
- **多电源多电压 (MSMV)**：核心逻辑使用不同电压
- **电源域关断**：整个域断电（节省漏电功耗 + 动态功耗）
- **电压缩放**：域在降低的电压下运行（节省动态功耗）

## 电源意图格式

### CPF (Common Power Format)
支持的版本：CPF 1.0, 1.0e, 1.1 (默认), 2.0

### UPF (IEEE 1801)
统一电源格式标准

---

## 命令流程顺序

### 1. 加载设计和电源意图

```tcl
# Initialize design with MMMC
init_design
# Set MMMC file: set init_mmmc_file viewDefinition.tcl

# Load CPF power intent
read_power_intent -cpf <cpf_file>

# OR load UPF power intent
read_power_intent -1801 <upf_file>

# Commit power intent (creates power domains, rules, synthesizes LP logic)
commit_power_intent
```

**`commit_power_intent` 的作用：**
- 检查 CPF/UPF 语法
- 创建电源域（组）和 site 列表
- 读取并提交 CPF/UPF 规则
- 综合低功耗使能信号的逻辑
- 生成全局和绑定连接
- 为优化/CTS/验证创建隐式 ISO/LS 规则
- 生成低功耗数据库 (*.cpfdb)

### 2. 电源域管理

电源域通过 CPF/UPF 文件创建。每个域具有：
- 特定的库（.lib, .lef）绑定
- 围栏约束（物理边界）
- 电源/地连接
- 用于标准单元放置的 site 列表

**每个域的库绑定（在 viewDefinition.tcl 中）：**
```tcl
create_library_set -name wc_0v81 -timing [list lib1.lib lib2.lib ...]
create_delay_corner -name AV_PM_on_dc -library_set wc_0v81 ...

# Bind library to specific power domain
update_delay_corner -name AV_PM_on_dc -power_domain PD1 \
  -library_set wc_0v81 -opcond_library <lib> -opcond <opcond>
```

### 3. 低功耗单元插入

低功耗单元在优化过程中根据 CPF/UPF 规则自动插入。

**单元类型：**
- **隔离单元**：防止域断电时信号浮空（钳位到高/低/保持）
- **电平转换器**：在域之间转换电压（低→高 或 高→低）
- **常开单元**：由次级电源引脚供电，域关断时保持开启
- **状态保持 DFF**：域断电时保持状态
- **电源开关单元**：控制域的开关电
- **LS/ISO 组合单元**：组合电平转换器和隔离功能

### 4. 电源规划和布线

```tcl
# Create power stripes for always-on feedthrough buffering
# Create PG rings for power domains to reduce IR drop
addStripe ...

# Route power switch always-on power over switches
addStripe ...

# Route secondary PG pins of LP cells (AO, SRPG, ISO, LS)
routePGPinUseSignalRoute

# Configure secondary power pin routing
setNanoRouteMode ...
setPGPinUseSignalRoute cell1:pin1 cell2:pin2 ...
```

**电源布线指南：**
- 为可开关域添加次级电源条带
- 为馈通 AO 缓冲添加条带
- 在信号布线之前布线次级电源引脚
- `optDesign -postRoute` 中的 ECO 布线处理次级引脚 ECO 布线

### 5. 布局

```tcl
# Cell placement is power domain aware, honors fence constraints
# ISO/LS placement near domain boundary or driver/receiver

# Control ISO/LS placement
setPlaceMode ...
# Create ISO/LS group constraints
# Set ISO/LS cell padding
# Create routing blockage along domain boundary
# Create pin guides
```

### 6. 优化

```tcl
# optDesign is power domain aware
optDesign ...

# Insert buffers respecting domain boundaries
# Use regular buffers or always-on (AO) buffers based on domain crossing

# Manual buffer insertion for crossing domain nets
ecoAddRepeater ...
```

**AO 缓冲控制（CPF）：**
```tcl
# Disable AO buffering for specific secondary domains
update_power_domain -name PD_C -user_attribute {{disable_secondary_domains {PD_TOP}}}

# Enable AO buffering for specific secondary domains
update_power_domain -name PD_A -user_attribute {{enable_secondary_domains {PD_TOP}}}
```

**AO 缓冲控制（UPF）：**
```tcl
create_power_domain PD_A -available_supplies <PD_TOP's supply set>
```

### 7. 验证

```tcl
# Verify low power design against CPF/UPF rules
verifyPowerDomain

# Verify by tracing PG connections in physical netlist
runCLP
```

**验证检查：**
- 从 Off→On 域需要隔离单元
- 从 Low→High 电压需要电平转换器
- PG 连接完整性

---

## 核心命令参考

### 电源意图加载

| 命令 | 描述 |
|---------|-------------|
| `read_power_intent -cpf <file>` | 读取 CPF 文件进行错误检查 |
| `read_power_intent -1801 <file>` | 读取 UPF (IEEE 1801) 文件 |
| `commit_power_intent` | 在 Innovus 中执行/提交电源意图 |
| `write_power_intent -cpf <file>` | 写出 CPF 文件 |

### 电源开关命令

| 命令 | 描述 |
|---------|-------------|
| `addPowerSwitch -ring` | 在域边界周围以环形添加电源开关 |
| `readPowerSwitchCell <file>` | 读取电源开关单元特性 |

**`addPowerSwitch -ring` 必需参数：**
- `-powerDomain`：目标电源域
- `-enablePinIn`：使能输入引脚名称
- `-enablePinOut`：使能输出引脚名称
- `-enableNetIn`：使能输入网络名称
- `-enableNetOut`：使能输出网络名称

**可选参数：**
- `-distribute 0`：堆叠单元而不是均匀分布（默认：均匀分布）
- `-specifySideList`：选择开关单元的边
- `-sideOffsetList`：域和环边之间的距离
- `-globalSwitchCellName`：为边指定开关单元
- `-cornerCellList`：角单元
- `-globalFillerCellName`：填充单元
- `-globalPattern`：单元模式（例如，`{S S D D G G F}`）
- `-continuePattern`：在下一边继续模式

### 电源规划命令

| 命令 | 描述 |
|---------|-------------|
| `addStripe` | 添加电源条带（包括电源开关） |
| `routePGPinUseSignalRoute` | 布线 LP 单元的次级 PG 引脚 |
| `setPGPinUseSignalRoute` | 定义用于次级 PG 布线的单元/引脚 |
| `setNanoRouteMode` | 配置次级引脚的布线模式 |

### 优化命令

| 命令 | 描述 |
|---------|-------------|
| `optDesign` | 电源域感知优化 |
| `ecoAddRepeater` | 为跨域网络手动插入缓冲器 |
| `setPlaceMode` | 控制 ISO/LS 放置行为 |

### 验证命令

| 命令 | 描述 |
|---------|-------------|
| `verifyPowerDomain` | 根据 CPF/UPF 规则验证设计 |
| `runCLP` | 通过跟踪 PG 连接进行验证（物理） |

---

## 电源开关单元特性参数

与 `readPowerSwitchCell` 一起使用：

| 参数 | 描述 |
|-----------|-------------|
| `-Idsat` | 饱和电流 |
| `-Ileak` | 漏电流 |
| `-rOn` | 导通电阻 |
| `-BufferDelay` | 缓冲延迟 |
| `-CellEM` | 电迁移限制 |

---

## 电源域规格参数

| 参数 | 描述 |
|-----------|-------------|
| `totalPower` | 总功耗 |
| `voltage` | 工作电压 |
| `maxSwitchIR` | 开关上的最大 IR 压降 |
| `maxLeakageCurrent` | 最大漏电流 |
| `loadCapacitance` | 负载电容 |
| `pgCapacitance` | 电源/地电容 |
| `pgInductance` | 电源/地电感 |
| `rampUpRailVoltagePercent` | 上升电压百分比（0-100） |
| `numberSimultaneousRampUpChain` | 同时上升链的数量 |

---

## 设计流程最佳实践

### MMMC 设置
- 将 MMMC（viewDefinition.tcl）与电源意图文件分离
- 确保每个电源域通过 `update_delay_corner -power_domain` 进行库绑定
- CPF/UPF 应该是无库的（时序信息在 viewDefinition.tcl 中）- 推荐用于 14.1+

### 电源域布局规划
- 创建矩形或简单的直线形状
- 最小化电源域边界边缘（减少跨越布线，有助于 ISO/LS 放置）
- 避免域之间的狭窄通道
- 避免分割/阻塞域围栏
- 为域创建 PG 环以减少 IR 压降

### ISO/LS 放置
- 将 ISO/LS 放置在靠近域边界或驱动器/接收器附近
- 增加优化在输入/输出网络上使用常规缓冲器的机会
- 通过 `setPlaceMode`、组约束、单元填充、布线阻塞、引脚引导进行控制

### 常开缓冲
- 最小化 AO 缓冲器使用（成本高于常规缓冲器）
- 当本地域与接收器不兼容时需要 AO 缓冲器
- 用于馈通网络、ISO/LS 使能信号、可开关域中的网络
- 优化使用基于成本的选择在常规和 AO 缓冲器之间

### 次级电源引脚布线
- 在信号布线之前布线次级引脚
- 为可开关域添加次级电源条带
- 为馈通 AO 缓冲添加条带
- 在 LP 单元插入和放置后使用 `routePGPinUseSignalRoute`

---

## 常见场景

### 场景 1：基于 CPF 的低功耗流程

```tcl
# 1. Load design
init_design

# 2. Load and commit CPF
read_power_intent -cpf design.cpf
commit_power_intent

# 3. Floorplan and power planning
floorPlan ...
addStripe ...  # Add PG rings and stripes

# 4. Placement
place_design

# 5. Optimization (inserts ISO/LS/AO cells)
optDesign -preCTS

# 6. Route secondary power pins
routePGPinUseSignalRoute

# 7. CTS
ccopt_design

# 8. Post-CTS optimization
optDesign -postCTS

# 9. Routing
routeDesign

# 10. Post-route optimization
optDesign -postRoute

# 11. Verification
verifyPowerDomain
runCLP
```

### 场景 2：基于 UPF 的低功耗流程

```tcl
# 1. Load design with MMMC
set init_mmmc_file viewDefinition.tcl
init_design

# 2. Load and commit UPF
read_power_intent -1801 design.upf
commit_power_intent

# 3-11. Same as CPF flow
...
```

### 场景 3：添加电源开关环

```tcl
# Add power switch ring around domain
addPowerSwitch -ring \
  -powerDomain PD1 \
  -enablePinIn A0 \
  -enablePinOut Z0 \
  -enableNetIn sw_enable \
  -enableNetOut sw_ack \
  -globalSwitchCellName {{SW_CELL S}} \
  -cornerCellList CORNER_CELL \
  -globalPattern {S S S}

# Route power switch secondary pins
addStripe ...
```

### 场景 4：手动 AO 缓冲器插入

```tcl
# Insert repeater on crossing domain net
ecoAddRepeater -net <net_name> -cell <ao_buffer_cell> ...
```

---

## 故障排除

### 问题：init_design 在使用 CPF 时出错
**原因**：没有 viewDefinition.tcl 且 CPF 未定义分析视图  
**解决方案**：提供 viewDefinition.tcl 或确保 CPF 包含 `create_analysis_view`

### 问题：ISO/LS 放置 QoR 差
**原因**：复杂的域形状、狭窄通道、许多边界边缘  
**解决方案**：简化域布局规划，最小化边界边缘，避免狭窄通道

### 问题：过多的 AO 缓冲器插入
**原因**：域电源可用性未正确约束  
**解决方案**：在 CPF 中使用 `update_power_domain -user_attribute {{disable_secondary_domains ...}}`，或在 UPF 中使用 `-available_supplies`

### 问题：次级电源引脚布线失败
**原因**：次级电源条带不足  
**解决方案**：在布线前添加更多次级电源条带，为馈通 AO 缓冲进行规划

---

## 相关主题

- 电源关断技术
- 多电压设计
- 跨域时钟树综合
- IR 压降分析
- 电迁移分析
- 低功耗验证
