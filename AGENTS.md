# CLAUDE.md

## 项目概述

将 EDA 工具手册转换为结构化 JSON 知识库，供 LLM 检索回答问题和生成 EDA 脚本。

## AI 职责

1. **使用知识库回答用户** — 回答 EDA 相关问题、编写 EDA 脚本，当使用者询问 EDA 相关问题时，**必须先阅读 INDEX.md**，优先根据知识库内容回答；知识库无法覆盖的内容可基于自身知识回答，但须注明"知识库中未找到相关内容"。**回答结束时必须注明来源文件路径**，格式：`**来源**：[相对路径](相对路径)`。
2. **开发和维护知识库** — 对 PDF 切片、整理 JSON、编写 wiki 快速参考

---

## 知识库使用流程

### 导航入口

从 [INDEX.md](INDEX.md) 出发，定位目标板块（STA / PrimeTime / Innovus 等），进入对应子知识库的 `INDEX.md`。

### 阅读优先级（重要）

`row/` 和 `json/` 只读，不得修改。

```
wiki（优先）→ json（次之）→ row（最后，仅当 json 有缺失时）
```

- **wiki/** — 从 JSON 提炼的快速参考，优先阅读，速度最快
- **json/** — 完整切片内容，wiki 无法解决时阅读
- **row/** — 原始 PDF/源文件，**仅当 json 内容有缺失或错误时才读**，并须向用户反馈 json 存在问题

`json/` 与 `row/` 通过**目录名匹配**对应：`legacy/json/innovusUG__211/` 对应 `legacy/row/innovusUG__211`，以此类推。


## 知识库开发流程

### PDF 切片

使用技能 `/slice-pdf` 对 PDF 进行切片。

- **row/** — 存放原始 PDF（只读，不修改）
- **json/** — 存放切片输出的 JSON（只读，不修改）
- **wiki/** — 存放从 JSON 提炼的快速参考（可更新）

### wiki 内容规范

wiki 文件开头须声明来源，`source` 为对应的 json 文件夹路径，可为多行：

```markdown
---
source: knowledge/Innovus/legacy/json | chapters: [0122, 0123]
source: knowledge/STA/json | chapters: [0010, 0011]
---
```

### 新增知识板块

按 [project-structure-plan.md](project-structure-plan.md) 中的模板套用目录结构。

---
