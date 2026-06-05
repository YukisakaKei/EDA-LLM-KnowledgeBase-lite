---
source: knowledge/Voltus/legacy/jsonl/voltustxtcmdref__211.jsonl | entries: [0107]
---

# set_power_analysis_mode 详解

## 概述

`set_power_analysis_mode` 是 Voltus 功耗分析的核心命令，用于配置静态/动态功耗分析的全部参数。所有参数均为可选，可多次调用该命令逐步设置；使用 `-reset` 可恢复默认值。

---

## 1. 分析方法选择

### `-method { static | dynamic_vectorless | dynamic_vectorbased | dynamic_mixed_mode | event_based | vector_profile }`
- **默认**：`static`
- **说明**：指定功耗分析类型。

| 值 | 说明 |
|---|---|
| `static` | 计算平均功耗 |
| `dynamic_vectorless` | 基于时序窗口的动态分析，无需仿真向量，使用 STA 时序到达窗口确定翻转时间 |
| `dynamic_vectorbased` | 基于 VCD/FSDB 仿真向量的动态分析 |
| `dynamic_mixed_mode` | 混合模式：对有向量的 block 用 vector-based，对缺向量的 block 用 vectorless |
| `event_based` | 基于事件的功耗分析，支持多种分析同时进行 |
| `vector_profile` | 向量剖析，识别最大活动度/功耗窗口 |

---

## 2. 工作模式与流程控制

### `-enable_state_propagation {true | false}`
- **默认**：`false`
- **说明**：启用 vectorless 的 state-propagation-based 动态分析流程。
- **适用**：用于 `-method dynamic_vectorless`

### `-enable_tempus_pi {true | false}`
- **默认**：`false`
- **说明**：启用 Tempus Power Integrity（Tempus PI）分析流程；启用后，data path scheduling 基于 timing slack 进行时序感知调度。
- **适用**：仅 state-propagation-based vectorless flow，即 `-method dynamic_vectorless -enable_state_propagation true`

### `-enable_xp {true | false}`
- **默认**：`false`
- **说明**：在 XP mode 下运行 standalone report generation。

### `-hybrid_analysis {true | false}`
- **默认**：`false`
- **说明**：启用 hybrid analysis。

### `-enable_rtl_vectorbased_dynamic_analysis {true | false}`
- **默认**：`false`
- **说明**：允许以 RTL 或部分 VCD/FSDB 文件作为输入，用于 dynamic vector-based flow；可为 activity file 中缺失的实例估算电流。
- **须配合**：`-method dynamic_vectorbased`

### `-static_netlist {verilog | def}`
- **默认**：`verilog`
- **说明**：指定静态功耗分析使用的网表格式。

---

## 3. 功耗计算控制

### `-honor_negative_energy {true | false}`
- **默认**：`true`
- **说明**：是否保留 `.lib` 内部功耗表中的负值。`false` 时将负功耗视为 0。

### `-disable_leakage_scaling {true | false}`
- **默认**：`false`
- **说明**：使用 `set_power` 指定目标总功耗时，若设为 `true`，则泄漏功耗不被缩放，仅缩放内部功耗和开关功耗。

### `-disable_static {true | false}`
- **默认**：`false`
- **说明**：在动态分析流程中，设为 `true` 时仅执行动态分析，关闭静态功耗计算。
- **注意**：与 `-write_static_currents` 互相关联 — 若 `-disable_static false` 且未设 `-write_static_currents`，工具自动将后者设为 `true`；反之亦然。

### `-write_static_currents {true | false}`
- **默认**：`false`
- **说明**：生成每 net 的电流数据文件。

### `-write_dynamic_currents {true | false}`
- **默认**：`false`
- **说明**：创建动态电流文件（全仿真时长或用户指定时长）。
- **适用**：仅 `-method event_based`

### `-current_generation_method { avg | peak }`
- **默认**：`avg`
- **说明**：实例电流离散化方法。
  - `peak`：使用每时间步的峰值电流，输出 `.ptipeak` 文件。推荐 CCSP 库使用。
  - `avg`：使用每时间步的平均电流，输出 `.ptiavg` 文件。推荐非 CCSP（NLPM）库使用。
- **适用**：仅动态功耗分析。建议 `-resolution` 设为 20ps。

### `-distribute_switching_power {true | false}`
- **默认**：`false`
- **说明**：当一个 net 有多个 driver 时，`true` 将所有 driver 均分开关功耗；`false` 将其全部归于一个 driver。

### `-split_bus_power {true | false}`
- **默认**：`false`
- **说明**：`true` 将内部功耗值除以总线宽度后分配给每位；`false` 将内部功耗值直接应用于每位。

### `-switching_power_on_rise_only {true | false}`
- **默认**：`false`
- **说明**：`true` 时仅对上升沿翻转执行开关功耗分析。

### `-include_seq_clockpin_power {true | false}`
- **默认**：`false`
- **说明**：是否将 Flip-Flop 的时钟引脚功耗计入时钟网络功耗。

### `-enable_input_net_power {true | false}`
- **默认**：`false`
- **说明**：是否计算输入 net 的开关功耗。
- **适用**：仅静态功耗分析。

### `-event_based_leakage_power {true | false}`
- **默认**：`false`
- **说明**：在 event-based 流程中，基于实例在各时间点的状态计算状态相关泄漏功耗。

### `-state_dependent_leakage {true | false}`
- **默认**：`true`
- **说明**：设为 `false` 时执行状态无关泄漏功耗计算。

### `-use_cell_leakage_power_density {true | false}`
- **默认**：`true`
- **说明**：当 cell 无泄漏功耗定义时，是否使用库的 `default_leakage_power_density × area`，而非 `default_cell_leakage_power`。

### `-generate_leakage_power_map_based_on_calculated_leakage {true | false}`
- **默认**：`false`
- **说明**：`true` 时直接用用户缩放因子乘以最终计算出的泄漏功耗值，而非缩放输入 `.lib` 中的值。

### `-relax_arc_match {true | false}`
- **默认**：`true`
- **说明**：`.lib` 中找不到精确 arc 时，`true` 将内部能量计算为多个 arc 的平均值；`false` 时返回 0 内部能量。

---

## 4. 信号翻转与活动度

### `-x_transition_factor value`
- **默认**：`0.5`
- **说明**：从/到 X 状态的翻转计数因子。例如 `0->X` 或 `X->1` 计为 `factor` 次完整翻转。注意：`0->X->1` 始终计为完整翻转，不受此参数影响。

### `-z_transition_factor value`
- **默认**：`0.25`
- **说明**：从/到 Z 状态的翻转计数因子。注意：`0->Z->1` 始终计为完整翻转。

### `-from_x_transition_factor value`
- **默认**：`0.5`
- **说明**：从 X 到 0/1 的翻转计数因子。

### `-from_z_transition_factor value`
- **默认**：`0.25`
- **说明**：从 Z 到 0/1 的翻转计数因子。

### `-to_x_transition_factor value`
- **默认**：`0.5`
- **说明**：从 0/1 到 X 的翻转计数因子。

### `-to_z_transition_factor value`
- **默认**：`0.25`
- **说明**：从 0/1 到 Z 的翻转计数因子。

### `-power_include_initial_x_transitions {true | false}`
- **默认**：`true`
- **说明**：是否计入时间 0 处初始 X 状态的翻转功耗（X→0/X→1）。

### `-x_count_transition_using_3_states {true | false}`
- **默认**：`false`
- **说明**：使用三个状态（前前状态、前状态、当前状态）计算 toggle rate。

### `-power_match_state_for_logic_x value`
- **默认**：`0`
- **说明**：控制功耗表 `when` 状态的布尔函数中 X 逻辑如何评估：
  - `0`：将 X 视为 0
  - `1`：将 X 视为 1
  - `x/X`：X 导致布尔函数恒为 false

### `-handle_glitch {true | false}`
- **默认**：`false`
- **说明**：`true` 时识别并单独报告毛刺功耗（开关功耗和内部功耗不含毛刺功耗）。

### `-dynamic_glitch_filter value`
- **默认**：`-1`
- **说明**：毛刺过滤阈值（ns）。宽度 ≤ 该值的翻转毛刺将被移除。

### `-ignore_glitches_at_same_time_stamp {true | false}`
- **默认**：`true`
- **说明**：同一时间戳的多次翻转仅保留最后一次，忽略之前的翻转。

### `-handle_tri_state {false | true}`
- **默认**：`false`
- **说明**：`true` 时考虑所有三态器件使能引脚值，影响通过三态门的活动度传播。

### `-honor_net_activity {true | false}`
- **默认**：`true`
- **说明**：使用 SAIF 文件 Net 段的活动度，忽略 pin-based SDPD 活动度。

### `-ignore_control_signals {true | false}`
- **默认**：`true`
- **说明**：`true` 时控制信号（reset/preset）在活动度传播中不影响时序实例的输出引脚。

### `-equivalent_annotation {true | false}`
- **默认**：`false`
- **说明**：当 Q 或 Qbar 引脚之一被标注时，启用等效标注。

### `-constant_override {true | false}`
- **默认**：`false`
- **说明**：`set_case_analysis` 定义的传播常量优先于全局活动度。

---

## 5. 时序与延迟

### `-transition_time_method {min | avg | max}`
- **默认**：Verilog 静态分析为 `max`；DEF 静态分析和动态分析为 `avg`
- **说明**：指定与集成定时器或外部 TWF 配合使用的转换时间方法。

### `-twf_delay_annotation {min | avg | max}`
- **默认**：`avg`
- **说明**：选择从 TWF 文件中使用 min/max/avg 到达时间注解到 RTL VCD/FSDB 零延迟向量。

### `-twf_load_cap {min | avg | max}`
- **默认**：`max`
- **说明**：选择 TWF 外部负载电容的最小/最大/平均值用于功耗计算。

### `-auto_twf_delay_annotation {true | false}`
- **默认**：`false`
- **说明**：自动检测零延迟向量并执行延迟注解，无需额外指定 `-use_zero_delay_vector_file` 和 `read_activity_file -zero_delay`。
- **适用**：仅 `-method event_based`

### `-use_zero_delay_vector_file {true | false}`
- **默认**：`false`
- **说明**：启用向量动态分析的零延迟模式。从 STA 工具或外部 TWF 添加延迟信息到 VCD/FSDB，避免电流估计过度悲观。

### `-zero_delay_vector_toggle_shift value`
- **默认**：`0ns`
- **说明**：在零延迟 VCD 流程中偏移电流波形（正值为右移/增加延迟，负值为左移/去除空闲期）。
- **支持单位**：s, ms, us, ns, ps

### `-enable_dynamic_current_slew_load_interpolation {true | false}`
- **默认**：`false`
- **说明**：使用基于电荷的 slew/load 插值（4-way 或 2-way），从 `.lib` 动态电流表中导出更真实的动态电流波形。

### `-enable_slew_based_ccs_pin_cap {true | false}`
- **默认**：`false`
- **说明**：使用 Liberty 文件中基于 slew 的 CCS 电容值。`true` 时使用 CCS 引脚电容。

### `-include_timing_in_current_file {true | false}`
- **默认**：`false`
- **说明**：在状态传播流程中为非开关实例写入 timing bits，使 Rail 分析能报告 EIV。
- **适用**：仅 `-enable_state_propagation true`

---

## 6. 时钟控制

### `-default_frequency value`
- **默认**：`100MHz`
- **说明**：未由 TWF 标注的 net 的默认频率（单位 MHz）。

### `-default_slew value`
- **默认**：静态 CTE 流程为 `0`；TWF 流程为 `0.1 × 默认频率(MHz)`
- **说明**：未由 TWF 标注的 net 的默认 slew（单位 ns）。

### `-scale_to_sdc_clock_frequency {true | false}`
- **默认**：RTL VCD 流程为 `true`；Gate VCD 流程为 `false`
- **说明**：是否将 VCD 时钟频率缩放至 SDC 时钟频率。Gate VCD 需同时设置 `-use_zero_delay_vector_file true`。

### `-domain_based_clipping {true | false}`
- **默认**：`false`
- **说明**：`true` 时使用 net 上最快时钟域的频率来裁剪过高的传播活动度；`false` 时使用设计中所有时钟的最快频率。

### `-disable_clock_gate_clipping {true | false}`
- **默认**：`true`
- **说明**：启用时钟门控输出裁剪，使 ICG 单元的输出转换密度不超过输入时钟引脚。

### `-honor_combinational_logic_on_clock_net {true | false}`
- **默认**：`true`
- **说明**：`true` 保留时钟 net 上组合逻辑的活动度传播；`false` 将其视为组合时钟门控处理。

### `-clock_source_as_clock {true | false}`
- **默认**：`false`
- **说明**：`true` 时，即使用 `set_case_analysis` 停止了时钟信号，也使用拓扑源时钟频率计算 flip-flop 输出 net 的转换密度。

### `-enable_generated_clock {true | false}`
- **默认**：`true`
- **说明**：静态功耗分析时是否获取生成时钟频率。
- **适用**：仅静态功耗分析，不适用于 `-static_netlist def`。

### `-ignore_data_phase_for_clk {true | false}`
- **默认**：`false`
- **说明**：`true` 时仅传播最快时钟引脚频率（忽略数据引脚频率）。

### `-use_fastest_clock_for_dynamic_scheduling {true | false}`
- **默认**：`false`
- **说明**：使用各 net/pin 关联的最快时钟来调度仿真周期内的事件。

### `-dynamic_scale_clock_by_frequency { freq_A factor_A ... }`
- **说明**：按频率值指定低频时钟的缩放因子，确保有限仿真周期内获得更高的翻转覆盖率。
- **适用**：仅 `dynamic_vectorless`

### `-dynamic_scale_clock_by_name { clk_A factor_A ... }`
- **说明**：按时钟名称指定缩放因子。
- **适用**：仅 `dynamic_vectorless`

---

## 7. 状态传播相关

### `-enable_flop_state_propagation {true | false}`
- **默认**：`false`
- **说明**：启用时序单元的精确时钟状态传播，使输出引脚翻转与时钟同步对齐。

### `-stateprop_ignore_unannot_pins {true | false}`
- **默认**：`false`
- **说明**：忽略输出引脚功能逻辑中未标注的输入引脚，防止因部分引脚未标注导致的错误传播。

### `-enable_duty_prop_with_global {true | false}`
- **默认**：`false`
- **说明**：在动态 vectorless 分析中用全局开关活动度设置传播 duty cycle。
- **不适用**：`-enable_state_propagation true`

### `-dynamic_vectorless_ranking_methods {load | clock | vector_activity}`
- **默认**：`""`
- **说明**：改变状态传播调度优先级：
  - `load`：优先调度高扇出单元
  - `clock`：优先调度与较快时钟关联的单元
  - `vector_activity`：优先调度高活动度单元
- **适用**：仅 `-enable_state_propagation true`

### `-enable_pba_for_tempus_pi {true | false}`
- **默认**：`false`
- **说明**：在 Tempus PI 流程中启用 Path-Based Analysis（PBA）计算 slack，默认使用 GBA。
- **适用**：仅 `-enable_state_propagation true`

### `-ir_derated_timing_view view_name`
- **说明**：指定 Tempus PI 流程中用于计算时序 slack 和排名的 timing view 名称。多 view 时必须指定。

---

## 8. 数据库与文件输出

### `-create_binary_db {true | false}`
- **默认**：`false`
- **说明**：创建二进制功耗数据库，用于 GUI 交互调试（Power & Rail Plots、Power Debug）。
- **适用**：静态和动态功耗分析

### `-binary_db_name filename`
- **默认**：`power.db`
- **说明**：自定义二进制数据库文件名。多数据库场景下便于追踪不同模式的生成结果。
- **须配合**：`-create_binary_db true`

### `-create_gui_db {true | false}`
- **默认**：`false`
- **说明**：在 XP 模式下为每个 Rail 分区创建分片功耗数据库，存于 `gui.db` 子目录。
- **适用**：静态和动态功耗分析

### `-create_driver_db {true | false}`
- **默认**：`false`
- **说明**：生成所有 flip-flop 的 driver/receiver 列表，是噪声容限计算和差分电压计算的前提。
- **适用**：仅动态功耗分析

### `-write_profiling_db {true | false}`
- **默认**：`false`
- **说明**：写出剖析数据库（`.trn` 文件），可用 SimVision 以直方图形式查看。

### `-write_simulation_db {true | false}`
- **默认**：`false`
- **说明**：保存向量解析过程中每个实例的功能波形，创建 SimVision 波形数据库（SHM）。

### `-save_bbox {true | false}`
- **默认**：`false`
- **说明**：保存每个实例的边界框、位置和旋转信息到功耗数据库。生成 Voltus 热模型时必须指定。

### `-output_current_data_prefix prefix`
- **说明**：为生成的静态/动态电流文件添加前缀。多 CPU 模式下输出目录和文件名均使用此前缀。

### `-generate_current_for_rail railnames`
- **说明**：仅为指定 Rail 生成电流文件。默认生成所有电源 Rail 的电流文件。

### `-merge_switched_net_currents {true | false}`
- **默认**：`false`
- **说明**：将开关网络电流合并到常通电流中。大量开关网络设计可提升性能，但无法用于上电分析。

### `-read_rcdb {true | false}`
- **默认**：`false`
- **说明**：从 RCDB 写出仅含总电容的 SPEF（含总 C）传递给动态功耗引擎，大幅减少寄生参数标注时间。

### `-write_default_uti {true | false}`
- **默认**：`true`
- **说明**：为未连接任何电源/地 Rail 的实例生成默认静态电流文件。

### `-partition_twf {true | false}`
- **默认**：`false`
- **说明**：读取输入 TWF 数据并生成 block 级 TWF。当 block/partition 级 TWF 不可用时必须指定。

### `-pin_based_twf {true | false}`
- **默认**：`false`
- **说明**：`true` 生成 pin-based TWF（更精确但较大）；`false` 生成 net-based TWF（文件小、处理快）。
- **须配合**：`read_sdc`

---

## 9. 报告生成

### `-report_black_boxes {true | false}`
- **默认**：`false`
- **说明**：报告缺失于 Liberty 或无功能定义的 black box 单元。

### `-report_idle_instances {true | false}`
- **默认**：`false`
- **说明**：生成 `idleinstance.rpt`，列出所有空闲/不翻转的实例。

### `-report_instance_switching_info {all | output_logic | none}`
- **默认**：`none`
- **说明**：报告状态传播中组合实例的翻转信息。
  - `all`：报告输入和输出引脚翻转
  - `output_logic`：仅报告输出引脚翻转
  - `none`：仅报告 flop 的翻转
- **用途**：调试目的

### `-report_instance_switching_list filename`
- **说明**：生成 `voltus_power.stateprop.switchlist`，包含指定实例的全部翻转时间。
- **适用**：`-enable_state_propagation true`

### `-report_time_display_fraction_digits value`
- **默认**：`-1`
- **说明**：设置翻转时间值的小数位数显示精度。

### `-report_library_usage {true | false}`
- **默认**：`false`
- **说明**：生成库使用统计报告（`.lib.rpt`），包含单元名、库格式（CCSP/ECSM/NLPM）等信息。
- **须配合**：`report_power -report_prefix`

### `-report_missing_input {true | false}`
- **说明**：报告输入文件中的缺失网表信息（库/LEF/DEF/PGV/SPEF/TWF/PGNET）。

### `-report_missing_bulk_connectivity {true | false}`
- **说明**：在缺失输入报告中补充报告缺失的 bulk 引脚。

### `-report_missing_nets {true | false}`
- **默认**：`false`
- **说明**：控制静态和动态分析中缺失 net 的报告（TWF/活动度文件/SDC/SPEF）。

### `-report_stat {true | false}`
- **默认**：`false`
- **说明**：报告实例功耗、功耗密度、时钟功耗、转换密度等统计数据。

### `-report_twf_attributes {detailed | summary}`
- **说明**：控制 TWF 属性报告生成级别。
  - `summary`：汇总报告
  - `detailed`：详细报告，含每个标注实例/引脚的 rise/fall 转换

### `-report_scan_chain_stats {true | false}`
- **默认**：`false`
- **说明**：生成扫描链统计报告 `voltus_power.scanchain.stat`。

### `-enable_scan_report {true | false}`
- **默认**：`false`
- **说明**：生成所有扫描模式分析报告（重复 FF、缺失 FF、状态冲突等）。

### `-enable_mt_reports {true | false}`
- **默认**：`false`
- **说明**：启用多线程生成功耗计算报告，加速报告生成。

### `-precision value`
- **默认**：`8`
- **说明**：`report_instance_power` 和 `report_power` 中功耗值的小数精度（1-8）。

### `-generate_activity_mapping_report {true | false}`
- **默认**：`false`
- **说明**：在向量动态流程中生成 `activity_mapping.rpt`，列出 Golden/Revised 网表间的信号名映射。
- **适用**：仅 `-method dynamic_vectorbased`

### `-annotation_detail_report {true | false}`
- **默认**：`false`
- **说明**：在 Vector Profile 流程中生成每实例的详细标注报告。
- **适用**：仅 `-method vector_profile`

### `-generate_static_report_from_state_propagation {true | false}`
- **默认**：`false`
- **说明**：直接从 RTL-VCD 输入和状态传播生成静态功耗分析结果，无需生成 TCF/FSDB 中间文件。
- **适用**：动态 propagation-based 流程

---

## 10. 工艺库与 PVT

### `-corner {min | max}`
- **默认**：`max`
- **说明**：非 MMMC 设置时的库 corner 选择。`min` 使用 min timing 库；`max` 使用 max timing 库。
- **适用**：静态和动态功耗分析

### `-power_grid_library { library_list }`
- **说明**：指定 Cadence 功耗单元库（`.cl`）列表。**必须按顺序**：技术库 PGV → 标准单元 PGV → 宏单元 PGV，选择基于首次匹配。

### `-library_preference {voltage | ecsm_ccsp}`
- **默认**：`voltage`
- **说明**：对同一单元有多个 PVT 库时的绑定策略：
  - `voltage`：绑定到最接近电压的库
  - `ecsm_ccsp`：绑定到最接近的 ECSM/CCSP 库

### `-leakage_scale_factor_for_temp scale`
- **默认**：`1`
- **说明**：对温度进行泄漏功耗线性缩放。替代 `.lib` 中温度的 k-factor。`0.8` = 80%，`1.2` = 120%。

### `-average_rise_fall_cap {true | false}`
- **默认**：`false`
- **说明**：`true` 时使用 Liberty 文件中上升和下降电容的平均值。
- **不适用**：`-static_netlist def`

---

## 11. 多场景 / 多窗口 / 向量分析

### `-multi_scenario_simulation {true | false}`
- **默认**：`false`
- **说明**：将多个向量合并为一个长向量，识别组合向量中的最差功耗区间（非重叠）。

### `-block_independent_peakpower {true | false}`
- **默认**：`false`
- **说明**：`true` 时识别每个 block 独立的最差功耗区间，而非所有向量一起的最差区间。

### `-worst_window_type { power | activity | delta_power | delta_activity | ir | critical_inst_power }`
- **默认**：`power`
- **说明**：多窗口分析的最差窗口类型：
  - `power`：最差实例功耗
  - `activity`：最差实例活动度
  - `delta_power`：最差 dp/dt
  - `delta_activity`：最差 da/dt
  - `ir`：最差 IR
  - `critical_inst_power`：IR 敏感实例的最差功耗

### `-worst_window_size value`
- **说明**：动态分析时长。须与 `-worst_step_size` 配合用于滑动窗口向量剖析。

### `-worst_step_size value`
- **说明**：向量剖析的步长/分辨率。

### `-worst_window_count value`
- **默认**：`1`
- **说明**：取前 N 个最差窗口进行动态功耗分析。

### `-worst_window_reports {full | worst | both}`
- **默认**：`full`
- **说明**：生成哪个窗口的静态功耗分析报告。

### `-worst_case_vector_activity {true | false}`
- **默认**：`false`
- **说明**：静态功耗计算中指定多个向量时，使用最差活动度值。

### `-smart_window {true | false}`
- **默认**：`false`
- **说明**：启用智能窗口——可变大小窗口捕获高功耗区域，按功耗指标降序排列。

### `-vector_profile_mode {activity | event_based | power_density | transient}`
- **默认**：`event_based`
- **说明**：向量剖析方法：
  - `activity`：仅活动度剖析
  - `event_based`：生成平均功耗报告
  - `power_density`：面积/功耗密度剖析（默认 10×10 tiles）
  - `transient`：生成平均功耗报告和最差功耗窗口的电流文件
- **须配合**：`-method vector_profile`

### `-static_multi_mode_scenario_file filename`
- **说明**：指定实例缩放场景文件，用于静态多模式 IR 分析。格式：`INST_NAME PIN_NAME SCALE_1 ... SCALE_N`。

### `-settling_buffer value`
- **默认**：`400ps`
- **说明**：多 VCD 窗口之间的缓冲时间（ps），确保拼接波形连续。

### `-start_time_alignment {true | false}`
- **默认**：`true`
- **说明**：`true` 时将所有信号对齐到时间零点。

### `-ignore_end_toggles_in_profile {true | false}`
- **默认**：`false`
- **说明**：`true` 时忽略最后一步结束边界的翻转（避免零延迟向量剖析中重复计数）。

### `-pre_simulation_period period`
- **说明**：设置 IR Drop 分析的预仿真周期，用于生成功耗报告和动态电流。

### `-pre_simulation_empty_period period`
- **说明**：在 IR Drop 分析仿真前添加空预仿真周期，仅创建平坦动态电流，不进行功耗分析。

### `-pre_simulation_power_exclude_period period`
- **说明**：预仿真期间排除功耗分析，仅用于创建动态电流。

### `-quit_on_activity_coverage_threshold threshold_value`
- **说明**：活动度覆盖率阈值，低于此值时软件自动退出。

---

## 12. 扫描链分析

### `-scan_control_file filename`
- **说明**：扫描模式分析的扫描控制文件名。文件格式包含 MODE（SHIFT/VECTORLESS）、chain_name、flop_inst 等。

### `-scan_chain_name { design_name chain_name pattern }`
- **说明**：从基于扫描链的 DEF 自动生成扫描控制文件。示例：
  - 所有链：`-scan_chain_name {all 11010}`
  - 指定链：`-scan_chain_name {counter AutoChain_1_seg1_clk_rising 10010}`

### `-scan_mbff_chain_type type`
- **说明**：多位扫描 flip-flop 类型：
  - `liberty`：使用 Liberty 语法决定
  - `serial`：从第一个 flop 开始串行处理
  - `parallel`：并行处理

---

## 13. 并行 / 分布式处理

### `-capacity {low | medium | high}`
- **说明**：启用分段功耗处理。向量仿真标注、功耗计算和报告构建并发执行，以内存换性能。
  - `low`：减少 flat run 内存
  - `medium`：进一步减少内存，运行时间约 1.2X
  - `high`：最大内存减少，运行时间约 2X

### `-distributed_setup file`
- **默认**：`""`
- **说明**：分布式模式下自定义设置的配置文件。格式（4列）：`INST/CELL` → `name` → `block` → `power.inc`。
- **注意**：不适用于分区边界分析重要的场景。

### `-distributed_combine_report_format {none | detailed | reduced}`
- **说明**：XP 模式下合并分布式分区报告：
  - `none`：分别输出各分区报告
  - `reduced`：合并部分报告（missingdata, stateprop, stats）
  - `detailed`：合并全部报告（含 `power.rpt`, `instpwr.rpt`, `lib.rpt`, 电流文件等）

### `-enable_mt_in_vectorbasedflow {true | false}`
- **默认**：`false`
- **说明**：在 VCD/FSDB 向量动态分析中启用多线程。
- **适用**：仅 `-method dynamic_vectorbased`

### `-extraction_tech_file filename`
- **说明**：顶层电源网格提取的提取技术文件（QRC TechFile）。

### `-extractor_include filename`
- **说明**：提取器（ZX）命令和变量的 include 文件。
- **适用**：仅 XP 模式（`-enable_xp true`）

### `-force_library_merging {true | false}`
- **默认**：`false`
- **说明**：`true` 时即使合并库有轻微冲突也强制合并 PGV。
- **适用**：仅 XP 模式（`-enable_xp true`）

---

## 14. 功耗目标流程

### `-enable_power_target_flow {true | false}`
- **默认**：`false`
- **说明**：启用功耗目标流程。配合 `set_power` 命令指定全芯片/block/net 的功耗目标，Voltus 自动缩放翻转率以达到目标。
- **适用**：仅 `-enable_state_propagation true` 且 XP 模式

### `-adjust_input_activity_in_iterations {true | false}`
- **默认**：`true`
- **说明**：功耗目标流程中，是否自动调节每次迭代的输入活动度值。
- **适用**：仅 `-enable_power_target_flow true`

### `-adjust_macro_activity_in_iterations {true | false}`
- **默认**：`true`
- **说明**：功耗目标流程中，是否自动调节每次迭代的宏单元活动度值。
- **适用**：仅 `-enable_power_target_flow true`

### `-keep_clock_gate_ratio_in_iterations {true | false}`
- **默认**：`false`
- **说明**：功耗目标流程中，是否保持时钟门控输出比例固定。
- **适用**：仅 `-enable_power_target_flow true`

### `-enable_dynamic_scaling {true | false}`
- **默认**：`false`
- **说明**：启用动态功耗分析的 `set_power` 缩放，使动态电流平均值匹配指定的缩放后静态功耗值。
- **适用**：probability-based vectorless 流程，不支持 `-enable_state_propagation true`

---

## 15. 温度与热分析

### `-thermal_input_file file`
- **说明**：读取功耗图文件进行热分析。将芯片面积划分为 tile，用各 tile 温度计算该 tile 内所有实例的功耗。

### `-thermal_leakage_temperature_scale_table_file filename`
- **说明**：用户定义的温度值和各实例的泄漏缩放因子表，用于热感知 IR Drop 分析。
- **须配合**：`-thermal_input_file`

---

## 16. 黑盒与层次化设计

### `-enhanced_blackbox_avg {true | false}`
- **默认**：`false`
- **说明**：增强黑盒传播中使用相关输入的平均翻转率。

### `-enhanced_blackbox_max {true | false}`
- **默认**：`false`
- **说明**：增强黑盒传播中使用相关输入的最大翻转率。

### `-decap_cell_list cell_list`
- **默认**：`""`
- **说明**：将去耦电容等物理 only 单元包含在功耗报告中。
- **适用**：仅静态功耗分析

### `-bulk_pins { bulk_pin_list }`
- **说明**：定义设计的电源/地 bulk LEF 引脚。当 Liberty 无体偏置定义时，功耗分析不分配到体偏置域。
- **适用**：仅静态功耗分析，不支持 DEF 静态网表和动态分析。

### `-flatten_xpgv_block_instances filename`
- **说明**：指定使用 DEF 而非 xPGV 进行功耗分析的 block 实例列表。格式：`<block_name> <instance_name|All|None>`。

### `-use_lef_for_missing_cells {true | false}`
- **默认**：`false`
- **说明**：允许在动态分析流程中混合使用 LEF 和 PGV（PGV 优先级更高）。

### `-hier_delimiter character`
- **默认**：`/`
- **说明**：覆盖 DEF 文件中的默认层次分隔符。

### `-fanout_limit value`
- **说明**：Net 扇出限制。实例的 net 数 ≥ 该值时，其开关/内部/泄漏功耗计为 0。

### `-external_load_config_file filename`
- **说明**：当有 TWF 但无 EXTERNAL_LOAD 时，指定外部负载电容文件。格式：`INST|CELL blockName ext_load_file`。

### `-ignore_inout_pin_cap {true | false}`
- **默认**：`false`
- **说明**：`true` 时忽略 I/O cell 的双向引脚电容。

### `-off_pg_nets net_list`
- **说明**：将被关闭的电源 Rail 名称。用于识别哪些 power gate 被关闭，关闭 net 上的实例仅贡献泄漏电流。

---

## 17. 自动映射

### `-enable_auto_mapping {true | false}`
- **默认**：`false`
- **说明**：自动执行 RTL 网表与 Gate 网表的实例名映射，无需映射文件。
- **适用**：仅 `-method static | dynamic_vectorbased | dynamic_mixed_mode`

### `-comprehensive_automapping {true | false}`
- **默认**：`false`
- **说明**：执行全面的实例名映射，处理 `[`, `]`, `.`, `/`, `\`, `_`, `:` 等字符及 MBFF、_reg 等命名规则。
- **适用**：文件映射和自动映射均可使用。

### `-case_insensitive_mapping {true | false}`
- **默认**：`false`
- **说明**：`true` 时 RTL ↔ Gate 网表映射不区分大小写。

---

## 18. 杂项控制

### `-min_leaf_count value`
- **默认**：`0`
- **说明**：写入剖析数据库层次数据所需的最小叶实例数，跳过过小的层次以节省磁盘空间和时间。

### `-add_simulation {true | false}`
- **默认**：`false`
- **说明**：无仿真向量或主要源未标注时自动添加仿真，确保完整设计覆盖。
- **适用**：仅 `-method event_based`

### `-mbff_toggle_behavior { simultaneous | independent | sbff }`
- **默认**：`independent`
- **说明**：多位 Flip-Flop（MBFF）的翻转行为：
  - `simultaneous`：多位同时翻转/不翻转
  - `independent`：各位独立翻转
  - `sbff`：视为多个单 bit FF，各自独立翻转

### `-generate_flop_ranking_data directoryname`
- **说明**：保存 Flop 排名数据到指定目录，可跨设计数据库版本重用。

### `-reuse_flop_ranking_data directoryname`
- **说明**：重用之前保存的 Flop 排名数据。

### `-reuse_flop_ranking_data_hier blockname`
- **说明**：从顶层分析中选择特定 block 的排名数据用于 block 级分析。

### `-default_supply_voltage value`
- **默认**：`1.0`
- **说明**：功耗引擎无法确定电源 net 电压时的默认电压值。

---

## 19. 重置参数

### `-reset`
- **说明**：重置所有或指定参数为默认值。
  - 全部重置：`set_power_analysis_mode -reset`
  - 指定参数：`set_power_analysis_mode -reset -method`（须为第一个参数，不带参数值）

---

## 典型用法示例

```tcl
# 1. 状态传播动态 Vectorless 分析（推荐）
set_power_analysis_mode \
    -method dynamic_vectorless \
    -enable_state_propagation true \
    -corner max \
    -create_binary_db true \
    -write_static_currents true \
    -honor_negative_energy true \
    -ignore_control_signals false \
    -power_grid_library { fast_allcells.cl }

# 2. 带功耗目标的 XP 模式分析
set_power_analysis_mode \
    -method dynamic_vectorless \
    -enable_state_propagation true \
    -enable_power_target_flow true \
    -power_grid_library { tech.cl std.cl macro.cl } \
    -enable_xp true

# 3. 事件驱动分析 + 动态电流
set_power_analysis_mode \
    -method event_based \
    -write_dynamic_currents true \
    -enable_state_propagation true \
    -power_grid_library { libgen_pv.cl }

# 4. 静态分析（默认方法）
set_power_analysis_mode -corner max -create_binary_db true

# 5. 重置全部参数
set_power_analysis_mode -reset
```

---