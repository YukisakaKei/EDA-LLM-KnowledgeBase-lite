# validate_jsonl.py — 使用说明

## 命令格式

```bash
python scripts/validate_jsonl/validate_jsonl.py <jsonl-or-dir> [<jsonl-or-dir> ...] [--check-source-file]
```

传入目录时，脚本会递归校验目录下所有 `*.jsonl` 文件。

## 参数说明

| 参数 | 类型 | 默认值 | 含义 |
|---|---|---|---|
| `paths` | 位置参数 | 必填 | 一个或多个 JSONL 文件或目录 |
| `--check-source-file` | 开关 | 关 | 检查每条 entry 的 `source_file` 是否能在推断的 `row/` 源目录中找到 |
| `--source-root DIR` | path | 无 | 完整源仓库根目录；用于 JSONL 在 lite 仓库、row 在 full repo 的场景 |
| `--target-root DIR` | path | 无 | lite/目标仓库根目录；与 `--source-root` 配合做相对路径映射 |
| `--max-errors N` | int | 100 | 最多打印多少条 issue；`0` 表示不限制 |
| `--quiet` | 开关 | 关 | 只打印失败文件和最终摘要 |

## 基础校验

```powershell
python scripts\validate_jsonl\validate_jsonl.py workspace\jsonl-test\html\dbSchema__211.jsonl
python scripts\validate_jsonl\validate_jsonl.py workspace\jsonl-test\pdf\optDesign_vs_timeDesign.jsonl
```

全量目录校验：

```powershell
python scripts\validate_jsonl\validate_jsonl.py knowledge\Innovus\legacy\jsonl knowledge\Voltus\legacy\jsonl
```

## 检查 `source_file`

如果 JSONL 和 `row/` 在同一仓库布局中：

```powershell
python scripts\validate_jsonl\validate_jsonl.py knowledge\Innovus\legacy\jsonl\dbSchema__211.jsonl --check-source-file
```

如果 JSONL 在 lite 仓库，`row/` 在完整源仓库：

```powershell
python scripts\validate_jsonl\validate_jsonl.py knowledge\Innovus\legacy\jsonl\dbSchema__211.jsonl `
  --check-source-file `
  --target-root D:\AI_Agent\EDA-LLM-KnowledgeBase-lite `
  --source-root D:\AI_Agent\EDA-LLM-KnowkedgeBase
```

## 输出示例

```text
OK   workspace\jsonl-test\html\dbSchema__211.jsonl (424 entries)
PASS: 1 file(s), 424 parsed entries, 0 issue(s)
```

失败时会按 `文件:行号: 问题` 输出，例如：

```text
FAIL bad.jsonl (2 issue(s), 10 parsed entries)
  bad.jsonl:7: missing required field: content
  bad.jsonl:8: index order violation: previous=12, current=10
FAIL: 1 file(s), 10 parsed entries, 2 issue(s)
```
