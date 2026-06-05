---
source: knowledge/Voltus/legacy/jsonl/voltustxtcmdref__211.jsonl | entries: [0107]
---

# Voltus 功耗分析学习笔记：Flow Vector Less

> 脚本执行顺序：Step 0 读入设计数据 → Step 1 设置 switching activity → Step 2 `set_power` 设置功耗相关约束 → Step 3 配置功耗分析模式 → Step 4 可选加载补充配置 → Step 5 配置 Rail 分析模式 → Step 6 定义 PG Net / Domain / 电压源位置 → Step 7 运行 Rail 分析

---

## 总流程对照

---

## Step 0：读入设计数据

在开始 vectorless 功耗分析之前，先准备并读入设计数据库、时序约束和寄生参数。该流程**不依赖 UPF/CPF**；power domain、PG net 与电压源位置统一在 **Step 6** 指定。

### 需要的输入文件

- LEF（technology LEF / std cell LEF / macro LEF）
- Timing Library（`.lib` / LDB）
- Verilog Netlist
- DEF
- SDC 或 TWF
- SPEF
- PGV（Power Grid View Library，`.cl`）
- Extraction Tech File（QRC Tech File）
- Extractor Include 文件
- EM Limit Scale Table

### 各输入文件的作用

#### LEF（工艺与物理抽象）

提供 technology LEF、标准单元 LEF 和宏单元 LEF中的版图抽象、层信息、pin 位置、macro 外形等物理信息。首个 LEF 应为 technology LEF。

#### Timing Library（功耗/时序模型）

提供标准单元和宏单元的时序/功耗库。Vectorless 功耗分析依赖库中的 internal power、switching power、leakage power 等模型来计算电流和功耗。

#### Verilog Netlist 与 Top Module（逻辑连接关系）

提供设计的逻辑连接关系，并定义分析的顶层入口。

#### DEF（物理实现信息）

提供 instance 摆放、布线和物理层次信息。若设计很大，也可以采用轻量方式只指定 DEF 文件列表。

#### SDC 或 TWF（时序信息）

二者用于提供 vectorless 分析所需的时序信息：
- `SDC`：提供时钟、例外路径等约束，便于工具结合设计环境建立时序上下文
- `TWF`：直接提供信号翻转时间窗口，是 vectorless 动态分析最直接的时间信息来源

若运行环境能直接得到时序窗口，可优先使用 TWF；若没有 TWF，则至少需要 SDC。

#### SPEF（寄生参数）

提供线网 RC 寄生参数，用于更准确地计算翻转传播、负载和动态功耗，也是后续 rail 分析的重要输入。

### 通过 `set_power_analysis_mode` / `set_rail_analysis_mode` 传入的补充文件

以下文件不通过独立的 `read_*` 命令读入，而是在后续步骤通过分析模式命令传入：

| 文件 | 作用 | 传入位置 |
|---|---|---|
| PGV（`.cl`） | Cadence power cell / power-grid view library；可包含 decap cell 标记，以及供功耗/rail 分析使用的 power-grid 相关库信息 | `set_power_analysis_mode -power_grid_library`；`set_rail_analysis_mode -power_grid_library` |
| Extraction Tech File | 带 EM model 的 qrcTechFile，用于顶层 power-grid extraction。TSMC 自带的 qrcTechFile 不含 EM model，可自行生成带 EM 的 qrcTechFile，或通过 `set_rail_analysis_mode -ict_em_models` 单独指定 ICT-EM rule file 补充 EM 信息。在 rail 分析中若未显式指定，可回退使用 PGV 内存储的提取技术文件 | `set_power_analysis_mode -extraction_tech_file`；`set_rail_analysis_mode -extraction_tech_file` |
| Extractor Include | 以 include 文件形式提供 extractor（ZX）命令和变量；在功耗分析里仅适用于 XP 模式下的 standalone report generation flow，在 rail 分析里可直接作为 extractor 控制文件使用 | `set_power_analysis_mode -extractor_include`；`set_rail_analysis_mode -extractor_include` |
| EM Limit Scale Table | 按 layer 为 avg/rms/peak EM limit 提供缩放因子；用于 layer-based EM limit scaling，且优先级高于 `-em_limit_scale_factor` | `set_rail_analysis_mode -em_limit_scale_table` |

其中：
- **Step 3** 侧重功耗分析，所以会传入：PGV、`extraction_tech_file`
- **Step 5** 侧重 rail 分析，所以会传入：PGV、`extractor_include`、`extraction_tech_file`、`em_limit_scale_table`

### 本流程不需要的输入

- 不需要 `read_activity_file`：这是 vector-based 流程才需要的 VCD/FSDB/SAIF 活动文件
- 不需要 UPF/CPF：power domain、PG net、电压阈值和电压源位置在 **Step 6** 通过相关命令手工指定

---

## Step 1：先设默认 activity，再修正关键对象

vectorless 流程没有 VCD/FSDB/SAIF 等活动文件，因此需要先补充 switching activity，供工具估算动态功耗和后续 rail 电流。

- `set_default_switching_activity`：先给未标注对象提供默认 activity，作为全设计的基础背景值
- `set_switching_activity`：再对特定 input / pin / net 显式修正 activity，例如 reset、clock gating 输出、macro 控制信号等关键对象

常见示例：

```tcl
set_default_switching_activity -input_activity 0.3 \
    -period 4.0 -clock_gates_output_ratio 0.5
set_switching_activity -reset
set_switching_activity -input_port rst -activity 0.25 -duty 0.30
```

通常先用 `set_default_switching_activity` 提供默认值，再用 `set_switching_activity` 修正关键对象；随后可选执行 `propagate_activity` / `get_activity` 检查结果。

---

## Step 2：`set_power` 设置功耗相关约束

`set_power` 用于**手工指定 cell 或 instance 的功耗**。它主要用于 `.lib` 或功耗模型不完整的场景，例如 macro、IP 或 black box 的功耗补充；如果库模型完整，通常不需要大量使用。

常见示例：

```tcl
set_power -reset
set_power -cell pll -pin VDD 0.5
set_power -instance u0 -pin VDD 0.5
```

其中：

- `-cell`：按 cell 类型统一指定功耗
- `-instance`：只对某个实例单独指定功耗

可以把 Step 1 和 Step 2 理解为：前者补 activity，后者补功耗模型。

---

## Step 3：`set_power_analysis_mode` 配置分析模式

这一阶段除了设置功耗分析方法外，flow 里还常会加一条时序建模相关设置：

```tcl
set_delay_cal_mode -equivalent_waveform_model_propagation true \
    -equivalent_waveform_model_type ecsm
```

它的作用是：在延迟计算中使用 ECSM 等效波形模型，并把波形形状继续向后级传播，而不是只按简单 slew 近似。这样后级 delay / slew 计算会更贴近真实波形，常用于高精度的 timing / power / IR 联合分析。

按新写法，这条命令等价于：

```tcl
set_delay_cal_mode -equivalent_waveform_model propagation
```

---

## Step 4：`set_power_include_file` 可选加载补充配置

---

## Step 5：`set_rail_analysis_mode` 配置 Rail 分析模式

---

## Step 6：定义 PG Net / Domain / 电压源位置

---

## Step 7：运行 Rail 分析

---

## 最小可运行脚本骨架

---

## 何时使用 `flow_vector_less`
