---
source: knowledge/Voltus/legacy/json/voltusUG__211 | chapters: [0128, 0129, 0130, 0131, 0132, 0133, 0134, 0135, 0136, 0137, 0138, 0139, 0140, 0141]
---

# 时间平均功耗计算（Static Power Calculation）

> **概念辨析：Voltus 中的 "Static" 不等同于物理上的"静态功耗 (Leakage)"**
>
> 在半导体物理中，"静态功耗"特指 leakage power——器件不切换时的漏电。但在 Voltus 中，`-method static` 指的是**时间平均分析方法**：对电路的翻转行为做时间平均，输出一个不随时间变化的稳态快照。与之对应的是 `-method dynamic`（动态/瞬态分析），它保留时间维度，使用 VCD 或 TWF 捕捉时变波形和峰值。
>
> | | Voltus Static（时间平均） | Voltus Dynamic（动态/瞬态） |
> |---|---|---|
> | **输入** | 平均 switching activity（概率值） | VCD 文件 或 TWF timing window |
> | **输出** | 每个 instance 一个平均电流值（`.ptiavg`） | 仿真窗口内的时变电流波形 |
> | **计算范围** | Switching + Internal + Leakage **三种都算** | Switching + Internal + Leakage **三种都算** |
> | **用途** | 评估长期平均 IR Drop 和 EM 风险 | 捕捉峰值 IR Drop、去耦电容优化 |
> | **运行速度** | 快 | 慢 |
>
> 因此，Voltus 的"Static Power Calculation"准确含义是**"时间平均功耗计算"**——它需要 switching activity 来计算 switching power 和 internal power，而不是只算 leakage。以下文档中的"静态"均指此含义。

## 功耗的三种基本类型

- **Switching Power** — 充放电互连电容消耗的功耗，通常占比最大
  - 公式：`P = 0.5 * C_L * V^2 * F * A`
  - `C_L` 为输出负载电容，`V` 为电压，`F` 为频率，`A` 为平均 switching activity
- **Internal Power** — 单元内部互连和器件电容充放电消耗的功耗，分为 Pin Power 和 Arc Power
  - 从 `.lib` 中的 internal power table 查表获得，基于 input slew 和 output load 插值
  - 若 `.lib` 中指定了 k-factor power scaling 参数（process/temperature/voltage），power engine 会将其纳入计算
- **Leakage Power** — 器件不切换时消耗的功耗，包含 state-dependent leakage
  - 来自 `.lib` 文件；支持 state-dependent（不同输入组合对应不同漏电值）

## 关键定义

- **Activity** — 一个 net 在一个时钟周期内发生 0->1 或 1->0 切换的概率
  - 例：若 activity = 0.1，表示每 10 个时钟周期切换 1 次
- **Duty Cycle** — 信号 net 为 1 的概率
- **Transition Density** — 信号每秒切换的次数，即 `Activity × Frequency`

## Power Engine 计算方式

Power engine 将功耗计算拆分为 4 个分量：
1. 输入 pin 的 state-dependent internal power
2. 输出 pin 的 state-dependent arc-based internal power
3. State-dependent leakage power
4. 输出 pin 的 switching power（充放电 net loading）

每个 instance 报告：Internal Power、Switching Power、Leakage Power、Total Power。

### State-Dependent Leakage 的处理

当 `.lib` 中 `when` 子句覆盖不完整时，power engine 通过以下策略处理：
- 子句完整（概率和 = 1.0）：直接加权求和
- 不完整但有 generic leakage value：用 generic value 填充缺失部分
- 不完整且无 generic value：按比例放大已有部分
- 过覆盖（概率和 > 1.0）：回退到 generic value 并报警

### Switching Power 计算

`SwitchingPower = 1/2 * C * V^2 * D`，其中 `D` 为 transition density。多驱动网（如 clock mesh）的电容会在各 driver 间分摊。

## 两种平均功耗计算方法

### 基于向量的平均功耗计算（Vector-based）

- 使用门级 VCD 或 TCF 文件获取各 net 的切换次数
- 要求良好的 functional coverage
- Transition 计数规则：0<->1 计为 1，0/1<->X 默认计 0.5，0/1<->Z 默认计 0.25
  - 可通过 `set_power_analysis_mode -x_transition_factor / -z_transition_factor` 修改
- 时钟定义优先顺序：VCD/TCF > SDC/TWF

### 基于传播的平均功耗计算（Propagation-based）

- 无需仿真向量，覆盖设计中所有 net
- 精度依赖于 primary input 的 switching probability 设定
- 关键建议：
  - 组合逻辑传播较易，可从 `.lib` 获取逻辑函数
  - 时序逻辑处于 sequential loop 中必须指定平均 activity
  - Macro 的 read/write 信号 activity 对 internal power 影响极大
  - Clock gate 的 enable 信号通常是低 activity，需手动指定

**推荐方法**：至少指定 `set_default_switching_activity` 设定平均 sequential activity；在此基础上补充 macro activity 和 clock gating activity 可大幅提升精度。

## 时间平均功耗分析流程

### 必备输入文件

- LEF、netlist (Verilog)、DEF
- CPF（定义 power domain）
- SPEF（寄生参数）

### 核心 Tcl 流程

```tcl
# 1. 加载设计
read_lib -lef $lefs
read_view_definition ../design/viewDefinition.tcl
read_verilog ../design/postRouteOpt.enc.dat/super_filter.v.gz
set_top_module super_filter -ignore_undefined_cell
read_def ../design/super_filter.def.gz

# 2. 指定 CPF
read_power_domain -cpf ../design/super_filter.cpf

# 3. 读入 SPEF
read_spef -rc_corner RC_wc_125 -decoupled \
    ../design/postRouteOpt_RC_wc_125.spef.gz

# 4. 设定功耗分析模式
set_power_analysis_mode -reset
set_power_analysis_mode \
    -analysis_view AV_wc_on \
    -write_static_currents true \
    -binary_db_name staticPower.db \
    -create_binary_db true \
    -method static

# 5. 可选：显式指定 instance/cell 功耗（无 .lib 时）
set_power -reset
set_power -cell pll -pin VDD 0.5
set_power -instance u0 -pin VDD 0.5

# 6. 设定 switching activity
set_switching_activity -reset
set_switching_activity -input_port rst -activity 0.25 -duty 0.30
propagate_activity

# 7. 检查 activity
get_activity -port rst

# 8. 设定默认 activity（未赋值的 net）
set_default_switching_activity -input_activity 0.3 \
    -period 4.0 -clock_gates_output_ratio 0.5

# 9. 指定输出目录
set_power_output_dir staticPowerResults

# 10. 运行功耗分析
report_power -outfile static.rpt
report_power -instances {u0} -outfile u0.rpt
```

### MMMC 模式注意点

- 使用 `set_power_analysis_mode -analysis_view viewname` 或 `report_power -view viewname` 指定 view
- 一次只运行一个 view，多 view 需多次运行
- View 优先级：`report_power` > `set_power_analysis_mode` > `set_analysis_mode`

### 输出文件

| 文件 | 说明 |
|------|------|
| `<name>.db` | 二进制功耗数据库，用于 GUI 查看和分析 |
| `staticPower.db.cnstr.tcl` | 保存功耗分析设置的 Tcl 脚本 |
| `<report>.rpt` | 功耗报告，按组（sequential/macro/clock）、power net、clock domain 汇总 |
| `static_<net_name>.ptiavg` | 各 power net 的电流文件，用于后续 rail analysis |

## Pre-CTS 网表功耗估算

- 使用 `set_virtual_clock_network_parameters` 命令构造虚拟时钟树，快速估算 clock network 功耗
- 可选择性估算特定 clock domain

## 热分析功耗地图文件

由 `report_power` 命令生成 tile-based 功率分布文件，供 PowerDC 进行热分析。

### 关键参数

- `-thermal_power_map_file <file>` — 指定输出文件名
- `-thermal_power_map_tile {X Y}` — 定义 X/Y 方向的 tile 数量（默认 10x10）
- `-thermal_power_map_format {simple | stack}` — simple 为 2D，stack 为 3D（支持多 die）
- `-thermal_leakage_temp {t1 t2 ...}` — 指定漏电计算的温度点
- `-thermal_conductivity_inputs <file>` — 指定各层导热率的输入文件

### 文件格式

- **Simple 格式**：包含 TRANSIENT POWER MAP 和 LEAKAGE POWER MAP 两部分
  - tri-lib flow：TRANSIENT 部分 = internal + switching，LEAKAGE 单独输出
  - 非 tri-lib flow：TRANSIENT 部分 = internal + switching + leakage
- **Stack 格式**：包含 DIE_STACK_POWER_MAP 和 LEAKAGE_POWER_MAP，支持多 die 堆叠，含每层厚度和导热率信息

## Voltus Thermal Model (VTM) 生成

适用于超大设计，使用 `specify_def` 而非 `read_def`，无需将设计数据完全加载到内存。

### 流程

```tcl
# 1. 提取金属密度信息
set_metal_density_options ...
extract_metal_density           # 生成 VTM 金属密度文件

# 2. 生成功率数据库（含边界框信息）
set_power_analysis_mode -save_bbox true
report_power

# 3. 合并生成 VTM
create_thermal_model           # 合并金属密度和功率数据

# 可选：合并 top 和 block 级别的 VTM
merge_vtm
```

## 查看功耗分析结果

### Power Results Viewer

- 加载设计和功率数据库后，通过 `Power & Rail > Power & Rail Plots` 打开
- 关键命令：
  ```tcl
  read_power_rail_results -power_db staticPowerResults/staticPower.db
  set_power_rail_display -plot ip -filter_max 0.0038 -filter_min 1.00001e-05
  report_power_rail_results -plot freq
  set_power_rail_display -plot none   # 清除显示
  ```
- 常用 plot 类型：Instance Total Power (ip)、Internal Power (ip_i)、Switching Power (ip_s)、Leakage Power (ip_l)、Transition Density (td)、Frequency Domain (freq)、Tile Power Density (tpd) 等
- Result Browser 提供 Detail（逐 instance 数据）和 Summary（直方图分布）两个标签页

### Power Debugger

- 通过 `Power & Rail > Histograms > Power Analysis` 打开
- 饼图展示层次化功耗分布，可双击下钻
- Histograms 标签页：Cell Type、Clock Network、Power Domain、Power Rail、Net、Net Toggle、Net Probability

## 功耗数据交互查询

- GUI 中选中 instance 按 `q` 键，Attribute Viewer 显示 total/internal/switching/leakage power
- Tcl 命令方式：`get_metric` 查询预定义指标
  - `power.total` — 总功耗
  - `power.total.leakage` — 总漏电功耗
  - `power.total.internal` — 总内部功耗
  - `power.total.switching` — 总开关功耗
  - `power.total.clock` — 时钟总功耗

## 调试实例功耗

使用 `report_instance_power` 命令生成指定 instance 的详细功耗明细报告。

```tcl
report_instance_power <instance_name>
```

报告包含：
- Total Internal / Switching / Leakage 分解
- 各输出 pin 的 switching power 明细（Net、Pin、Voltage、Duty、Density、Cap、Slew、Power）
- State-dependent leakage 各状态的功率 x duty cycle
- 各 timing arc 的 internal power 计算过程（activity x energy）

## 保存和恢复功耗数据库

```tcl
# 生成功耗数据库（使用 specify_def 提升性能）
set_power_analysis_mode -create_binary_db true -binary_db_name power.db
report_power

# 恢复功耗数据库（在同一或多个 session 中）
read_power_rail_results -power_db <dir>/power.db
```

- 恢复后可进行增量报告生成、查看直方图和功率 plot，无需重新运行功耗分析
- 注意：恢复后不应修改 power mode 设置，否则会触发重新分析

## 生成独立功耗报告

从已有的二进制功耗数据库直接生成报告，无需重新分析：

```tcl
report_power -power_db_directory <database_dir> -outfile <report_name>
```

XP 模式下需额外指定：
```tcl
set_power_analysis_mode -enable_xp true -extraction_tech_file <filename>
```

- Local 模式：数据库在 `power_output_dir/power.db`
- Distributed/XP 模式：数据库在 `power_output_dir/dist_X/power.db` 或 `power_output_dir/part_X/power.db`
