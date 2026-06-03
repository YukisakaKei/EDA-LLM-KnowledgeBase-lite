# HTMLView 切片提取脚本 — 实现计划

## 背景

PrimeTime htmlView_20 是 man page 格式的 HTML 参考手册，包含 7766 个独立的 HTML 文件，分布在 6 个子目录（command、attribute、variable、topic、shell、message）中。每个 HTML 文件是一个独立条目，无需 TOC 文件。

本脚本将 htmlView_20 目录切片为与现有知识库格式兼容的 JSON 文件（参考 `knowledge/Innovus/legacy/json/` 的 `chapter_NNNN.json` 格式）。

脚本设计为通用工具，适用于所有结构相同的 man page 格式 HTML 手册。

---

## 命令行接口

```bash
python htmlview_slicer.py <html_dir> <output_dir>
```

| 参数 | 说明 |
|------|------|
| `html_dir` | 包含 HTML 文件的目录（可递归包含子目录） |
| `output_dir` | 输出 JSON 文件的目录（保持与输入相同的子目录结构） |

**示例**：

```bash
# 处理 command 子目录
python htmlview_slicer.py \
  knowledge/PrimeTime/row/htmlView_20/command \
  knowledge/PrimeTime/json/htmlView_20/command

# 处理 message 子目录（包含子目录）
python htmlview_slicer.py \
  knowledge/PrimeTime/row/htmlView_20/message \
  knowledge/PrimeTime/json/htmlView_20/message
```

---

## 输入文件结构

htmlView_20 目录结构：

```
htmlView_20/
├── command/
│   ├── create_clock.html
│   ├── set_input_delay.html
│   └── ...（769 个文件）
├── attribute/
│   ├── cell_attributes.html
│   └── ...（35 个文件）
├── variable/
│   ├── arch.html
│   └── ...（513 个文件）
├── topic/
│   ├── collections.html
│   └── ...（17 个文件）
├── shell/
│   ├── primetime.html
│   └── pt_shell.html
└── message/
    ├── ADES/
    │   ├── ADES-002.html
    │   └── ...
    ├── AOCVM/
    └── ...（6430 个文件，分布在多个子目录）
```

每个 HTML 文件遵循统一的 man page 格式：

```html
<h1>create_clock</h1>
<h2><a id="NAME"></a>NAME</h2>
<div class="mpsection">
  <p><strong>create_clock</strong></p>
  <div id="shortdesc" class="mpindent">
    <p>Creates a clock object.</p>
  </div>
</div>
<h2><a id="SYNTAX"></a>SYNTAX</h2>
<div class="mpsection">
  <pre>string <strong>create_clock</strong> ...</pre>
</div>
<h2><a id="ARGUMENTS"></a>ARGUMENTS</h2>
...
```

---

## 实现步骤

### Step 1 — 遍历 HTML 文件

递归遍历 `html_dir` 目录，收集所有 `.html` 文件：

```python
def collect_html_files(html_dir):
    # 返回 [(relative_path, full_path), ...]
    # relative_path 用于保持输出目录结构
```

按文件名排序，生成连续的 index（1-based）。

### Step 2 — 解析单个 HTML 文件

对每个 HTML 文件：

1. **提取 title**：`<h1>` 标签的文本内容
2. **提取 content**：`<body>` 内的所有内容元素

```python
def parse_html_file(html_path):
    # 返回 {'title': str, 'content': [item, ...]}
```

**需要剥离的元素**：
- `<head>` — 元数据
- `<p>` 内的目录链接（文件开头的 `<a href="#NAME">NAME</a>` 列表）
- `<hr />` — 分隔线

### Step 3 — 内容元素识别与提取

在 `<body>` 内按 DOM 顺序遍历，识别以下元素类型：

#### 文本类（type: text）

| HTML 元素 | 处理方式 |
|-----------|---------|
| `<h2>`, `<h3>` | 提取标题文本（去掉 `<a id="...">` 锚点），作为 text item |
| `<p>` | 提取段落文本，保留内联 `<strong>`, `<em>`, `<code>` 的文本内容 |
| `<ul>`, `<ol>` | 递归提取列表项，每项一行，加 `- ` 或序号前缀 |
| `<div class="mpsection">` | 递归提取内部所有文本元素 |

**特殊处理**：
- `<span class="nowrap">` — 提取文本，忽略样式
- `<strong>`, `<em>` — 提取文本，不保留标记
- 内联 `<code>` — 保留文本内容

#### 代码块类（type: code）

`<pre>` 标签内容：

- 保留所有换行和缩进
- 去除内部 `<strong>`, `<em>` 标签，保留文本
- 每行作为 lines 数组的一个元素

#### 表格类（type: table）

`<table>` 结构：

- 第一行 `<tr>` 的 `<th>` 作为 headers
- 后续 `<tr>` 的 `<td>` 作为 rows
- 单元格内 `<br />` 替换为空格
- 单元格内 `<code>`, `<strong>` 保留文本内容
- 输出格式：`{"type": "table", "headers": [...], "rows": [[...], ...]}`

**注意**：部分 HTML 文件可能没有表格，只有 text 和 code。

### Step 4 — 文本清洗

所有提取文本统一处理：

- HTML 实体解码（BeautifulSoup 自动处理）
- 去除零宽字符（`​`, `‌`, `‍`, `﻿`, `­`, `⁠`, `᠎`）
- `&nbsp;` 和 `&#160;` 替换为普通空格
- 合并连续空白为单个空格
- 去除首尾空白
- 保留段落之间的空行（在 lines 数组中用空字符串表示）

```python
def clean_text(text):
    # 返回清洗后的字符串
```

### Step 5 — 内容分组规则

**text item 的 lines 数组**：

- 每个 `<p>` 段落独立成一个 text item
- `<h2>`, `<h3>` 标题独立成一个 text item
- 列表项合并为一个 text item，每项一行

**code item 的 lines 数组**：

- `<pre>` 标签内容按换行符分割为多行
- 保留空行

**table item**：

- 单个表格对应一个 table item
- headers 和 rows 分别存储

### Step 6 — 输出格式

每个 HTML 文件输出 `entry_{index:04d}.json`，格式：

```json
{
  "index": 1,
  "title": "create_clock",
  "depth": 0,
  "file": "command/create_clock.html",
  "content": [
    {
      "type": "text",
      "lines": ["NAME"]
    },
    {
      "type": "text",
      "lines": ["create_clock"]
    },
    {
      "type": "text",
      "lines": ["Creates a clock object."]
    },
    {
      "type": "text",
      "lines": ["SYNTAX"]
    },
    {
      "type": "code",
      "lines": [
        "string create_clock",
        "   -period period_value",
        "   [-name clock_name]",
        "   ..."
      ]
    },
    {
      "type": "text",
      "lines": ["Data Types"]
    },
    {
      "type": "code",
      "lines": [
        "period_value        float",
        "clock_name          string",
        "..."
      ]
    },
    {
      "type": "text",
      "lines": ["ARGUMENTS"]
    },
    {
      "type": "text",
      "lines": ["-period period_value"]
    },
    {
      "type": "text",
      "lines": ["Specifies the clock period in library time units. ..."]
    }
  ]
}
```

**字段说明**：

- `index`：文件序号（1-based，按文件名排序）
- `title`：`<h1>` 标签的文本
- `depth`：固定为 0（所有条目都是顶级）
- `file`：相对于 `html_dir` 的路径（如 `command/create_clock.html`）
- `content`：内容数组，每项包含 `type` 和 `lines`（或 `headers`/`rows`）

### Step 7 — 输出目录结构

保持与输入相同的子目录结构：

```
output_dir/
├── entry_0001.json
├── entry_0002.json
└── ...
```

或（如果输入有子目录）：

```
output_dir/
├── ADES/
│   ├── entry_0001.json
│   └── ...
├── AOCVM/
│   └── ...
└── ...
```

**文件命名规则**：
- 按全局顺序编号（不是每个子目录独立编号）
- 例如：command 目录的 769 个文件编号为 0001-0769

---

## 边界情况处理

| 情况 | 处理方式 |
|------|---------|
| HTML 文件解析失败 | 打印错误，跳过该文件，继续处理 |
| `<h1>` 标签不存在 | 使用文件名（去掉 `.html`）作为 title |
| content 为空 | 输出空数组 `[]` |
| 表格没有 `<th>` | 第一行 `<td>` 作为 headers |
| `<pre>` 标签嵌套 `<pre>` | 只提取最外层 |
| HTML 实体和特殊字符 | BeautifulSoup 自动解码，再做二次清洗 |
| 子目录结构 | 保持原有子目录结构，但 index 全局连续 |

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

# 处理 command 子目录
python htmlview_slicer.py \
  ../knowledge/PrimeTime/row/htmlView_20/command \
  ../knowledge/PrimeTime/json/htmlView_20/command

# 验证文件数量
find ../knowledge/PrimeTime/row/htmlView_20/command -name "*.html" | wc -l
# 应为 769
find ../knowledge/PrimeTime/json/htmlView_20/command -name "entry_*.json" | wc -l
# 应为 769

# 抽查 create_clock 条目
jq '.' ../knowledge/PrimeTime/json/htmlView_20/command/entry_0001.json
```

**验证要点**：
- 文件数量与输入 HTML 文件数一致
- `create_clock` 的 SYNTAX 章节代码块格式完整
- `cell_attributes` 的属性定义顺序与 HTML DOM 顺序一致
- 表格的 headers 和 rows 数量正确
- 特殊字符（`<`, `>`, `&`）正确转义

---

## 与 html_slicer.py 的差异

| 特性 | html_slicer.py | htmlview_slicer.py |
|------|----------------|-------------------|
| 输入结构 | Confluence 导出，需 TOC 文件 | man page 格式，无 TOC |
| 章节层级 | 多层级（depth 0-2） | 单层级（depth 固定为 0） |
| 文件对应 | 一个 HTML 可能对应多个章节（通过 anchor） | 一个 HTML 对应一个条目 |
| 输出命名 | `chapter_NNNN.json` | `entry_NNNN.json` |
| 索引文件 | 生成 `toc.json` | 不生成索引文件 |
| 子目录 | 不支持 | 支持递归子目录 |

---

## 实现优先级

1. **核心功能**：遍历文件、解析 HTML、提取 text/code/table、输出 JSON
2. **文本清洗**：HTML 实体、零宽字符、空白处理
3. **边界情况**：缺失 `<h1>`、空 content、解析失败
4. **子目录支持**：保持输入目录结构
5. **性能优化**：批量处理、进度显示

---

## 预期输出

处理完成后，每个子目录包含对应数量的 `entry_NNNN.json` 文件：

- `command/` — 769 个文件
- `attribute/` — 35 个文件
- `variable/` — 513 个文件
- `topic/` — 17 个文件
- `shell/` — 2 个文件
- `message/` — 6430 个文件（保持子目录结构）

总计：7766 个 JSON 文件
