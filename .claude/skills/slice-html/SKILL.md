---
name: slice-html
description: 对 Confluence 导出的 HTML 手册进行切片，提取每章内容为 JSON，并检查切片质量。
---

# HTML 切片技能

## 目标
将 Confluence 导出的 HTML 手册按 TOC 切片，输出每章的结构化 JSON，并抽查质量。

## 脚本位置
脚本位于项目根目录下的 `scripts/html_slicer.py`，同目录下还有 `html_slicer_usage.md`。

## 步骤

### 1. 确认参数

从用户输入中获取：
- HTML 手册目录路径（包含所有章节 HTML 文件）
- TOC HTML 文件路径
- 输出目录

### 2. 检查 TOC 文件

确认 TOC 文件存在，并快速预览其结构（`<h2>`、`<p>`、`<dd>` 层级），确认脚本能正确解析。

### 3. 运行切片脚本

**参数说明**

| 参数 | 类型 | 默认值 | 含义 |
|---|---|---|---|
| `html_dir` | 位置参数 | 必填 | 包含章节 HTML 文件的目录 |
| `output_dir` | 位置参数 | 必填 | 输出目录（自动创建） |
| `--toc` | 路径 | 必填 | TOC HTML 文件路径 |
| `--from N` | int | 1 | 起始章节编号（1-based，含） |
| `--to M` | int | 最后一章 | 结束章节编号（含） |
| `--skip-empty` | 开关 | 关 | 跳过正文内容为空的章节（仅含子章节链接的索引页） |

**直接运行，每隔一分钟检查一次**

用 Bash 工具运行脚本，然后用 ScheduleWakeup 每隔 1 分钟检查输出目录中的文件数量，直到文件数量不再增加（即切片完成）。

```
# 正确用法（伪代码）
Bash(command="python scripts/html_slicer.py <html_dir> <output_dir> --toc <toc_file>")
# → ScheduleWakeup(delaySeconds=60, reason="检查切片进度")
# → 醒来后统计输出目录文件数，若与上次相同则视为完成，否则继续等待
```

### 4. 等待完成

每次 ScheduleWakeup 触发后，统计输出目录中的文件数量。若文件数量与上次相同（不再增加），则视为切片完成；否则继续 ScheduleWakeup 等待下一分钟。完成后确认文件数量与章节数一致（章节数 + 1 个 toc.json）。

### 5. 质量抽查

随机抽取 5 个 `chapter_NNNN.json`，对每章输出所有 content 项（不截断），重点检查：

- **内容缺失**：对照章节标题，判断正文、参数表是否完整；若某章 content 为空或 item 数量异常少，标记为疑似缺失
- **锚点切片**：同一 HTML 文件被多个 TOC 条目引用时，各章内容应按锚点正确分割，不应包含相邻章节的内容
- **零宽字符**：检查 text 和 table 中是否含 `​` 等不可见字符
- **NOTE/WARNING 前缀**：Confluence info macro 内容应带有 `[NOTE]`、`[WARNING]`、`[TIP]`、`[INFO]` 前缀
- **表格完整性**：表格行列数应与 HTML 原文一致，单元格内容不应截断

将发现的问题汇报给用户，说明是系统性问题还是个别章节问题。
