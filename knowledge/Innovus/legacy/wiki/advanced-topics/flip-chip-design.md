---
source: knowledge/Innovus/legacy/json/innovusUG__211 | chapters: [0725, 0731, 0732, 0733, 0734, 0735, 0740, 0741, 0742, 0743]
---

# Flip Chip Design

## 概述

Flip Chip 是一种将 I/O bump 和驱动单元放置在芯片整个区域的方法论，支持边界（Peripheral I/O）或核心（Area I/O）配置。Innovus 处理 bump 阵列、I/O 驱动、ESD 单元和布线信息。功率、地和信号分配在 bump 放置后进行。

**注意**：Flip Chip 有时在 Innovus 文档中称为 Area I/O 放置，Area I/O 是 Flip Chip 的子集。

### 相关工具

- **Allegro® Package Designer (APD)**：用于包设计和 bump 可布线性验证
- **Allegro® SiP Digital Layout**：SiP 设计工具
- 需要单独许可证运行 APD

---

## Flip Chip 设计流程

### 总体流程

Flip Chip 设计包含以下主要阶段：

1. **Floorplan 规划** — 定义 die 尺寸、I/O pad 位置、bump 位置
2. **Bump 创建** — 使用 `create_bump` 命令生成 bump 阵列
3. **Bump 分配** — 将信号、功率、地分配到 bump
4. **电源规划** — 创建电源环和条纹
5. **RDL 布线** — 建立 bump 到 I/O 单元的连接
6. **标准流程** — 后续的 placement、routing、timing 等

### 前置条件

使用 Flip Chip 前需要准备：

- Bump 参数数据（尺寸、间距、材料）
- I/O pad 规格和位置
- 功率/地分配策略
- RDL 层定义和约束

---

## Flip Chip 实现方法论

### SiP Bump Flow

用于 System-in-Package 设计。详见 System-in-Package Flow Guide。

**数据大小优化**：使用 `defOut -noCoreCells` 减少导出数据量，用于 SiP 导入。

```tcl
defOut -noCoreCells
```

**包布线可行性验证**：使用 APD/SiP 工具检查 bump 到包的可布线性。

### Area I/O Flow (AIO)

I/O PAD 放置在核心区域，支持更灵活的布线。

**优点**：
- 布线约束少，拥塞问题少
- Bump 可靠近 I/O pad，缩短网长
- 信号完整性效果好

**缺点**：
- I/O pad 放置影响标准单元放置和时序
- 功率布线更复杂，需要专用电源条纹

**AIO 设计步骤**：

1. 加载带 I/O pad 放置的 floorplan
2. 定义 bump（使用 `create_bump` 或 Create Bump Array 表单）
3. 分配信号、功率、地到 bump
   - 使用 Flip Chip 表单的 Bump Assignment 标签
   - 信号 bump：蓝色方块
   - 功率 bump：红色方块
   - 地 bump：黄色方块
4. 创建电源环和条纹
   - 使用 Add Rings 表单在核心周围和 P/G bump 周围创建环
   - 使用 Add Stripes 表单创建连接到 P/G bump 的条纹
5. 连接功率（从 bump 到 I/O 单元或环/条纹）
   - 使用 Flip Chip 表单的 RDL Routing 标签

**分层 AIO Flow**：使用 `fcroute` 命令将 bump 布线到 I/O 驱动单元，然后使用 `handlePtnAreaIo -insertBuffer` 推送数据到下层。

### Peripheral I/O Flow (PIO)

I/O PAD 放置在芯片边界，bump 通过 RDL 连接。

**特点**：
- 不影响默认的 timing/area/power/DFM-DFY 流程
- 建议在 floorplan 阶段完成 bump 位置、分配和 RDL 布线
- 可在设计闭合后作为后处理步骤

**PIO 流程步骤**：

1. 初始 floorplan（设置 die、放置 I/O 驱动单元）
2. RDL 实现
   - Bump 放置和分配
   - I/O 驱动单元放置优化
   - RDL 布线
3. 将 bump 分配传递给 APD 进行包设计
4. RDL 布线设计准备进行功率规划/Quantus/placement/routing
5. 使用 `extractRC` 提取初始寄生参数，或导出 GDSII 到 Assura RCX 进行精确提取

---

## Bump 创建和分配

### Bump 创建

Bump 通常以固定间距的规则图案创建。`create_bump` 命令支持以下图案：

```tcl
create_bump -pattern_full_chip          # 全芯片覆盖
create_bump -pattern_side {side width}  # 边界图案
create_bump -pattern_array {row col}    # 阵列图案
create_bump -pattern_ring width         # 环形图案
create_bump -pattern_center {row col}   # 中心图案
```

**注意**：不同的 bump 图案可在同一 floorplan 中共存。

**重叠处理**：
- 默认情况下，工具在 bump 几何重叠时发出警告并不创建 bump
- 使用 `-allow_overlap_control` 选项允许重叠创建
- 使用 `deleteBumps -overlap_blockages` 或 `-overlap_macro` 清理 bump 放置

**Bump 位置类型**：`create_bump` 支持四种位置类型：

1. Bump 单元中心
2. Bump 单元左下角：`dbGet [dbGet top.bumps.name $Bump_name -p].pt`
3. Bump 几何中心：`dbGet top.bumps.bump_shape_center`
4. Bump 几何左下角：`dbGet top.bumps.bump_shape_bbox`

**相对位置创建**：使用 `-relative_type` 参数相对于现有对象创建 bump（embedded bump、inst_pin_port、block）。

**基于 Block Pin 创建**：
- 使用 `-relative_block` 指定 block 列表
- 使用 `-relative_block_constraint` 指定约束文件
- 约束格式：`BUMP_ON_BLOCK_PIN`、`MACRO`、`PIN`、`PORT`、`GEOMETRY_SHAPE`

**Undo/Redo 支持**：Bump 放置支持撤销/重做操作，恢复 name、location、port properties、fixed status、placement status。

### Bump 分配

Bump 分配是将信号、功率、地分配到已创建的 bump。

**手动优化**：
- 使用 `swapSignal` 命令进行小规模 ECO
- 使用 Flip Chip 表单的 Assignment Opt 标签

**分配约束**：支持以下约束类型：

1. **SHARE_FIND_PORT**：过滤不必要的端口
   ```
   SHARE_FIND_PORT
   PIN pin_name_list
   MACRO macro_name_list
   LAYERS top_layer [:bottom_layer]
   GEOMETRY_SHORT_EDGE min_value [:max_value]
   GEOMETRY_LONG_EDGE min_value [:max_value]
   net_name_list
   END SHARE_FIND_PORT
   ```
   - 需指定网名和至少一个参数（LAYERS、GEOMETRY_SHORT_EDGE、GEOMETRY_LONG_EDGE）
   - LEF 文件中的 CLASS BUMP 属性优先级更高

2. **ASSIGN_ANALOG_PG_NETS**：指定模拟 P/G 网

3. **SHARE_IGNORE_* / ASSIGN_IGNORE_***：排除实例、宏、引脚或网

4. **ASSIGN_PAD2BUMP_RATIO**：指定每个网、宏或实例的 pad 到 bump 比率

---

## Bump 分配优化

### 手动优化

对已分配的 bump 进行小规模 ECO：

```tcl
swapSignal bump1 bump2  # 交换两个 bump 的信号分配
```

使用 Flip Chip 表单的 Assignment Opt 标签进行交互式优化。

### 约束优化

通过约束文件自动优化 bump 分配，支持过滤、忽略和比率控制。

---

## Flip Chip Flightlines 查看

Flightlines 用于可视化 bump、I/O pad 和内部网的连接关系。

### viewBumpConnection 命令

```tcl
viewBumpConnection                      # 显示所有 flightlines
viewBumpConnection -bump {bump_list}    # 显示指定 bump 的连接
viewBumpConnection -io_inst {io_list}   # 显示指定 I/O 实例的连接
viewBumpConnection -net {net_list}      # 显示指定网的连接
viewBumpConnection -selected            # 显示选中对象的连接
viewBumpConnection -honor_color         # 按 bump 类型或网着色
```

### 自动重绘

Flightlines 在以下操作后自动重绘：

- `swapSignal`：交换的 bump flightlines 更新
- `unassignBump`：移除指定 bump 的 flightlines
- Bump/I/O pad/block 移动：重绘反映新位置

### 选择高亮

- 选中 bump 或 I/O pad：对应 flightline 加粗显示
- 选中多个对象：所有 flightlines 加粗显示
- 选中带多个 I/O pin 的 block：所有 flightlines 加粗显示
- 取消选中：flightlines 恢复正常

### 着色方案

**按 Bump 类型着色**（默认）：
- 蓝色：信号 bump
- 红色：功率 bump
- 黄色：地 bump

**按网着色**：
1. 创建 bump 颜色映射文件（格式：`net_name color_name`）
2. 使用 `ciopLoadBumpColorMapFile` 加载文件
3. 运行 `viewBumpConnection -honor_color`

### DIFFPAIR 高亮

Flightlines 遵守 flip chip 布线约束文件中的 DIFFPAIR 约束。选中 DIFFPAIR 中的任一 bump 或 I/O pad，工具高亮显示该 DIFFPAIR 的所有 flightlines。

---

## Flip Chip 设计最佳实践

### 流程规划

1. **早期 Floorplan**：在设计早期完成 bump 位置、分配和 RDL 布线规划
2. **PIO 推荐**：对于 Peripheral I/O，建议在 floorplan 阶段完成，而非设计闭合后
3. **AIO 灵活性**：Area I/O 提供更多布线灵活性，但需要更仔细的功率规划

### Bump 管理

1. **验证重叠**：使用 `deleteBumps -overlap_blockages` 清理与布线阻挡的重叠
2. **DRC 检查**：Bump 需分配（提交）后 `verify_drc` 才能检查短路违规
3. **清理未分配 Bump**：设计实现后删除未分配的 bump 是常规做法

### 约束使用

1. **SHARE_FIND_PORT**：精确过滤端口，避免不必要的分配
2. **ASSIGN_IGNORE_***：排除特定实例或网，简化分配
3. **PAD2BUMP_RATIO**：控制 pad 到 bump 的比率，优化功率分配

### 可视化和调试

1. **Flightlines 验证**：使用 `viewBumpConnection` 验证 bump 连接正确性
2. **着色辅助**：使用 `-honor_color` 快速识别 bump 类型和网
3. **选择高亮**：利用选择高亮快速定位相关连接

### 与 SiP 集成

1. **数据优化**：使用 `defOut -noCoreCells` 减少 SiP 导入数据量
2. **可布线性验证**：在 APD 中验证 bump 到包的可布线性
3. **寄生提取**：使用 `extractRC` 或 Assura RCX 进行精确提取

---

## 常用命令速查

| 命令 | 功能 |
|------|------|
| `create_bump` | 创建 bump 阵列 |
| `deleteBumps` | 删除 bump |
| `swapSignal` | 交换 bump 信号分配 |
| `unassignBump` | 取消 bump 分配 |
| `viewBumpConnection` | 显示 flightlines |
| `fcroute` | RDL 布线 |
| `handlePtnAreaIo -insertBuffer` | 推送分层 AIO 数据 |
| `defOut -noCoreCells` | 导出 DEF（SiP 优化） |
| `extractRC` | 提取寄生参数 |
| `ciopLoadBumpColorMapFile` | 加载 bump 颜色映射 |

