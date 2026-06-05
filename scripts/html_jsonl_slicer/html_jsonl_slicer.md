# html_jsonl_slicer.py

`html_jsonl_slicer.py` 将 Confluence 风格 HTML 手册按 TOC 切分为单个 JSONL 文件。脚本复用旧 `scripts/html_slicer.py` 的 TOC 解析和正文抽取逻辑，只替换写入层，因此内容提取行为与旧目录式 JSON slicer 保持一致。

## 核心函数

| 函数 | 作用 | 输入 | 输出 |
|---|---|---|---|
| `ensure_utf8_stdio()` | 在 Windows GBK 终端下将标准输出切到 UTF-8，避免中文日志乱码 | 无 | 无 |
| `build_parser()` | 构建命令行参数解析器 | 无 | `argparse.ArgumentParser` |
| `parse_args(argv)` | 解析并校验参数范围 | 可选参数列表 | `argparse.Namespace` |
| `resolve_output_path(html_dir, output_arg)` | 解析输出位置；传目录时使用 `<html-dir-name>.jsonl` | HTML 目录、输出参数 | `Path` |
| `select_chapters(chapters, from_n, to_n)` | 按旧 slicer 的 1-based `index` 范围筛选章节 | TOC entries、起止 index | TOC entries |
| `build_entry(chapter, content)` | 将旧 TOC 章节和抽取内容整理为 JSONL entry | 章节 dict、content list | entry dict |
| `slice_html_to_entries(args)` | 解析 TOC、读取 HTML 文件、抽取内容并处理 `--skip-empty` | 参数对象 | `(entries, skipped)` |
| `main(argv)` | 命令行入口，调用 JSONL writer 写入单文件 | 可选参数列表 | 进程返回码 |

## 输出字段

每条记录至少包含：

| 字段 | 说明 |
|---|---|
| `index` | 来自 TOC 的章节序号；`--skip-empty` 跳过空章节时不重排 |
| `title` | TOC 标题 |
| `depth` | TOC 层级 |
| `source_file` | 原 HTML 文件名，由旧字段 `file` 显式映射而来 |
| `anchor` | 可选；TOC href 中存在 anchor 时保留 |
| `content` | 由旧 `extract_chapter_content()` 生成的 `text/table/code` 内容块数组 |

## 关键边界条件

- 旧 `html_slicer.py` 的 `parse_toc()` 会去重相同 `(file, anchor)`，并保留原始 index。
- `--skip-empty` 只跳过写入，不会重排后续 `index`。
- 缺失 HTML 文件会跳过并打印 warning，不会生成空 entry。
- JSONL 写入统一走 `scripts/jsonl_utils/jsonl_utils.py`，会校验必填字段、内容块结构、index 唯一性，并按 `index` 升序写入。
