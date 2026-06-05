---
source: knowledge/Innovus/legacy/jsonl/innovusUG__211.jsonl | entries: [91, 334, 335, 338, 351, 352, 353, 354, 355, 426]
---

# 布局概念

## 布局器基础

### GigaPlace 概述

GigaPlace 是 Innovus 的高级布局引擎，采用并发宏和标准单元布局策略。

**核心特性：**
- 并发布局宏和标准单元，由拥塞度、线长和时序驱动
- 减少手动工作量，加快设计周期
- 相比传统流程提供更好或相当的 QoR（质量）

**关键优势：**
- 改进的宏布局周期时间（TAT）
- 线长减少
- 功耗改进
- 拥塞度降低

**主要命令：**
- `place_opt_design` - 替代旧的 `place_design + optDesign –preCTS` 流程
- `place_opt_design –incremental` - 增量时序优化

### Mixed Placer 概述

Mixed Placer 是集成的布局和规划流程，在传统流程中将规划阶段与布局阶段合并。

**适用设计：**
- 宏数量多的设计
- 矩形设计形状
- 宏面积与总面积比例 < 60%

**流程优势：**
- 减少手动迭代
- 更快的 TAT
- 更好的 QoR 收敛

**使用模式：**

1. **带参考规划开始** - 提取电源布线密度文件用于拥塞和线长建模
2. **不带参考规划开始** - 需要手动推送宏到核心并创建电源条纹进行密度建模
3. **规划清理** - 移除所有规划对象、布线阻挡、布局阻挡等
4. **设置约束** - 使用 `set_macro_place_constraint` 命令
5. **并发布局** - 使用 `place_design –concurrent_macros`
6. **合法化** - 使用 `refine_macro_place` 命令

**关键命令：**
- `create_pg_model_for_macro_place` - 为并发宏布局创建 PG 模型
- `place_design –concurrent_macros` - 并发时序驱动布局
- `refine_macro_place` - 合法化宏以满足约束和规则

---

## 宏布局约束

### 宏方向约束

限制宏的旋转方向（R0、R90、R180、R270）。

**用途：**
- 控制宏的物理方向
- 影响功率分布和信号完整性
- 支持特定的设计拓扑

**支持情况：**
- `place_design -concurrent_macros` - 支持
- `refine_macro_place` - 不支持
- `check_macro_place_constraint` - 支持检查

### 最大堆叠长度

限制宏在特定方向上的连续堆叠长度。

**用途：**
- 防止过长的宏堆叠
- 改进布局可布线性
- 控制设计的物理特性

**支持情况：**
- `place_design -concurrent_macros` - 不支持
- `refine_macro_place` - 支持
- `check_macro_place_constraint` - 支持检查

### 固定宏位置

将宏固定在特定位置，防止在布局过程中移动。

**用途：**
- 预先放置关键宏
- 保持已知的良好布局
- 减少布局搜索空间

**建议：**
- 大宏对规划可行性有重大影响
- 建议手动预放置大宏并设置 FIXED 属性

**支持情况：**
- `place_design -concurrent_macros` - 支持
- `refine_macro_place` - 支持
- `check_macro_place_constraint` - 不支持

### I/O 引脚禁区

定义 I/O 引脚周围的禁止布局区域。

**用途：**
- 保护 I/O 引脚连接区域
- 防止标准单元干扰 I/O 布线
- 改进信号完整性

**支持情况：**
- `place_design -concurrent_macros` - 支持
- `refine_macro_place` - 支持
- `check_macro_place_constraint` - 不支持

### 宏布局光晕（Halo）

在宏周围创建保护区域，防止标准单元和其他块放置。

**用途：**
- 为物理单元预留空间（EndCap、WellTap、PSW）
- 减少拥塞度
- 改进布局质量

**配置示例：**
```tcl
# 增加光晕以预留物理单元空间
addHaloToBlock -allBlock {2 2 2 2}

# 布局后重置为标准光晕
addHaloToBlock -allBlock {1 1 1 1}

# 为特定单元设置不对称光晕
addHaloToBlock {10.0 20.0 40.0 30.0} –cell {ram1 ram2} –ori R0
```

**支持情况：**
- `place_design -concurrent_macros` - 支持
- `refine_macro_place` - 支持
- `check_macro_place_constraint` - 支持检查重叠

---

## 布局阻挡和指导

### 布局阻挡概述

使用布局阻挡来指导布局过程，控制单元放置区域。

**创建命令：**
```tcl
createPlaceBlockage
```

**阻挡类型：**

| 类型 | 说明 |
|------|------|
| **Hard** | 区域不能用于放置块或单元（默认） |
| **Soft** | 布局期间不能使用，但可在优化、CTS、ECO 或合法化期间使用 |
| **Partial** | 允许指定百分比的布局密度（如 75% 表示最多 75% 的布局密度） |
| **Macro-Only** | 不能放置块，但可放置标准单元 |

### 布局阻挡属性

通过属性编辑器为阻挡分配属性。

**常见用途：**
- 预留布线通道
- 控制拥塞热点
- 保护关键区域

### 自动通道阻挡

在硬块之间的小通道中自动添加软布局阻挡。

**启用方式：**
```tcl
setPlaceMode -place_global_auto_blockage_in_channel true
```

**优势：**
- 改进布局可布线性
- 不影响优化操作中的单元放置
- 有助于改进时序和可布线性

### 拥塞修复

使用 `congRepair` 命令缓解拥塞。

**特点：**
- 使用全局布线 + 增量布局
- 可能对时序有负面影响
- 需要谨慎使用

**建议：**
- 通常需要额外的 `optDesign` 调用
- 可能不会收敛
- 作为最后手段使用

---

## Mixed Place 约束支持矩阵

| 约束类型 | place_design -concurrent_macros | refine_macro_place | check_macro_place_constraint |
|---------|--------------------------------|-------------------|------------------------------|
| 宏数组约束 | Yes | Yes | No |
| 组约束（align_group） | Yes | No | No |
| 组约束（softGuide） | Yes | No | No |
| 指导/区域/栅栏 | Yes | Yes | Check Region/Fence |
| 间距约束 | No | Yes | Yes |
| 宏方向约束 | Yes | No | Yes |
| 宏上电源布线建模 | Yes | No | No |
| 最大堆叠长度 | No | Yes | Yes |
| 固定位置 | Yes | Yes | No |
| I/O 引脚禁区 | Yes | Yes | No |
| 宏布局光晕 | Yes | Yes | Check overlap |

---

## 布局流程最佳实践

### 布局前检查

- 运行 `checkDesign -all` 检查库和设计数据完整性
- 运行 `timeDesign -prePlace` 获取零线负载时序基线
- 创建布局阻挡（通常在规划期间完成）
- 检查预放置单元和块的违规

### 拥塞分析

- 检查日志文件中的溢出值（通常应 < 1%）
- 打开拥塞图分析热点
- 使用部分布局阻挡减少指定区域的密度
- 考虑时钟布线约束的影响

### 时序优化指导

- 定义路径组以聚焦优化
- 使用 `setOptMode -setupTargetSlack` 调整目标松弛
- 使用 `setOptMode -drcMargin` 控制 DRV 修复
- 启用自适应面积回收控制利用率

