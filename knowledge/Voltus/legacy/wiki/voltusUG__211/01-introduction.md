---
source: knowledge/Voltus/legacy/json/voltusUG__211 | chapters: [0001, 0002, 0003, 0004, 0005, 0006, 0007, 0008, 0009, 0010, 0011, 0012, 0013, 0014, 0015, 0016, 0017]
---

# Voltus IC Power Integrity Solution — 简介与许可

> **术语说明**：本文中 "static" 均指**时间平均分析方法**（与 "dynamic" 瞬态分析对立），而非物理上的"静态功耗(leakage)"。Voltus 的 static power analysis 计算的是时间平均总功耗（含 switching + internal + leakage），不是仅算漏电。

## 工具定位

Voltus IC Power Integrity Solution（简称 Voltus）是 Cadence 推出的门级 power grid 分析工具，用于对 ASIC 设计进行 IR drop、EM（电迁移）及功耗分析，判断 power grid 是否满足设计要求。

Voltus 可从 Innovus 或 Tempus 内部调用，但必须持有 Voltus 许可证。例外：以下功能可在 Innovus 中免许可使用：
- 时间平均功耗分析（static power analysis）
- 基于时间平均功耗的 Early Rail Analysis（ERA）

> ERA 的动态功耗模式需要 VTS-XL 许可。

---

## 手册覆盖范围

本手册涵盖以下主题（按章节顺序）：

- 产品与许可信息
- 快速入门与数据准备
- GUI 使用与设计导入
- 分布式处理 / 大规模并行处理（Voltus-XP）
- 设计健全性检查
- Power Grid Library 生成
- 时间平均功耗、IR drop 与 EM 分析
- 动态功耗与 IR drop 分析
- 层次化功率完整性分析（Extreme Modeling）
- ESD 分析
- 封装分析（Package Analysis）
- What-If Rail 分析 / Power Gate 分析
- Through-Silicon Via（TSV）与 SiP
- IR drop 对时序的影响
- IR drop 感知布局（IR-aware placement）
- 信号 EM（Signal ElectroMigration）
- 自热效应（Self-Heating Effect）分析
- 统计电迁移预算（Statistical EM Budgeting）
- 文件格式参考

---

## 相关文档

| 文档 | 说明 |
|------|------|
| What's New in Voltus | 本版本新特性说明 |
| Voltus Known Problems and Solutions | 已知问题（CCR）及规避方法 |
| Voltus Text Command Reference | 文本命令语法与示例 |
| Voltus Menu Reference | GUI 菜单说明 |
| Voltus Stylus Common UI Text Command Reference | Stylus Common UI 命令参考 |
| Voltus Stylus Common UI Migration Guide | 从 legacy 迁移到 Stylus Common UI 的指南 |
| Stylus Common UI Database Object Information | 数据库对象说明 |

---

## 文档约定

| 格式 | 含义 |
|------|------|
| `command_name`（等宽字体） | 命令行命令或参数 |
| *File – Save*（斜体） | GUI 菜单操作，`–` 分隔菜单层级 |
| `filename`（等宽斜体） | 需替换为实际值的变量 |
| `< options >` | 可选参数 |
| `[a\|b\|c]` | 必选其一 |
| `[a\|b\|c]+` | 至少选一，可多选 |

---

## 产品与许可

### 基础产品包

启动命令：`voltus`

| 产品名 | 缩写 | 编号 | 核心能力 |
|--------|------|------|----------|
| Voltus IC Power Integrity Solution - L | VTS-L | VTS100 | 静态/动态 IR drop、EM 分析；vectorless 与 vector-driven 功耗计算；what-if 分析；与 Innovus/Tempus 紧密集成。**仅支持单 CPU。** |
| Voltus IC Power Integrity Solution - XL | VTS-XL | VTS200 | 包含 VTS-L 全部功能，另增层次化分析（Hierarchical Analysis）和 Hotspot Debugger。**支持多 CPU，单许可最多 8 CPU。** |
| Virtuoso Digital Signoff Power Solution | VDS-Power | VDS200 | 包含 VTS-L 和 VTS-AA 全部功能。单许可支持最多 50K 实例，可叠加至 2 许可（100K 实例）。 |

### 产品选项（Product Options）

| 选项名 | 缩写 | 编号 | 说明 |
|--------|------|------|------|
| Advanced Analysis GXL Option | VTS-AA | VTS201 | 增加 SLPA（统计漏电功耗分析）、有效电阻计算、片上电压调节器、时钟/信号 jitter 分析、20nm 以下 qrcTechFile 支持、Sigrity Package Analysis（SPA）等高级功能 |
| Extreme Modeling | VTS-XM | VTS202 | 支持大型数字模块的 xPGV 模型生成，用于顶层全芯片分析。需以 VTS-XL 为基础许可。每个 xPGV 模型需 1 个 XM 许可，最多叠加 10 个 XM 许可 |
| ESD Analysis | VTS-ESD | VTS203 | 支持 ESD 电阻检查和电流密度分析。需以 VTS-L、VTS-XL 或 VDS-P 为基础许可 |
| Massive Parallel Option | VTS-MP | VTS300 | 每个 VTS-MP 许可额外增加 8 CPU。仅与 VTS-XL 配合使用（VTS-L 不支持多 CPU） |
| Sigrity Package Analysis | VTS-SPA | SIGR955 | 集成 Voltus + Sigrity 的 Chip-PKG 协同分析。包含 Sigrity XtractIM 和 Sigrity PowerDC。完整流程需：VTS-L/XL + VTS-AA + VTS-SPA |
| Tempus Power Integrity | TPS-PI | TPS600 | 识别 IR 敏感关键路径。需以 Tempus-XL 或 VTS-XL 为基础许可 |

---

## 许可术语

- **Base license**：软件启动时检出的基础许可（VTS-L 或 VTS-XL），产品选项许可不能作为 base license。
- **Dynamic license**：按需检出的产品选项许可，在实际使用对应功能时才检出，可叠加多个。
- **Multi-CPU license**：启用多线程/分布式处理的许可，在 base license 检出后叠加。VTS-XL 可叠加多个以扩展 CPU 数量。

---

## 许可检出命令

**启动时指定选项：**

```tcl
# 立即检出 startup_options，动态检出 lic_options
voltus -lic_startup_options "option1 option2 ..." -lic_options "option1 option2 ..."

# 禁止动态检出
voltus -lic_startup_options "option1 option2 ..." -lic_options ""
```

**运行时检出选项：**

```tcl
# 立即检出 checkout，动态检出 optionList
set_license_check -checkout option -optionList "option1 option2 ..."

# 禁止动态检出
set_license_check -checkout option -optionList ""
```

> 注意：`-checkout` 每次只能指定一个选项；未检出 base license 时无法检出产品选项许可。
