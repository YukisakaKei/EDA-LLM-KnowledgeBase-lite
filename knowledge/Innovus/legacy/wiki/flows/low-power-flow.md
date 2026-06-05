---
source: knowledge/Innovus/legacy/jsonl/innovusUG__211.jsonl | entries: [0357, 0359, 0367, 0370, 0373, 0374, 0376, 0377, 0378, 0379, 0380]
---

# Innovus 低功耗设计流程

## 概述

低功耗设计通过多供电电压（MSV）技术实现功耗节省。Innovus 支持两种 MSV 设计方式：

- **多供电单电压（MSSV）** — 核心逻辑运行在单一电压，部分逻辑隔离在独立电源上
- **多供电多电压（MSMV）** — 核心逻辑使用不同电压的供电

**功率域（Voltage Island）** 是 Innovus 中的 Floorplan 对象，具有物理围栏约束。每个功率域关联特定的库文件（.lib、.lef），标准单元实例只能放置在其对应的功率域内。

## 功率域关闭与电压缩放

### 功率域关闭（Power Domain Shutdown）

在特定工作模式下关闭整个功率域，实现漏电和动态功耗节省。关键要点：

- 晶体管与电源和地线隔离
- 必须使用隔离单元（Isolation Cell）将接口信号驱动到已知状态
- 关闭模式下设计通常运行在单一电压（MSV 设计）
- 关闭的功率域必须与系统其他部分隔离，以便独立关闭

### 电压缩放（Voltage Scaling）

一个或多个功率域运行在低于核心逻辑的电压，提供动态功耗节省和可能的漏电节省。

**注意**：这两种技术可单独使用或组合使用。

### 典型架构示例

```
三个功率域：RTC、PD1、默认功率域
- PD1 和默认域可共享库（相同工作电压）
- 功率开关使 PD1 能够关闭
- RTC 运行在不同电压
- RTC 可保持常开
- 默认域↔RTC 和 PD1↔RTC 之间需要电平转换器
- 隔离单元在功率域关闭时将输出驱动到已知状态
```

## CPF 和 IEEE1801 支持

### CPF（Common Power Format）

CPF 是 Cadence 提供的通用功率格式，用于在支持低功耗设计流程的工具间交换数据。

**CPF 命令主要功能**：

- 创建功率域并指定其电源/地连接
- 指定时序库（可选，也可在 Innovus viewDefinition.tcl 中定义）
- 创建分析视图和定义库集
- 定义功率模式和功率状态表
- 定义隔离、电平转换、SRPG 和功率开关规则

### IEEE1801 流程

Innovus IEEE1801 低功耗流程与 CPF 流程类似。所有实现步骤（Floorplan 规划、放置、优化、时钟树综合、布线）都已增强以支持 IEEE1801。

**基本流程**：

```tcl
init_design
# 使用 "set init_mmmc_file viewDefinition.tcl" 指定 MMMC 设置

read_power_intent -1801 IEEE1801File
commit_power_intent

# 其余 IEEE1801 低功耗流程（与 CPF 流程相同）
```

**支持的 IEEE1801 命令版本**：主要支持 IEEE1801 2.0 命令和选项，同时兼容部分 IEEE1801 1.0 和 2.1 命令。

## 低功耗单元类型

### 隔离单元（Isolation Cell）

- 在两个功率域之间插入，防止驱动域关闭时信号浮动
- 隔离逻辑类型：高电平、低电平或保持最后值

### 常开单元（Always-On Cell）

- 由第二电源引脚供电
- 在可切换功率域中，由常开电源供电时可在功率域关闭时保持工作
- 具有第二电源引脚为保留逻辑供电

### 状态保留 DFF（State Retention DFF）

- 可切换功率域中的特殊触发器
- 功率域关闭时保留状态值
- 具有第二电源引脚为保留逻辑供电

### 功率开关单元（Power Gate / Power Switch Cell）

- 用于打开/关闭功率域的电源供应

### 电平转换器单元（Level Shifter Cell）

- 将信号从低电压转换到高电压，或反之
- 可能产生显著的延迟影响

### 电平转换/隔离组合单元（Level Shifter/Isolation Combo Cell）

- 电平转换器和隔离单元的组合
- 常用于同时具有 MSV 和 PSO 的设计

### 电压调节器单元（Voltage Regulator Cell，可选）

- 提供片上不同的电压供应
- 需要特殊处理面积、IR 压降和噪声问题

## 低功耗单元定义

所有低功耗单元和相关电源引脚信息需在 Liberty 文件中使用 Liberty 低功耗属性定义。

## Innovus 低功耗流程步骤

### 1. 编写功率意图文件

使用 CPF 或 IEEE1801 格式编写功率意图文件，指定：

- 低功耗单元定义（也可在 Liberty 中定义）
- 电源网和标称条件（功率域工作电压）
- 功率域的创建和更新
- 功率模式/功率状态表的创建和更新
- 隔离/电平转换、SRPG 和功率开关规则

### 2. 设置低功耗流程

**分离 MMMC 和功率意图文件**：

- 在 Innovus viewDefinition.tcl 中单独编写 MMMC 配置
- 确保每个功率域都有库绑定

**viewDefinition.tcl 示例**：

```tcl
create_library_set -name wc_0v81 \
  -timing [list ./timing/tcbn45gsbwpwc.lib \
           ./timing/tcbn45lpbwp_c070208wc0d720d9_modified.lib]

create_library_set -name bc_0v81 \
  -timing [list ./timing/tcbn45gsbwpbc.lib \
           ./timing/tcbn45lpbwp_c070208bc0d881d1_modified.lib]

create_op_cond -name PM_wc_virtual \
  -library_file ./timing/tcbn45gsbwpwc.lib \
  -P 1 -V 0.81 -T 125

create_delay_corner -name AV_PM_on_dc \
  -library_set wc_0v81 \
  -opcond_library tcbn45gsbwpwc \
  -opcond PM_wc_virtual

# 为每个功率域指定绑定
update_delay_corner -name AV_PM_on_dc \
  -power_domain PDdefault \
  -library_set wc_0v81 \
  -opcond_library tcbn45gsbwpwc
```

### 3. 初始化设计

```tcl
init_design
set init_mmmc_file viewDefinition.tcl
```

### 4. 读取和提交功率意图

```tcl
# CPF 流程
read_power_intent -cpf power_intent.cpf
commit_power_intent

# 或 IEEE1801 流程
read_power_intent -1801 power_intent.upf
commit_power_intent
```

### 5. Floorplan 规划

```tcl
# 创建功率域
floorPlan -site CoreSite -trackOffset 0 -d 1000 1000 10 10 10 10

# 创建功率域区域
createPowerDomain -name PD_A -box 0 0 500 500
```

### 6. 放置和优化

所有放置和优化命令都是功率域感知的：

```tcl
placeDesign
optDesign -preCTS
```

### 7. 时钟树综合

```tcl
ccopt_design -cts
```

### 8. PostCTS 优化

```tcl
optDesign -postCTS
```

### 9. 布线

```tcl
globalDetailRoute
```

### 10. PostRoute 优化

```tcl
optDesign -postRoute
```

### 11. 验证

```tcl
verifyPowerDomain
runCLP
```

## 低功耗规划和布线

### 功率网格规划

- 为每个功率域规划独立的电源网格
- 确保功率开关和隔离单元的正确连接
- 考虑 IR 压降和噪声

### 布线考虑

- 隔离单元和电平转换器的布线优先级
- 功率开关网络的特殊处理
- 避免在功率域边界处的拥塞

## 低功耗优化

### 隔离单元优化

- 最小化隔离单元数量
- 优化隔离单元的放置
- 平衡功耗和性能

### 电平转换器优化

- 最小化电平转换器数量
- 优化电平转换器的放置
- 考虑电平转换器的延迟影响

### 功率开关优化

- 优化功率开关的尺寸
- 考虑功率开关的 RMS 电流
- 平衡功耗和性能

## 低功耗设计验证

### 功率域验证

```tcl
verifyPowerDomain
```

### 连接性检查

```tcl
check_connectivity
```

### 时序验证

```tcl
timeDesign -outDir timingReports
```

### 功率分析

```tcl
report_power
```

## 低功耗调试命令

### 功率域信息查询

```tcl
# 查询功率域实例信息
reportPowerDomain -inst

# 查询功率域网络信息
reportPowerDomain -net

# 查询功率域引脚信息
reportPowerDomain -pin

# 详细报告
reportPowerDomain -inst |-net |-pin |-powerDomain -verbose
```

### Tcl 数据库访问

```tcl
dbGet top.pds.??
```

### 低功耗 GUI 调试器

- 设计浏览器
- 违规浏览器和原理图查看器
- 屏幕捕获

---

## 快速参考

### 基本流程命令序列

```tcl
# 1. 初始化设计
init_design
set init_mmmc_file viewDefinition.tcl

# 2. 读取功率意图（CPF 或 IEEE1801）
read_power_intent -cpf power_intent.cpf
# 或
read_power_intent -1801 power_intent.upf

# 3. 提交功率意图
commit_power_intent

# 4. Floorplan 规划、放置、优化、CTS、布线
# （所有步骤都是功率域感知的）

# 5. 验证
verifyPowerDomain
runCLP

# 6. 调试
reportPowerDomain -inst
reportPowerDomain -net
reportPowerDomain -pin
```

### 常见 CPF 命令

```tcl
# 创建功率域
create_power_domain -name PD_A -elements {inst1 inst2}

# 更新功率域
update_power_domain -name PD_A -user_attribute {{enable_secondary_domains {PD_TOP}}}

# 定义隔离规则
create_isolation_rule -name iso_rule -domain PD_A -isolation_type low

# 定义电平转换规则
create_level_shifter_rule -name ls_rule -from PD_A -to PD_B

# 定义功率开关
create_power_switch_rule -name ps_rule -domain PD_A
```

### 常见 IEEE1801 命令

```tcl
# 创建功率域
create_power_domain PD_A -available_supplies {VDD GND}

# 创建功率模式
create_power_mode -name mode1 -domain_supply_expr {PD_A {VDD 0.9V}}

# 定义隔离规则
create_isolation_rule -name iso_rule -domain PD_A -isolation_type low

# 定义电平转换规则
create_level_shifter_rule -name ls_rule -from PD_A -to PD_B
```
