---
source: knowledge/Innovus/legacy/json/innovusUG__211 | chapters: [357, 358, 359, 360, 361, 362, 363, 364, 365, 366, 367, 368, 369, 370, 371, 372, 411, 412]
---

# 低功耗设计概念

## 低功耗设计基础

### 多供电电压设计概述

Innovus 支持多供电电压（MSV）设计，帮助降低芯片功耗。MSV 设计分为两类：

- **多供电单电压（MSSV）** — 核心逻辑运行在单一电压，部分逻辑隔离在独立电源上
- **多供电多电压（MSMV）** — 核心逻辑使用不同电压的电源

### 电源域（电压岛）

电源域是 Innovus 中的一个 floorplan 对象，也称为电压岛。每个非默认、非虚拟电源域具有物理围栏约束，并关联特定的库文件（.lib、.lef）。

**关键特性：**
- 属于电源域的标准单元实例只能放置在该电源域内（Macros、IP 块和 IO 除外）
- 支持跨域边界的自动 level shifter 放置
- 支持跨域时序优化、时钟树综合（CTS）和布线
- 可获得 DRC-clean 的电源布线

### 电源域关闭与电压调节

#### 电源域关闭

电源域关闭是一种在特定工作模式下完全关闭电源域的技术，可同时实现漏电功耗和动态功耗节省。

**实现要点：**
- 晶体管与电源和地线隔离
- 必须使用隔离单元（isolation cells）将接口信号驱动到预定义的已知状态
- 关闭模式下，设计可在单一电压运行，但被关闭的部分必须在独立电源域中
- 需要电源开关（power switches）实现独立关闭

#### 电源域电压调节

一个或多个电源域以低于其他核心逻辑的电压运行，提供动态功耗节省，并可能提供漏电功耗节省。

**注意：** 关闭和电压调节技术可单独使用或在同一设计中组合使用。

#### 电源域架构示例

典型的多电源域设计包含：
- **PD1 和默认域** — 共享库，运行在相同电压
- **RTC 域** — 运行在不同电压，可保持常开
- **电压 level shifter** — 在默认域与 RTC 之间、PD1 与 RTC 之间插入
- **隔离单元** — 当电源域关闭时，将输出驱动到已知状态

---

## CPF 和 IEEE1801 标准

### Common Power Format（CPF）支持

CPF 是 Cadence 提供的通用电源格式，使用户能够在 Cadence 工具间自由交换数据，并在设计早期而非后端阶段捕获低功耗设计意图。

**CPF 文件功能：**
- 创建电源域并指定其电源/地连接
- 指定时序库（可选，用户也可在 Innovus viewDefinition.tcl 中定义）
- 创建分析视图并为每个电源域定义库集（可选）
- 定义工作条件（可选）
- 定义低功耗单元
- 创建低功耗规则：隔离规则、level shifter 规则、SRPG 规则、电源开关规则

**CPF 版本支持：**
- CPF 1.0
- CPF 1.0e
- CPF 1.1（默认）
- CPF 2.0

### CPF 命令

Innovus 支持以下 CPF 相关命令：

- `read_power_intent -cpf` — 读取 CPF 文件进行错误检查
- `commit_power_intent` — 在 Innovus 环境中执行（提交）CPF 命令
- `write_power_intent -cpf` — 写出 CPF 文件

### CPF 文件加载与提交

**GUI 方式：** Power → Multiple Supply Voltage → Load/Commit CPF

**命令流程：**
1. `read_power_intent -cpf <file>` — 读取并验证 CPF 文件
2. `commit_power_intent` — 提交 CPF 命令

### init_design 中的 CPF 处理

`init_design` 命令通过以下逻辑处理 CPF：

- 若存在 viewDefinition.tcl，不重新生成
- 若不存在 viewDefinition.tcl，调用 `read_power_intent -cpf` 生成
- 若同时提供 viewDefinition.tcl 和 CPF，viewDefinition.tcl 优先级更高
- 若无 viewDefinition.tcl 且 CPF 未定义分析视图，init_design 报错

**库路径设置示例：**
```tcl
set libDir "libs/"
# viewDefinition.tcl 将引用 tcl 变量 libDir
# 库规范示例：create_library_set -library $libDir/ …
```

**CPF 与 viewDefinition.tcl 的关系：**
- 从 14.1 版本起，推荐 CPF 为 library-less（仅指定电源意图），所有时序信息在 viewDefinition.tcl 中指定
- 若 CPF 无分析视图定义，viewDefinition.tcl 必须存在
- 若 CPF 和 viewDefinition.tcl 都缺失，`commit_power_intent` 报错

### IEEE1801 标准支持

IEEE1801 标准从 Innovus 13.2 及以上版本支持，用于指定设计的电源意图。

**IEEE1801 特性：**
- 仅指定电源意图（类似 library-less CPF）
- 所有时序信息在 viewDefinition.tcl 中指定
- Innovus 主要支持 IEEE1801 2.0 命令和选项
- 为兼容性考虑，也支持部分 IEEE1801 1.0 和 2.1 命令

### IEEE1801 低功耗流程

IEEE1801 低功耗流程与 CPF 流程类似，所有 Innovus 实现步骤（floorplan、placement、优化、CTS、布线）都已增强以支持 IEEE1801。

**基本流程：**
```tcl
init_design  # 使用 "set init_mmmc_file viewDefinition.tcl" 指定 MMMC 设置
read_power_intent -1801 IEEE1801File
commit_power_intent
# IEEE1801 低功耗流程的其余部分（与 CPF 低功耗流程相同）
```

### IEEE1801 命令集支持

Innovus 支持的主要 IEEE1801 命令包括：

**电源域和供电相关：**
- `create_power_domain` — 创建电源域
- `create_supply_net` — 创建供电线网
- `create_supply_port` — 创建供电端口
- `set_domain_supply_net` — 设置电源域供电线网

**隔离和 Level Shifter：**
- `set_isolation` — 设置隔离规则
- `map_isolation_cell` — 映射隔离单元
- `set_level_shifter` — 设置 level shifter 规则
- `map_level_shifter_cell` — 映射 level shifter 单元

**电源开关：**
- `create_power_switch` — 创建电源开关
- `map_power_switch` — 映射电源开关单元

**保留和状态：**
- `set_retention` — 设置保留规则
- `map_retention_cell` — 映射保留单元
- `add_power_state` — 添加电源状态
- `add_port_state` — 添加端口状态

**其他命令：**
- `load_upf` — 加载 UPF 文件
- `upf_version` — 指定 UPF 版本

---

## 低功耗单元和时序

### 低功耗单元定义

所有低功耗（LP）单元及其相关电源引脚信息必须在 Liberty 文件中使用 Liberty LP 属性定义。

### 时序信息

在 Innovus MMMC viewDefinition.tcl 文件中定义时序信息，使用以下命令：

```tcl
set init_mmmc_file viewDefinition.tcl
```

**重要注意：** 在定义时序信息前，必须通过 `update_delay_corner` 命令为每个电源域指定电源域库绑定。

### 电源域参数和规范

#### 电源域属性

- **总功耗** — 例如 1.0 mW
- **域电压** — 例如 1.0 V
- **最大开关 IR 容限** — 例如 10 mV
- **最大允许域漏电流** — 例如 2 µA
- **域电容** — 例如 1 µF
- **封装电感** — 例如 0.1 nH

#### 电源开关单元属性

- **Idsat** — 饱和电流，例如 1 mA
- **Ron** — 导通电阻，例如 800 Ω
- **Ileak** — 漏电流，例如 10 nA
- **开关缓冲延迟** — 例如 100 ps

#### 电源开关单元特性

- **Idsat** — 最大饱和电流
- **Ileak** — 漏电流
- **rOn** — 导通电阻
- **BufferDelay** — 缓冲延迟
- **CellEM** — 电迁移特性
- **readPowerSwitchCell** — 读取电源开关单元文件

#### 电源域规范选项

- **totalPower** — 总功耗
- **voltage** — 工作电压
- **maxSwitchIR** — 最大开关 IR 压降
- **maxLeakageCurrent** — 最大漏电流
- **loadCapacitance** — 负载电容
- **pgCapacitance** — 电源/地电容
- **pgInductance** — 电源/地电感
- **rampUpRailVoltagePercent** — 上升沿轨道电压百分比（0-100%）
- **numberSimultaneousRampUpChain** — 同时上升链数量
