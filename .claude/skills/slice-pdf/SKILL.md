---
name: slice-pdf
description: 对 EDA 工具手册 PDF 进行切片，提取每章内容为 JSON，并检查切片质量。
---

# PDF 切片技能

## 目标
将 EDA 工具手册 PDF 按书签切片，输出每章的结构化 JSON，并抽查质量。

## 脚本位置
脚本位于项目根目录下的 `scripts/pdf_slicer.py`，同目录下还有 `toc_parser.py` 和 `toc_parser_usage.md`。

## 步骤

### 1. 确认参数

从用户输入中获取：
- 输入 PDF 路径
- 输出目录

### 2. 检查书签

```python
from <slicer_module> import extract_outlines
outlines = extract_outlines('<pdf_path>')
missing = [o for o in outlines if o['top'] is None]
print(f'Total: {len(outlines)}, missing /Top: {len(missing)}')
```

- 有书签且含 `/Top`：加 `--precise`
- 有书签但无 `/Top`：不加 `--precise`
- **书签为空**：PDF 没有书签，需要从目录页解析。读取 `toc_parser_usage.md`，按其说明测量参数值后，在 `pdf_slicer.py` 命令中追加 TOC 参数组

### 3. 运行切片脚本

**参数说明**

| 参数 | 类型 | 默认值 | 含义 |
|---|---|---|---|
| `pdf_path` | 位置参数 | 必填 | 输入 PDF 文件路径 |
| `output_dir` | 位置参数 | 必填 | 输出目录（自动创建） |
| `--from N` | int | 1 | 起始章节编号（1-based，含） |
| `--to M` | int | 最后一章 | 结束章节编号（含） |
| `--precise` | 开关 | 关 | 所有书签含 `/Top` 坐标时加，否则不加 |
| `--strip-headers` | 开关 | 关 | 建议添加 |
| `--merge-cross-page` | 开关 | 关 | 建议添加 |
| `--ocr-text` | 开关 | 关 | 文本层乱码时改用离线 OCR |
| `--fitz-text` | 开关 | 关 | PyMuPDF 抽文本，pdfplumber 抽表格 |
| `--ocr-scale S` | float | 2.0 | OCR 渲染倍率；更高更准，但更慢 |

**输出 schema**

- 文本项：`{type: "text", lines: ["..."]}`
- 表格项：`{type: "table", page, table_index, data: [[...]]}`

**直接运行，每隔一分钟检查一次**

用 Bash 工具运行脚本，然后用 ScheduleWakeup 每隔 1 分钟检查输出目录中的文件数量，直到文件数量不再增加（即切片完成）。

```
# 正确用法（伪代码）
Bash(command="python scripts/pdf_slicer.py ...")
# → ScheduleWakeup(delaySeconds=60, reason="检查切片进度")
# → 醒来后统计输出目录文件数，若与上次相同则视为完成，否则继续等待
```

### 4. 等待完成

每次 ScheduleWakeup 触发后，统计输出目录中的文件数量。若文件数量与上次相同（不再增加），则视为切片完成；否则继续 ScheduleWakeup 等待下一分钟。完成后确认文件数量与章节数一致（章节数 + 1 个 toc.json）。

### 5. 质量抽查

随机抽取 5 个 `chapter_NNNN.json`，对每章输出所有 content 项（不截断），重点检查：

- **内容缺失**：对照章节标题，判断正文、参数表是否完整；若某章 content 为空或 item 数量异常少，标记为疑似缺失
- **页眉残留**：text 类型 item 中出现与本章无关的章节名或文档标题，属于页眉未剔除干净
- **零宽字符**：检查 text 和 table 中是否含 `\u200b` 等不可见字符
- **章节边界**：首个 text item 应以本章标题开头，末尾 item 不应包含下一章的内容

将发现的问题汇报给用户，说明是系统性问题还是个别章节问题。
