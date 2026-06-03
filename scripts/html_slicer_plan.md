# HTML 切片提取脚本 — 实现计划

## 背景

Innovus User Guide 21.1 版本以 Confluence 导出的 HTML 格式提供，每章是独立的 HTML 文件。相比 PDF，HTML 结构更清晰、表格提取更可靠、内容顺序有 DOM 保证。本脚本将 HTML 目录切片为与 `pdf_slicer.py` 输出格式兼容的 JSON 文件。

脚本设计为通用工具，适用于所有结构相同的 Confluence 导出 HTML 手册，不硬编码任何文件名。

---

## 命令行接口

```bash
python html_slicer.py <html_dir> <output_dir> --toc <toc_file> [--from N] [--to M] [--skip-empty]
```

| 参数 | 说明 |
|------|------|
| `html_dir` | 包含所有章节 HTML 文件的目录 |
| `output_dir` | 输出 JSON 文件的目录 |
| `--toc <toc_file>` | TOC HTML 文件路径（必填），用于解析章节层级和顺序 |
| `--from N` | 从第 N 章开始（1-based，默认 1） |
| `--to M` | 到第 M 章结束（含，默认全部） |
| `--skip-empty` | 可选：跳过正文内容为空的章节（仅含子章节链接列表的索引页） |

---

## 输入文件结构

Confluence 导出的 HTML 手册目录结构：

```
html_dir/
├── innovusUGTOC.html        ← TOC 文件（由 --toc 参数指定）
├── About_This_Manual.html
├── Introduction_and_Setup_Guide.html
├── Product_and_Licensing_Information.html
├── Clock_Tree_Synthesis.html
├── ...
├── attachments/             ← 图片附件（忽略）
├── images/                  ← 图标（忽略）
└── styles/                  ← CSS（忽略）
```

---

## 实现步骤

### Step 1 — 解析 TOC，构建章节列表

TOC 文件（如 `innovusUGTOC.html`）包含完整的层级结构：

```html
<h2><a href="Introduction_and_Setup_Guide.html">Introduction and Setup Guide</a></h2>
<dd><a href="Product_and_Licensing_Information.html">Product and Licensing Information</a></dd>
<dd><a href="Getting_Started.html">Getting Started</a></dd>
```

解析规则：

| HTML 元素 | depth | 说明 |
|-----------|-------|------|
| `<h2>` 内的 `<a>` | 0 | 顶级章节 |
| `<dd>` 内的 `<a>`（一级） | 1 | 二级章节 |
| `<dd>` 内嵌套 `<dd>` 的 `<a>` | 2 | 三级章节 |

**已知格式问题（所有 `__211` 手册）：** Confluence 导出的 TOC 中，每个顶级章节有两个相邻 `<h2>`，第一个是纯数字编号（"1"、"2"...）或空文本，第二个才是真实标题。需过滤掉纯数字/空文本的 `<h2>` 条目。

每个条目提取：
- `title`：链接文本（过滤掉纯数字或空文本的 `<h2>` 条目）
- `file`：`href` 属性（文件名，去掉锚点 `#` 后的部分）
- `anchor`：`href` 中 `#` 后的锚点（若有），用于定位章节在文件内的起始位置
- `depth`：由 HTML 嵌套层级决定

```python
def parse_toc(toc_path):
    # 返回 [{'index', 'title', 'file', 'anchor', 'depth', 'parent'}, ...]
```

### Step 2 — 过滤章节范围

按 `--from` / `--to` 参数过滤章节列表（1-based index）。

### Step 3 — 提取单章内容

对每个章节条目，读取对应的 HTML 文件，提取 `<div class="wiki-content group" id="main-content">` 内的内容。

若章节有 `anchor`，则从该锚点对应的标题元素开始提取，到下一个同级或更高级标题结束（用于同一 HTML 文件被多个 TOC 条目引用的情况）。

锚点定位分两条路径：

- **直接子元素路径**：目标 heading 是 `main-content` 的直接子元素（标准 Confluence 导出），直接从该 heading 开始向下收集顶层兄弟节点，遇到同级或更高级 heading 停止。
- **嵌套路径**：目标 heading 嵌套在 `<p>` 或 `<div>` 容器内（部分文档的 Confluence 导出格式），先在容器内从该 heading 收集后续兄弟节点，再继续收集 `main-content` 层面容器之后的顶层节点，遇到同级或更高级 heading 停止。

```python
def extract_chapter_content(html_path, anchor=None):
    # 返回 content 列表，每项为 text item 或 table item
```

**需要剥离的 boilerplate：**
- `<header>` — 导航栏
- `<footer>` — 版权和翻页链接
- `<div id="cad_image_modal">` — 图片弹窗
- `<div class="toc-macro">` — 章节内自动生成的目录
- `<script>` / `<style>` 标签

### Step 4 — 内容元素识别与提取

在 `main-content` 内按 DOM 顺序遍历，识别以下元素类型：

#### 文本类

| HTML 元素 | 处理方式 |
|-----------|---------|
| `<p>` | 提取文本，保留内联 `<code>` 内容 |
| `<h2>`, `<h3>`, `<h4>` | 提取标题文本，作为独立 text item |
| `<ul>`, `<ol>` | 递归提取列表项，每项一行，加 `- ` 或序号前缀 |
| `<div class="confluence-information-macro-*">` | 提取 body 文本，前缀标注类型（`[NOTE]`, `[WARNING]`, `[TIP]`） |

#### 表格类

`<div class="table-wrap"><table class="wrapped confluenceTable">` 结构：

- 遍历 `<tr>`，每行提取所有 `<th>` / `<td>` 的文本
- 单元格内 `<br />` 替换为空格
- 单元格内 `<code>` 保留文本内容
- `colspan` / `rowspan` 暂不展开，保留原始单元格数量
- 输出为二维数组 `data: [[row0col0, row0col1, ...], ...]`

#### 代码块

`<p style="margin-left: 30.0px;"><code>...</code></p>` 或多行缩进代码段：

- 识别连续的缩进 `<code>` 段落，合并为单个 text item
- 内容前缀标注 `[CODE]` 以便 LLM 识别

### Step 5 — 文本清洗

所有提取文本统一处理：
- 去除零宽字符（`​\u200b \u200c \u200d \ufeff \u00ad \u2060 \u180e \u00a0­`）
- 去除 HTML 实体（`&nbsp;` → 空格，`&#160;` → 空格等）
- 合并连续空白为单个空格
- 去除首尾空白

每个 `<p>` / 标题 / 列表 / NOTE 各自独立成一个 text item，`lines` 数组只有一个元素。不做跨元素合并。

### Step 6 — 输出格式

每章输出 `chapter_{index:04d}.json`，格式与 `pdf_slicer.py` 兼容：

```json
{
  "index": 10,
  "title": "Clock Tree Synthesis",
  "depth": 1,
  "file": "Clock_Tree_Synthesis.html",
  "content": [
    {
      "type": "text",
      "lines": ["Overview"]
    },
    {
      "type": "text",
      "lines": ["The Innovus Implementation System offers Clock Tree Synthesis (CTS)..."]
    },
    {
      "type": "table",
      "table_index": 0,
      "data": [
        ["Setting", "Default", "Behavior in place_opt_design"],
        ["false (default)", "false", "No clock tree building"]
      ]
    },
    {
      "type": "text",
      "lines": ["[NOTE] PostCTS configuration – CCOpt combines CTS with datapath optimization..."]
    }
  ]
}
```

与 PDF 输出的差异：
- 无 `page_start` / `page_end`（HTML 无页码概念），改为 `file` 字段记录来源文件名
- table item 无 `page` / `table_index` 字段（无意义），仅保留 `table_index` 作为文件内序号
- 新增 `[NOTE]` / `[WARNING]` / `[CODE]` 前缀标注

同时输出 `toc.json`。

---

## toc.json 设计

```json
{
  "doc": "innovusUG__211",
  "chapters": [
    {
      "index": 1,
      "title": "About This Manual",
      "depth": 0,
      "parent": null,
      "file": "chapter_0001.json",
      "source_file": "About_This_Manual.html"
    },
    {
      "index": 2,
      "title": "Introduction and Setup Guide",
      "depth": 0,
      "parent": null,
      "file": "chapter_0002.json",
      "source_file": "Introduction_and_Setup_Guide.html"
    },
    {
      "index": 3,
      "title": "Product and Licensing Information",
      "depth": 1,
      "parent": "Introduction and Setup Guide",
      "file": "chapter_0003.json",
      "source_file": "Product_and_Licensing_Information.html"
    }
  ]
}
```

| 字段 | 说明 |
|------|------|
| `doc` | 手册标识（输出目录名） |
| `index` | 章节序号（TOC 顺序，1-based） |
| `title` | 章节标题 |
| `depth` | 层级深度（0 = 顶级） |
| `parent` | 最近上级标题，depth=0 时为 null |
| `file` | 对应 chapter JSON 文件名 |
| `source_file` | 来源 HTML 文件名 |

---

## 关键边界情况

| 情况 | 处理方式 |
|------|---------|
| 章节 HTML 文件不存在 | 打印警告，跳过该章节，继续处理 |
| 同一 HTML 文件被多个 TOC 条目引用 | 按 anchor 定位各自范围分别提取；heading 为直接子元素时走标准路径，嵌套在容器内时走嵌套路径（先收集容器内兄弟，再继续顶层兄弟） |
| 章节内容为空（仅含子章节链接） | 默认保留空 content；`--skip-empty` 时跳过 |
| 表格内嵌套表格 | 只提取最外层表格，内层作为文本处理 |
| `colspan` / `rowspan` 合并单元格 | 保留原始结构，不展开 |
| HTML 实体和特殊字符 | BeautifulSoup 自动解码，再做二次清洗 |
| `<h2>` title 为纯数字或空（Confluence 章节编号装饰） | 跳过该条目，不计入章节列表 |

---

## 依赖

```
beautifulsoup4
lxml        # BS4 解析器，速度快于 html.parser
```

---

## 验证方法

```bash
cd scripts

# 基本用法
python html_slicer.py ../knowledge/Innovus/legacy/row/innovusUG__211 \
    ../knowledge/Innovus/legacy/json/innovusUG__211 \
    --toc ../knowledge/Innovus/legacy/row/innovusUG__211/innovusUGTOC.html

# 指定范围
python html_slicer.py ../knowledge/Innovus/legacy/row/innovusUG__211 \
    ../knowledge/Innovus/legacy/json/innovusUG__211 \
    --toc ../knowledge/Innovus/legacy/row/innovusUG__211/innovusUGTOC.html \
    --from 5 --to 10

# 跳过空章节
python html_slicer.py ../knowledge/Innovus/legacy/row/innovusUG__211 \
    ../knowledge/Innovus/legacy/json/innovusUG__211 \
    --toc ../knowledge/Innovus/legacy/row/innovusUG__211/innovusUGTOC.html \
    --skip-empty
```

**验证要点：**
- `toc.json` 中章节数量与 TOC 文件条目数一致
- `Clock_Tree_Synthesis` 章节的表格行列数与 HTML 原文一致
- `CCOpt_Properties` 章节的属性定义顺序与 HTML DOM 顺序一致
- Note/Warning 框内容带有 `[NOTE]` / `[WARNING]` 前缀
- 代码示例带有 `[CODE]` 前缀且缩进内容完整
