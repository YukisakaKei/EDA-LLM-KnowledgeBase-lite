---
source: knowledge/Innovus/legacy/jsonl/innovusUG__211.jsonl | entries: [21, 69, 72, 445, 1058]
---

# 多 CPU 处理

## 概述

Innovus 支持多 CPU 处理以加速设计流程。通过并行处理，可以显著缩短 Placement、Routing、RC 提取等耗时操作的执行时间。多 CPU 处理支持本地多核和分布式远程处理两种模式。

---

## 多 CPU 许可证管理

### 多 CPU 矩阵

多 CPU 矩阵定义了每个基础许可证和附加许可证启用的 CPU 数量：

- **第一列** — 基础产品名称（缩写格式）
- **第二列** — 基础产品编号
- **第三列** — 基础产品启用的 CPU 数量
- **顶行** — 可用作多 CPU 许可证的产品名称（缩写格式）
- **第二行** — 产品编号
- **第 4 列及后续列** — 每个多 CPU 许可证启用的额外 CPU 数量

### 许可证限制

- 产品选项许可证不能用作基础许可证或多 CPU 许可证
- 如果请求的 CPU 数超过可用数量，软件会发出警告并使用可用的 CPU 数运行

### 查询多 CPU 许可证

使用 `getMultiCpuUsage` 命令查询当前许可证配置：

```tcl
getMultiCpuUsage
```

输出示例：
```
Total CPU(s) Enabled: 2
Current License(s): 1
Encounter_Digital_Impl_Sys_XL
keepLicense: true
licenseList: enccpu edsl edsxl
```

### 限制许可证搜索范围

每个基础许可证允许使用特定的许可证集合进行多 CPU 处理。可以使用 `setMultiCpuUsage -licenseList` 命令自定义许可证列表：

```tcl
setMultiCpuUsage -licenseList {enccpu edsl edsxl}
```

---

## 多 CPU 配置

### 本地多 CPU 模式

在单台机器上使用多个本地 CPU：

```tcl
setDistributeHost -local
setMultiCpuUsage -localCpu <num_cpus>
```

**示例：使用 4 个本地 CPU**

```tcl
setDistributeHost -local
setMultiCpuUsage -localCpu 4
```

### 分布式多 CPU 模式

在多台远程主机上分布式处理：

```tcl
setDistributeHost -rsh -add {host1 host2 host3}
setMultiCpuUsage -remoteHost <num_cpus>
```

**示例：在 3 台远程主机上分布式处理**

```tcl
setDistributeHost -rsh -add {host1 host2 host3}
setMultiCpuUsage -remoteHost 3
```

### 保持许可证

使用 `-keepLicense` 选项在多 CPU 处理期间保持许可证：

```tcl
setMultiCpuUsage -keepLicense true
```

---

## Placement 多 CPU 模式

### 基本流程

Placement 是设计流程中耗时最长的阶段之一。多 CPU 模式可以显著加速 Placement：

```tcl
# 配置多 CPU 环境
setDistributeHost -local
setMultiCpuUsage -localCpu 4

# 执行 Placement
placeDesign
```

### Placement 前准备

在执行 Placement 前，运行以下命令检查设计完整性：

```tcl
# 检查设计和库数据完整性
checkDesign

# 获取零线负载时序基线
timeDesign -prePlace

# 创建放置阻挡
createPlaceBlockage

# 检查放置违规
checkPlace
```

### Placement 多 CPU 优化

```tcl
# 配置本地多 CPU（推荐 4-8 个 CPU）
setDistributeHost -local
setMultiCpuUsage -localCpu 8

# 执行 Placement
placeDesign

# 验证结果
checkPlace
```

---

## RC 提取多 CPU 模式

### 电容表生成

#### 本地模式

在本地机器上使用多 CPU 生成电容表：

```tcl
setDistributeHost -local
setMultiCpuUsage -localCpu 3
generateCapTbl -ict sample.ict -output sample.capTbl
```

#### 分布式模式

在多台远程主机上分布式生成电容表：

```tcl
setDistributeHost -rsh -add {host1 host2 host3}
setMultiCpuUsage -remoteHost
generateCapTbl -ict sample.ict -output sample.capTbl
```

### IQuantus/TQuantus 提取

#### 本地模式

```tcl
setDistributeHost -local
setMultiCpuUsage -localCpu 3
setExtractRCMode -engine postRoute -effortLevel medium
extractRC
```

#### 分布式模式

```tcl
setDistributeHost -rsh -add {host1 host2 host3}
setMultiCpuUsage -remoteHost 3
setExtractRCMode -engine postRoute -effortLevel medium
extractRC
```

### 提取努力级别

- **medium** — 平衡精度和速度
- **high** — 更高精度，处理时间更长
- **signoff** — 最高精度，用于 Signoff 级别提取

---

## 多 CPU 性能优化

### CPU 数量选择

| 场景 | 推荐 CPU 数 | 说明 |
|---|---|---|
| Placement | 4-8 | 取决于设计规模和机器配置 |
| Routing | 2-4 | Routing 并行化效果不如 Placement |
| RC 提取 | 3-8 | 取决于网络数量和复杂度 |
| 电容表生成 | 4-8 | 高度并行化任务 |

### 性能调优建议

1. **监控系统资源** — 确保有足够的内存和 I/O 带宽
2. **避免过度订阅** — CPU 数不应超过物理核心数
3. **使用本地模式优先** — 本地多 CPU 比分布式模式更高效
4. **分布式模式配置** — 确保网络连接稳定，主机间延迟低
5. **许可证管理** — 监控许可证使用情况，避免许可证冲突

### 常见问题排查

**问题：多 CPU 模式下性能未改善**

- 检查许可证配置：`getMultiCpuUsage`
- 验证 CPU 数量是否正确设置
- 检查系统资源是否充足
- 考虑设计规模是否足够大以充分利用多 CPU

**问题：分布式模式连接失败**

- 验证远程主机可达性
- 检查 RSH 或 SSH 配置
- 确保远程主机上安装了 Innovus
- 检查许可证服务器配置

---

## 多 CPU 命令速查

| 命令 | 功能 |
|---|---|
| `getMultiCpuUsage` | 查询当前多 CPU 配置和许可证 |
| `setMultiCpuUsage` | 配置多 CPU 参数 |
| `setMultiCpuUsage -localCpu <n>` | 设置本地 CPU 数量 |
| `setMultiCpuUsage -remoteHost` | 启用分布式模式 |
| `setMultiCpuUsage -licenseList` | 限制许可证搜索范围 |
| `setDistributeHost -local` | 配置本地多 CPU 模式 |
| `setDistributeHost -rsh -add` | 配置分布式模式主机列表 |
| `placeDesign` | 执行 Placement（支持多 CPU） |
| `generateCapTbl` | 生成电容表（支持多 CPU） |
| `extractRC` | 执行 RC 提取（支持多 CPU） |

---

## 典型工作流示例

### 本地多 CPU 完整流程

```tcl
# 1. 配置本地多 CPU（4 个 CPU）
setDistributeHost -local
setMultiCpuUsage -localCpu 4

# 2. 加载设计
restoreDesign design.enc

# 3. 检查设计
checkDesign

# 4. 执行 Placement（多 CPU 加速）
placeDesign

# 5. 执行 CTS
clockDesign

# 6. 执行 Routing
routeDesign

# 7. 执行 RC 提取（多 CPU 加速）
setExtractRCMode -engine postRoute -effortLevel medium
extractRC

# 8. 保存设计
saveDesign design_final.enc
```

### 分布式多 CPU 完整流程

```tcl
# 1. 配置分布式多 CPU（3 台主机）
setDistributeHost -rsh -add {host1 host2 host3}
setMultiCpuUsage -remoteHost 3

# 2. 加载设计
restoreDesign design.enc

# 3. 执行 Placement（分布式加速）
placeDesign

# 4. 执行 Routing
routeDesign

# 5. 执行 RC 提取（分布式加速）
setExtractRCMode -engine postRoute -effortLevel high
extractRC

# 6. 保存设计
saveDesign design_final.enc
```
