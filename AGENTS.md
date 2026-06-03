# AGENTS.md

这是给 Codex 使用的轻量入口文件。不要在这里重复维护项目规则。

## 唯一指令源

- 优先阅读 [CLAUDE.md](CLAUDE.md)。它是本项目唯一维护的主指令，包含项目目标、知识库检索规则、来源标注要求和开发流程。
- 项目本地技能从 [.claude/skills](.claude/skills) 读取。例如 `/slice-pdf` 对应 `.claude/skills/slice-pdf/SKILL.md`。
- 如果本文件和 `CLAUDE.md` 出现冲突，以 `CLAUDE.md` 为准。

## Codex 使用说明

- 这是一个知识库查询项目。回答 EDA 相关问题时，从 [INDEX.md](INDEX.md) 开始，再进入对应子索引。
- 阅读优先级遵循 `CLAUDE.md`：先看 `wiki/`，再看 `json/`，只有当 JSON 缺失或错误时才看 `row/`。
- 除非用户明确要求维护知识库，否则将 `row/` 和 `json/` 视为只读目录。
- 切片或导入文档时，使用 `.claude/skills` 中对应的流程，并结合 [scripts](scripts) 下的脚本。
