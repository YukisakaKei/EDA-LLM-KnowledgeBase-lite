---
name: slice-pdf
description: 对 EDA 工具手册 PDF 进行切片，输出 JSONL 知识库记录，并检查切片质量。
---

# PDF 切片技能

## 目标

将 EDA 工具手册 PDF 按书签或目录页切片，输出单文件 JSONL：每行是一条完整章节记录，字段至少包含 `index/title/depth/content`，并保留 `page_start/page_end` 作为溯源字段。切片完成后校验 JSONL 格式，并抽查章节边界和内容质量。

## 脚本位置

- 主脚本：`scripts/pdf_jsonl_slicer/pdf_jsonl_slicer.py`
- 说明：`scripts/pdf_jsonl_slicer/pdf_jsonl_slicer.md`
- 用法：`scripts/pdf_jsonl_slicer/pdf_jsonl_slicer_usage.md`
- TOC fallback：`scripts/pdf_jsonl_slicer/toc_parser.py`
- JSONL 校验：`scripts/validate_jsonl/validate_jsonl.py`

## 步骤

### 1. 确认参数

从用户输入中获取：

- 输入 PDF 路径
- 输出 JSONL 文件路径，或输出目录

输出路径建议直接传 `.jsonl` 文件；如果传入目录，脚本会输出到该目录下的 `<pdf-stem>.jsonl`。

### 2. 检查书签

先用小范围试跑确认书签状态。脚本日志会显示是否找到 bookmark entries；如果没有书签，按 TOC fallback 参数从目录页解析。

- 有书签且都含 `/Top`：可加 `--precise`
- 有书签但部分缺少 `/Top`：不要加 `--precise`
- **书签为空**：读取 `scripts/pdf_jsonl_slicer/pdf_jsonl_slicer_usage.md` 和 `python scripts\pdf_jsonl_slicer\toc_parser.py --help`，按测量结果追加 TOC fallback 参数组

### 3. 运行 JSONL 切片脚本

**参数说明**

| 参数 | 类型 | 默认值 | 含义 |
|---|---|---|---|
| `pdf_path` | 位置参数 | 必填 | 输入 PDF 文件路径 |
| `output_jsonl` | 位置参数 | 必填 | 输出 `.jsonl` 文件路径，或输出目录 |
| `--from N` | int | 1 | 起始章节编号（1-based，含） |
| `--to M` | int | 最后一章 | 结束章节编号（含） |
| `--precise` | 开关 | 关 | 所有书签含 `/Top` 坐标时加，否则不加 |
| `--strip-headers` | 开关 | 关 | 自动检测并剔除重复页眉页脚，通常建议添加 |
| `--merge-cross-page` | 开关 | 关 | 合并跨页断开的文本段落或连续表格，通常建议添加 |
| `--ocr-text` | 开关 | 关 | 文本层乱码时改用离线 OCR；表格会退化为文本行 |
| `--fitz-text` | 开关 | 关 | PyMuPDF 抽文本，pdfplumber 抽表格 |
| `--ocr-scale S` | float | 2.0 | OCR 渲染倍率；更高更准，但更慢 |

`--ocr-text` 和 `--fitz-text` 互斥，不能同时使用。

TOC fallback 参数：

```text
--toc-start N --toc-end M --header-bottom Y --footer-top Y --page-x1-1 X --page-x1-2 X --page-x1-3 X --page-x1-4 X [--skip-x0-max X]
```

**命令示例**

```powershell
python scripts\pdf_jsonl_slicer\pdf_jsonl_slicer.py `
  "<pdf_path>" `
  "<output_jsonl>" `
  --precise `
  --strip-headers `
  --merge-cross-page
```

小范围试跑时优先使用 `--from N --to M`，确认参数、书签和章节边界都正常后再全量运行。

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

抽查至少 3-5 个 entry，优先覆盖首章、中间章节、跨页章节、含表格章节。重点检查：

- **内容缺失**：对照章节标题，判断正文、参数表是否完整；若某条 `content` 为空或 item 数量异常少，标记为疑似缺失
- **页眉残留**：text 类型 item 中出现与本章无关的章节名或文档标题，属于页眉未剔除干净
- **零宽字符**：检查 text 和 table 中是否含 `\u200b` 等不可见字符
- **章节边界**：首个 text item 应以本章标题开头，末尾 item 不应包含下一章内容
- **页面范围**：`page_start/page_end` 应覆盖本章内容，不应明显越界
- **检索可用性**：用 `rg -n '"index":N,' <output_jsonl>` 和关键词检索确认能定位到完整单行记录

将发现的问题汇报给用户，说明是系统性问题还是个别章节问题。
