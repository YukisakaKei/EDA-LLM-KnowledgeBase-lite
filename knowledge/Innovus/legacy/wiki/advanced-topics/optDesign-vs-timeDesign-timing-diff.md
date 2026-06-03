---
source: knowledge/Innovus/legacy/json/optDesign_vs_timeDesign
---

# optDesign -postRoute 与 timeDesign -postRoute 时序差异诊断

## 问题现象

`optDesign -postRoute` 完成时报告的时序，与后续在新 session 中跑 `timeDesign -postRoute` 的结果不一致。典型表现为：optDesign 结束时 WNS 为正（无违例），timeDesign 报告 WNS 为负（出现违例），且差异量级超过可接受范围。

## 四大原因

### 1. Mode 设置不一致

两个 session 的 `setDelayCalMode`、`setSIMode`、`setExtractRCMode` 等配置不同。

**排查**：在两个 session 中分别 `saveDesign`，diff 各自的 `<design>.mode` 和 `<design>.globals` 文件。

### 2. 加密的 Timing Correlation 设置丢失

加密 TCL 的设置不会保存在 `.mode` 文件中，新 session 恢复 design 后需手动重新 source。

### 3. 增量 vs. 全量 TQRC 提取（主因）

`optDesign -postRoute` 内部为加速运行使用 Incremental TQRC，而后续 `timeDesign` 可能触发 Full TQRC 重新提取。两种方式之间存在寄生参数差异，通常 <10ps，但特定设计下会放大。

TQRC 的三种提取方式：

| 方式 | 触发条件 |
|---|---|
| **Full** | design 进入 optDesign/timeDesign 时未处于已提取状态，或优化步骤对设计有较大改动 |
| **Incremental** | design 之前已提取，且优化步骤只有"较小"改动 |
| **None** | 优化步骤未对设计产生任何改动 |

**从 log 中辨别**：
```
Full:       "No TQRC parasitic data in encounter. Going for fullchip extraction."
Incremental: "Region and/or Nets changed is small. Going for incremental extraction."
None:       "No changed net or region found. No need to perform incremental extraction."
```

### 4. Multi-CPU 导致的微小差异

TQRC 使用的 CPU 数量不同会轻微影响提取结果（Ostrich 对比 8 CPU vs 1 CPU 的比例因子约为 1.001/0.999），通常不造成时序差异。如需消除此变量：`setMultiCpuUsage -localCpu 1`（以运行时间为代价）。

## 诊断流程

### 方法一：比较模式文件
```
# session 1 (optDesign)
encounter > optDesign -postRoute
encounter > saveDesign 1.enc
# 新 session
encounter > timeDesign -postRoute
encounter > saveDesign 2.enc
# shell
diff 1.enc.dat/<design>.mode 2.enc.dat/<design>.mode
diff 1.enc.dat/<design>.globals 2.enc.dat/<design>.globals
```

### 方法二：用 saveDesign -rc 隔离寄生差异

`saveDesign -rc` 将寄生数据包含在存档中，这样新 session 的 timeDesign 会使用与 optDesign 完成时相同的寄生数据。若时序仍不同，则问题根源不在 TQRC。

### 方法三：SPEF + Ostrich 对比

在 optDesign 和 timeDesign 后分别导出 SPEF，用 Ostrich 对比 TCAP（总电容）和 XCAP（耦合电容）。

## 解决方案

### Workaround 1：禁用弱驱动单元

弱驱动单元的延时对负载电容和 input slew 的微小变化极其敏感。在 critical/near-critical 路径中应避免使用。

```tcl
setOptMode -leakagePowerEffort none
optDesign -postRoute
setDontUse *D0* true            # 禁用特定弱驱动 cell
setOptMode -setupTargetSlack 0.2 # 留出 guardband
optLeakagePower
```

### Workaround 2：禁用增量 TQRC

```tcl
setExtractRCMode -incremental false
```

代价：optDesign -postRoute 运行时间增加约 20%，但可彻底消除增量/全量 TQRC 之间的时序差异。

### Workaround 3：限制单 CPU 运行

```tcl
setMultiCpuUsage -localCpu 1
```

仅在确认 Multi-CPU 是差异来源时使用，否则不推荐。

## 受影响设计的特征

- 标准单元库中有大量弱驱动单元（如 `*D0*` 等低驱动强度 cell）可用
- 设计时序较容易收敛（因此工具倾向于在 near-critical 路径上使用弱驱动 cell 以节省功耗）
- 每次优化修改量较小（允许连续多次走增量提取，而非触发全量提取）

## 关键命令速查

| 命令 | 用途 |
|---|---|
| `setExtractRCMode -incremental false` | 关闭增量 TQRC |
| `setDontUse *D0* true` | 禁用弱驱动单元 |
| `saveDesign -rc` | 存档时包含寄生数据 |
| `rcOut -rc_corner <name> -spef <name>.spef.gz` | 导出 SPEF 用于对比 |
| `setMultiCpuUsage -localCpu 1` | 限制为单 CPU |
| `report_timing -path_type full_clock` | 详细路径报告（用于检查弱驱动单元） |
