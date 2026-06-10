---
source: knowledge/Voltus/legacy/jsonl/voltustxtcmdref__211.jsonl | entries: [0095, 0107, 0119, 0154, 0157, 0422]
source: knowledge/Voltus/cui/jsonl/voltusTCRcom__211.jsonl | entries: [0313, 0381]
source: knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl | entries: [0133, 0165, 0206, 0240]
---

# Voltus 电流文件整理

## 核心结论

Voltus 的电流文件通常是 `report_power` 生成、再由 rail analysis 通过 `set_power_data -format current` 读入的二进制电流激励文件。最常见的后缀是 `.ptiavg`，动态功耗计算中也可能因为 `set_power_analysis_mode -current_generation_method peak` 生成 `.ptipeak`。

需要区分两层概念：

- **文件用途/来源**：静态电流、动态电流、total current、power-up 波形、package tracing 波形、Library Simulator 输出等。
- **文件后缀/离散方法**：`.ptiavg` 表示按时间步平均电流，`.ptipeak` 表示按时间步峰值电流；Library Simulator 还会输出 `.ptimax`、`.ptirms`。

## 工程结论

实际工程中，为了避免动态 rail analysis 过于悲观，电流文件生成采用 **`avg + CCSP`**：库模型仍使用 CCSP，但 `current_generation_method` 选择 `avg`，让每个 time step 使用平均电流而不是峰值电流。

这和手册中“CCSP 推荐使用 `peak`”的说明并不矛盾：`peak + CCSP` 更贴近 CCSP 电流波形中的瞬时峰值，但在工程 signoff/相关性调校中可能带来更保守的 IR/EM 结果；`avg + CCSP` 是为了降低这种离散化峰值带来的悲观性，属于工程策略选择，最终应以项目相关性、foundry/客户要求和 signoff 方法学为准。

## 常见文件类型

| 文件或后缀 | 典型来源 | 含义/用途 |
|---|---|---|
| `static_<net_name>.ptiavg` | static `report_power` | 每个 power/ground net 的时间平均静态电流文件，常用于 static rail/EM analysis。 |
| `dynamic_<net_name>.ptiavg` | dynamic `report_power`，且 `current_generation_method avg` | 每个 power/ground net 的动态电流文件，电流按每个 time step 的平均值离散。 |
| `<filename>.ptipeak` | dynamic `report_power`，且 `current_generation_method peak` | 动态实例电流文件，电流按每个 time step 的峰值离散。 |
| `static_default_power_rail.ptiavg` / `static_default_ground_rail.ptiavg` | `report_power` | 未连接到任意 power/ground rail 的 instance，其电流会反映到默认静态电流文件中。 |
| total current `.ptiavg` | `query_power_data -total_current` | 针对某个 net 的所有 taps 生成总电流文件。 |
| `dynamic_powerup_<powerup_net>_<always-on_net>.ptiavg` | What-if / power-gate flow | power-up 场景下的电流波形文件。 |
| `voltus_rail_pad.tran.ptiavg` | off-chip package tracing | switched net bump current / bump voltage waveform。 |
| `.ptimax` / `.ptirms` / `.ptiavg` | Library Simulator `pwrnet tallyint` | 分别表示接到 voltage source 的器件 peak dynamic current、RMS current、average current；这类不是常规 `report_power` 的主流输出。 |

## 用 `query_power_data` 查看/导出 `.ptiavg` 内容

`query_power_data` 是 Voltus 内置的 PTI 二进制文件查询工具，可用于查看 Power Calculation / Rail Analysis 生成的 `.ptiavg` / `.ptipeak` 文件内容。虽然命令说明主要以 current / tap current 描述，但其输入参数也明确覆盖 VDD/VSS instance voltage PTI files，因此它也可用于查看动态 rail 结果中的 instance voltage waveform。

一个典型工程问题是：在 CTS cell 上，单个 clock cycle 内有效电压 `VDD - VSS` 的峰峰变化量是多少。也就是：

```text
ΔVpp(cycle) = max(VDD - VSS) - min(VDD - VSS)
```

这个值可用于 PLL / clock jitter 相关分析。Voltus 有内建的 cycle-to-cycle EIV / jitter 分析流程；但当需要按自定义 CTS instance 列表抽取原始电压波形并自行计算 `ΔVpp` 时，可用 `query_power_data` 将 VDD/VSS voltage `.ptiavg` 导出为 PWL，再做后处理。

单个 instance 的有效电压波形可用 `view_dynamic_waveform -type voltage -effective_voltage_waveform` 做可视化确认；批量统计仍建议使用 `query_power_data` 导出 PWL 后处理。

常用场景：

| 目标 | Legacy 命令参数 | 导出/生成的数据 |
|---|---|---|
| 列出 PTI 文件中的 tap / instance 名称 | `-list [-pin]` | 名称列表；`-pin` 会带 pin 名，适合先确认可查询对象名。 |
| 导出指定 instance 的波形 | `-dump_pwl -instance_list_file inst.list` | ASCII PWL 文本，适合再转换为 CSV。输入 current PTI 时值为 current；输入 voltage PTI 时按 voltage waveform 理解。 |
| 导出平均值 | `-average_current` | 每个 instance/tap 的平均 current 统计值。 |
| 导出峰值和峰值时间 | `-peak_current -peak_time` | 每个 instance/tap 的 peak current 与发生时间。 |
| 按时间步汇总 | `-time_steps` | 每个 interval 的 min / max / average / total current 摘要，用于定位 transient worst window。 |
| 生成总电流波形 | `-total_current input.ptiavg -output out_name` | 新的 total current `.ptiavg`，可在 SimVision 中只看总电流波形。 |

示例：先列出 rail voltage `.ptiavg` 中可查询的对象名。

```tcl
query_power_data VDD/VDD.ptiavg \
    -list \
    -pin \
    -output vdd_voltage_pti.list
```

示例：批量导出指定 instance 的 VDD 电压波形为 PWL 文本。

```tcl
query_power_data VDD/VDD.ptiavg \
    -dump_pwl \
    -instance_list_file inst.list \
    -pin \
    -output vdd_voltage.pwl
```

若需要 effective voltage，可分别导出 VDD/VSS voltage PWL，再在脚本中按同一 timestamp 计算 `VDD - VSS`。`query_power_data` 本身导出的是 PWL/统计报告或新的 `.ptiavg`，不是直接导出 CSV；CSV 通常由后处理脚本从 PWL 转换得到。

## `current_generation_method`

legacy Tcl 写法：

```tcl
set_dynamic_power_simulation -resolution 20ps

set_power_analysis_mode \
    -method dynamic_vectorless \
    -current_generation_method avg

report_power
```

CUI/db 写法：

```tcl
set_db power_current_generation_method avg
```

参数取值：

| 取值 | 输出后缀 | 适合场景 | 说明 |
|---|---|---|---|
| `avg` | `.ptiavg` | 非 CCSP / NLPM library | 每个 time step 使用平均电流。对于 NLPM，Voltus power engine 会根据 LUT 启发式构造三角波形。默认值是 `avg`。 |
| `peak` | `.ptipeak` | CCSP Liberty | 每个 time step 使用峰值电流。CCSP library 本身提供来自仿真的真实电流波形，工具可直接使用。 |

官方说明里把该参数定义为：基于 `set_dynamic_power_simulation -resolution <ps>` 指定的 time step，选择 instance current discretization 或 continuous current waveform generation 的方法。推荐的 power simulation resolution 是 `20ps`。

## avg 与 peak 的差异

`avg` 和 `peak` 的核心差异不是动态/静态分析类型，而是**在每个动态仿真时间步内如何代表 instance current waveform**：

- `avg` 取该 time step 内的平均电流，文件名以 `.ptiavg` 结束。
- `peak` 取该 time step 内的峰值电流，文件名以 `.ptipeak` 结束。
- time step 越小，平均值和峰值越接近；当 step size 很小时，两种方法会收敛。

适用范围也有两个限制：

- 该参数只适用于 dynamic power calculation flow。
- 该参数只用于 instance current waveform generation，不适用于 total/composite current waveform generation。生成 total current/composite waveform 时，Voltus 会对每个 step 汇总所有 instance 的 peak current values。

因此，看到 `report_power` 生成 `.ptiavg`，可能有两种常见情况：

- static power flow 生成 `static_<net>.ptiavg`，这是静态 rail 分析常用的时间平均电流文件。
- dynamic power flow 中 `current_generation_method` 为默认 `avg` 或显式设为 `avg`，生成 `dynamic_<net>.ptiavg`。
