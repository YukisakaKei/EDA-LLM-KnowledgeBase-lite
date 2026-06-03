---
source: knowledge/Voltus/legacy/json/voltusUG__211 | chapters: [0241, 0242, 0243, 0244, 0245, 0246, 0247, 0248, 0249, 0250, 0251, 0252, 0253, 0254, 0255, 0256, 0257, 0258, 0259, 0260, 0261, 0262, 0263, 0264, 0265, 0266, 0267, 0268, 0269, 0270, 0271]
---

# TSV、SiP、IR Drop 对 Timing 的影响及 Tempus PI 分析

## 1. Through-Silicon Via (TSV) 与 System-in-Package (SiP)

### TSV 概述

TSV 是一种多 die 分析方法，多个芯片垂直堆叠，通过穿过衬底的 via 对象（TSV）实现连接。TSV 将 die 背面的信号/电源/地通过衬底连接到传统 Metal1 以上的布线区域。

支持两种堆叠配置：

- **faceDown 配置**（top metal 到 top metal）：仅下层 die 使用 TSV，上层 die 通过顶层金属（如 Metal7）的 landing pad/bump cell 连接。
- **faceUp 配置**（top metal 到背面金属）：两个 die 都使用 TSV，信号/电源/地从下层 die 顶层金属通过上层 die 的背面金属 TSV 到达其互连层。

关键点：slave die 无直接封装连接，电流全部通过 master die 抽取，master die 需满足自身和 slave 的电流需求，IR drop 敏感性更高。

### TSV Domain-Based 流程

TSV 分析使用 Innovus 生成的 mapping file 建立 die 之间的虚拟连接。Mapping file 格式为每行一个 mapping pair，由空格或 Tab 分隔：

```
<design1> <net_in_design1> <Vsrc_in_design1>
```

支持嵌入式 bump 的层次化 TSV 设计。

### SiP 概述

SiP（System-in-Package）与 TSV 类似，但 die 之间仅通过封装连接，无虚拟直连。Voltus 可同时分析所有 die 的 IR drop，无需逐个仿真。

SiP 可生成包含多 die 端口的单一 package model，端口命名由 Innovus 输出的 DEF 驱动。

### TSV + SiP 混合方案

Voltus 支持传统 SiP（多 die 通过封装连接）与 TSV 堆叠 die 的组合。典型场景如：
- 封装连接多个 die，部分 die 通过 TSV 堆叠（master-slave 配置）
- 部分 die 使用 wire-bonding 连接
- Microbump 的 RLC 寄生在 slave die 的 voltage source file 中添加

## 2. IR Drop 对时序的影响

### 基本原理

IR drop 导致电源电压降低，影响 cell delay 和 net delay。电压降低使信号摆幅缩小，导致 net delay 增加和 receiver 端 input slew 变化。Cell delay 受 input slew 和 output load 共同影响，从而产生 timing 恶化。

### Voltus/Tempus 基本流程

1. **Voltus 侧**：基于低/高 switching activity 分别做 min/max IR drop 分析，计算每个 instance 的有效工作电压，生成 `.iv`（instance voltage）文件。
2. **Tempus 侧**：使用 `update_delay_corner` 读入 IR drop 文件，基于 instance 级别的 min/max 电压进行 delay 计算和时序验证。
3. **SPICE 集成**：Tempus 为每个 instance 创建恒定电压源（来自 IR drop 文件），或使用 Voltus 生成的 PWL 电压波形，进行 critical path 的 Spectre 仿真。

### Voltus 设置

- **Min activity**：仅 clock network 翻转，组合逻辑关闭（设置 1% 而非 0% activity，否则会回退到默认 20%）
- **Max activity**：预期平均 activity，门控时钟关闭
- 也可使用 VCD 文件通过 `read_activity_file` 指定高低 activity 周期
- 使用 `set_rail_analysis_mode -eiv_method {best worst}` 生成 min/max 实例电压文件
- 生成的 `.iv` 文件位于 IR drop 结果目录的 `Reports/` 下

### Library 设置 (triLibs)

推荐使用多个不同电压表征的库（triLibs），Tempus delay calculator 在两个最接近实例 IR drop 电压的库之间插值计算 delay。

加载方式有三种：

1. **`read_lib` 命令**：将同组 cell 的不同电压库归入列表
2. **MMMC 设置**：在 `create_library_set` 中为特定 corner 指定 triLibs
3. **`read_design` 配置文件**：在 saved database 的配置文件中指定

建议相邻库电压差不超过 20%，低电压区域可进一步缩小差值以提高精度。

### Skew Analysis

Skew = launch 和 capture register 时钟到达时间差。OCV 模式下：
- Launch flop 用 late path（高 activity → 高 IR drop → 低电压 → 大 delay）
- Capture flop 用 early path（低 activity → 低 IR drop → 高电压 → 小 delay）

Tempus 中使用 `report_clock_timing -type skew` 查看时钟 skew，`-verbose` 选项输出详细报告。

### Jitter Analysis

Jitter = 同一 register 时钟 pin 上 late 和 early 到达时间差。Voltus Clock Jitter Analysis 流程将 Voltus power/rail 分析与 Tempus STA 及 Spectre 仿真整合：

1. 使用 vectorless 或 vector-based 动态功耗计算生成 power profile
2. 使用 `set_rail_analysis_mode -eiv_average_per_window_list` 生成 cycle-to-cycle EIV 报告
3. 识别最差两个 cycle 进行 jitter 分析
4. 使用 `analyze_jitter` 命令计算 clock endpoint jitter

主要命令序列：
```
set_power_analysis_mode -method dynamic_vectorless ...
set_rail_analysis_mode -eiv_method {worst best avg} ...
analyze_rail -type domain -output OUTPUT/IRDROP PD
analyze_jitter -eiv_file ... -model_file ... -subckt_file ... -spectre ... -run_simulation ...
```

输出文件包括 `summary.jitter`（endpoint pair jitter 汇总）和 `clock_branch*.jitter`（逐级详细报告）。

### IR Drop 感知 Critical Path SPICE 分析

Tempus 使用 `create_spice_deck` 命令生成带 IR drop 的 sensitized spice netlist，调用 Spectre 仿真后比较 spice delay 与内部 delay calculator 的差异。每个 instance 自动使用 IR drop 文件中的电压值创建恒定电压源。

### IR Drop 感知时钟 Jitter SPICE 分析

对于最长/最短时钟路径中共同的 instance，需分别为最长路径（高 activity IR drop）和最短路径（低 activity IR drop）创建独立的 spice netlist，分别仿真后计算 arrival time 差值即 clock jitter。

## 3. Tempus Power Integrity Analysis (Tempus PI)

### 概述

Tempus PI 是 Tempus STA 与 Voltus power/IR drop 技术的深度融合，共享数据库和运行时内存模型。核心目标是识别 IR-sensitive timing paths — 即传统 STA 下有足够正 slack 但 IR drop 下显著恶化的路径。

**关键特性**：
- 识别 IR-sensitive paths（电阻敏感、功耗敏感、时序敏感、邻域 IR 敏感等）
- 创建 functional path switching scenarios（timing slack 和 path aware 的 realistic WCS scenario）
- 识别 proximity aggressors（基于 power grid 电阻和 timing 敏感性的空间邻近 aggressor）
- 使用 cycle-cycle voltage 统计计算 delay/timing 影响

### License 需求

| 工具 | 基础 License | 启用选项 | 附加 License |
|------|-------------|---------|-------------|
| Tempus | Tempus XL (TPS200) | `-enable_tempus_pi true` | Tempus PI (TPS600) + Voltus XL (VTS200) |
| Voltus | Voltus XL (VTS200) | `-enable_tempus_pi true` | Tempus PI (TPS600) + Tempus XL (TPS200) |

### Tempus PI 流程

1. **DB Signoff** — 加载设计输入数据
2. **Critical Path Analysis** — 在 Tempus STA 阶段识别 critical paths
3. **IR Drop Analysis** — 在 Voltus 中报告 IR drop hotspot（EIV），识别最差 violation victims 及其 aggressors
4. **Tempus ECO Optimization** — 对导致 IR drop 的 aggressor cell 进行 downsizing，同时做 ECO timing 优化
5. **IR Fix Validation** — 重新运行 Tempus PI 验证 ECO 结果

### 详细执行步骤

**Step 1: Tempus STA (IR Derated)**
加载 LEF、timing libraries、netlist、SDC、DEF、SPEF，创建 nominal view（如 1.0V，非 derated）和 derated view（如 0.85V）。

**Step 2: Voltus Power & IR Drop**
```
set_power_analysis_mode -method dynamic_vectorless -enable_tempus_pi true \
  -ir_derated_timing_view AV_wc_0p85 -enable_pba_for_tempus_pi true
set_dynamic_power_simulation -resolution 50ps -period 320ns
report_power
set_rail_analysis_mode -method dynamic -accuracy hd -eiv_method {bestavg worstavg}
analyze_rail -output ... -type domain ALL
```

**Step 3: IR-Aware STA**
```
set_delay_cal_mode -early_irdrop_data_type best_average -late_irdrop_data_type worst_average
update_delay_corner -name DC_wc_1p00 -library_set {LS_wc_1p00 LS_wc_0p90 LS_wc_0p85} \
  -irdrop_data <rail_output_dir>
update_timing -full
report_timing -max_paths 200000 -retime path_slew_propagation -retime_mode exhaustive
```

最终分析在非 derated 电压 corner（如 1.0V）上完成，通过 triLibs 插值精确计算 IR drop 下的 delay。

### 结果分析

与传统 timing signoff 对比：
- 传统 flow 下所有 path 为正 slack
- Tempus PI 下可识别出数十至上百条负 slack path，这些 path 在传统 flow 中被 IR derate 掩盖
- 这些 failing paths 可使用 Tempus PI ECO 功能修复

**性能参考**（5.05M 标准单元实例，36-CPUs @ 2.3GHz）：
| 步骤 | 耗时 | 峰值内存 |
|------|------|---------|
| Update Timing (pre) | 37m 41s | 31.2G |
| Report Power | 2h 13m 51s | 142.8G |
| Analyze Rail | 1h 24m 35s | 57.3G |
| Update Timing (post) | 2h 14m 35s | 57.7G |
| **Total** | **6h 30m 42s** | - |
