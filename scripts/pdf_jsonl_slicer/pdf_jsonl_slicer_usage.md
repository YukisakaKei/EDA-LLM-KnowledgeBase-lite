# pdf_jsonl_slicer.py — 使用说明

## 命令格式

```bash
python scripts/pdf_jsonl_slicer/pdf_jsonl_slicer.py <pdf_path> <output_jsonl> [--from N] [--to M] [--precise] [--strip-headers] [--merge-cross-page] [--fitz-text | --ocr-text] [--ocr-scale S]
```

`<output_jsonl>` 推荐直接传 `.jsonl` 文件路径；如果传入目录，脚本会输出到该目录下的 `<pdf-stem>.jsonl`。

## 参数说明

| 参数 | 类型 | 默认值 | 含义 |
|---|---|---|---|
| `pdf_path` | 位置参数 | 必填 | 输入 PDF 文件路径 |
| `output_jsonl` | 位置参数 | 必填 | 输出 JSONL 文件路径，或输出目录 |
| `--from N` | int | 1 | 起始章节编号，按 TOC/bookmark 的 1-based index，包含 |
| `--to M` | int | 最后一章 | 结束章节编号，包含 |
| `--precise` | 开关 | 关 | 使用书签 `/Top` y 坐标精确裁剪章节 |
| `--strip-headers` | 开关 | 关 | 自动检测并剔除重复页眉页脚 |
| `--merge-cross-page` | 开关 | 关 | 合并跨页断开的文本段落或连续表格 |
| `--ocr-text` | 开关 | 关 | 使用离线 OCR 提取正文；表格退化为文本行 |
| `--fitz-text` | 开关 | 关 | 使用 PyMuPDF 提取正文，表格仍由 pdfplumber 提取 |
| `--ocr-scale S` | float | 2.0 | OCR 渲染倍率 |

## TOC fallback 参数

当 PDF 没有书签时，可提供下列参数从目录页解析章节：

```bash
--toc-start N --toc-end M --header-bottom Y --footer-top Y --page-x1-1 X --page-x1-2 X --page-x1-3 X --page-x1-4 X [--skip-x0-max X]
```

这些参数用于 TOC fallback 解析逻辑。TOC fallback 不提供 `/Top` 坐标，因此不能与 `--precise` 联用。

## 输出 JSONL 格式

每行是一条完整记录，示例：

```jsonl
{"index":1,"title":"Overview","depth":0,"source_file":"manual.pdf","page_start":3,"page_end":3,"content":[{"type":"text","lines":["Overview"]}]}
```

输出满足：

- UTF-8，无 BOM。
- 一行一个 JSON object。
- `ensure_ascii=False`，紧凑分隔符。
- 按 `index` 升序排列。
- 每条记录至少包含 `index/title/depth/content`。
- `page_start/page_end` 作为 PDF 溯源字段保留。

## 测试样本命令

```powershell
python scripts\pdf_jsonl_slicer\pdf_jsonl_slicer.py `
  "D:\AI_Agent\EDA-LLM-KnowkedgeBase\knowledge\Innovus\legacy\row\optDesign_vs_timeDesign.pdf" `
  workspace\jsonl-test\pdf\optDesign_vs_timeDesign.jsonl `
  --precise `
  --strip-headers
```

验证：

```powershell
python -m json.tool workspace\jsonl-test\pdf\optDesign_vs_timeDesign.jsonl
rg -n "optDesign" workspace\jsonl-test\pdf\optDesign_vs_timeDesign.jsonl
rg -n '"index":1,' workspace\jsonl-test\pdf\optDesign_vs_timeDesign.jsonl
```
