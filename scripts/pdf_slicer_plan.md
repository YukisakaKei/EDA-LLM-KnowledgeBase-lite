# PDF 切片提取脚本 — 实现计划

## 背景

项目目标是从 EDA 工具手册（如 Innovus DBA 参考手册）构建 LLM 知识库。新脚本需要：

- 按 PDF 目录（书签）切片，支持两种模式
- 增量提取，每章提取完立即输出并释放内存
- 每章文本 + 表格合并到同一个 JSON 文件
- 支持指定输入/输出路径和提取的章节范围（第 n 到第 m 章）

---

## 命令行接口

```bash
python pdf_slicer.py <pdf路径> <输出目录> [--from N] [--to M] [--merge-cross-page] [--strip-headers] [--precise] [--fitz-text | --ocr-text] [--ocr-scale S]
```

| 参数 | 说明 |
|------|------|
| `pdf路径` | 输入 PDF 文件路径 |
| `输出目录` | 输出 JSON 文件的目录 |
| `--from N` | 从第 N 章开始（1-based，默认 1） |
| `--to M` | 到第 M 章结束（含，默认全部） |
| `--merge-cross-page` | 可选：合并跨页的文本段落和表格 |
| `--strip-headers` | 可选：自动检测并剔除页眉页脚 |
| `--precise` | 可选：启用书签 `/Top` y 坐标精确切片；若任意书签缺少坐标则报错退出 |
| `--ocr-text` | 可选：使用离线 OCR 提取文本，绕过 PDF 内嵌文本层乱码 |
| `--fitz-text` | 可选：使用 PyMuPDF 提取文本，表格仍由 pdfplumber 提取 |
| `--ocr-scale S` | 可选：OCR 渲染倍率，默认 `2.0`；越高越准，但越慢 |

---

## 两种切片模式

### 默认模式（页码范围）

沿用现有逻辑：

```
chapter[i].page_start = outline[i]['page']          # 0-based，pypdf 直接返回
chapter[i].page_end   = max(page_start+1, outline[i+1]['page'] + 1)
最后一章的 page_end   = total_pages
```

提取 `[page_start, page_end)` 范围内的所有页面，边界页与相邻章节共享（存在轻微内容重叠）。

### `--precise` 模式（书签坐标切片）

pypdf 书签包含 `/XYZ` 目标，提供 `(page_index, top_y)` 锚点：

```
dbAddCellObs    → page=58, top=469.44
dbAddCoverInst  → page=59, top=552.0
dbAddDeCapAtLoc → page=59, top=141.12
```

**启动时校验**：遍历所有书签，若任意一项缺少 `/Top` 字段（值为 `None`），立即报错退出：

```
Error: bookmark "XYZ" (index N) has no /Top coordinate. --precise requires all bookmarks to have /Top. Aborting.
```

提取范围定义：
- **起点**：`(page_i, plumber_y_i)` — 书签所在页，从该 y 坐标开始
- **终点**：`(page_{i+1}, plumber_y_{i+1})` — 下一书签所在页，到该 y 坐标结束（不含）
- **最后一章**：终点为最后一页末尾

坐标转换（PDF 原生 y 从底部算，pdfplumber 从顶部算）：
```python
plumber_y = page.height - pdf_top
```

---

## 文本提取后端

章节边界仍然只有两种切片模式（默认页码范围 / `--precise` 坐标切片），但正文提取现在支持两种后端：

### 默认后端：PDF 文本层

- 使用 `pdfplumber` 提取正文和表格
- 能保留表格网格，速度更快
- 适合大多数正常 PDF

### `--fitz-text` 后端：PyMuPDF 文本层

- 使用 `PyMuPDF` 提取正文，使用 `pdfplumber` 提取表格
- 文本和表格按 `_top` 排序后输出

### `--ocr-text` 后端：离线 OCR

- 使用 `PyMuPDF` 把当前裁剪区域渲染成图片，再用 `RapidOCR` 识别
- 适合这类“书签正常、页面显示正常，但复制/抽文本大量乱码”的 PDF
- 章节边界仍按书签切，不改变切片逻辑，只替换文本提取来源
- 当前实现中，OCR 模式下的表格会退化为按阅读顺序输出的文本行，不再强保留原始表格网格
- OCR 会比文本层提取慢，且可能存在少量空格粘连、`1/l` 混淆、项目符号识别不完美

---

## 实现步骤

### Step 1 — 提取书签

在 `pdf_slicer.py` 中直接用 pypdf 提取，不再复用 `plain_parser.extract_outlines_only()`（该方法丢弃了 `/Top`）：

```python
def extract_outlines(pdf_path):
    # 返回 [{'title', 'depth', 'page', 'top'}, ...]
    # page: 0-based index（pypdf 直接返回整数）
    # top:  PDF 原生 y 坐标（float），无则为 None
```

### Step 2 — 校验（仅 `--precise`）

```python
if args.precise:
    missing = [o for o in outlines if o['top'] is None]
    if missing:
        print(f"Error: bookmark \"{missing[0]['title']}\" (index {missing[0]['index']}) has no /Top coordinate. --precise requires all bookmarks to have /Top. Aborting.")
        sys.exit(1)
```

### Step 3 — 构建章节列表

两种模式共用同一章节列表结构，差异仅在 `end` 字段含义：

```python
# 默认模式
{'page_start': int, 'page_end': int}   # 0-based，半开区间 [start, end)

# --precise 模式
{'start_page': int, 'start_y': float,  # pdfplumber 坐标
 'end_page':   int, 'end_y':   float}
```

### Step 4 — 提取内容

**默认模式**：遍历 `[page_start, page_end)` 页面，每页完整提取（现有逻辑不变）。

**`--precise` 模式**：对每章按三段处理：

1. **首页**（`start_page`）：`page.crop((x0, start_y, x1, page_h))`
2. **中间页**（`start_page < p < end_page`）：完整提取
3. **末页**（`end_page`，若与首页不同）：`page.crop((x0, 0, x1, end_y))`
4. **首页 == 末页**（整章在同一页）：`page.crop((x0, start_y, x1, end_y))`

每段裁剪后，按以下逻辑提取文本和表格，按 top 坐标排序。

#### 4A. 默认文本层后端

**单页内文本与表格的顺序保持**

`_extract_page_content` 的提取逻辑：

1. `page.find_tables()` 获取所有表格及其 bbox
2. 定义 `outside_tables` filter（word 级别），过滤掉表格内的字符
3. `filtered.extract_words()` 拿到所有非表格 word，每个 word 带有 `top` 坐标
4. 按表格的 y 区间对 words 分桶：
   - `word.top < table[0].bbox[1]` → 第 0 组（第一个表格之前）
   - `table[0].bbox[3] < word.top < table[1].bbox[1]` → 第 1 组（表格 0 和表格 1 之间）
   - 以此类推，最后一个表格之后的 words 归入最后一组
5. 对每个非空分桶，用 `filtered.crop((x0, bucket_top, x1, bucket_bot)).extract_text()` 提取文本，生成独立 text item；`_top` 取该桶第一个 word 的 `top`
6. 表格 item 保持不变，`_top` 取 `table.bbox[1]`
7. 所有 item 按 `_top` 排序后输出

这样文本过滤精度不变（仍用 word 级别的 `outside_tables` filter），文本分组依据 word 的实际 `top` 坐标而非表格 bbox 裁剪，不会截断紧贴表格边缘的文本行，横向并排表格也能正确处理。

#### 4B. OCR 后端（`--ocr-text`）

当 PDF 文本层系统性乱码时，改用 OCR：

1. 用 `PyMuPDF` 打开原 PDF
2. 对当前章节页的裁剪区域 `page.bbox` 按 `--ocr-scale` 渲染为 PNG
3. 用 `RapidOCR` 的本地模型识别文字框和文本
4. 将 OCR 框坐标映射回当前裁剪页坐标系
5. 按 `(top, x0)` 排序，并根据相邻行距离聚类为 `text` items

实现约束：

- OCR 模式不依赖 PDF 内嵌文字，因此能绕开坏掉的字体映射
- OCR 模式当前只输出 `text` items，不输出 `table` items
- 为避免联网下载，`RapidOCR` 强制使用包内本地模型文件：
  - `ch_PP-OCRv4_det_infer.onnx`
  - `ch_ppocr_mobile_v2.0_cls_infer.onnx`
  - `ch_PP-OCRv4_rec_infer.onnx`
  - `ppocr_keys_v1.txt`

### Step 5 — `--strip-headers` 叠加

两种模式均支持。检测到的 `header_bottom` / `footer_top` 与裁剪区间叠加：
- `effective_top = max(crop_top, header_bottom)`
- `effective_bottom = min(crop_bottom, footer_top)`

`detect_header_footer_margins()` 签名增加 `page_indices` 参数，由调用方传入采样页的索引列表，不再内部固定取前 N 页：

```python
def detect_header_footer_margins(pdf, page_indices):
```

调用方（`main()`）从所有章节的页面中随机抽取约 20 页（跳过目录页，仅从第一章起始页之后的正文页中采样），传给该函数。正文内容因章节不同而各异，不会在多页中重复出现，不会达到阈值；真正的页眉在每页都出现，能被稳定检测到。

### Step 6 — 零宽字符清洗与换行处理

所有提取的文本在写入 content 前统一去除零宽字符（`​\u200b \u200c \u200d \ufeff \u00ad­`）。

正文（text 类型）：按 `\n` 拆分为 `lines` 数组，每元素一行。

表格单元格：`\n` 替换为空格，保持字符串格式。单元格内的换行是 PDF 排版产生的，不是语义分隔，替换为空格后内容可读性更好，且不影响 grep 输出量。

OCR 正文：先对单行做空白折叠，再按相邻行距离聚类成 `lines`。

### Step 7 — `--merge-cross-page`（基本不变）

对相邻页的首尾 content 项做文本/表格合并判断，逻辑不变。

补充说明：

- 默认后端下，可能出现 `text` / `table` 混合
- OCR 后端下，当前只有 `text`

### Step 8 — 输出格式

每章输出 `chapter_{index:04d}.json`：

```json
{
  "index": 10,
  "title": "dbAddCellObs",
  "depth": 2,
  "page_start": 59,
  "page_end": 60,
  "content": [
    {"type": "text", "lines": ["第一行", "第二行", "第三行"]},
    {"type": "table", "page": 59, "table_index": 0, "data": [...]}
  ]
}
```

text 类型的 `text` 字段改为 `lines` 数组，每个元素对应原文本中以 `\n` 分隔的一行。空行保留为空字符串 `""`。grep 命中时只输出匹配行，不再输出整段内容。

`page_start` / `page_end` 存储印刷页码（0-based index + 1），两种模式均如此。

同时输出 `toc.json`。

---

## 关键边界情况

| 情况 | 默认模式 | `--precise` 模式 |
|------|---------|-----------------|
| 同页多章 | 边界页被多章共享（轻微重叠） | 按 y 坐标精确分割，无重叠 |
| 整章在同一页 | 提取整页 | crop `[start_y, end_y]` |
| 章节跨多页 | 提取整个页码范围 | 首尾 crop，中间完整 |
| 最后一章 | end = total_pages | end = 最后一页末尾 |
| 书签无 `/Top` | 正常运行（不使用坐标） | 报错退出 |

额外的 OCR 边界：

| 情况 | `--ocr-text` 模式 |
|------|------------------|
| PDF 文本层乱码 | 可绕过，通常恢复为可读文本 |
| 表格结构要求严格 | 不适合，当前只输出文本行 |
| 页眉页脚残留 | 建议叠加 `--strip-headers` |
| 极小字体或稠密页面 | 可提高 `--ocr-scale`，但速度会下降 |

---

## 验证方法

```bash
cd workspcace/scripts

# 默认模式（页码范围）
python pdf_slicer.py ../row/innovusDBAref__18p11.pdf ../wiki/innovus_page --from 10 --to 15

# 精确模式（坐标切片）
python pdf_slicer.py ../row/innovusDBAref__18p11.pdf ../wiki/innovus_coord --from 10 --to 15 --precise

# 精确模式 + 全部选项
python pdf_slicer.py ../row/innovusDBAref__18p11.pdf ../wiki/innovus_coord_full --from 10 --to 15 --precise --strip-headers --merge-cross-page

# 文本层乱码的 PDF：改走 OCR，并保留跨页正文合并
python pdf_slicer.py manual.pdf out_ocr/ --from 10 --to 15 --precise --ocr-text --strip-headers --merge-cross-page

# pdfplumber 文本抽取异常的 PDF：改走 PyMuPDF，表格仍保留
python pdf_slicer.py manual.pdf out_fitz/ --from 10 --to 15 --precise --fitz-text --strip-headers --merge-cross-page
```

预期（`--precise`）：`chapter_0010.json` 的 content 只包含 `dbAddCellObs` 的参数表、Command Order、Example，不含 `dbAddCoverInst` 的任何内容。

预期（`--precise --ocr-text --merge-cross-page`）：当 PDF 文本层存在系统性乱码时，章节正文恢复为可读文本，章节边界仍按书签正确切分，跨页续写段落尽量合并。

---

## toc.json 设计

chapter JSON 的 text 类型内容以 `lines` 数组存储，grep 命中时只输出匹配行。toc.json 作为轻量索引，AI 先 grep toc.json 定位章节文件名，再按需读取对应 chapter JSON。

```json
{
  "doc": "innovusDBAref",
  "chapters": [
    { "index": 1, "title": "About This Manual", "depth": 0, "parent": null, "page_start": 3, "page_end": 54, "file": "chapter_0001.json" },
    { "index": 2, "title": "Audience", "depth": 1, "parent": "About This Manual", "page_start": 54, "page_end": 55, "file": "chapter_0002.json" }
  ]
}
```

| 字段 | 说明 |
|------|------|
| `doc` | 手册标识（输出目录名） |
| `index` | 章节序号 |
| `title` | 书签标题，grep 主要目标 |
| `depth` | 书签层级 |
| `parent` | 最近上级标题，depth=0 时为 null |
| `page_start` / `page_end` | 印刷页码 |
| `file` | 对应 chapter JSON 文件名 |
