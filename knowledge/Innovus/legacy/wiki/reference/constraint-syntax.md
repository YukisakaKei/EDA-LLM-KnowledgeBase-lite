---
source: knowledge/Innovus/legacy/json/innovusUG__211 | chapters: [0103, 0172, 0173, 0174, 0175, 0176, 0177, 0178, 0179, 0180, 0181]
---

# SDC 约束语法和 MMMC 配置参考

## 概述

SDC（Synopsys Design Constraints）是业界标准的时序约束格式，用于定义设计的时序要求。MMMC（Multi-Mode Multi-Corner）是 Innovus 中的多模式多工艺角配置方法，允许在单个设计会话中同时分析多个工作模式和工艺角。

## 时序约束基础

### 时钟约束

#### create_clock - 创建时钟

定义设计中的主时钟信号。

```tcl
create_clock -name clock_name -period period_value [clock_port]
create_clock -name clk -period 10 [get_ports clk]
```

**参数说明：**
- `-name`：时钟名称
- `-period`：时钟周期（纳秒）
- `clock_port`：时钟端口或网络

**常用选项：**
- `-waveform {rise_time fall_time}`：定义时钟波形
- `-add`：添加额外的时钟定义

#### set_propagated_clock - 设置传播时钟

在时钟树综合（CTS）后，将时钟标记为传播时钟，使用实际的时钟延迟进行时序分析。

```tcl
set_propagated_clock [all_clocks]
set_propagated_clock [get_clocks clk]
```

**用途：**
- PostCTS 阶段必须设置
- 使用实际的时钟树延迟而非理想延迟
- 提高时序分析的准确性

#### set_clock_uncertainty - 设置时钟不确定性

定义时钟的不确定性，包括抖动和偏差。

```tcl
set_clock_uncertainty -setup 0.5 [get_clocks clk]
set_clock_uncertainty -hold 0.3 [get_clocks clk]
```

**参数说明：**
- `-setup`：建立时间不确定性
- `-hold`：保持时间不确定性
- 值为纳秒

**PostCTS 调整：**
- PreCTS：包含时钟偏差和抖动
- PostCTS：仅包含抖动（因为实际偏差已知）

#### set_clock_latency - 设置时钟延迟

定义时钟源到时钟端口的延迟。

```tcl
set_clock_latency -source 2.0 [get_clocks clk]
set_clock_latency 1.5 [get_clocks clk]
```

**参数说明：**
- `-source`：源端延迟（从时钟源到芯片边界）
- 无 `-source`：网络延迟（从芯片边界到时钟端口）

**PostCTS 调整：**
- 可能需要调整 IO 约束以防止 IO 路径成为关键路径
- 使用 `update_io_latency` 命令调整

### 输入/输出延迟约束

#### set_input_delay - 设置输入延迟

定义外部逻辑到芯片输入端口的延迟。

```tcl
set_input_delay -clock clk -max 2.0 [get_ports data_in]
set_input_delay -clock clk -min 0.5 [get_ports data_in]
```

**参数说明：**
- `-clock`：参考时钟
- `-max`：最大输入延迟（建立时间检查）
- `-min`：最小输入延迟（保持时间检查）
- 值为纳秒

**常用选项：**
- `-add`：添加多个约束
- `-relative_to`：相对于时钟的特定边沿

#### set_output_delay - 设置输出延迟

定义芯片输出端口到外部逻辑的延迟。

```tcl
set_output_delay -clock clk -max 1.5 [get_ports data_out]
set_output_delay -clock clk -min 0.2 [get_ports data_out]
```

**参数说明：**
- `-clock`：参考时钟
- `-max`：最大输出延迟（建立时间检查）
- `-min`：最小输出延迟（保持时间检查）

**常用选项：**
- `-add`：添加多个约束
- `-relative_to`：相对于时钟的特定边沿

### 时钟域交叉

#### set_clock_groups - 定义时钟组

指定不相关的时钟组，禁止跨时钟域的时序检查。

```tcl
set_clock_groups -asynchronous -group [get_clocks clk1] -group [get_clocks clk2]
set_clock_groups -logically_exclusive -group [get_clocks clk_a] -group [get_clocks clk_b]
```

**参数说明：**
- `-asynchronous`：完全异步的时钟组
- `-logically_exclusive`：逻辑互斥的时钟组
- `-physically_exclusive`：物理互斥的时钟组

### 路径例外

#### set_false_path - 设置假路径

禁止对特定路径的时序检查。

```tcl
set_false_path -from [get_ports reset] -to [get_pins */D]
set_false_path -from [get_clocks clk1] -to [get_clocks clk2]
```

**用途：**
- 异步复位路径
- 不相关的时钟域
- 测试模式路径

#### set_multicycle_path - 设置多周期路径

允许路径跨越多个时钟周期。

```tcl
set_multicycle_path -setup 2 -from [get_pins src_reg/Q] -to [get_pins dst_reg/D]
set_multicycle_path -hold 1 -from [get_pins src_reg/Q] -to [get_pins dst_reg/D]
```

**参数说明：**
- `-setup`：建立时间周期数
- `-hold`：保持时间周期数
- 默认值为 1

## MMMC 配置和约束模式管理

### MMMC 概述

MMMC 是一个分层配置系统，用于管理多个工作模式和工艺角的组合分析。

**层级结构：**
1. **库集（Library Set）** - 库文件组合
2. **延迟计算角（Delay Calculation Corner）** - 工艺角和操作条件
3. **约束模式（Constraint Mode）** - 时序约束集合
4. **分析视图（Analysis View）** - 延迟角 + 约束模式的组合

### 库集配置

#### create_library_set - 创建库集

```tcl
create_library_set -name lib_set_ss \
  -timing [list lib_ss.lib] \
  -si [list lib_ss_si.cdb]
```

**参数说明：**
- `-name`：库集名称
- `-timing`：时序库文件列表
- `-si`：信号完整性库文件列表

**最佳实践：**
- 为每个工艺角创建独立的库集
- 保持时序库和 SI 库同步

### 延迟计算角配置

#### create_rc_corner - 创建 RC 角

定义 RC 提取数据和工艺角。

```tcl
create_rc_corner -name rc_corner_typical \
  -preRoute_cap 1.0 \
  -preRoute_res 1.0 \
  -postRoute_cap 1.0 \
  -postRoute_res 1.0
```

**参数说明：**
- `-preRoute_cap/res`：布线前的电容/电阻缩放因子
- `-postRoute_cap/res`：布线后的电容/电阻缩放因子
- `-postRoute_clkcap`：时钟网络的布线后电容

#### create_delay_corner - 创建延迟角

```tcl
create_delay_corner -name delay_corner_ss \
  -library_set lib_set_ss \
  -rc_corner rc_corner_ss \
  -operating_condition ss_1p08v_125c
```

**参数说明：**
- `-library_set`：关联的库集
- `-rc_corner`：关联的 RC 角
- `-operating_condition`：工作条件（温度、电压）

### 约束模式配置

#### create_constraint_mode - 创建约束模式

```tcl
create_constraint_mode -name constraint_mode_func \
  -sdc_files [list constraints_func.sdc]
```

**参数说明：**
- `-name`：约束模式名称
- `-sdc_files`：SDC 约束文件列表

**多个约束文件：**
```tcl
create_constraint_mode -name constraint_mode_all \
  -sdc_files [list base.sdc clocks.sdc io.sdc]
```

### 分析视图配置

#### create_analysis_view - 创建分析视图

```tcl
create_analysis_view -name view_ss_func \
  -delay_corner delay_corner_ss \
  -constraint_mode constraint_mode_func
```

**参数说明：**
- `-name`：分析视图名称
- `-delay_corner`：延迟计算角
- `-constraint_mode`：约束模式

**完整示例：**
```tcl
# 创建多个分析视图
create_analysis_view -name view_ff_func \
  -delay_corner delay_corner_ff \
  -constraint_mode constraint_mode_func

create_analysis_view -name view_ss_func \
  -delay_corner delay_corner_ss \
  -constraint_mode constraint_mode_func

create_analysis_view -name view_tt_func \
  -delay_corner delay_corner_tt \
  -constraint_mode constraint_mode_func
```

### 设置活跃分析视图

#### set_analysis_view - 设置活跃视图

```tcl
set_analysis_view -setup [list view_ff_func view_ss_func] \
                  -hold [list view_ff_func view_ss_func]
```

**参数说明：**
- `-setup`：建立时间检查的活跃视图列表
- `-hold`：保持时间检查的活跃视图列表

## PostCTS 约束调整

### PostCTS 时序约束更新

在时钟树综合后，需要调整约束以反映实际的时钟树延迟。

**关键步骤：**

1. **设置传播时钟**
```tcl
set_propagated_clock [all_clocks]
```

2. **调整时钟不确定性**
```tcl
# 仅保留抖动，移除偏差
set_clock_uncertainty -setup 0.2 [get_clocks clk]
set_clock_uncertainty -hold 0.1 [get_clocks clk]
```

3. **移除或修改无效约束**
```tcl
# 移除 PreCTS 的时钟延迟约束
remove_clock_latency [get_clocks clk]

# 调整 IO 延迟以防止 IO 路径成为关键路径
update_io_latency -source_latency 1.0 [get_clocks clk]
```

4. **调整去耦因子**
```tcl
# 信号网络使用布线后的去耦因子
create_rc_corner -name rc_corner_postCTS \
  -postRoute_cap 1.0 \
  -postRoute_res 1.0

# 时钟网络可能使用不同的去耦因子
create_rc_corner -name rc_corner_postCTS_clk \
  -postRoute_clkcap 1.0 \
  -postRoute_cap 1.0
```

5. **运行时序分析**
```tcl
timeDesign -postCTS -outDir postctsTimingReports
```

## 物理约束语法

### Floorplan 约束

#### set_fp_placement_strategy - 设置 Floorplan 放置策略

```tcl
set_fp_placement_strategy -strategy balanced
```

#### create_fp_placement - 创建 Floorplan 放置

```tcl
create_fp_placement -name placement_core \
  -type core \
  -area {0 0 1000 1000}
```

### Placement 约束

#### set_placement_density - 设置放置密度

```tcl
set_placement_density -target 0.7
```

#### create_placement_blockage - 创建放置阻挡

```tcl
create_placement_blockage -type hard \
  -area {100 100 200 200}
```

### Routing 约束

#### set_route_width - 设置布线宽度

```tcl
set_route_width -layer metal1 -width 0.5
```

#### create_route_blockage - 创建布线阻挡

```tcl
create_route_blockage -type hard \
  -layer metal2 \
  -area {50 50 150 150}
```

## 约束验证和调试

### 检查约束

#### check_timing - 检查时序约束

```tcl
check_timing
```

**检查项目：**
- 时钟定义完整性
- 输入/输出延迟定义
- 时钟不确定性设置
- 路径例外定义

#### report_timing - 生成时序报告

```tcl
report_timing -max_paths 10 -nworst 5 -setup
report_timing -max_paths 10 -nworst 5 -hold
```

**常用选项：**
- `-setup`：建立时间检查
- `-hold`：保持时间检查
- `-max_paths`：报告的最大路径数
- `-nworst`：每个端点的最坏路径数

### 约束调试

#### report_clock - 生成时钟报告

```tcl
report_clock -attributes
report_clock [get_clocks clk]
```

#### report_constraint_mode - 生成约束模式报告

```tcl
report_constraint_mode
report_constraint_mode [get_constraint_modes constraint_mode_func]
```

#### report_analysis_view - 生成分析视图报告

```tcl
report_analysis_view
report_analysis_view [get_analysis_views view_ss_func]
```

## 约束文件准备

### 从 DC/PT 导出约束

#### write_script - 导出约束脚本

```tcl
# 在 dc_shell 或 pt_shell 中执行
write_script -format ptsh -output constraints.sdc
```

#### write_sdc - 导出 SDC 文件

```tcl
# 在 Genus 中执行
write_sdc
```

**最佳实践：**
- 使用 `write_script` 或 `write_sdc` 避免变量替换混淆
- 一个会话中只读取一种格式的约束
- 不需要在 Innovus 中翻译 DC 约束

### 约束文件组织

**推荐结构：**
```
constraints/
├── base.sdc              # 基础约束（库、工艺角）
├── clocks.sdc            # 时钟定义
├── io.sdc                # 输入/输出延迟
├── exceptions.sdc        # 路径例外
├── modes/
│   ├── func.sdc          # 功能模式
│   ├── test.sdc          # 测试模式
│   └── low_power.sdc     # 低功耗模式
└── corners/
    ├── ss.sdc            # 慢速角
    ├── ff.sdc            # 快速角
    └── tt.sdc            # 典型角
```

## 常见约束场景

### 异步复位处理

```tcl
# 定义异步复位为假路径
set_false_path -from [get_ports reset_n] -to [get_pins */D]

# 或使用多周期路径
set_multicycle_path -setup 0 -from [get_ports reset_n] -to [get_pins */D]
```

### 时钟域交叉（CDC）

```tcl
# 定义异步时钟组
set_clock_groups -asynchronous \
  -group [get_clocks clk1] \
  -group [get_clocks clk2]

# 同步器路径通常需要特殊处理
set_multicycle_path -setup 2 -from [get_pins sync_ff1/Q] -to [get_pins sync_ff2/D]
set_multicycle_path -hold 1 -from [get_pins sync_ff1/Q] -to [get_pins sync_ff2/D]
```

### 测试模式约束

```tcl
# 创建测试模式约束
create_constraint_mode -name constraint_mode_test \
  -sdc_files [list test_constraints.sdc]

# 在测试模式中禁用某些检查
set_false_path -from [get_ports scan_in] -to [get_pins */D]
```

### 低功耗模式约束

```tcl
# 创建低功耗模式约束
create_constraint_mode -name constraint_mode_lp \
  -sdc_files [list lp_constraints.sdc]

# 可能需要放宽某些约束
set_clock_uncertainty -setup 0.8 [get_clocks clk_lp]
```

## 参考命令

### 约束查询命令

```tcl
# 查询所有时钟
get_clocks

# 查询特定时钟属性
get_attribute [get_clocks clk] period

# 查询所有约束模式
get_constraint_modes

# 查询所有分析视图
get_analysis_views

# 查询所有延迟角
get_delay_corners
```

### 约束修改命令

```tcl
# 更新约束模式
update_constraint_mode -name constraint_mode_func \
  -sdc_files [list new_constraints.sdc]

# 删除约束模式
remove_constraint_mode constraint_mode_old

# 更新 IO 延迟
update_io_latency -source_latency 1.5 [get_clocks clk]
```

## 最佳实践

1. **约束分离** - 将不同类型的约束分离到不同的文件中
2. **版本控制** - 使用版本控制系统管理约束文件
3. **文档化** - 为复杂的约束添加注释说明
4. **验证** - 使用 `check_timing` 验证约束完整性
5. **迭代** - 根据时序分析结果迭代调整约束
6. **PostCTS 调整** - 在 CTS 后及时更新约束
7. **多角分析** - 使用 MMMC 进行全面的多角分析
8. **文档保存** - 保存时序报告用于设计审查和追溯

