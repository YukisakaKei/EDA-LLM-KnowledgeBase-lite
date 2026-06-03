---
name: slice-htmlview
description: 对 man page 格式的 HTML 手册进行切片，提取每个条目内容为 JSON，并检查切片质量。
---

# HTMLView 切片技能

## 目标
将 man page 格式的 HTML 手册（如 PrimeTime htmlView）切片，输出每个条目的结构化 JSON，并抽查质量。

## 脚本位置
脚本位于项目根目录下的 `scripts/htmlview_slicer.py`，同目录下还有 `htmlview_slicer_usage.md` 和 `htmlview_slicer_plan.md`。

## 步骤

### 1. 确认参数

从用户输入中获取：
- HTML 手册目录路径（包含所有 HTML 文件，支持子目录）
- 输出目录

**注意**：与 `slice-html` 不同，此脚本**不需要 TOC 文件**，每个 HTML 文件独立成为一个条目。

### 2. 检查输入目录

确认输入目录存在，并统计 HTML 文件数量：

```bash
find <html_dir> -name "*.html" | wc -l
```

快速预览几个 HTML 文件的结构（`<h1>` 标题、`<h2>` 章节、`<pre>` 代码块、`<ul>` 列表），确认是 man page 格式。

### 3. 运行切片脚本

**参数说明**

| 参数 | 类型 | 必填 | 含义 |
|---|---|---|---|
| `html_dir` | 位置参数 | 是 | 包含 HTML 文件的目录（支持子目录） |
| `output_dir` | 位置参数 | 是 | 输出目录（自动创建） |

**直接运行**

```bash
python scripts/htmlview_slicer.py <html_dir> <output_dir>
```

脚本会：
- 递归扫描所有 `.html` 文件
- 按文件名排序，生成全局连续的 index
- 每个 HTML 文件输出一个 `entry_NNNN.json`
- 保持子目录结构（如 message/ADES/）

### 4. 验证完成

切片完成后，验证文件数量：

```bash
# 统计输入 HTML 文件数
find <html_dir> -name "*.html" | wc -l

# 统计输出 JSON 文件数
find <output_dir> -name "entry_*.json" | wc -l
```

两者应该完全一致。

### 5. 质量抽查

随机抽取 3-5 个 `entry_NNNN.json`，对每个条目检查：

**内容完整性**
- `<h1>` 标题是否正确提取到 `title` 字段
- NAME、SYNTAX、ARGUMENTS、DESCRIPTION 等章节是否完整
- 代码块（`<pre>`）是否保留了缩进和换行
- 列表（`<ul>`/`<ol>`）是否正确转换为 Markdown 格式（`- 项目` 或 `1. 项目`）

**文本清洗**
- 段落文本中是否有多余的 `\n` 换行符
- HTML 实体是否正确解码（`&nbsp;` → 空格，`&lt;` → `<`）
- 零宽字符是否已去除（`​`、`‌`、`‍` 等）

**格式正确性**
- JSON 结构是否符合规范：`{index, title, depth, file, content[]}`
- content 数组中的 type 是否只有 `text` 和 `code`（man page 格式无表格）
- `file` 字段路径是否使用 `/` 分隔符（而非 `\`）

**边界情况**
- 短条目（只有 NAME 和 SEE ALSO）是否正确处理
- 包含特殊字符的文件名是否正确处理
- 非 UTF-8 编码的文件是否成功转换

将发现的问题汇报给用户，说明是系统性问题还是个别文件问题。

## 与 slice-html 的区别

| 特性 | slice-html | slice-htmlview |
|------|-----------|----------------|
| 输入格式 | Confluence 导出 | man page 格式 |
| TOC 文件 | 必需 | 不需要 |
| 章节层级 | 多层级（depth 0-2） | 单层级（depth 固定为 0） |
| 文件对应 | 一个 HTML 可能对应多个章节 | 一个 HTML 对应一个条目 |
| 输出命名 | `chapter_NNNN.json` | `entry_NNNN.json` |
| 索引文件 | 生成 `toc.json` | 不生成索引文件 |
| 子目录 | 不支持 | 支持递归子目录 |
| 表格 | 支持 | 支持（但 htmlView 中无表格） |

## 典型使用场景

```bash
# 处理单个子目录
python scripts/htmlview_slicer.py \
  knowledge/PrimeTime/row/htmlView_20/command \
  knowledge/PrimeTime/json/htmlView_20/command

# 批量处理所有子目录
for dir in command attribute variable topic shell message; do
  python scripts/htmlview_slicer.py \
    knowledge/PrimeTime/row/htmlView_20/$dir \
    knowledge/PrimeTime/json/htmlView_20/$dir
done
```
