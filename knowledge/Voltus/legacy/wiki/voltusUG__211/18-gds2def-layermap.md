---
source: knowledge/Voltus/legacy/jsonl/voltusUG__211.jsonl | entries: [0334, 0335, 0336, 0337, 0338, 0339, 0340]
---

# GDS2DEF 工具与 TRIM Metals 层配置

## GDS2DEF Utility 概述

`convert_gds_to_def` 是一个 GDS2DEF 转换工具，将 GDSII 格式文件转换为 DEF 文件，用于 power/rail signoff 分析。适用场景：

- 某些 cell 仅有 GDS 格式，无法在 Voltus GUI 中查看内部设计数据
- 通过 Str2oa / oa2def 等现有转换器无法获取所需的互联信息
- DEF 文件不可获取时（如 redistribution layer (RDL) flip-chip bump 层描述仅以 GDSII 格式提供），需先转为 DEF/LEF 以集成到 DB 数据中

该工具同时支持 **cell-level** 和 **full-chip level** 的 GDS 转换。生成的 DEF 包含：

- P/G routing 的全部 geometry
- 指定的 P/G pin 信息
- component 和逻辑互联信息

注意：signal nets 会被过滤掉，不在 DEF 中输出。

## 数据需求

`convert_gds_to_def` 需要以下四类输入：

| 输入 | 说明 |
|------|------|
| GDSII 文件 | GDS 中 top cell 的名称即生成 DEF 中的 design 名称 |
| Layer mapping 文件 | GDS layer 与 tech layer 之间的映射文件 |
| Net pin 信息 | 包含坐标和 layer 名称列表的文件，作为 trace 起点 |
| Tech and Macro 信息 | 需要作为 instance 处理的 cell 需提供 Macro LEF，工具利用 LEF 中 pin shape 来 trace net 连接，不检查 GDS 内部 geometry；未提供 LEF macro 时工具会将所有 cell instance 展开（flatten）。同时需要 tech file（.cl library）提供 LEF layer 信息 |

## ESD 分析支持

通过 `convert_gds_to_def` 可以对 macro 进行 ESD 分析，相关参数：

- `-esd_marker_layer_file <filename>` -- 指定包含 ESD cell/instance 名称及其 GDS marker layer 的文件格式：`<cellname> <marker layer> [top layer] [bottom layer]`
- `-esd_cell_bbox_file <filename>` -- 指定每个 ESD cell 的 bounding box 文件格式：`<esd inst name> <x1 y1 x2 y2> [top layer] [bottom layer]`

指定任意一个参数后，工具识别 ESD cell 的 bounding box，收集内部所有指定 layer 范围的 GDS shapes，视为 ESD cell LEF pin shapes。工具会为每个 ESD cell 生成 LEF 文件以支持 PGV 生成。

## 基本用法

```
convert_gds_to_def new.gds -top.def
```

详细参数说明请参考 Voltus Text Command Reference 中的 `convert_gds_to_def` 命令。

## 为 TRIM Metals 层自定义 GDS Layermap 和 XTC Command File

CUT/TRIM 层用于切割 metal 层以分离不同的电源/地供应。Voltus 需要正确识别 CUT 层，为此需要手动修改 GDS layermap 文件，并在 power-grid library 生成时自定义 XTC command file 以支持这些层。

### 示例文件类型

| 文件 | 说明 |
|------|------|
| Simple GDS Layer Map | 不含 CUT 层的简单映射 |
| Simple XTC Command File | 不含 CUT 层的简单配置 |
| Modified Layer Map | 重命名 Metal（M0, M1, M2）和 Mask 层后的映射 |
| XTC with STOP@VIA0 | 在 VIA0 处停止的 XTC 配置 |
| XTC with STOP@VIA1 | 在 VIA1 处停止的 XTC 配置 |
| XTC with STOP@VIA2 | 在 VIA2 处停止的 XTC 配置 |

配置步骤：

1. 在 GDS layermap 文件中手工修改 CUT 层定义
2. 根据实际工艺选择对应的 XTC command file 模板
3. 根据所需的 via 层级（VIA0/VIA1/VIA2），使用相应的 `STOP@VIA` 配置来控制 power-grid library 生成的层范围
