# Innovus 21.1 Legacy 脚本编写指南 — 计划文件

> 本文件夹目标：为 agent 提供可直接参考的 Innovus 21.1 Tcl 脚本语法指南，覆盖常见脚本类型，使 agent 能独立编写语法正确的脚本。

---

## 数据来源

| 来源 | 说明 |
|------|------|
| `knowledge/Innovus/legacy/eda_scripts/innovus_gift__211/` | 188 个示例脚本，**仅供思路参考，不是语法权威** |
| `knowledge/Innovus/legacy/jsonl/dbSchema__211.jsonl` | DB 对象模型，**属性名与合法值的权威来源** |
| `knowledge/Innovus/legacy/jsonl/innovusTCR__211.jsonl` | Tcl 命令参考，**命令名与参数签名的权威来源** |

---

## 文件结构规划

```
scripting-guide/
├── _plan.md                      ← 本文件（计划与索引）
├── 00-db-api-primer.md           ← dbGet / dbShape / dbForEach 核心 API
├── 01-eco-scripts.md             ← ECO 类：插 buffer、rebind、net 连接、IO/diode
├── 02-floorplan-scripts.md       ← Floorplan 类：blockage、halo、obstruct、partition
├── 03-placement-scripts.md       ← Placement 类：fix/unplace inst、place macro、pad sequential
├── 04-net-wire-scripts.md        ← Net/Wire 类：net 属性、NDR、tie floating、wire 操作
├── 05-report-scripts.md          ← Report 类：查找 inst/net/pin/hport
├── 06-skew-scripts.md            ← Skew 类：set_ccopt_property、ICG latency
└── 07-common-patterns.md         ← 通用模式：参数解析、单位转换、错误处理
```

---

## 各文件内容规划

### 00-db-api-primer.md — DB API 核心速查

> **注意**：`dbGet` / `dbSet` 是 TCR 收录的通用命令。以 `db` 开头的其他函数（`dbForEach*`、`dbIs*`、`dbGet*ByName` 等）均来自 gift 脚本，TCR 未收录，编写指南时须标注来源。

- **dbGet / dbSet 查询语法**（TCR ✓）：`-p` / `-p2` / `-p3` 层级穿透；`-e` 精确匹配；常用属性路径
- **dbShape 几何操作**（⚠ gift 脚本来源）：SIZEX/SIZEY 扩缩；OR/AND/ANDNOT 布尔运算；MOVE 平移
- **dbForEach 迭代族**（⚠ gift 脚本来源）：`dbForEachCellInst`、`dbForEachNetTerm`、`dbForEachInstInputTerm`、`dbForEachInstOutputTerm`、`dbForEachHInstHInst`
- **对象导航函数**（⚠ gift 脚本来源）：`dbGetNetByName`、`dbGetHInstByName`、`dbTermInst`、`dbTermNet`、`dbInstName`、`dbInstCellName`
- **类型判断函数**（⚠ gift 脚本来源）：`dbIsObjTerm`、`dbIsInstBlock`、`dbIsCellBlock`、`dbObjType`
- **单位转换**（⚠ gift 脚本来源）：`dbMicronsToDBU` / `dbDBUToMicrons`；坐标提取 `dbBoxLLX/LLY/URX/URY`

### 01-eco-scripts.md — ECO 脚本指南

覆盖场景：
- 插入 buffer / repeater（`ecoAddRepeater`、`addInst`、`attachTerm`、`addNet`）
- Buffer rebind / upsize（`ecoChangeCell -inst <name> -cell <newCell>`）
- Net 连接修改（detach/attach 模式：`attachTerm` 重连、`addNet` 新建 net）
- 层级 buffer 插入（跨 partition 场景）
- 典型完整示例：给指定 net 的所有 fanout 插 buffer

关键 API：
```tcl
ecoAddRepeater -term <instName/termName> -cell <cellName>
addInst <cellName> <instName>
attachTerm <instName> <pinName> <netName>
addNet <netName>
ecoChangeCell -inst <instName> -cell <newCellName>   ;# rebind/upsize，替代已废弃的 ecoSwapMaster
```

### 02-floorplan-scripts.md — Floorplan 脚本指南

覆盖场景：
- 创建 placement blockage（`createPlaceBlockage`）
- 创建 route blockage（`createRouteBlk`）
- 创建 halo（`addHaloToBlock`）
- 密度屏蔽（zero-density screen）
- 基于 macro 自动生成 blockage
- 典型完整示例：为所有 hard macro 创建 route blockage

关键 API：
```tcl
createPlaceBlockage -box <llx lly urx ury> -type <hard|soft|partial>
createRouteBlk -box <llx lly urx ury> -layer <layerName>
addHaloToBlock -allBlock <left> <bottom> <right> <top>
deleteHaloFromBlock -allMacro
```

### 03-placement-scripts.md — Placement 脚本指南

覆盖场景：
- Fix / unfix inst（`dbSet $inst.pStatus fixed/placed`）
- Fix 所有 macro（遍历 `dbIsCellBlock` 后批量 `dbSet .pStatus fixed`）
- Fix 所有 sequential cell（遍历 `dbIsCellSequential` 后批量 `dbSet .pStatus fixed`）
- 为 sequential cell 设置 cell padding（`specifyCellPad`、`deleteAllCellPad`）
- 查询 cell padding（`dbGet [dbGetCellByName <name>].padding`）
- 典型完整示例：为所有 sequential cell 按宽度比例设置 padding（`userAutoPadSequentials`）

关键 API：
```tcl
# inst.pStatus — 可写 enum：cover / fixed / placed / softFixed / unplaced
dbGet $instPtr.pStatus               ;# 查询 placement status
dbSet $instPtr.pStatus fixed         ;# fix inst
dbSet $instPtr.pStatus placed        ;# unfix（恢复为 placed）

# inst.pStatusCTS — CTS 专用 placement status（fixed / softFixed / unset）
dbGet $instPtr.pStatusCTS
dbSet $instPtr.pStatusCTS fixed

# 批量操作模式（dbGet -p2 返回满足条件的 inst 指针列表）
foreach inst [dbGet -p2 top.insts.cell.baseClass block] {
    dbSet $inst.pStatus fixed
}

placeInstance <instName> <x> <y> -fixed  ;# 放置并 fix（坐标单位：microns，TCR ✓）
specifyCellPad <cellName> <padInM2Pitches>   ;# TCR ✓
deleteAllCellPad                              ;# TCR ✓
dbGet [dbGetCellByName <cellName>].padding    ;# dbSchema ✓（libCell.padding 属性）
# ⚠ 以下来源于 gift 脚本，TCR 未收录
dbIsCellSequential $cellPtr              ;# 判断是否为 sequential cell
dbLayerWirePitch M2                      ;# 取 M2 pitch（DBU）
```

### 04-net-wire-scripts.md — Net/Wire 脚本指南

覆盖场景：
- 遍历 special net 的所有 route（wire / via）并读写属性
- 生成 NDR（Non-Default Rule）LEF 文件并加载（`loadLefFile`）
- 删除所有 signal net 的 wire（`dbNetFreeWires`）
- 删除指定 net（`userDeleteAllNetsExceptClockNets` 模式）
- 典型完整示例：生成 xN 宽度 NDR 并写出 LEF（`userGenXWidthNDR`）

关键 API：
```tcl
# ⚠ 以下均来源于 gift 脚本，TCR 未收录，参数签名以 gift 脚本为参考
dbForAllCellNet [dbgTopCell] netPtr { ... }
dbIsNetSpecial $netPtr
dbIterAllRoutes / dbIterRoutes $netPtr / dbRouteNext $iter / dbEndIterAllRoutes
dbIsRouteWire $route / dbIsRouteVia $route
dbNetFreeWires $netPtr
dbForEachHeadLayer [dbgHead] lPtr { ... }
dbLayerName $lPtr / dbLayerLefName $lPtr / dbLayerPrefDir $lPtr
dbLayerWireWidth $lPtr / dbHeadMicronPerDBU
loadLefFile <fileName>   ;# TCR ✓
```

### 05-report-scripts.md — Report/查找脚本指南

覆盖场景：
- 按 net 名查找连接的 inst（`dbGetNetByName` + `dbForEachNetTerm`）
- 按 cell 名查找 inst（`dbForEachCellInst` + 属性过滤）
- 查找所有 sequential cell（`dbIsCellSequential`）
- 查找 clock gating cell（`dbFTermType` == `dbcGatedClockTerm`）
- 查找特定 hport / IO port（`dbForEachCellFTerm`）
- 按名称模式匹配 inst（`string match`）
- 典型完整示例：列出指定 net 的所有 fanout inst 及其 cell 类型

关键 API：
```tcl
# ⚠ 以下均来源于 gift 脚本，TCR 未收录
dbGetNetByName <netName>
dbForEachNetTerm $netPtr termPtr { ... }
dbForEachNetOutputTerm $netPtr termPtr { ... }
dbForEachNetInputTerm $netPtr termPtr { ... }
dbForEachCellInst [dbHeadTopCell] inst { ... }
dbForEachCellFTerm [dbHeadTopCell] fterm { ... }
dbIsObjTerm $termPtr          ;# 区分 inst term vs fterm
dbObjType $ptr                ;# 返回 dbcObjInst / dbcObjTerm / dbcObjHInst 等
dbIsCellBlock $cellPtr
dbIsCellSequential $cellPtr
dbFTermType $ftermPtr         ;# dbcGatedClockTerm 表示 clock gating pin
# dbGet/dbSet 是 TCR 收录的通用命令（TCR ✓）
dbGet -p2 top.insts.cell.baseClass block   ;# 快速过滤 block inst
```

### 06-skew-scripts.md — Skew/Clock 定制脚本指南

核心思路：通过 `set_ccopt_property` 对 clock tree 中的特定节点（通常是指定的 register 或 clock sink）施加客制化约束，例如设置 insertion delay offset、调整 skew target，从而影响 CTS 的 tree 构建结果。

覆盖场景：
- 用 dbGet 查找指定 register 的 clock pin，获取其在 clock tree 中的节点信息
- 用 `set_ccopt_property` 对特定 sink 或 sink group 设置 insertion delay 偏移
- 按 clock domain 批量遍历 FF，筛选目标 register 后批量施加约束
- 从文件读取 reg 列表，循环处理并生成约束
- 典型完整示例：从文件读取 reg 列表，批量对其 clock sink 设置 insertion delay offset

关键 API（执行时须从 `innovusTCR__211` 确认完整参数签名，不得臆造）：
- `set_ccopt_property`：对 clock tree 节点设置属性，是本类脚本的核心命令，具体 `-target_insertion_delay`、`-sink_type` 等参数须查阅 TCR 文档确认
- dbGet 查询 FF 的 clock pin 路径：通过 `top.insts` 遍历，过滤 `cell.baseClass == "seq"` 后取 clock term
- 文件读取循环：标准 Tcl `open`/`gets`/`close` 模式

### 07-common-patterns.md — 通用 Tcl 模式

覆盖内容：
- proc 定义与参数解析（`args` 风格 vs 位置参数）
- `-h` 帮助信息模式（`string match "-h*" $args`）
- 单位换算（microns ↔ DBU：`dbMicronsToDBU` / `dbDBUToMicrons` / `dbHeadMicronPerDBU`）
- 坐标操作（box 解构：`dbBoxLLX/LLY/URX/URY`；`dbInstBox`；`join` 展开 list 传给命令）
- 文件读写（`open`/`gets`/`puts`/`close`、生成 .tcl 脚本）
- 错误处理（`catch`、`error`）
- 层级分隔符（`dbgHierChar`；`split`/`join` 处理层级名）
- 常用 list 操作（`lsearch`、`lsort -real`、`concat`、`lappend`）
- `eval` + `join` 展开 list 作为命令参数（`eval "cmd [join $list]"`）

---

## 编写优先级

| 优先级 | 文件 | 理由 |
|--------|------|------|
| P0 | `00-db-api-primer.md` | 所有脚本的基础，必须先完成 |
| P1 | `01-eco-scripts.md` | 最常用场景，gift 脚本覆盖最多 |
| P1 | `02-floorplan-scripts.md` | blockage 操作频繁 |
| P2 | `03-placement-scripts.md` | fix/unplace/pad 操作常见 |
| P2 | `04-net-wire-scripts.md` | NDR、wire 操作通用性强 |
| P2 | `05-report-scripts.md` | 查找/报告类通用性强 |
| P3 | `06-skew-scripts.md` | CTS 专项场景 |
| P3 | `07-common-patterns.md` | 补充，可穿插在其他文件中 |

---

## 编写规范

每个指南文件统一结构：

```
---
source: knowledge/Innovus/legacy/jsonl/dbSchema__211.jsonl | ...
source: knowledge/Innovus/legacy/jsonl/innovusTCR__211.jsonl | ...
---

# 标题

## 概述（2-3 句）

## 核心 API 速查表

## 典型场景 + 代码示例

## 注意事项 / 常见错误
```

### 核心原则

1. **仅收录 TCR 命令**：文档内**禁止出现 TCR 中不存在的指令**，避免浪费 agent 阅读时的上下文容量
2. **参考文档位置**：`source` 声明仅在文件开头 frontmatter 中出现，**不在文末重复**
3. **gift 脚本用途**：`innovus_gift__211` 脚本**仅供编写思路参考**，不得在文档中引用或列出其中的函数

### 内容来源优先级

1. **Tcl 命令**（`ecoAddRepeater`、`createPlaceBlockage` 等）：以 `innovusTCR__211` 为准
   - TCR 未收录的命令**不得出现在文档中**
2. **DB 对象属性**（`.pStatus`、`.name` 等）：以 `dbSchema__211` 为准
3. **代码示例场景**：可参考 `innovus_gift__211` 脚本获取编程思路，但实现必须使用 TCR 收录的命令

### 严格禁止

- ❌ 文档中出现 TCR 未收录的函数（如 `dbForEachCellInst`、`dbGetNetByName`、`dbIsCellSequential` 等）
- ❌ 在文档中引用或列出 gift 脚本的函数签名
- ❌ 虚构指令：对于不确定的命令名或参数，必须先查阅 `innovusTCR__211` 或 `dbSchema__211` 确认
- ❌ 在文末添加"参考资料"章节（已在 frontmatter 声明）
