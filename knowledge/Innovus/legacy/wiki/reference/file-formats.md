---
source: knowledge/Innovus/legacy/jsonl/innovusUG__211.jsonl | entries: [79, 80, 155, 156, 157, 160, 162, 163, 164, 178, 179, 181, 186, 187, 188, 190, 219, 221, 222, 224, 248, 323, 627, 738, 1207]
---

# Innovus 文件格式参考

## 输入文件格式速查

### Verilog 网表
- **用途**：设计逻辑网表，定义电路连接关系
- **导入方式**：`File > Import Design` 或 `init_design` 命令
- **要求**：
  - 必须是门级网表（gate-level）
  - 设计必须唯一化（uniquified），以支持 CTS、Scan Reorder 和时序优化
  - 自动唯一化：设置 `init_design_uniquify` 全局变量为 1
- **特殊处理**：
  - Verilog assign 语句可被 Innovus 自动添加、删除或替换为缓冲器
  - 所有应用（GigaOpt、CTS、CCopt、Place、Route、Hierarchy/ILM Flow、MSV、ECO）原生支持 Verilog assign 网表

### LEF（Library Exchange Format）
- **用途**：定义工艺信息、标准单元库、物理库
- **内容**：
  - 工艺层定义（金属层、切割层）
  - 通孔（via）定义和生成规则
  - 标准单元宏（MACRO）定义
  - 设计规则（DRC）和互连 RC 数据
- **导入顺序**：必须先导入工艺 LEF，再导入标准单元 LEF 和块 LEF
- **版本支持**：支持 LEF 5.7 版本（部分语法不支持，见下文）
- **特殊格式**：
  - iPRT 格式可通过 `iprt2lef` 转换器转换为 LEF
  - 支持 RDL 层定义（用于 Flip Chip 设计）

### Liberty 库文件（.lib）
- **用途**：标准单元时序和功耗特性库
- **用途**：支持多个库文件定义不同工艺角或功率域
- **配置**：通过库集（Library Sets）管理多个库文件

### SDC（Synopsys Design Constraints）
- **用途**：时序约束文件
- **包含**：时钟定义、输入/输出延迟、时序例外等

### CPF（Common Power Format）
- **用途**：功率域和电源网络定义
- **配置**：通过 `init_cpf_file` 全局变量指定

### OpenAccess 设计
- **用途**：OpenAccess 数据库格式的设计
- **导入信息**：
  - 库（Library）
  - 单元（Cell）
  - 视图（View）
  - 参考库（Reference Libraries）
  - 抽象视图名称（Abstract View Names）
  - 布局视图名称（Layout View Names）

---

## 输出文件格式速查

### GDSII Stream 格式
- **用途**：流片前的最终物理设计文件
- **导出命令**：
  ```
  setStreamOutMode [options]
  streamOut <filename>
  ```
- **压缩**：支持 GZIP 压缩，文件名添加 `.gz` 后缀
- **合并**：支持多个 GDSII 文件合并
  ```
  streamOut -merge {file1 file2 ...} [-uniquifyCellNames]
  ```
- **版本**：合并时使用所有文件中的最高版本号
- **通孔重命名**：
  - 命令：`setStreamOutMode -SEvianames true`
  - 命名规则：`topStructureName_VIAindex`（如 `chip_VIA1`）

### OASIS 格式
- **用途**：GDSII 的替代格式，文件更小
- **导出命令**：
  ```
  setStreamOutMode [options]
  streamOut <filename>
  ```
- **合并**：支持与 GDSII 相同的合并操作

### DEF（Design Exchange Format）
- **用途**：设计物理信息交换格式
- **包含**：
  - 芯片边界（DIEAREA）
  - 行定义（ROWS）
  - 单元放置（COMPONENTS）
  - 网络布线（NETS）
  - 特殊网络（SPECIALNETS）
  - 通孔定义（VIAS）
- **版本支持**：支持 DEF 5.7 版本（部分语法不支持，见下文）
- **特殊行支持**：
  - 支持 NIMH（Non-Integer Multiple Height）行
  - 支持非对齐行（Unaligned Rows）
  - 需要定义功率域以正确放置

### SPEF（Standard Parasitic Exchange Format）
- **用途**：寄生参数（RC）信息交换
- **用途**：用于时序分析和信号完整性分析

### Verilog 网表导出
- **导出命令**：`saveNetlist <filename>`
- **物理单元**：使用 `-phys` 参数输出物理单元实例
- **电源/地网络**：自动插入电源和地网络
- **用途**：LVS（Layout vs. Schematic）验证

---

## 导入导出命令参考

### 设计导入

#### 基于 LEF + Verilog 的导入
```
File > Import Design
- 指定 Verilog 网表文件
- 选择顶层单元（Auto Assign 或 By User）
- 指定 LEF 文件（工艺 LEF 优先）
```

#### OpenAccess 设计导入
```
File > Import Design > OA
- 指定库、单元、视图
- 指定参考库和抽象视图名称
```

#### 数据验证
```
setCheckMode -netlist true -library true
getCheckMode
```

### 设计导出

#### GDSII/OASIS 导出
```
setStreamOutMode [options]
streamOut <filename>
```

#### GDSII/OASIS 文件合并
```
streamOut -merge {file1 file2 ...} [-uniquifyCellNames]
```

#### Verilog 网表导出
```
saveNetlist <filename> [-phys]
```

---

## LEF 格式支持矩阵

### LEF 5.7 不支持的语法（解析但忽略）

#### 布线层（Layer Routing）
- `DIAGWIDTH`、`DIAGSPACING`、`DIAGMINEDGELENGTH`
- `SLOTWIREWIDTH`、`SLOTWIRELENGTH`、`SLOTWIDTH`、`SLOTLENGTH`
- `MAXADJACENTSLOTSPACING`、`MAXCOAXIALSLOTSPACING`、`MAXEDGESLOTSPACING`
- `SPLITWIREWIDTH`、`HEIGHT`、`SHRINKAGE`、`CAPMULTIPLIER`

#### 宏引脚（Macro Pin）
- `TAPERRULE`
- `NETEXPR`

#### 非默认规则（Nondefault Rule）
- `DIAGWIDTH`、`HARDSPACING`、`USEVIARULE`

#### 通孔规则生成（Via Rule Generate）
- `DEFAULT` 关键字

### LEF 5.7 不支持的语法（产生错误）

#### 布线层方向
- `DIRECTION {DIAG45 | DIAG135} ;` ❌ 不支持

---

## DEF 格式支持矩阵

### DEF 5.7 不支持的语法（解析但忽略）

#### 阻挡（Blockages）
- `[+ SLOTS]`

#### 组（Groups）
- `[+ PROPERTY {...}]`

#### 扩展（Extensions）
- 所有 `BEGINEXT` 语法

#### 历史（History）
- 所有 `HISTORY` 语法

#### 网络（Nets）
- `[+ SYNTHESIZED]`
- `[+ VPIN ...]`
- `[+ SUBNET ...]`（NONDEFAULTRULE 被忽略）
- `[+ USE {RESET | SCAN | TIEOFF}]`
- `[+ PATTERN {STEINER | WIREDLOGIC}]`
- `[+ ESTCAP ...]`
- `[+ SOURCE ...]`

#### 引脚（Pins）
- `[+ USE {TIEOFF | SCAN | RESET}]`
- `[+ DIRECTION FEEDTHRU]`
- `[+ NETEXPR ...]`
- `[+ SUPPLYSENSITIVITY ...]`
- `[+ GROUNDSENSITIVITY ...]`

#### 引脚属性（Pin Properties）
- 所有 `PINPROPERTIES` 语法

#### 属性定义（Property Definitions）
- `GROUP`、`REGION`、`ROW` 对象类型

#### 区域（Regions）
- `[+ PROPERTY {...}]`

#### 行（Rows）
- `[+ PROPERTY {...}]`

#### 插槽（Slots）
- 所有 `SLOTS` 语法

#### 特殊网络（Special Nets）
- `[+ SYNTHESIZED]`
- `[+ VOLTAGE ...]`
- `[+ SOURCE ...]`
- `[+ USE ...]`
- `[+ PATTERN ...]`
- `[+ ESTCAP ...]`
- `[+ WEIGHT ...]`（仅在 NETS 部分支持）
- `[+ STYLE ...]`（显示错误，使用默认样式）

#### 样式（Styles）
- 所有 `STYLES` 语法

### DEF 5.7 不支持的语法（产生错误）

#### 网络布线语句
- `[orient] [STYLE styleNum]` ❌ 不支持

---

## GDSII/OASIS 映射文件

### 映射文件格式
- **用途**：定义 Innovus 数据库层到 GDSII/OASIS 层的映射
- **最大层数**：1000 层
- **列数**：4 列

### 映射文件列定义

| 列 | 名称 | 说明 |
|---|------|------|
| 1 | layerObjName | LEF 层名称或特殊对象（LEFOVERLAP、COMP、DIEAREA、NAME 等） |
| 2 | layerObjType | 对象类型（NET、SPNET、VIA、PIN、LEFPIN、FILL、BLOCKAGE 等） |
| 3 | layerNumber | GDSII/OASIS 层号（0-999） |
| 4 | dataType | 数据类型（通常为 0） |

### 特殊对象类型

- **LEFOVERLAP**：宏边界
- **COMP**：单元轮廓
- **DIEAREA**：芯片边界
- **MAXVOLTAGE/MINVOLTAGE**：电压标签（VDR 流程）
- **NAME**：文本标签（可选）
- **ALL**：布线层等价于 NET、SPNET、VIA、PIN、LEFPIN、FILL、FILLOPC、LEFOBS、VIAFILL、VIAFILLOPC

### 映射文件示例
```
# 工艺层映射
METAL1 NET 1 0
METAL1 SPNET 999 0
METAL1 PIN 1000 0
METAL1 LEFPIN 2000 0
METAL1 FILL 3000 0
METAL1 VIA 4000 0
METAL1 VIAFILL 5000 0
METAL1 LEFOBS 10000 0
NAME METAL1/NET 20000 0
```

---

## LEF 文件检查清单

### 关键检查项

#### MINSIZE 语句
- ❌ 不支持：`MINSIZE` 不带 `AREA`
- ✅ 正确：`MINSIZE` 必须与 `AREA` 一起指定

#### UNITS 语句
- ❌ 不支持：`DATABASE MICRONS 100`
- ✅ 解决方案：导入前执行 `setImportMode -minDBUPerMicron 1000`

#### MANUFACTURINGGRID
- ✅ 必须定义制造网格

#### MACRO 定义
- ✅ 标准单元宏应定义为 `CLASS CORE`
- ✅ 使用实际形状（非块式抽象）以改进引脚接入

#### VIA 定义
- ✅ `TOPOFSTACKONLY` 关键字在有 `LAYER AREA` 语句时不必要
- ✅ 布线器自动从 `AREA` 语句推导 `TOPOFSTACKONLY` 通孔
- ✅ 无 `AREA` 语句时，布线器从 `TOPOFSTACKONLY` 通孔推导 `AREA` 规则

---

## 文件格式兼容性

### 设计导入流程

```
Verilog 网表 + LEF 文件 → Innovus 数据库
                ↓
        (可选) OpenAccess 转换
                ↓
        (可选) DEF 导入/导出
```

### 设计导出流程

```
Innovus 数据库 → GDSII/OASIS 流片文件
             → DEF 物理设计文件
             → Verilog 网表（LVS 验证）
             → SPEF 寄生参数文件
```

### 分层设计处理

#### GDSII/OASIS 合并规则
- 合并单元：设计中直接引用的单元 + 递归搜索中可引用的单元
- 不合并单元：未被引用且无递归路径的单元
- 版本选择：使用所有合并文件中的最高版本号

#### 唯一化单元名称
- 参数：`-uniquifyCellNames`
- 要求：顶层文件必须列在第一位
- 命名规则：`originalName_sourceFileName`

---

## 常见文件格式问题和解决方案

### 问题 1：LEF 文件中的单元定义重复

**症状**：导入时出现警告或错误

**解决方案**：
- Innovus 仅从第一个定义读取几何信息
- 后续定义仅读取天线信息
- 检查 LEF 文件中是否有重复的 MACRO 定义

### 问题 2：DEF 文件中的行定义不兼容

**症状**：NIMH 行或非对齐行放置不正确

**解决方案**：
- 为每个不同的行样式定义功率域
- 预先放置和调整功率域大小以覆盖特殊行
- 避免在主核心行区域移动功率域（会重新初始化行）

### 问题 3：GDSII/OASIS 导出时层映射错误

**症状**：导出文件中层号不正确或缺失

**解决方案**：
- 检查映射文件中的 `layerObjName` 和 `layerObjType` 是否与 LEF 定义匹配
- 确保 `layerNumber` 和 `dataType` 符合工艺要求
- 验证映射文件中没有重复的层定义

### 问题 4：Verilog 网表中的 assign 语句处理

**症状**：assign 语句在导出时丢失或被替换

**解决方案**：
- Innovus 原生支持 Verilog assign 网表
- assign 语句可被自动添加、删除或替换为缓冲器
- 所有应用（Place、Route、CTS 等）都支持 assign 网表

### 问题 5：OpenAccess 导入时视图名称不匹配

**症状**：无法找到抽象或布局视图

**解决方案**：
- 指定正确的 OA Abstract View Names（如 `abstract`、`abstract2`）
- 指定正确的 OA Layout View Names
- 第一个参考库必须包含工艺信息
- 按顺序处理参考库和视图名称

### 问题 6：数据验证失败

**症状**：导入时报告缺失的 Verilog、LEF 或 .lib 文件

**解决方案**：
```
setCheckMode -netlist true -library true
getCheckMode
```
- 确保所有必需文件在导入前可用
- 检查文件路径和权限

---

## 工艺文件转换

### iPRT 到 LEF 转换

**工具**：`iprt2lef` 转换器

**转换内容**：
- iDRC 规则
- iPRT 工艺数据
- iRCX RC 数据

**输出**：工艺 LEF 格式

---

## Flip Chip 设计特殊格式

### RDL 层定义
- 类型：`ROUTING`
- 方向：`VERTICAL` 或 `HORIZONTAL`
- 包含间距表、面积规则等标准层定义

### BUMP 单元定义
- 宏类型：`CLASS COVER BUMP`
- 形状：支持八边形和矩形
- 引脚定义：在 RDL 层上定义

### I/O Pad 定义
- 宏类型：`CLASS COVER PAD`
- 用于 Flip Chip 设计的 I/O 接口

