# validate_jsonl.py

JSONL 知识库切片的全量校验脚本。它负责检查文件编码、JSONL 单行格式、entry 必填字段、内容块结构、文件内 index 顺序，以及可选的 `source_file` 源文件反查。

## 核心函数

| 函数 | 作用 | 关键输入 | 输出 |
|---|---|---|---|
| `build_parser()` / `parse_args()` | 定义并校验命令行参数 | CLI argv | `argparse.Namespace` |
| `collect_jsonl_files()` | 收集待校验文件；目录会递归查找 `*.jsonl` | paths | 文件列表和路径级问题 |
| `read_utf8_no_bom()` | 读取文件并检查 UTF-8、无 BOM、末尾换行 | JSONL path | 文本和文件级问题 |
| `validate_json_line()` | 逐行 `json.loads`，并调用 `jsonl_utils.validate_entry()` 校验 entry schema | 单行文本 | entry dict 或 `None` |
| `infer_row_container()` | 根据 JSONL 路径推断对应 `row/` 目录；可配合 `--source-root/--target-root` 做跨仓库映射 | JSONL path | row container path |
| `build_source_candidates()` | 为一条 `source_file` 生成候选源文件路径 | row 目录、JSONL 文件名、source_file | path list |
| `validate_source_file()` | 在 `--check-source-file` 模式下检查源文件是否存在 | entry、row 目录 | issue list side effect |
| `validate_jsonl_file()` | 单文件主校验流程，汇总文件级、行级和 source 反查问题 | JSONL path 和选项 | `FileReport` |
| `print_reports()` / `main()` | 输出每个文件的校验结果和总摘要 | reports | process exit code |

## 校验规则

- 文件必须是 UTF-8 且不能包含 BOM。
- 非空文件必须以换行符结尾。
- 每一行必须是一条完整 JSON object；空行不允许。
- 每条 entry 必须包含 `index/title/depth/content`。
- `index` 必须是整数，在同一文件内唯一，并按升序排列；允许空缺。
- `content` 必须是数组。
- `text/code` 内容块必须包含 `lines: list[str]`。
- `table` 内容块必须包含 `table_index` 和 `data: list[list[str]]`。
- 任何跨行记录都会因为单行 `json.loads` 或 entry schema 校验失败而报错。

## `source_file` 反查

开启 `--check-source-file` 后，脚本会根据 JSONL 路径推断对应的 `row/` 目录：

- 默认把 JSONL 文件父路径中的最后一个 `jsonl` 路径段替换为 `row`。
- 对 `knowledge/Innovus/legacy/jsonl/dbSchema__211.jsonl`，推断 row container 为 `knowledge/Innovus/legacy/row`。
- 检查候选路径：
  - `row/<jsonl-stem>/<source_file>`，适用于 HTML 目录型源文件。
  - `row/<source_file>`，适用于 PDF 单文件源文件。
- `source_file` 可以是多级相对路径，例如 `chapter/subpage.html`。
- 当 JSONL 在 lite 仓库而 `row/` 在完整仓库时，可使用 `--source-root` 和 `--target-root` 映射。
