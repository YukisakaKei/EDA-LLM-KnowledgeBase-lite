# html_jsonl_slicer.py — 使用说明

## 命令格式

```bash
python scripts/html_jsonl_slicer/html_jsonl_slicer.py <html_dir> <output_jsonl> --toc <toc_file> [--from N] [--to M] [--skip-empty]
```

`<output_jsonl>` 推荐直接传 `.jsonl` 文件路径；如果传入目录，脚本会输出到该目录下的 `<html-dir-name>.jsonl`。

## 参数说明

| 参数 | 类型 | 默认值 | 含义 |
|---|---|---|---|
| `html_dir` | 位置参数 | 必填 | 包含 HTML 章节文件的目录 |
| `output_jsonl` | 位置参数 | 必填 | 输出 JSONL 文件路径，或输出目录 |
| `--toc <toc_file>` | path | 必填 | TOC HTML 文件路径 |
| `--from N` | int | 1 | 起始章节编号，按 TOC 中的 1-based index，包含 |
| `--to M` | int | 最后一章 | 结束章节编号，包含 |
| `--skip-empty` | 开关 | 关 | 跳过无内容章节，保留后续原始 index，不重排 |

## 输出 JSONL 格式

每行是一条完整记录，示例：

```jsonl
{"index":26,"title":"inst","depth":1,"source_file":"inst.html","content":[{"type":"text","lines":["Parent Object"]},{"type":"table","table_index":0,"data":[["Child Object or Attribute","Type","Edit","Description"]]}]}
```

输出满足：

- UTF-8，无 BOM。
- 一行一个 JSON object。
- `ensure_ascii=False`，紧凑分隔符。
- 按 `index` 升序排列。
- 每条记录至少包含 `index/title/depth/content`。
- `source_file` 为原 HTML 文件名；TOC href 中存在 anchor 时额外保留 `anchor`。

## 测试样本命令

```powershell
python scripts\html_jsonl_slicer\html_jsonl_slicer.py `
  "D:\AI_Agent\EDA-LLM-KnowkedgeBase\knowledge\Innovus\legacy\row\dbSchema__211" `
  workspace\jsonl-test\html\dbSchema__211.jsonl `
  --toc "D:\AI_Agent\EDA-LLM-KnowkedgeBase\knowledge\Innovus\legacy\row\dbSchema__211\dbSchemaTOC.html" `
  --skip-empty
```

验证：

```powershell
python -B -c "import json,pathlib; p=pathlib.Path('workspace/jsonl-test/html/dbSchema__211.jsonl'); rows=[json.loads(line) for line in p.read_text(encoding='utf-8').splitlines()]; print(len(rows))"
rg -n '\x22index\x22:26,' workspace\jsonl-test\html\dbSchema__211.jsonl
rg -n "pStatus" workspace\jsonl-test\html\dbSchema__211.jsonl
```
