---
source: knowledge/Voltus/legacy/jsonl/voltustxtcmdref__211.jsonl | entries: [0154]
---

# set_rail_analysis_mode 详解

## 概述

`set_rail_analysis_mode` 用于定义 Voltus Rail 分析的运行方式，是 `analyze_rail` 之前必须完成的核心配置命令。它既控制分析模式、精度和 PGV 输入，也控制 EIV、EM、ERA、调试探针、结果复用与 XP 并行等高级行为。

## 1. 基础分析框架

### `-method {static | dynamic | era_static | era_dynamic}`
- **默认**：`static`
- **说明**：选择 Rail 分析类型。

| 值 | 适用场景 | 说明 |
|---|---|---|
| `static` | 常规静态 IR/EM | 基于平均电流做 Rail 分析 |
| `dynamic` | 动态 IR/EM signoff | 结合时间维度、电流波形做分析 |
| `era_static` | 早期布局 / 未完全布线 | Early Rail Analysis 静态模式 |
| `era_dynamic` | 早期动态评估 | Early Rail Analysis 动态模式 |

### `-accuracy {xd | hd}`
- **默认**：`hd`
- **说明**：设置求解精度。

| 值 | 说明 |
|---|---|
| `xd` | accelerated definition，适合实现早期快速评估 |
| `hd` | high definition，适合最终验证 |

### `-power_grid_library dir_list`
- 指定 Rail 分析使用的 Power Grid View Library。
- 这是 `set_rail_analysis_mode` 的基础输入之一，没有 PGV 就无法建立标准 Rail 分析环境。

### `-analysis_view view`
- 指定 CPF 中定义的 analysis view。
- 常用于按 power domain / analysis view 驱动分析设置。

### `-reset`
- 将所有 `set_rail_analysis_mode` 参数恢复默认值。
- 适合在同一会话中切换分析场景，避免旧设置残留。

## 2. 提取与基础设施输入

### `-extraction_tech_file filename`
- 指定顶层 power-grid extraction 使用的技术文件。
- 若不指定，则使用 PGV 内嵌的 extraction tech 数据。

### `-extractor_include filename`
- 通过 include 文件传入 ZX extractor 命令和变量。
- 适合补充提取器高级控制选项。

### `-enable_2d_partition_extraction {true | false}`
- **默认**：`false`
- 启用 2D partition extraction，提升大设计提取并行度。
- 设为 `true` 时，必须显式提供完整 `-extraction_tech_file`。
- 不支持 3DIC、inductance extraction、full-chip GDS flow。

### `-enable_scheduler {true | false}`
- **默认**：`true`
- 控制 Voltus advanced scheduler。
- 官方建议保持 `true`，可改善大规模 CPU 下的数据处理、性能与内存表现。

### `-disable_parallel_extraction`
- 强制使用单处理器执行 R/C 提取。
- 默认不指定时使用并行提取。

### `-compress_powergrid_database {true | false}`
- **默认**：`false`
- 压缩 extraction 与 rail analysis 输出文件，节省磁盘空间。
- 代价约为 5%~10% 性能下降。

### `-work_directory_name directory`
- 指定 extraction 数据工作目录。

### `-temp_directory_name directory`
- 指定临时文件目录。
- 若同时设置 `TMPDIR` 与本参数，以本参数优先。

## 3. 设计范围与对象控制

### `-off_rails net_name_list`
- 指定不参与分析的 net。
- 常用于带 power switch 的设计，排除不需分析的 rail。

### `-set_analyze_bbox { xmin ymin xmax ymax }`
- 将分析范围限制在指定矩形区域内。
- 坐标单位为微米。

### `-cell_ignore_file filename`
- 从设计数据库中排除指定 cell 引用。

### `-ignore_incomplete_net {true | false}`
- 跳过设计中未定义或无 instance 连接的 power/ground net。

### `-ignore_nets_without_vsrc {true | false}`
- **默认**：`false`
- `true` 时，对缺少 voltage source 的 net 仅报错但继续运行。
- 若全部 VDD/VSS 都没有 vsrc，分析仍会退出。

### `-remove_duplicate_inst {true | false}`
- **默认**：`false`
- DEF 解析时去除重名 instance，减少 disconnected instance 噪声。

### `-unconnectedcell_ignore_file filename`
- 指定忽略 connectivity 问题的 cell / instance / pin 列表。
- 适合过滤已知但不计划修复的连接告警。

### `-verify_logical_connectivity {true | false}`
- 生成逻辑不连通 PG pin 报告 `cell.unconnected_pins`。

## 4. 电源源点与封装相关

### `-vsrc_search_distance value`
- **默认**：`50`
- 指定在 power pin location 附近搜索 voltage source 的距离，单位微米。

### `-check_vsrc_placement_on_switched_net {true | false}`
- **默认**：`false`
- 检查是否把 voltage source 错放到 switched net 上，并在发现短路时报错。

### `-ignore_duplicate_vsrc {true | false}`
- **默认**：`true`
- 控制 `.ploc` 中重名 voltage source 的处理方式。

### `-default_package_resistor / -default_package_inductor / -default_package_capacitor`
- 为 package RLC 模型设置默认 R/L/C 参数。
- 当 PGV 中定义 area-based voltage source 时，Voltus 会按 source 数量折算到单个 source 上。

### `-package_trace_connectivity {true | false}`
- **默认**：`false`
- 启用 die pin 到 board pin 的 package trace connectivity tracing。

### `-generate_package_pin_current_voltage {true | false}`
- **默认**：`false`
- 生成 package pin 的静态或动态电流/电压文件。

### `-probe_package_interface_ports {true | false}`
- **默认**：`false`
- 自动把 package interface port 写入 probe 节点，用于观察电压波形。

### `-unconnected_die_pkg_pins {ignore | error | edit}`
- **默认**：`ignore`
- 控制 die/package 未连接 pin 的处理方式。

## 5. 静态 / 动态通用分析增强

### `-enable_manufacturing_effects {true | false}`
- **默认**：`false`
- 在静态或动态分析中考虑 manufacturing effects。
- 若 `-accuracy hd`，该能力默认被启用。

### `-enable_rc_analysis {true | false}`
- **默认**：`false`
- 启用 resistor current analysis，即使没有 EM rule 也能生成 RC plot 用于 IR 调试。

### `-report_instances_missing_current_data {true | false}`
- **默认**：`false`
- 生成缺失 current data 的实例报告。

### `-record_inst_peak_current {true | false}`
- **默认**：`false`
- 保存实例 peak current，便于定位异常峰值导致的高 IR drop。

### `-record_results_start_time time`
- 从指定时间开始记录 rail 结果。
- 会影响 instance voltage、dynamic waveform、power-gate optimization 等结果的记录起点。

### `-report_power_in_parallel {true | false}`
- 在 rail analysis 同时并行执行 power analysis，以缩短整体周转时间。

### `-report_power_options option_names`
- 当 `-report_power_in_parallel true` 时，通过此参数补充 `report_power` 选项。

## 6. 动态分析与时域控制

### `-pre_simulation_period value`
- 设置 rail analysis 的粗粒度 pre-simulation 时长。

### `-fine_pre_simulation_period value`
- 设置 fine-grain pre-simulation 时长。
- 若同时指定粗粒度与细粒度预仿真，则细粒度阶段在粗粒度之后执行。

### `-pre_simulation_resolution value`
- 设置 transient time step / resolution。
- 默认单位 ps。

### `-limit_number_of_steps {true | false}`
- **默认**：`true`
- 若 dynamic IR drop 或 power-up 分析步数超过 1000，默认报错退出。
- 这个限制主要用于防止仿真窗口设置错误导致运行失控。

### `-save_voltage_waveforms {true | false}`
- 保存 instance voltage waveform 到 state directory。
- 可供 `view_dynamic_waveform`、Tempus SPICE critical path 或 substrate noise 使用。

### `-watch_location_waveform { { layerName xCoord yCoord }+ }`
- 按坐标与金属层观察节点电压波形。

### `-scale_initial_condition_current filename`
- 为 time 0 初始条件电流设置缩放因子。
- 主要用于减少 package 振荡、缩短 settling time。

## 7. EIV（Effective Instance Voltage）

### `-eiv_method {worst | best | avg | worstavg | bestavg}`
- **默认**：`worst`
- 控制 EIV 的计算方法。

| 值 | 说明 |
|---|---|
| `worst` | 报告最差实例电压 |
| `best` | 报告最佳实例电压 |
| `avg` | 报告平均实例电压 |
| `worstavg` | 各窗口先求平均，再取最差平均值 |
| `bestavg` | 各窗口先求平均，再取最佳平均值 |

### `-eiv_eval_window {switching | timing | both | elapse}`
- **默认**：`both`
- 控制在哪种窗口内评估 EIV。

| 值 | 含义 |
|---|---|
| `switching` | 仅开关活动窗口 |
| `timing` | 仅 TWF/时序窗口 |
| `both` | 两者并集 |
| `elapse` | 整段 rail 仿真时间 |

### `-eiv_eval_nodes {tap | port}`
- 默认按 tap node 计算 EIV，也可改为 port。

### `-eiv_eval_gnd_window {true | false}`
- **默认**：`false`
- 将 ground net switching window 也纳入 EIV 评估。

### `-eiv_report {auto | netonly | all}`
- **默认**：`auto`
- 控制生成 domain-based 还是 net-based EIV 报告。

### `-eiv_threshold value`
- 设置 EIV drop 报告阈值，单位 mV。

### `-eiv_pin_based_report {true | false}`
- **默认**：`false`
- 将 `.iv` 文件从 instance 粒度切换为 pin 粒度。

### `-eiv_pin_location {true | false}`
- **默认**：`false`
- 配合 `-eiv_pin_based_report` 输出 pin 坐标。
- 仅支持 net-based ivdn，不支持 domain-based ivdd。

### `-eiv_print_time {true | false}`
- **默认**：`false`
- 输出 worst voltage 的时间戳，便于回溯对应 current signature。

### `-eiv_average_per_window_list filename`
- 对指定 instance/cell 或 `ALL` 生成逐窗口平均 EIV 报告。

### `-eiv_histogram_min / -eiv_histogram_max / -eiv_histogram_number_of_bucket`
- 用于自定义 EIV histogram 的统计范围和 bucket 数量。

### `-eiv_max_instances value`
- 控制 `.iv` 文件中包含的最大实例数量。

### `-report_voltage_drop {true | false}`
- `false` 报实例实际电压，`true` 改为报 voltage drop / bounce。

## 8. EM（Electromigration）分析

### `-em_models file`
- 指定 EM model 文件。
- 与 `-process_techgen_em_rules` 互斥。
- 在 static 模式下若未提供 EM 模型，RJ 分析会被禁用。

### `-process_techgen_em_rules {true | false}`
- **默认**：`false`
- 从 `-extraction_tech_file` 或 `.cl` 中读取 EM rule。
- 适合直接复用 techgen / PGV 内嵌规则。

### `-ict_em_models file`
- 指定只含 EM rule 的 ICT-EM 文件，不含 RC 数据。

### `-ircx_models {RC.ircx EMIR.ircx}|{RC.ircx}`
- 用 IRCX 工艺文件提供 RC/EM 建模信息。
- 适合无 ICT-EM 文件时使用。

### `-em_threshold value`
- 控制 EM report 的输出阈值。
- 默认报告所有超过 0.9×limit 的电阻。

### `-em_limit_scale_factor {{avg value} {rms value} {peak value}}`
- 按 avg/rms/peak 维度缩放 EM limit。

### `-rms_em_analysis {true | false}`
- **默认**：`false`
- 动态 rail 中计算 RMS EM；若提供 EM 模型，通常会自动启用。

### `-peak_em_analysis {true | false}`
- **默认**：`false`
- 动态 rail 中生成 peak EM 报告。

### `-avg_em_analysis {true | false}`
- **默认**：`false`
- 动态 rail 中生成 average EM 报告。

### `-em_peak_analysis {true | false}`
- **默认**：`false`
- 配合 `-process_techgen_em_rules` 或 `-em_models` 同时输出 RMS 与 Peak EM。

### `-em_ignore_pgv_resistors {true | false}`
- **默认**：`false`
- 过滤掉 macro 内部 PGV 电阻的 EM violation。

### `-em_report_line_threshold value`
- 限制 EM 文本报告最大行数，防止低阈值时报告爆量。

### `-em_temperature string`
- 设置 EM analysis 温度。

### `-em_temperature_layer_list {...}`
- 针对指定层单独设置 EM 温度。

### `-em_rms_delta_T temp` / `-em_rms_delta_T_layer_list {...}`
- 设置 RMS current limit 分析的 delta temperature，全局或分层生效。

### `-check_thermal_aware_em {true | false}` + `-read_thermal_map thermal_map_file`
- 用 thermal map 驱动 EM 检查温度，适合温度分布不均匀的大芯片。

### `-check_current_balanced_power_grid_em {true | false}`
- **默认**：`false`
- 检查特定工艺节点下可放宽的 power-grid EM 规则。

### `-lowest_layer_for_em_check layer_name`
- 屏蔽指定层以下的 EM plot / report。

### `-disable_em_split_ac_dc_rules {true | false}`
- 关闭 AC/DC 分离规则，统一按同一套 EM 规则处理 signal 和 PG net。

## 9. REFF / RLRP / 电阻路径分析

### `-enable_reff_analysis {true | false}`
- **默认**：`false`
- 在 static/dynamic IR drop 分析时同时执行全芯片 effective resistance 分析。

### `-enable_rlrp_analysis {true | false}`
- **默认**：`false`
- 启用 Least Resistance Path 分析。

### `-reff_eval_nodes {port | tap}`
- 控制 REFF 以 port 还是 tap 节点为准。

### `-rlrp_eval_nodes {port | tap}`
- 控制 RLRP 以 port 还是 tap 节点为准。

### `-reff_pin_report_layer {top | bottom | all}` / `-rlrp_pin_report_layer {top | bottom | all}`
- 限定按哪些 pin layer 报 REFF / RLRP。

### `-reff_pin_report_method {best | worst}`
- **默认**：`worst`
- 多节点 pin 选择最佳或最差 REFF。

### `-rlrp_pin_report_method {best | worst | eiv_best | eiv_worst | eiv_best_window | eiv_worst_window}`
- **默认**：`worst`
- RLRP 可与 EIV 最佳/最差节点联动。

### `-reff_report_all {true | false}`
- 默认仅报 FAIL pin；设为 `true` 时同时报 pass/fail。

### `-reff_detail_report {true | false}`
- 在 `effr.rpt` 中增加坐标、layer、floating node 等细节列。

### `-rlrp_detail_report {true | false}`
- 报告 power gate 路径上的总电阻、net 电阻、PGATE_RON 等附加信息。

### `-common_res_inst_pair_file_name file`
- 对同源 vsrc 的 instance 对计算 common resistance。

### `-generate_instance_effr_report file`
- 为指定 cell / instance 生成 layer-based REFF 报告。

### `-generate_instance_ir_report file`
- 为指定 cell / instance 生成 layer-based IR drop 报告。

### `-generate_instance_pin_ir_report file`
- 为指定对象输出 pin node 级别的详细 IR 报告。

## 10. Power gate / Power-up / Switch net

### `-block_powerup_rail netname`
- 指定 block power-up analysis 的单个目标 net。

### `-powering_up_rails net_name1 ...`
- 指定正在上电的 switched rails。

### `-powering_down_rails net_name1 ...`
- 指定正在掉电的 rails。

### `-powerup_sequence_file filename`
- 指定每个 power gate instance 的触发时间、slew 等时序文件。

### `-prechain_powerup_sequence_file filename`
- 用 pre-chain / data-chain 时序约束生成 power-up 时序。

### `-powerup_fast_mode {true | false}`
- **默认**：`true`
- Native power-up fast mode，使用 lumped parasitic 模型快速估算 turn-on time 与 rush current。

### `-enable_instance_powergate_report {true | false}`
- **默认**：`false`
- 生成功耗门级别报告 `powergate.inst.rpt`。

### `-finegrain_powergate_ron {min | avg | max}`
- **默认**：`max`
- 为有多组 Ron 的 power gate cell 选择 Ron 取值。

### `-finegrain_powergate_ron_list filename`
- 按 cell / inst 逐项指定 Ron 取值。

## 11. 动态触发与 xPGV / current 建模

### `-dynamic_trigger_file filename`
- 为 Macro EM view with current signature 指定触发时刻。
- 用户自定义 trigger 的优先级高于 power analysis 自动生成的 `trigger*.txt`。

### `-static_trigger_file filename`
- 为 static 分析中的 xPGV current scaling 提供按 PG net 定义的触发 / scale 信息。
- 与 `-enable_xpgv_scaling` 互斥。

### `-enable_xpgv_scaling {true | false}`
- **默认**：`false`
- 按分析电压 / PGV 电压比例缩放 xPGV 中保存的电流。
- 适合同一 xPGV 复用到不同电压设计。

### `-generate_multi_voltage_library {true | false}`
- 使用多个不同电压生成的 PGV，做电压相关电容插值。

### `-use_early_view_list / -use_em_view_list / -use_ir_view_list`
- 指定某些 cell 使用 early / EM / IR PGV view。

### `-snap_layer_for_current_taps file_name`
- 将低层 via current tap 吸附到较高 via 层，减小分析规模。
- 适合 full-chip 使用已有子块详细结果时加速顶层分析。

### `-honor_negative_static_current {true | false}`
- **默认**：`false`
- static rail 中保留 `.ptiavg` 文件里的负电流值。

### `-static_multi_mode_analysis {true | false}`
- **默认**：`false`
- 对 macro 跨多个 functional mode 计算 worst-case static IR drop。

## 12. ERA（Early Rail Analysis）

### ERA 的核心目标
ERA 适用于未完全放置、未完全布线或希望快速评估 power grid 的阶段，可通过虚拟 followpin / via 和 area/current region 做早期 IR 分析。

### `-era_current_distribution {unplaced | placed | all | none}`
- 控制 ERA 电流分布策略。

| 值 | 含义 |
|---|---|
| `unplaced` | 仅给未放置实例分布电流 |
| `placed` | 给未显式定义功耗的已放置实例分布电流 |
| `all` | 两者都分布 |
| `none` | 不做 ERA current distribution |

### `-era_current_distribution_layer layer_name`
- 指定未放置实例 current region 分布层。

### `-era_current_distribution_unplaced_area {instance | diearea}`
- **默认**：`instance`
- 控制未放置实例按实例面积还是按剩余 die area 分摊电流。

### `-era_current_distribution_nets { net1 net2 ... }`
- 限定仅对指定 net 进行 current distribution。

### `-era_current_distribution_factor_for_placed value`
- **默认**：`1`
- 调整 placed block / macro 按面积分流时的等效面积比例。

### `-era_current_region_file filename`
- 指定区域电流文件，可写静态电流或动态 PWL 电流。
- 支持 `ADD_OVERLAP` / `SUBTRACT_OVERLAP` 控制重叠区域行为。

### `-era_instance_dynamic_current_file filename`
- 在 `era_dynamic` 下直接提供 instance/cell 级 PWL current 文件。
- 可不依赖 `.ptiavg/.ptiavk` 当前文件做动态 ERA。

### `-era_insert_virtual_followpins {standard | extended | none}`
- **默认**：`none`
- 生成虚拟 followpin，`extended` 比 `standard` 覆盖更广。

### `-era_insert_virtual_followpin_for_io {true | false}`
- 将虚拟 followpin 插入范围从 core 扩展到 IO 区域。

### `-era_insert_virtual_via_on_layers value`
- 控制 ERA 允许在哪些层对之间插入 virtual via。

### `-era_skip_virtual_via_by_type {whatif | def | all | none}`
- **默认**：`all`
- 选择跳过 what-if via、DEF via、全部或都不跳过。

### `-era_skip_virtual_via_on_layers {{ layer1 layer2 } ... }`
- 指定层对上不插入 virtual via。

### `-era_check_wires_for_generated_current_regions {true | false}`
- **默认**：`false`
- 仅在实际存在布线的地方生成 unplaced current region。

### `-era_techlib_generation {true | false}`
- **默认**：`true`
- 控制 ERA 是否自动生成 technology PGV。

### `-era_lef_layermap filename`
- 自动 layer map 生成失败时，手工指定 ERA 的 layermap。

### `-era_power_gate_file filename`
- 无 power gate PGV 时，提供 steady-state analysis 所需的 power gate 模型文件。

## 13. Probe / 波形 / 可视化调试

### `-probe_waveform_list filename`
- 指定要抓取电压 / 电流波形的实例或 cell 列表。
- 支持 `PROBE VOLTAGE|CURRENT|ALL`。

### `-probe_instance_pin_waveforms {true | false}`
- **默认**：`false`
- 为 probing instance 的全部 pin 输出电压 / 电流波形。

### `-probe_instance_tap_waveforms {true | false}`
- **默认**：`false`
- 为 probing instance 的全部 tap node 输出波形。

### `-probing_node_file file_name`
- 通过坐标、层、net 或 package node / resistor 名称定义 probe 点。

### `-probe_pin_voltage_list filename`
- 为指定 instance/cell 输出 block boundary voltage 文件。

### `-generate_combined_ivd_gif {true | false}`
- 生成全 domain 合并的 instance voltage drop GIF。

### `-gif_iv_threshold value`
- 设置 combined IVD GIF 的红色阈值。

### `-gif_resolution {low | medium | high}`
- **默认**：`medium`
- 控制 rail analysis 生成的 GIF 分辨率。

### `-gif_new_color_scale {true | false}`
- 使用与 GUI 一致的色标。

### `-gif_zoom_area { x1 y1 x2 y2 }`
- 对 GIF 限定显示区域。

### `-gif_zoom_topcell_diearea {true | false}`
- 用 topcell DIEAREA 而非总设计边界作为 GIF bbox。

### `-enable_vsrc_in_gif {true | false}`
- **默认**：`true`
- 控制 GIF 中是否显示 voltage source。

### `-enlarge_vsrc_in_vuvc {true | false}`
- 放大 vc/vu plot 中电源源点的图形显示。

### `-print_gif_range_percentage {true | false}`
- 在 IR / EIV GIF 标题中显示 voltage drop 百分比。

## 14. GDS / RDL / 多 die / 层次化场景

### `-gds_file / -gds_map / -gds_top_cell / -gds_offset / -gds_purpose`
- 控制 GDS 输入、layermap、top cell、偏移和用途。
- `-gds_purpose` 支持 `metalFill` / `flipChip` / `fullChip`。

### `-rdl_def / -rdl_def_list / -rdl_placement / -rdl_orientation`
- 在顶层 Rail 分析中引入一个或多个 RDL DEF，并设置其位置与方向。

### `-topcell_placement / -topcell_orientation`
- 设置 top DEF block 在 virtual top 中的位置和方向。

### `-die_mode {single|multi-die}`
- **默认**：`single`
- 切换 single-die 或 multi-die rail 分析。

### `-die_instance_name` / `-design`
- 多 die 分析时指定 die instance name 与设计名。

### `-enable_multi_die_connectivity_check {true | false}`
- 检查 nonvsrc 与 vsrc 之间是否存在有效电阻路径。

### `-mcp_model_mapping {...}`
- 建立 package model 与 die 名称映射。

### `-tsv_subckt_modelfile_list filename`
- 指定 3D-IC 的 TSV subckt model 文件。

### `-def_based_hierarchical_reports {true | false}`
- **默认**：`false`
- 为每个 DEF hierarchy 生成分层 rail 报告。

### `-generate_hier_bbv {true | false}`
- 为使用 xPGV 的层次块生成 block boundary voltage，支持顶层结果向下回灌块级分析。

### `-hpgv_block_lefs list_of_files` / `-hpgv_generate_view {ir | em | all}`
- 驱动自动 hierarchical PGV generation，并选择输出 IR / EM / all 视图。

## 15. XP 并行与结果复用

### `-enable_xp {true | false}`
- **默认**：`false`
- 启用 XP（Extensively Parallel）模式，在 extraction、report、GUI、simulation 各阶段分布式并行。

### `-xp_host_allocation_method {on_demand | at_startup}`
- **默认**：`on_demand`
- 控制远程主机的分配方式。

### `-xp_cpu_per_job_power value`
- 指定 XP 模式下每个 power analysis job 的 CPU 数。

### `-xp_cpu_per_job_simulation value`
- 指定 XP 模式下每个 simulation job 的 CPU 数。

### `-xp_simulation_min_cpu value`
- 设定 simulation 阶段的最小 CPU 要求。

### `-xp_simulation_cpu_timeout value`
- **默认**：`7200s`
- 等待获取所需 CPU 的超时时间。

### `-xp_resume {true | false}`
- **默认**：`false`
- 从 XP run 失败步骤恢复。

### `-xp_reuse_extraction_directory directory_name`
- 在 XP 模式下复用旧 run 的 extraction 数据。

### `-xp_purge {full}`
- XP run 完成后清理中间目录。
- 启用后当前 state directory 未来不能再做 reuse。

### `-reuse_state_directory dir_name`
- 复用已有 state directory 的 power-grid database。
- 适合设计数据和 PGV 没变，仅想切换分析条件的场景。

### `-skip_extraction {true | false}`
- **默认**：`false`
- 复用现有 extraction work directory，常用于 net-by-net flow。

### `-force_extraction {true | false}`
- **默认**：`false`
- 忽略已有 extraction 数据，强制重新提取。

## 16. 常见易错点

1. **`-em_models` 与 `-process_techgen_em_rules` 互斥**，不要同时指定。
2. **`-enable_xpgv_scaling` 与 `-static_trigger_file` 互斥**，二者都是 xPGV current scaling 方案。
3. **dynamic / power-up 仿真步数过大时**，默认 `-limit_number_of_steps true` 会直接退出，需要先检查窗口、TWF 或 stop time 设置是否合理。
4. **`-eiv_pin_location` 必须配合 `-eiv_pin_based_report` 使用**，且只支持 net-based ivdn。
5. **`-enable_2d_partition_extraction true` 时必须提供完整 `-extraction_tech_file`**。
6. **忽略 filler/decap 前先确认其是否承担 follow-pin 连通性**，否则会把真实连通关系分析断掉。
7. **`-dynamic_trigger_file` 的用户定义触发优先级高于自动 trigger 文件**，调试 macro current signature 时要注意覆盖关系。

## 17. 最小示例

### 静态 Rail

```tcl
set_rail_analysis_mode \
  -method static \
  -accuracy hd \
  -power_grid_library ./techonly.cl
```

### 动态 Rail + EIV + RLRP

```tcl
set_rail_analysis_mode \
  -method dynamic \
  -accuracy hd \
  -power_grid_library ./techonly.cl \
  -enable_rlrp_analysis true \
  -eiv_eval_window switching \
  -save_voltage_waveforms true
```

### ERA 静态分析

```tcl
set_rail_analysis_mode \
  -method era_static \
  -accuracy xd \
  -extraction_tech_file ./qrcTechFile \
  -era_current_distribution unplaced \
  -era_current_distribution_layer M1 \
  -era_insert_virtual_followpins extended \
  -era_skip_virtual_via_by_type none
```
