# CLAUDE.md

## 项目概述

将 EDA 工具手册转换为结构化 JSONL 知识库，供 LLM 检索回答问题和生成 EDA 脚本。

## AI 职责

1. **使用知识库回答用户** — 回答 EDA 相关问题、编写 EDA 脚本，当使用者询问 EDA 相关问题时，**必须先阅读 INDEX.md**，优先根据知识库内容回答；知识库无法覆盖的内容可基于自身知识回答，但须注明"知识库中未找到相关内容"。**回答结束时必须注明来源文件路径**，格式：`**来源**：[相对路径](相对路径)`。
2. **开发和维护知识库** — 对 PDF/HTML 切片、整理 JSONL、编写 wiki 快速参考

---

## 知识库使用流程

### 导航入口

从 [INDEX.md](INDEX.md) 出发，定位目标板块（STA / PrimeTime / Innovus 等），进入对应子知识库的 `INDEX.md`。

Windows/PowerShell 环境读取中文 Markdown/JSON/JSONL 时，必须显式使用 UTF-8（如 `Get-Content -Encoding UTF8`），避免无 BOM 文件被按本地 ANSI 解码。

### 阅读优先级（重要）

`row/`、`jsonl/` 和旧 `json/` 只读，不得修改。

```
wiki（优先）→ jsonl（次之）→ json（仅未迁移遗留板块）→ row（最后，仅当前面内容有缺失时）
```

- **wiki/** — 从 JSONL/JSON 提炼的快速参考，优先阅读，速度最快
- **jsonl/** — 已迁移板块的完整切片内容，wiki 无法解决时阅读；按 `index` 定位单行记录
- **json/** — 未迁移遗留板块的完整切片内容；已迁移板块中的旧 `json/` 仅作迁移对照和回滚依据
- **row/** — 原始 PDF/源文件，**仅当 jsonl/json 内容有缺失或错误时才读**，并须向用户反馈中间层存在问题

`jsonl/` 与 `row/` 通过**文件名/目录名匹配**对应：`legacy/jsonl/innovusUG__211.jsonl` 对应 `legacy/row/innovusUG__211`，以此类推。未迁移遗留 `json/` 仍按目录名匹配：`PrimeTime/json/htmlView_20/topic/` 对应其源目录。


## 知识库开发流程

### PDF 切片

使用技能 `/slice-pdf` 对 PDF 进行切片。

- **row/** — 存放原始 PDF（只读，不修改）
- **jsonl/** — 存放切片输出的 JSONL（只读，不修改）
- **json/** — 存放未迁移遗留 JSON，或已迁移板块的对照/回滚副本（只读，不修改）
- **wiki/** — 存放从 JSONL/JSON 提炼的快速参考（可更新）

### wiki 内容规范

wiki 文件开头须声明来源，`source` 为对应的 JSONL 文件路径；未迁移遗留板块可继续引用旧 JSON 路径。`source` 可为多行：

```markdown
---
source: knowledge/Innovus/legacy/jsonl/innovusUG__211.jsonl | entries: [0122, 0123]
source: knowledge/PrimeTime/json/htmlView_20/topic | entries: [0009, 0017]
---
```

### 新增知识板块

按 [project-structure-plan.md](project-structure-plan.md) 中的模板套用目录结构。

---
