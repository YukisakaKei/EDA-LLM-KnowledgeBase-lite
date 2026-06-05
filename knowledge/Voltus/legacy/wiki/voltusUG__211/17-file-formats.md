---
source: knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl | entries: [0330, 0331, 0332, 0333]
---

# 文件格式参考

本文档汇总 Voltus 库生成、功耗分析、Rail 分析三大场景中涉及的输入/输出文件格式，说明其用途、使用命令及关键字段。

---

## 库生成文件格式

| 文件类型 | 用途 | 关联命令 | 格式要点 |
|---|---|---|---|
| **Current Region File** | 定义由 x/y 坐标围成的区域内的电流分布，覆盖 LibGen 计算值 | `set_pg_library_mode -current_distribution current_region` | `UNIT` 设置电流/电容默认单位；`CELL` / `NET` / `LAYER` / `REGION` 层级声明；`PROP FLAT\|HIER` 控制层次追踪 |
| **Cell Pin Net Map File** | LEF pin 名到内部 net 名的映射，用于 LEF 多 power pin 接同一 net 的场景 | `set_advanced_pg_library_mode -cell_pinnet_map_file` | 三列：`cellname net_name pin_name` |
| **Cell Accura Data File** | 存放单元电气特性数据（频率、活动因子、平均功耗），支持 include 层次描述 | `set_advanced_pg_library_mode -cell_accura_data_file` | `FREQ` / `CLK_FILE` / `FA_VALUE` / `FA_FILE` / `AVG_PWR` / `AVG_PWR_FILE`；可搭配 Clock File / Frequency Activity File / Average Power File |
| **Cell Decap File** | 指定单元的去耦电容值 | `set_pg_library_mode -cell_decap_file` | `UNIT`（默认 fF）；`CELL` 指定单元总 decap；`NET` 指定 net decap |
| **Cell Well Cap File** | 指定单元的阱电容值 | `set_advanced_pg_library_mode -well_cap_file` | 格式与 Decap File 类似，`CELL` 指定阱电容 |
| **Circuit Include File** | 指定 LibGen 模拟器输入文件，包含单元信息、被动器件 MODEL card、附加 DC 电压 | `set_advanced_pg_library_mode -circuit_include_file` | SPICE 格式 |
| **GDS Layermap File** | GDS layer number 到 technology layer 的映射 | `set_pg_library_mode -gds_layermap` | 列：`类型(diff\|poly\|via\|metal\|layer)` / `Library Layer Name` / `GDSII Layer Number` / `GDS Datatype`；支持 `PORT` / `TEXT_ONLY` / `NO_TEXT` 属性 |
| **LEF-DEF Layermap File** | LEF/DEF layer 名到 technology layer 的映射 | `set_pg_library_mode -lef_layermap` | 列：`类型` / `Library Layer Name` / `LEFDEF Layer Name` |
| **Pad Voltage Source File** | 在 pad cell 上定义电压源位置 | `set_advanced_pg_library_mode -source_location_file` | `MIN_SPACING` / `DENSITY` 全局参数；`CELL` / `NET` 作用域；`PORT\|DETAILED` 视图选择；点或矩形坐标 |
| **Port File** | 定义 switched rail 的端口标签信息 | `set_advanced_pg_library_mode -add_port_labels` | `MACRO` + cell name；`PIN` + pin name + direction（B/I/O） |
| **Trigger File** | 定义各单元的触发条件，用于识别自定义 macro 的功能模式（读/写/空闲） | `set_pg_library_mode -current_distribution dynamic_simulation` | 见下方 Trigger File 子格式 |

### Trigger File 子格式

Trigger File 支持多种电流表征方法，通过 `CURRENT_CHARACTERIZATION_METHOD` 声明：

| 方法 | 关键字 | 说明 |
|---|---|---|
| 仿真向量 | `SIMULATION` | 基于 vector 的仿真，需 `CONDITIONAL_STIMULUS_FILE` 指定 PWL 激励 |
| Liberty 库 | `DOTLIB` | 从 dotlib 自动生成 trigger，适用于 memory cell |
| 用户定义 PWL | `PWL` | `USER_PWL_FILE` + `PWL_START_TIME/PWL_END_TIME` 定义多 mode 时间窗口 |
| FSDB | `FSDB` | 从 FSDB 格式的 SPICE 总电流波形获取，`FSDB_PATH` / `FSDB_NET_NAME` 等 |
| Datasheet | `DATASHEET` | 提供 memory 的 datasheet 参数（`DATASHEET_INPUT_SLEW` / `OUTPUT_SLEW` / `DELAY` / `PARAMETER`） |
| Spice Deck | `SPICE_DECK_BASED` | 用户指定 SPICE deck，`DECK_FILE` / `SIM_OPTIONS` / `FSDB_FILE` |

通用字段：`CELL` / `MODE_NAME` / `CONDITIONAL_INPUT` / `CONDITIONAL_PIN` / `END_MODE` / `END`

---

## 功耗分析文件格式

| 文件类型 | 用途 | 关联命令 | 格式要点 |
|---|---|---|---|
| **Instance ASCII Power File** | 按 instance 指定峰值或平均功耗值（瓦），适用于缩放静态/动态分析中的 cell peak power | `set_power_data -format ascii` | 每行：`instancename power_value power_pin_name`；cell name 不支持通配符 |
| **Instance Temperature File** | 热感知泄漏功耗计算的温度输入，由热引擎生成 | `set_inst_temperature_file` | 首行 `Default_temperature`，后续 `instance_name temperature` |
| **TCF (Toggle Count Format) File** | 翻转活动信息，含 toggle count 和 1 态概率，用于低功耗综合和功耗分析 | `read_activity_file -format TCF` | 层次化结构：`tcfversion` / `generator` / `duration` / `unit`；instance 下 pin/net 的 `(probability toggle_count)` 对 |
| **TWF (Timing Windows File)** | 时序窗口和 slew 数据，源自 STA 分析，约束 vectorless 动态功耗计算中的信号时序依赖 | `read_twf`（Tempus 端 `write_twf` 生成） | **Header**: `VERSION` / `DESIGN` / `DATE` / `PROGRAM` / `DELIMITERS` / `TIME_SCALE` / `CAP_SCALE` / `RES_SCALE` / `VOLTAGE_SCALE` / `VOLTAGE_THRESHOLD` / `LIFETIME` / `OPERATING_CONDITIONS` / `DEFAULT_INPUT_SLEW` |

### TWF Body 结构

| 节 | 说明 |
|---|---|
| `CTLF Files` | 引用的 TLF/CTLF 库文件位置 |
| `WAVEFORM` | 定义抽象周期波形（`name period {edge_position}`） |
| `CLOCK` | 将波形关联到 port（clock root） |
| `CLOCK_GROUP` | 按 waveform name 分组 |
| `DRIVER_CELL` | 输入 port 的驱动单元信息（library / cell / pos_neg_edge / input_slew） |
| `DRIVER_STRENGTH` | 驱动单元的保持电阻 |
| `EXTERNAL_LOAD` | port 的外部负载电容 |
| `CONSTANT` | 非切换 net 的逻辑约束（0/1）及源电阻 |
| `INPUT_SLEW` | 输入 port 的 slew |
| `CAUSED_BY` | 按 clock pin 分组的 arrival time 约束；`CAUSED_BY NULL` 表示无时序约束的 net/pin。参数：`rise_at` / `rise_time` / `rise_k` / `rise_slack` / `fall_at` / `fall_time` / `fall_k` / `fall_slack` / `clock_or_data` |

---

## Rail 分析文件格式

| 文件类型 | 用途 | 关联命令 | 格式要点 |
|---|---|---|---|
| **Dynamic Trigger File (Rail)** | 层次化设计中触发 detailed dynamic view block 的时机 | `set_rail_analysis_mode -dynamic_trigger_file` | `INSTANCE` / `CELL` 关键字指定实例或全部实例；格式：`[INSTANCE\|CELL] name trigger_time` |
| **EM Models File** | 指定电迁移分析所需的模型参数 | `set_rail_analysis_mode -em_models` | 支持 **Limit-based**（限值）和 **Risk-based**（风险）两种 EM 模型语法 |
| **EM Only ICT File** | 仅含 EM 信息的工艺文件，文本格式 | `set_rail_analysis_mode -process_techgen_em_rules true -ict_em_models` | 全局参数：`background_dielectric_constant` / `layout_scale` / `temp_reference` / `em_tref` / `em_output_wlt` / `em_variables` / `em_conductor_unit mA` / `em_via_unit mA` / `em_segment_length` |
| **Package Model and Mapping File** | SPICE 格式封装模型 + 端子映射文件 | `set_package -spice -mapping` | 映射格式支持 Voltus-specific 和 MCP (Model Connection Protocol) 两种 |
| **Power-Up Sequence File** | 定义各 power gate instance 的触发时间 | `set_rail_analysis_mode -powerup_sequence_file` | 每行：`inst_name pin_name always_on_net switch_net rise_time rise_slew fall_time fall_slew` |

### EM Models File 关键参数

**Risk-based 模型参数（Black's equation）**：

| 参数 | 默认值 | 说明 |
|---|---|---|
| `em_A` / `em_A_n` / `em_A_w` | 700 / 700 / 45000 | Black's equation 系数（A^2 h/kcm^4） |
| `em_Ea` / `em_Ea_n` / `em_Ea_w` | 0.8 / 0.8 / 0.6 eV | 激活能 |
| `em_m` | 1 | 温度系数 |
| `em_n` | 2.0 (metal) / 1.0 (via) | 电流指数 |
| `em_sigma` | 0.7 | 对数正态失效模型 sigma |
| `em_vcwidth` | 0 (metal) / 0.5 (via) um | Via 标准宽度 |

**Limit-based 模型参数**：

| 参数 | 默认值 | 说明 |
|---|---|---|
| `em_jmax_dc_avg` | 1.0e+5 A/cm^2 (cond) / 0.001A/via | DC 平均电流密度限值 |
| `em_jmax_dc_peak` | 1.0e+7 A/cm^2 (cond) / 0.001A/via | DC 峰值电流密度限值 |
| `em_jmax_dc_rms` | 1.0e+6 A/cm^2 (cond) / 0.001A/via | DC RMS 电流密度限值 |
| `em_jmax_ac_avg` / `em_jmax_ac_peak` / `em_jmax_ac_rms` / `em_jmax_ac_rec` | None | AC 各类电流密度限值 |
| `em_recover` | 1 | Recovery 因子，设为 -1 时使用 abs(current) 平均 |

参数支持窄线/宽线（`_n` / `_w` 后缀）、PWL 表、EQU 方程、温度缩放表（`jmax_factor`）、宽度/长度条件、电流方向（`current_direction up\|down`）等限定符。

**Conductor 层**：通常使用 EQU 方程描述 EM 模型，形式为 `fn(w) * beneficial_factor`，可附加 `jmax_factor` 温度缩放表。

**Via 层**：通常使用 PWL 分段线性插值，以 cut area 为索引，含 base PWL table 和条件 PWL table（宽度/长度/电流方向限定）。

### Package 映射格式

**Voltus-specific 格式**：
```
subckt_terminal_name [power|ground|pin toplevel_pin_name|cell pad_cell_instance_name|x,y|power_pin net_name|ground_pin net_name]
```

**MCP 格式**：以 `[MCP Begin]` / `[MCP End]` 标记块，包含 `[MCP Ver]`、`[Coordinate Unit]`、`[Connection]`/`[Connection Type]`、`[Power Nets]`/`[Ground Nets]`/`[Signal Nets]` 节，每行记录 `pin cktnode net x y`。
