---
name: slice-html
description: 对 Confluence 导出的 HTML 手册进行切片，输出 JSONL 知识库记录，并检查切片质量。
---

# HTML 切片技能

## 目标

将 Confluence 导出的 HTML 手册按 TOC 切片，输出单文件 JSONL：每行是一条完整章节记录，字段至少包含 `index/title/depth/content`。切片完成后校验 JSONL 格式，并抽查内容质量。

## 脚本位置

- 主脚本：`scripts/html_jsonl_slicer/html_jsonl_slicer.py`
- 说明：`scripts/html_jsonl_slicer/html_jsonl_slicer.md`
- 用法：`scripts/html_jsonl_slicer/html_jsonl_slicer_usage.md`
- JSONL 校验：`scripts/validate_jsonl/validate_jsonl.py`

## 步骤

### 1. 确认参数

从用户输入中获取：

- HTML 手册目录路径（包含所有章节 HTML 文件）
- TOC HTML 文件路径
- 输出 JSONL 文件路径，或输出目录

输出路径建议直接传 `.jsonl` 文件；如果传入目录，脚本会输出到该目录下的 `<html-dir-name>.jsonl`。

### 2. 检查 TOC 文件

确认 TOC 文件存在，并快速预览其结构（`<h2>`、`<p>`、`<dd>` 层级），确认脚本能正确解析。

### 3. 运行 JSONL 切片脚本

**参数说明**

| 参数 | 类型 | 默认值 | 含义 |
|---|---|---|---|
| `html_dir` | 位置参数 | 必填 | 包含章节 HTML 文件的目录 |
| `output_jsonl` | 位置参数 | 必填 | 输出 `.jsonl` 文件路径，或输出目录 |
| `--toc` | 路径 | 必填 | TOC HTML 文件路径 |
| `--from N` | int | 1 | 起始章节编号（1-based，含） |
| `--to M` | int | 最后一章 | 结束章节编号（含） |
| `--skip-empty` | 开关 | 关 | 跳过正文内容为空的章节，保留后续原始 index，不重排 |

**命令示例**

```powershell
python scripts\html_jsonl_slicer\html_jsonl_slicer.py `
  "<html_dir>" `
  "<output_jsonl>" `
  --toc "<toc_file>" `
  --skip-empty
```

小范围试跑时优先使用 `--from N --to M`，确认参数、TOC 和内容抽取都正常后再全量运行。

### 4. 等待完成

JSONL 脚本输出单个文件。长文档运行时，每隔一段时间检查输出文件是否存在、大小或修改时间是否仍在变化；命令退出码为 0 且输出行数符合预期时视为完成。

### 5. 校验 JSONL

基础校验：

```powershell
python scripts\validate_jsonl\validate_jsonl.py "<output_jsonl>"
```

如果 JSONL 位于 `knowledge/.../jsonl/...` 布局下，且 `row/` 源文件在完整源仓库，可追加源文件检查：

```powershell
python scripts\validate_jsonl\validate_jsonl.py "<output_jsonl>" `
  --check-source-file `
  --target-root "<target_repo_root>" `
  --source-root "<source_repo_root>"
```

### 6. 质量抽查

抽查至少 3-5 个 entry，优先覆盖首章、中间章节、含表格章节、含 anchor 的章节。重点检查：

- **内容缺失**：对照章节标题，判断正文、参数表是否完整；若某条 `content` 为空或 item 数量异常少，标记为疑似缺失
- **锚点切片**：同一 HTML 文件被多个 TOC 条目引用时，各 entry 内容应按锚点正确分割，不应包含相邻章节内容
- **零宽字符**：检查 text 和 table 中是否含 `\u200b` 等不可见字符
- **NOTE/WARNING 前缀**：Confluence info macro 内容应带有 `[NOTE]`、`[WARNING]`、`[TIP]`、`[INFO]` 前缀
- **表格完整性**：表格行列数应与 HTML 原文一致，单元格内容不应截断
- **检索可用性**：用 `rg -n '"index":N,' <output_jsonl>` 和关键词检索确认能定位到完整单行记录

将发现的问题汇报给用户，说明是系统性问题还是个别章节问题。
