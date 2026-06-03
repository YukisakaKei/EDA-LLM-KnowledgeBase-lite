# html_slicer.py — 使用说明

## 命令格式

```bash
python html_slicer.py <html_dir> <output_dir> --toc <toc_file> [--from N] [--to M] [--skip-empty]
```

## 参数说明

| 参数 | 类型 | 默认值 | 含义 |
|---|---|---|---|
| `html_dir` | 位置参数 | 必填 | 包含章节 HTML 文件的目录 |
| `output_dir` | 位置参数 | 必填 | 输出目录（不存在会自动创建） |
| `--toc` | 路径 | 必填 | TOC HTML 文件路径 |
| `--from N` | int | 1 | 起始章节编号（1-based，含） |
| `--to M` | int | 最后一章 | 结束章节编号（含） |
| `--skip-empty` | 开关 | 关 | 跳过正文内容为空的章节（仅含子章节链接的索引页） |

## 输出文件

- `output_dir/toc.json` — 所有提取章节的目录，字段：`{index, title, depth, parent, file, source_file}`
- `output_dir/chapter_NNNN.json` — 每章一个文件，字段：`{index, title, depth, file, content[]}`，其中 content 每项为 `{type: "text", lines: ["..."]}` 或 `{type: "table", table_index, data: [[...]]}`

## 典型用法

```bash
# 全量提取
python html_slicer.py manual_dir/ out/ --toc manual_dir/TOC.html

# 提取第 5-20 章
python html_slicer.py manual_dir/ out/ --toc manual_dir/TOC.html --from 5 --to 20

# 跳过无正文内容的索引章节
python html_slicer.py manual_dir/ out/ --toc manual_dir/TOC.html --skip-empty
```
