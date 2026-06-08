# CLAUDE.md

## 项目概述

将 EDA 工具手册转换为结构化 JSONL 知识库，供 LLM 检索回答问题和生成 EDA 脚本。

## AI 职责

1. **使用知识库回答用户** — 回答 EDA 相关问题、编写 EDA 脚本，当使用者询问 EDA 相关问题时，**必须先阅读 INDEX.md**，优先根据知识库内容回答；知识库无法覆盖的内容可基于自身知识回答，但须注明"知识库中未找到相关内容"。**回答结束时必须注明来源文件路径**，格式：`**来源**：[相对路径](相对路径)`。
2. **开发和维护知识库** — 对 PDF/HTML 切片、整理 JSONL、编写 wiki 快速参考

---

## 知识库使用流程

### 导航入口

从 [INDEX.md](INDEX.md) 出发，定位目标板块（Innovus / Voltus / eda_formats 等），进入对应子知识库的 `INDEX.md`。

Windows/PowerShell 环境读取中文 Markdown/JSONL 时，必须显式使用 UTF-8（如 `Get-Content -Encoding UTF8`），避免无 BOM 文件被按本地 ANSI 解码。

### 阅读优先级（重要）

`row/` 和 `jsonl/` 只读，不得修改。

```
wiki（优先）→ jsonl（次之）→ row（最后，仅当前面内容有缺失时）
```

- **wiki/** — 从 JSONL 提炼的快速参考，优先阅读，速度最快
- **jsonl/** — 完整切片内容，wiki 无法解决时阅读；按 `index` 定位单行记录
- **row/** — 原始 PDF/源文件，**仅当 jsonl 内容有缺失或错误时才读**，并须向用户反馈中间层存在问题

`jsonl/` 与 `row/` 通过**文件名/目录名匹配**对应：`legacy/jsonl/innovusUG__211.jsonl` 对应 `legacy/row/innovusUG__211`，以此类推。


## 知识库开发流程

### PDF 切片

使用技能 `/slice-pdf` 对 PDF 进行切片。

- **row/** — 存放原始 PDF（只读，不修改）
- **jsonl/** — 存放切片输出的 JSONL（只读，不修改）
- **wiki/** — 存放从 JSONL 提炼的快速参考（可更新）

### wiki 内容规范

wiki 文件开头须声明来源，`source` 为对应的 JSONL 文件路径。`source` 可为多行：

```markdown
---
source: knowledge/Innovus/legacy/jsonl/innovusUG__211.jsonl | entries: [0122, 0123]
---
```

### 新增知识板块

按 [project-structure-plan.md](project-structure-plan.md) 中的模板套用目录结构。

---
