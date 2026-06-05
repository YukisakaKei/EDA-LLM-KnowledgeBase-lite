---
source: knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl | entries: [0321, 0322, 0323, 0324, 0325, 0326, 0327, 0328, 0329]
---

# Body Bias 分析、Leakage Power Scaling 与 RTL Activity 文件

> **术语说明**：本文中 "static" 指**时间平均分析方法**，非物理 leakage。Voltus 原文 "Static Power Calculation" 指的是时间平均总功耗计算（含 switching + internal + leakage），而非仅算漏电。物理 leakage 在原文中始终用 "leakage" 一词。

## Body Bias 分析

### 概述

Body biasing 在先进工艺节点中用于以下目的：

- **防止 latch-up**
- **优化 sub-threshold leakage**
- **优化性能**

通常设计中 WELL 接触点连接到 core VDD 和 VSS。通过专用的 body bias supply rails 施加 body 电压来控制晶体管的 Vth，从而优化漏电与性能：

- **Reverse body bias (RBB)**：在 idle 模式下对低 Vth 器件施加，提高 Vth，降低漏电
- **Forward body bias (FBB)**：在 active 模式下对高 Vth 器件施加，降低 Vth，提高性能

Body 电压通常远低于 core supply rails 电压，因为过高的 RBB 反而会增加漏电，过高的 FBB 则可能导致器件电流过大。

### 库生成

含 body bias pin 的单元需要在 power-grid view 库生成时包含这些 pin。Body bias pin 应在 cell LEF 中定义。

关键步骤与命令：

1. **WELL 层映射** — WELL 层在 PG view 库生成时不自动处理，需将其映射到 diffusion 层以提取连接：
   ```
   set_pg_library_mode -lef_layermap <LEF:QRC technology mapping file>
   ```

2. **定义 bias pin**：
   ```
   set_pg_library_mode -power_pins {pin1 voltage1} -ground_pins {pin}
   set_advanced_pg_library_mode -process_bulk_diffusion_ports true
   ```

3. **验证** — 检查 `<library>.report`，确认 body bias pin 已存在且 current taps 已生成。

### 功耗分析

Bias pin 定义从 liberty (.lib) 文件中读取。只要 liberty 文件正确表征了 body bias power domain，通常无需额外命令即可计算功耗。

Liberty 文件中 `type` 为 `pwell` 和 `nwell` 的 PG pin 会被视为 body bias pin，其绝对电压作为参考电压计算 leakage 和 internal power。

若 body bias pin 在 LEF 中有定义但在 liberty 中缺失，可通过以下命令显式指定：
```
set_power_analysis_mode -bulk_pins {VNW VPW}
```
此时功耗分析不会将功率分配到 body bias domain。

### Rail 分析

完成含 body bias pin 的 PG view 库生成和功耗分析后，可对 body bias network 进行时间平均/动态 IR drop 分析。

关键设置：
```
set_rail_analysis_mode -process_bulk_pins_for_body_bias true
set_rail_analysis_mode -extractor_include ./mybbias.cmd
```

在 `mybbias.cmd` 中指定：
```
setvar enable_toplevel_diff_extract true
```

- `-process_bulk_pins_for_body_bias true`（默认 false）：处理 PG view 库中分配给 bulk pin 的 current taps
- `enable_toplevel_diff_extract true`（默认 false）：提取 PG view 库中 diffusion 层上定义的端口，用于提取 body bias 在 diffusion 层的连接

---

## Leakage Power Scaling (使用 Liberate 库文件)

在低工艺节点下 leakage power 占总功耗比例显著，需要在不同 voltage/temperature 转角下精确计算漏电功耗。本流程使用 Liberate 生成的 liberty 文件在 Voltus 中进行 leakage power scaling。

### 使用 Liberate 生成 Liberty 文件

1. **获取 cell leakage power** — Liberate 按以下优先级选取：
   - 若 cell group 有 `cell_leakage_power` 属性，取其值
   - 若无，取第一个不带 `when` 属性的 `leakage_power` group 的 `value`
   - 若均无，跳过该 cell 并输出警告

2. **库表征** — 两种 use model：

   **Model 1：所有 corner 的 liberty 文件齐全**
   ```
   read_library { \
       SS_1.0_25.lib SS_1.0_85.lib SS_1.0_125.lib \
       SS_1.2_25.lib SS_1.2_85.lib SS_1.2_125.lib \
       TT_1.0_25.lib TT_1.0_85.lib TT_1.0_125.lib \
       TT_1.2_25.lib TT_1.2_85.lib TT_1.2_125.lib \
   }
   merge_leakage -process {SS TT} \
       -voltage {1.0 1.2} \
       -temp {25 85 125} \
       -base {TT 1.0 25}
   write_library -ecsm ecsm.lib
   ```

   **Model 2：缺少部分 corner 的 liberty 文件**
   - 先按工艺角分别基于 V/T 生成 scaling library 文件
   - 再通过 `merge_library` 命令合并

### Voltus 使用流程

在 Voltus 中直接加载 Liberate 生成的 liberty 文件，指定各文件的 P/V/T 参数即可进行 leakage power scaling 计算。

---

## RTL Activity 文件在时间平均功耗计算中的应用

将 RTL 仿真产生的 toggle 数据（VCD/TCF）映射到门级网表进行功耗分析。

### 流程

```
RTL Verilog 仿真 → VCD/TCF
       ↓
Conformal LEC → 生成 mapping 文件
       ↓
Voltus map_activity_file → 门级网表功耗计算
```

- 使用 `map_activity_file` 命令指定 RTL 与门级网表之间的实例名映射
- 映射文件由 Conformal 的 `report mapped points -long` 命令生成
- Conformal 中 Golden (G) 设计指 RTL 网表，Revised (R) 设计指门级网表

### Conformal 设置要点

- **Library pin name**：默认 Conformal 使用 DFF 原始 pin 名（如 `U$1`），可用以下选项在报告中输出库 pin 名：
  ```
  set gate report -USE_LIBRARY_PIN_NAME
  ```
  该选项影响所有 report 命令，需在保存 mapping 文件前使用。注意该映射文件不可被 Conformal 重新读回。需要 Conformal 15.10-s180 或更高版本。

- **SET NAMING RULE**：Conformal 中此命令可提高 mapping 效率，但可能使映射文件不可用。解决方法：注释掉 Conformal 脚本中 `SET NAMING RULE` 相关代码，强制 LEC 按功能而非名称映射信号，但这会增加 Conformal 运行时间。
