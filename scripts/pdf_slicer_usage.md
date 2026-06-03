# pdf_slicer.py — 使用说明

## 命令格式

```bash
python pdf_slicer.py <pdf_path> <output_dir> [--from N] [--to M] [--precise] [--strip-headers] [--merge-cross-page] [--fitz-text | --ocr-text] [--ocr-scale S]
```

## 参数说明

| 参数 | 类型 | 默认值 | 含义 |
|---|---|---|---|
| `pdf_path` | 位置参数 | 必填 | 输入 PDF 文件路径 |
| `output_dir` | 位置参数 | 必填 | 输出目录（不存在会自动创建） |
| `--from N` | int | 1 | 起始章节编号（1-based，含） |
| `--to M` | int | 最后一章 | 结束章节编号（含） |
| `--precise` | 开关 | 关 | 用书签 `/Top` y 坐标精确裁剪页面，而非提取整页 |
| `--strip-headers` | 开关 | 关 | 自动检测并剔除重复出现的页眉页脚 |
| `--merge-cross-page` | 开关 | 关 | 合并被页面边界截断的文本段落和表格行 |
| `--ocr-text` | 开关 | 关 | 使用离线 OCR 提取文本，绕过 PDF 内嵌文本层乱码 |
| `--fitz-text` | 开关 | 关 | 使用 PyMuPDF 提取文本，表格仍由 pdfplumber 提取 |
| `--ocr-scale S` | float | 2.0 | OCR 渲染倍率；更高更准，但更慢 |

## 输出文件

- `output_dir/toc.json` — 所有提取章节的目录，字段：`{index, title, depth, page_start, page_end}`
- `output_dir/chapter_NNNN.json` — 每章一个文件，字段：`{index, title, depth, page_start, page_end, content[]}`，其中 content 每项为 `{type: "text", lines: ["..."]}` 或 `{type: "table", page, table_index, data: [[...]]}`

## 可选参数的使用判断

### `--precise`
所有书签含有 `/Top` 坐标时加，否则不加（脚本会报错退出）。

### `--strip-headers`
建议添加。

### `--merge-cross-page`
建议添加。

### `--ocr-text`
当 PDF 用 `pdfplumber` / `pypdf` / `PyMuPDF` 抽文本后出现系统性乱码时使用。常见原因是 PDF 内嵌字体的字符映射损坏，普通文本提取库都会读出错误字符；此时改用 OCR 更稳。

注意：

- OCR 模式仍然按书签切章节
- OCR 会比原生文本提取慢
- OCR 结果通常可读、可检索，但可能有少量空格粘连、`1/l` 混淆、项目符号识别不完美
- 当前 `--ocr-text` 模式下，表格会被按可读文本行输出，不再强保留原始表格网格

### `--fitz-text`
当 `pdfplumber.extract_text()` 输出为空或异常时使用。文本由 PyMuPDF 提取，表格仍保留为 `table`。

## 典型用法

```bash
# 全量提取，默认模式
python pdf_slicer.py manual.pdf out/

# 提取第 10–50 章，精确坐标切片（适合 API 参考手册）
python pdf_slicer.py manual.pdf out/ --from 10 --to 50 --precise

# 连续正文文档，有页眉页脚，段落跨页
python pdf_slicer.py manual.pdf out/ --strip-headers --merge-cross-page

# 全选项组合
python pdf_slicer.py manual.pdf out/ --from 10 --to 50 --precise --strip-headers --merge-cross-page

# 文本层乱码的 PDF：改走 OCR，并保留跨页正文合并
python pdf_slicer.py manual.pdf out/ --precise --ocr-text --strip-headers --merge-cross-page

# pdfplumber 文本抽取异常的 PDF：改走 PyMuPDF，表格仍保留
python pdf_slicer.py manual.pdf out/ --precise --fitz-text --strip-headers --merge-cross-page
```
