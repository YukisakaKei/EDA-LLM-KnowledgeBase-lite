# htmlview_slicer.py — 使用说明

## 命令格式

```bash
python htmlview_slicer.py <html_dir> <output_dir>
```

## 参数说明

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `html_dir` | 位置参数 | 是 | 包含 HTML 文件的目录（支持子目录） |
| `output_dir` | 位置参数 | 是 | 输出目录（不存在会自动创建） |

## 输出文件

- `output_dir/entry_NNNN.json` — 每个 HTML 文件对应一个 JSON 文件
- 每个条目包含：`{index, title, depth, file, content[]}`
- 内容项类型：`{type: "text", lines: [...]}` 或 `{type: "code", lines: [...]}`

## 典型用法

```bash
# 处理单个目录
python htmlview_slicer.py \
  knowledge/PrimeTime/row/htmlView_20/command \
  knowledge/PrimeTime/json/htmlView_20/command

# 批量处理所有子目录
for dir in command attribute variable topic shell message; do
  python htmlview_slicer.py \
    knowledge/PrimeTime/row/htmlView_20/$dir \
    knowledge/PrimeTime/json/htmlView_20/$dir
done
```

## 主要特性

- **自动编码检测** — UTF-8 失败时自动回退到 latin-1/cp1252
- **内容类型** — 提取文本段落、代码块、列表
- **保留结构** — 保持子目录层级和代码缩进
- **Markdown 列表** — 将 `<ul>` 转换为 `- 项目`，`<ol>` 转换为 `1. 项目`
- **文本清洗** — 去除 HTML 实体、零宽字符、多余空白

## 输出格式示例

```json
{
  "index": 41,
  "title": "create_clock",
  "depth": 0,
  "file": "create_clock.html",
  "content": [
    {
      "type": "text",
      "lines": ["Creates a clock object."]
    },
    {
      "type": "code",
      "lines": [
        "string create_clock",
        "   -period period_value",
        "   [-name clock_name]"
      ]
    },
    {
      "type": "text",
      "lines": [
        "- status can be OFF or FULL_ON",
        "- Voltage value must be defined"
      ]
    }
  ]
}
```

## 注意事项

- 无需 TOC 文件（与 `html_slicer.py` 不同）
- 每个 HTML 文件生成一个独立的 JSON 条目
- index 在所有文件中全局连续（按文件名排序）
- 专为 man page 格式的 HTML 文档设计
