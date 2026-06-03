---
source: knowledge/Voltus/legacy/json/voltusUG__211 | chapters: [0051, 0052, 0053, 0054, 0055, 0056, 0057, 0058, 0059, 0060, 0061, 0062, 0063, 0064, 0065, 0066, 0067, 0068, 0069, 0070, 0071, 0072, 0073]
---

# 处理模式：分布式处理与 Voltus-XP

## 一、分布式处理（Distributed Processing）

### 概述

多 CPU 可缩短功耗和 IR drop 分析的整体运行时间。性能提升在超过 8 个 CPU 后趋于饱和。

**许可方案**

| 许可类型 | CPU 数量 |
|----------|----------|
| VTS-L（首个） | 1 CPU，不可叠加 |
| VTS-XL（首个） | 8 CPU |
| 每增加一个 VTS-XL 或 VTS-MP | +8 CPU（VTS-MP 优先级更高） |

---

### 设置分布式处理

支持两种模式：

**本地模式（Local Mode）**
```tcl
set_distribute_host -local
set_multi_cpu_usage -localCpu 4
```

**分布式模式（Distributed Mode）**
```tcl
set_distribute_host -rsh -add {pe-opt11 pe-opt12}
set_multi_cpu_usage -localCpu 4 -remoteHost 2 -cpuPerRemoteHost 2
```

- 需要对远程主机有 rlogin 访问权限
- 支持 LSF、SGE 队列或自定义 job 提交脚本

---

### 多 CPU 模式下的功率分析

静态、动态 vectorless、向量驱动功耗分析均支持多 CPU（本地和分布式模式）。

分布式模式下通过配置文件指定分区：

```tcl
set_power_analysis_mode -distributed_setup <file>
```

配置文件格式（4 列）：
```
INST/CELL  <name>  hier/block  [power.inc]
```

- `INST`/`CELL`：指定实例或单元
- `hier`：保留完整层次（从顶层到块的 DEF 全部包含）
- `block`：仅包含下层 DEF
- 未指定的实例/单元与顶层合并为一组

**示例 dp_setup.txt：**
```
INST top.block1 block
INST top.block4 block
CELL block2 block
```

---

### 独立分布式功率分析（Standalone Distributed Power Analysis）

不运行 rail analysis，仅在多 CPU 模式下执行动态功耗分析和 vector profiling。

关键参数：
- `report_power -distribute`：启用独立分布式功耗分析
- `set_power_analysis_mode -vector_profile_mode event_based`：分布式模式下的 vector profiling
- `set_power_analysis_mode -partition_twf true`：读取输入 TWF 并生成块级 TWF（块级 TWF 不可用时必须指定）

**本地模式脚本示例：**
```tcl
set_distribute_host -local
set_multi_cpu_usage -localCpu 4
read_lib -lef <LEF>
read_lib <timing libraries>
read_verilog <verilog netlist>
read_sdc <timing constraints>
read_def -skip_signal <DEFs>
read_spef <RC parasitic files>
set_power_analysis_mode -reset
set_power_analysis_mode -method dynamic_vectorless -disable_static true
set_dynamic_power_simulation -period 8ns -resolution 50ps
set_default_switching_activity -input_activity 0.2 -seq_activity 0.1 -period 10.0
report_power
```

**分布式模式脚本示例：**
```tcl
set_distribute_host -rsh -add "m1 m2"
set_multi_cpu_usage -remoteHost 8 -cpuPerRemoteHost 2 -localCpu 16
set_power_analysis_mode -method dynamic_vectorless -distributed_setup dp_setup.txt
```

**LSF 独立分布式功耗分析示例：**
```tcl
set_distribute_host -lsf -queue lnx64 -timeout 500000 \
  -args {-P resource:test -W 150:00 -o temp} -resource "lnx86_test"
set_multi_cpu_usage -remoteHost 4 -cpuPerRemoteHost 8 -localCpu 16
set_power_analysis_mode \
  -method dynamic_vectorless \
  -power_grid_library "$DesignDir/../techonly.cl $DesignDir/../stdcells.cl" \
  -distributed_setup power_control.txt \
  -create_binary_db true \
  -partition_twf true
report_power -distribute -report_prefix report -output static_power
```

---

### 异构分布式处理（Multi-size Heterogeneous Distributed Processing）

通过 `-custom_script_list` 指定不同内存规格的机器，按优先级顺序分配：

```tcl
set_distribute_host -custom -custom_script_list \
  {{{string1} count1} {{string2} count2} ... {{stringN} countN}}
```

- 按顺序提交：先提交 count1 个 string1 任务，再提交 count2 个 string2 任务，直到总数达到请求数量
- 分布式配置文件中的 job 顺序决定机器分配顺序

**示例（2 台 512GB + 30 台 256GB）：**
```tcl
set_multi_cpu_usage -remoteHost 32
set_distribute_host -custom -custom_script_list \
  {{{bsub -R "OSNAME==Linux && mem > 500000"} 2} \
   {{bsub -R "OSNAME==Linux && mem > 256000"} 30}}
set_power_analysis_mode -method dynamic_vectorless -distributed_setup dp_setup.txt
```

---

### 多 CPU 模式下的库生成

```tcl
set_distribute_host -local -timeout 240
set_multi_cpu_usage -localCpu 4
set_pg_library_mode -enable_distributed_processing true \
  -celltype macros|stdcells \
  -macros_config_file config.file
generate_pg_library -output <directory_name>
```

宏单元配置文件格式（`-macros_config_file`）：
```
CELL <cell1> GDS_FILE <gds_file1> SUBCKT_FILE <subckt_file1> \
  TRIGGER_FILE <trigger_file_path> POWER_GATE_PARAMS <parameters>
CELL <cell2> ...
```

---

### 多 CPU 模式下的 IR Drop 分析

- power-grid extraction 和 matrix solver 均支持多 CPU
- 静态和动态分析均支持 domain-based 分析
- 默认 matrix solver 使用本地 CPU；启用分布式 solver 需指定：

```tcl
set_rail_analysis_mode -enable_distributed_processing_in_solver true
set_distribute_host -rsh -add {host1 host2 host2 host3 host3}
set_multi_cpu_usage -localCpu 4
```

> 建议 `-remoteHost` 数量等于 domain 中关联 net 数，以获得最佳负载均衡。

**Domain-based IR Drop 分析脚本示例：**
```tcl
set_distribute_host -rsh -add {pe-opt11 pe-opt12}
set_multi_cpu_usage -localCpu 8 -remoteHost 2 -cpuPerRemoteHost 2
# ... 读取设计数据 ...
set_rail_analysis_mode \
  -method dynamic -accuracy hd -temperature 25 \
  -power_grid_library { stdcells.cl memories.cl }
set_power_data -reset
set_power_data -format current -scale 1 {dynamic_VDD.ptiavg dynamic_VSS.ptiavg}
set_pg_nets -net VDD -voltage 1.08 -threshold 0.972 -tolerance 0.3
set_pg_nets -net VSS -voltage 0.0 -threshold 0.108 -tolerance 0.3
set_rail_analysis_domain -name core -pwrnets VDD -gndnets VSS
set_power_pads -net VDD -format xy -file VDD.ppl
set_power_pads -net VSS -format xy -file VSS.ppl
analyze_rail -type domain core
```

> **注意**：domain-based 分析使用分布式模式；net-based 分析应始终使用本地模式。

---

## 二、Voltus-XP 大规模并行处理

### 介绍

Voltus-XP（Extensively Parallel）模式专为先进工艺节点的 power-grid sign-off 设计，支持：
- 最高 **5X** 性能提升
- **千亿级（giga-scale）**设计
- 数千 CPU、数百台机器的近线性扩展

适用场景：传统单机或分布式模式无法处理的超大规模设计（5 亿实例以上），传统方式面临 TB 级内存需求、数天运行时间、GUI 极慢等问题。

---

### 关键特性

| 特性 | 说明 |
|------|------|
| Cloud-based 环境 | 支持 AWS，serverless，动态分配资源 |
| 分区数据库 | 压缩格式存储，降低磁盘延迟；chip-power、extraction、IR drop、EM、GUI 全流程并行 |
| 简单使用模型 | 与分布式模式使用相同 Tcl 脚本，仅增加少量 XP 专用参数 |
| Sub-flow 数据隔离 | 每个子流程独立存储，支持断点续跑，NFS 故障可快速恢复 |
| 输出目录结构 | 按流程步骤分类存储，rail 报告在 `/Reports/rail`，EM 报告在 `/Reports/em` |
| 弹性资源 | 自动匹配可用资源，支持部分资源启动分析 |
| GUI 性能提升 | 分布式 GUI 加载，生成 image cache，内存占用更小，启动更快 |
| 增强日志 | 子流程级别独立日志，便于定位问题 |

---

### XP 模式 Rail Analysis 关键 TCL 参数

`set_rail_analysis_mode` 的 XP 专用参数：

| 参数 | 说明 |
|------|------|
| `-enable_xp true` | 启用 XP 模式 |
| `-xp_cpu_per_job_power` | 每个功耗 job 的 CPU 数 |
| `-xp_cpu_per_job_simulation` | 每个仿真 job 的 CPU 数 |
| `-xp_host_allocation_method` | 主机分配方法 |
| `-xp_purge` | 清除 XP 输出目录 |
| `-xp_resume` | 从断点续跑 |
| `-xp_reuse_extraction_directory` | 复用已有 extraction 结果 |
| `-xp_reuse_power_directory` | 复用已有功耗结果 |
| `-xp_simulation_cpu_timeout` | 仿真 CPU 超时设置 |
| `-xp_simulation_min_cpu` | 仿真最小 CPU 数 |
| `-extraction_tech_file` | 指定 Quantus extraction 技术文件（去除对 PGV 的依赖） |
| `-report_power_in_parallel true` | 功耗分析与 rail 分析并行运行，提升整体 TAT |

---

### 动态功耗与 Rail 分析流程（XP 模式）

**所需输入文件：**
- 设计数据（LEF、netlist、DEF）
- SPEF
- Power-grid libraries（.cl）
- 动态功耗计算结果（vectorless 或 vector-based）
- Quantus extraction 技术文件

**完整流程步骤：**

```tcl
# 1. 分布式处理设置（至少 8 CPU）
set_multi_cpu_usage -localCpu 8 -remoteHost 2 -cpuPerRemoteHost 8
set_distribute_host -custom -custom_script_list \
  {{{bsub -m "host1" -q hier -n 8 -K} 1} {{bsub -m "host2" -q hier -n 8 -K} 1}}

# 2. 读取设计数据
read_lib -lef $lefs
read_verilog ../design/postRouteOpt.v.gz
set_top_module super_filter -ignore_undefined_cell
read_twf ../design/super_filter.twf
specify_def ../design/super_filter.def.gz

# 3. 指定 SPEF
specify_spef ../design/postRouteOpt_RC_wc_125.spef.gz

# 4. 指定功耗输出目录
set_power_output_dir dynVecLessPowerResults

# 5. 定义功耗分析模式
set_power_analysis_mode -reset
set_power_analysis_mode \
  -disable_static false \
  -write_static_currents true \
  -binary_db_name dynvectorlessPower.db \
  -create_binary_db true \
  -method dynamic_vectorless \
  -power_grid_library { techonly.cl stdcells.cl macros_pll.cl } \
  -enable_state_propagation true \
  -current_generation_method avg \
  -distributed_setup dp_setup.txt

# 6. 可选：设置实例动态切换模式
set_power -instance u0 -dynamic_switch_pattern {READ 0 READ}

# 7. 可选：设置默认切换活动
set_default_switching_activity -input_activity 0.3 -period 4.0 \
  -clock_gates_output_ratio 2.0

# 8. 可选：定义仿真周期和分辨率
set_dynamic_power_simulation -reset
set_dynamic_power_simulation -period 20 -resolution 50

# 9. 定义 rail 分析模式（启用 XP）
set_rail_analysis_mode \
  -method dynamic \
  -accuracy hd \
  -temperature 125 \
  -gif_resolution 0 \
  -power_grid_library { techonly.cl stdcells.cl macros_pll.cl } \
  -extraction_tech_file /design/super_filter/qrcTechFile \
  -report_power_in_parallel true \
  -enable_xp true

# 10. 定义 power nets 和 domain
set_pg_nets -net VDD_AO -voltage 0.9 -threshold 0.85
set_pg_nets -net VDD_external -voltage 0.9 -threshold 0.85
set_pg_nets -net VSS -voltage 0.0 -threshold 0.05
set_rail_analysis_domain -name core -pwrnets {VDD_AO VDD_external} -gndnets VSS

# 11. 定义电压源位置
set_power_pads -net VDD_AO -format xy -file super_filter_VDD_AO.pp
set_power_pads -net VDD_external -format xy -file super_filter_VDD_external.pp
set_power_pads -net VSS -format xy -file super_filter_VSS.pp

# 12. 运行 rail 分析
analyze_rail -type domain -output dynamic_rail core
```

> 默认情况下 XP 支持部分资源启动：请求 16 台主机但只有 8 台可用时，工具会以 8 台开始运行。

---

### XP 输出目录结构

`analyze_rail -output <dir>` 指定的输出目录下，每次运行生成一个 state directory：
- 动态分析：`<domainName>_<temperature>_dynamic_<X>`
- 静态分析：`<domainName>_<temperature>_avg_<X>`
- `latest` 符号链接指向最新的 state directory

**State directory 内部结构：**

| 目录 | 内容 |
|------|------|
| `gui/` | GUI 相关 JSON 数据（层、net、分区映射等） |
| `logs/` | 各子流程日志；`voltus_xp.log` 为合并日志 |
| `misc/` | 各流程步骤生成的临时/应用文件 |
| `pgdb/` | 电气数据（节点、元件、实例、tap 节点、电压源等） |
| `reports/design/` | 设计检查报告 |
| `reports/em/` | 电流密度报告（`netname.rj.avg.rpt`） |
| `reports/rail/<net>/` | 各 net 的 GIF 图和 rail 报告 |
| `reports/rail/domain/` | Domain-based IVD/EIV/DIV GIF 和 IV 报告 |
| `reports/rail/package/` | 封装相关信息 |
| `reports/rail/waveforms/` | 电流波形文件（`.ptiavg`） |
| `results/` | 仿真、EM、rail 各步骤结果文件 |
| `voltus_data/` | 各 rail 分析步骤的运行目录和二进制文件（调试用） |

**日志文件：**
- `voltus.log`：当前工作目录，完整运行日志
- `<state_dir>/logs/voltus_xp.log`：XP 子流程跟踪日志
- `<state_dir>/reports/rail/domain/report_generation.log`：电路 profile 和 rail 报告

---

### Distributed GUI（DGUI）

Voltus-XP 的 GUI 模式称为 DGUI，支持加载数十亿实例的超大设计，将 GUI 操作分布到多台主机。

启动方式：先设置分布式处理命令，再加载设计并读取 XP 输出目录：

```tcl
set_multi_cpu_usage ...
set_distribute_host ...
# 加载设计后读取 rail 结果
read_power_rail_results <xp_output_dir>
```

- 支持 flat 和层次化数据库（HDB）
- 超大设计推荐使用 HDB + `read_power_rail_results`
- 加载时显示 "Caching images" 进度提示
