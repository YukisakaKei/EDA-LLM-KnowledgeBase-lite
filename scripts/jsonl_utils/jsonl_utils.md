# jsonl_utils.py

公共 JSONL 工具模块，供 PDF/HTML 等 JSONL slicer 调用。它只处理 JSONL 中间格式的字段规范、内容块规范、校验和写入，不负责从 PDF 或 HTML 提取内容。

## 核心函数

| 函数 | 作用 | 输入 | 输出 |
|---|---|---|---|
| `normalize_entry(entry)` | 规范化单条记录，将输入字段 `file` 映射为 `source_file`，并规范化 `content` | dict-like entry | dict |
| `normalize_content(content)` | 规范化 `text/code/table` 内容块；`text/code` 使用 `lines`，`table` 使用连续 `table_index` 和二维字符串数组 `data` | content list | content list |
| `validate_entry(entry)` | 检查记录是否满足 JSONL 必要字段和内容块结构 | dict-like entry | 错误字符串列表；空列表表示通过 |
| `write_jsonl(entries, output_path)` | 校验、按 `index` 升序排序，并以 UTF-8 无 BOM 单行 JSON 写入 `.jsonl` | entries iterable, 输出路径 | 写入行数 |

## 边界条件

- `index/title/depth/content` 为必填字段。
- `source_file` 可选；如果输入存在字段 `file` 且没有 `source_file`，会自动映射。
- `text` 和 `code` 块必须包含 `lines: list[str]`。如果内容块只有 `text` 字符串，会按换行拆成 `lines`。
- `table` 块必须包含 `table_index` 和 `data: list[list[str]]`。表格会按记录内出现顺序重新编号，避免跨页表格的 `table_index` 重复。
- `write_jsonl()` 会检查 `index` 唯一性；允许 index 空缺。
- 输出使用 `ensure_ascii=False` 和紧凑分隔符，每行一条完整 JSON 记录。
