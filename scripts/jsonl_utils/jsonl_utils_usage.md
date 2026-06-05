# jsonl_utils.py — 使用说明

## 典型用法

```python
from jsonl_utils.jsonl_utils import write_jsonl

entries = [
    {
        "index": 1,
        "title": "Overview",
        "depth": 0,
        "source_file": "manual.pdf",
        "content": [{"type": "text", "lines": ["first line"]}],
    }
]

count = write_jsonl(entries, "out/manual.jsonl")
print(f"wrote {count} entries")
```

## 输出格式

`write_jsonl()` 写出的文件满足：

- UTF-8，无 BOM。
- 每行一个完整 JSON 对象。
- 按 `index` 升序排列。
- `json.dumps(..., ensure_ascii=False, separators=(",", ":"))`，不做 pretty-print。
- 文件最后保留一个换行。

## 校验行为

```python
from jsonl_utils.jsonl_utils import JsonlValidationError, validate_entry, write_jsonl

errors = validate_entry(entry)
if errors:
    print(errors)

try:
    write_jsonl(entries, "out/manual.jsonl")
except JsonlValidationError as exc:
    print(exc)
```

常见错误包括缺少 `index/title/depth/content`、`content` 不是数组、`text/code` 块缺少 `lines`、`table` 块缺少 `table_index/data`、以及重复 `index`。
