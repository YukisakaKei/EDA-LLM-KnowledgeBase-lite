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

知识库开发流程、目录结构、文件命名、wiki 规范、eda_scripts 规范和新增板块检查清单，统一以 [specs/sub-knowledge-base.md](specs/sub-knowledge-base.md) 为准。

进行 PDF/HTML 切片、JSONL 整理、wiki 快速参考编写或新增知识板块前，先阅读该规范，避免在 AGENTS.md 中重复维护流程定义。

---
