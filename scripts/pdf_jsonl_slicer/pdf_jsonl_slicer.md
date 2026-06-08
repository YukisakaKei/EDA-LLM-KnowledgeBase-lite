# pdf_jsonl_slicer.py

PDF JSONL 切片脚本。它通过 `pdf_extractor.py` 使用 PDF 书签解析、页码/坐标切片、正文/表格提取、页眉页脚剔除、跨页合并、OCR 和 PyMuPDF 文本后端，并统一走 JSONL 写入与校验流程。

## 核心函数

| 函数 | 作用 | 关键输入 | 输出 |
|---|---|---|---|
| `build_parser()` / `parse_args()` | 定义并校验命令行参数 | CLI argv | `argparse.Namespace` |
| `resolve_output_path()` | 将输出参数解析为最终 `.jsonl` 路径；若传入目录则使用 `<pdf-stem>.jsonl` | PDF 路径、输出参数 | `Path` |
| `load_outlines()` | 优先读取 PDF 书签；无书签时按 TOC fallback 参数调用 `toc_parser.parse_toc()` | PDF 与 TOC 参数 | outlines list |
| `validate_precise_outlines()` | 在 `--precise` 模式下检查每个书签是否有 `/Top` 坐标 | outlines list | 无；失败时退出 |
| `prepare_text_backend()` / `close_text_backend()` | 打开并关闭可选的 OCR 或 PyMuPDF 文本后端 | CLI 参数 | OCR/PyMuPDF 资源 |
| `build_selected_chapters()` | 根据 `--precise` 选择坐标切片或页码范围切片，并应用 `--from/--to` | outlines、PDF | 全部章节与选中章节 |
| `detect_strip_margins()` | 在 `--strip-headers` 时采样正文页并检测页眉页脚裁剪边界 | PDF、章节 | margin tuple 或 `None` |
| `extract_content_for_chapter()` | 调用 `pdf_extractor.py` 的提取函数，返回该章节的 `content` 数组 | 章节、模式、后端 | content list |
| `build_entry()` | 组装 JSONL entry，包含 `index/title/depth/source_file/page_start/page_end/content` | 章节、content、源文件名 | entry dict |
| `slice_pdf_to_entries()` | 主流程：读目录、切章节、提取内容，返回全部 entries | CLI 参数 | entries list |
| `main()` | 写出最终 JSONL；实际写入和校验由 `jsonl_utils.write_jsonl()` 完成 | CLI argv | process exit code |

## 输出边界

- 每个 PDF 输出一个 `.jsonl` 文件。
- 每行是一条完整 entry，按 `index` 升序排序。
- 每条 entry 至少包含 `index/title/depth/content`，并额外保留 `source_file/page_start/page_end`。
- `content` 块由 `jsonl_utils.normalize_content()` 做最终规范化：
  - `text/code` 块使用 `lines: list[str]`。
  - `table` 块使用 `table_index` 和 `data: list[list[str]]`。
  - PDF 跨页产生的表格编号会按 entry 内出现顺序重新编号。

## 关键边界条件

- `--precise` 要求所有书签都有 `/Top` 坐标；TOC fallback 产生的目录没有坐标，不能与 `--precise` 联用。
- 默认页码范围模式按书签页码边界切片，可能与相邻章节共享边界页。
- `--ocr-text` 和 `--fitz-text` 互斥。
- `--ocr-text` 模式下表格会退化为 OCR 文本行，不保留表格网格。
- `--from/--to` 只筛选输出 entry，不重排 index。
