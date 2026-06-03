---
source: knowledge/Voltus/legacy/json/voltusUG__211 | chapters: [0142, 0143, 0144, 0145, 0146, 0184, 0185, 0186, 0187, 0305, 0306, 0307]
source: knowledge/Voltus/legacy/json/voltustxtcmdref__211 | chapters: [0154]
---

# Voltus 中的 Resistance 类型汇总

Voltus 中涉及多种 resistance 概念，分布在 power grid 分析、封装分析、ESD 分析、power gate 分析和自热分析等不同场景中。

---

## 1. Effective Resistance (Reff) — 有效电阻

**定义**：从某个 instance/node 到其供电 voltage source 之间的等效电阻。

**用途**：评估 power grid 的供电能力，Reff 越大则 IR drop 越大。

**两种分析模式**：

| 模式 | 命令 | 说明 |
|------|------|------|
| Domain-based | `analyze_resistance -domain ALL` | 计算 domain 内所有 net 的 Rvdd+Rvss 总和及占比 |
| Net-based node-to-pad | `analyze_resistance -net <name> -node_list` | 计算指定节点到所有 voltage source 的电阻 |
| Net-based node-to-node | `analyze_resistance -net <name> -node_pair_list` | 计算两点之间的 point-to-point 电阻 |

**启用方式**：

```tcl
# 独立运行
analyze_resistance -domain ALL -output_dir Reff_domain
analyze_resistance -net VDD -instance_list {{INV11 VDD} {INV21 VDD}}
analyze_resistance -net VDD -cell CKBD8

# 随 Rail 分析一并执行
set_rail_analysis_mode -enable_reff_analysis true
```

**输出**：Net-based → `effr.rpt`；Domain-based → `domain_effr.rpt`；图像 → `effr.gif`

**关键参数**：
- `-reff_eval_nodes {port | tap}` — 以 port 还是 tap 节点计算
- `-reff_pin_report_method {best | worst}` — 多节点 pin 取最佳或最差值
- `-reff_detail_report true` — 在报告中增加坐标、layer、floating node 等细节

---

## 2. RLRP (Least Resistance Path) — 最小电阻路径

**定义**：从某个 instance/resistor 到最近 voltage source 的**最低电阻路径**（最优供电路径）。RLRP 不仅给出电阻值，还给出**完整的路径拓扑**（经过哪些 metal layer、via、坐标等）。

**用途**：定位 IR drop 热点时追溯电流路径，找出路径上哪一段电阻过大导致压降。

**启用方式**：

```tcl
set_rail_analysis_mode -enable_rlrp_analysis true
```

**GUI 交互**：选中 instance 或电阻后点击 **Trace**，高亮 LRP 路径。Resistance Path 窗口显示每段的 layer name、坐标、累计电阻、累计压降。

**Plot 类型**：`-plot rlrp`（Instance LRP）

**关键参数**：
- `-rlrp_eval_nodes {port | tap}` — 以 port 还是 tap 节点评估
- `-rlrp_pin_report_method {best | worst | eiv_best | eiv_worst | ...}` — 可与 EIV 联动
- `-rlrp_detail_report true` — 报告 power gate 路径上的总电阻、net 电阻、PGATE_RON

---

## 3. Grid Resistance — Power Grid 段电阻

**定义**：power grid 中各金属段（segment）本身的寄生电阻值。

**用途**：独立于活动向量，早期评估 power grid 的弱点区域（电阻过大的走线段）。

**查看方式**：

```tcl
report_power_rail_results -plot res
```

**特点**：不依赖功耗计算和电流数据，仅反映网格自身的电阻分布。

---

## 4. Common Resistance — 公共电阻

**定义**：共享同一 voltage source 的两个 instance 之间的**公共供电路径电阻**。即从 vsrc 到分叉点之间，两个 instance 共享的那段路径的电阻。

**用途**：评估电源噪声耦合——两个 instance 的公共电阻越大，一个 instance 的电流波动对另一个的供电电压影响越大。

**启用方式**：

```tcl
set_rail_analysis_mode -common_res_inst_pair_file_name <file>
```

---

## 5. Package Resistance — 封装电阻

**定义**：封装（package）模型中的寄生电阻。

**两种模型**：

| 模型 | 说明 |
|------|------|
| Simple Lumped RLC Pin | 每个 power pad 一个集总 R 值：`set_package -R <value>` |
| Distributed RLCK SPICE | 完整的分布式 RLCK SPICE 子电路模型 |

**静态 vs 动态分析**：
- 静态分析：仅考虑电阻成分（电容视为开路，电感视为短路）
- 动态分析：考虑 R、L、C 全部效应

**默认封装电阻**（area-based voltage source 时生效）：

```tcl
set_rail_analysis_mode -default_package_resistor <value>
```

---

## 6. Ron (On-Resistance) — Power Gate 导通电阻

**定义**：power gate transistor 在导通状态下的等效电阻。

**用途**：
- 稳态分析中将 power gate 建模为线性电阻
- 评估是否放置了足够的 power gate 以满足 switched block 的电流需求
- 判断 power gate 是否工作在线性区（非饱和区）

**来源**：power gate 库表征，由 Ron/Ileakage/Idsat 三参数构成。

**Ron 选择方式**：

```tcl
set_rail_analysis_mode \
  -finegrain_powergate_ron min   ;# 或 avg / max（默认）
  -finegrain_powergate_ron_list <file>  ;# 逐 cell/inst 指定
```

**RON 文件格式**（PGV 表征用）：

```
<cell_name> <min_ron> <avg_ron> <max_ron>
```

**What-If 缩放**：

```tcl
# 缩放已放置 power gate 的 on-resistance 做快速评估
scale_what_if_resistance -global -net VDD_AO -layer Metal4 -scale 4
```

---

## 7. Thermal Resistance — 热阻

**定义**：用于自热效应（Self-Heating）分析中的热阻参数。

**分类**：

| 类型 | 说明 |
|------|------|
| FEOL Thermal Resistance | 晶体管级的热阻，取决于 cell type（core vs IO）、finger 数、fin 数 |
| BEOL Thermal Resistance | 互连导线级的热阻，由 RMS 电流和金属宽度决定 |

**输入文件**：Cell Thermal Resistance File（TRF），包含实例名、finger 数、fin 数。

**使用方式**：

```tcl
analyze_self_heat \
  -cell_thermal_resistance_file TRF.txt \
  -instance_power_file ./static_db/static_power.rpt \
  ...
```

---

## 8. ESD Effective Resistance — ESD 有效电阻

**定义**：ESD 分析中，bump 与 ESD clamp 器件之间、或 bump 与 bump 之间路径的有效电阻。

**用途**：确保 ESD 事件发生时存在低阻泄放路径，防止静电损坏器件。

**常见检查类型及对应电阻**：

| 检查类型 | 电阻含义 |
|----------|----------|
| bump2clamp | bump 到 clamp 的有效电阻 |
| bump2bump | power bump 经 ESD device 到 ground bump 的路径电阻 |
| clamp2clamp | 同一 net 上 clamp 彼此间的有效电阻 |
| bump2instance | bump 到 instance 的电阻（与 b2c 对比） |
| clamp2instance | instance 到最近 clamp 的电阻（用于 CDM） |

**阈值设置**（ESD Rule File）：

```
reff_threshold <value>     ; 有效电阻 pass/fail 阈值
path_reff_threshold <value> ; bump-to-bump 路径电阻阈值
lerp_threshold <value>      ; 最小有效电阻路径阈值
```

**启用方式**：

```tcl
analyze_esd_network PD \
  -config_file rule.txt \
  -output ESD_analysis \
  -type domain -use_power_pad true
```

---

## 9. Resistor Sensitivity — 电阻灵敏度

**定义**：IR drop 对每个电阻元件的偏导数 `dV/dR`，表示该段电阻变化对最终 IR drop 的影响程度。

**用途**：指导 power grid 优化——优先加宽灵敏度高的走线段。

**启用方式**：

```tcl
set_rail_analysis_mode -enable_sensitivity_analysis true
```

**查看**：`-plot rs`（Resistor Sensitivity plot）

**与 What-If 联动**：灵敏度分析结果可指导 `scale_what_if_resistance` 的目标区域。

---

## 10. What-If Resistance Scaling — 虚拟电阻缩放

**定义**：不修改实际版图，对指定 layer/区域的电阻值进行缩放，快速评估电阻变化对 IR drop 的影响。

**用途**：评估 power grid 修复 effort——例如"这层金属加宽 4 倍后 IR drop 改善多少？"

```tcl
scale_what_if_resistance -global -net VDD_AO -layer Metal4 -scale 4 \
  -auto_scale_adjacent_via_layers true
```

---

## 11. Dangling Resistor — 悬空电阻

**定义**：PGV 中未连接到有效供电路径的孤立电阻元件。

**用途**：尽量减少 dangling resistor 以优化 IR drop 分析精度和 EM Blech length 计算。

**处理方式**（PGV 生成时）：

```tcl
set_advanced_pg_library_mode -remove_emview_dangling_resistor true
```

---

## 快速对照表

| Resistance 类型 | 核心命令/参数 | 分析阶段 | 输出/查看 |
|-----------------|--------------|----------|-----------|
| Effective Resistance | `analyze_resistance` / `-enable_reff_analysis` | Rail 分析 | `effr.rpt` |
| RLRP | `-enable_rlrp_analysis` | Rail 分析 | `-plot rlrp` + Trace GUI |
| Grid Resistance | `-plot res` | Rail 分析 | GUI plot |
| Common Resistance | `-common_res_inst_pair_file_name` | Rail 分析 | 报告文件 |
| Package Resistance | `set_package -R` / `-default_package_resistor` | Rail 分析 | 嵌入 SPICE 网表 |
| Ron (Power Gate) | `-finegrain_powergate_ron` | Power Gate 表征/分析 | `pi.report` |
| Thermal Resistance | `-cell_thermal_resistance_file` | Self-Heat 分析 | Delta T 报告 |
| ESD Effective Resistance | `analyze_esd_network` | ESD 分析 | `b2c_*.reff` / `c2c_*.reff` 等 |
| Resistor Sensitivity | `-enable_sensitivity_analysis` | Rail 分析 | `-plot rs` |
| What-If Resistance Scaling | `scale_what_if_resistance` | What-If 分析 | 重新 run rail 后查看 |
| Dangling Resistor | `-remove_emview_dangling_resistor` | PGV 生成 | PGV 质量报告 |
