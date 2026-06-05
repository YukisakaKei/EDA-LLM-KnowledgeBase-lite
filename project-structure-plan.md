# 项目文件结构规划

## Context

用户需要为 EDA-LLM-KnowkedgeBase 项目规划一套清晰的目录结构。该项目的核心目标是：
- 将 EDA 工具手册（PDF/网页/MD）转换为 JSONL 知识库，供 LLM 检索
- 提供 workspace 供 AI 输出 EDA 脚本
- 提供快速参考文件（可实时更新），从 JSONL 中提炼关键内容
- 提供 PDF 切片脚本
- 提供 index.md 引导 AI 导航

个人使用，workspace 不需要按项目隔离。快速参考文件根据源文件类型不同：工具手册 → 命令速查表 + 概念摘要 + 示例脚本；技术文章 → AI 自动生成摘要。

---

## 推荐目录结构

```
EDA-LLM-KnowkedgeBase/
│
├── index.md                            # 总导航：引导 AI 找到各模块路径和用途
│
├── knowledge/                          # 知识库核心
│   │
│   │   # --- 类型A：通用知识类（技术文章、概念等）---
│   ├── <topic>/                        # 例：sta_fundamentals
│   │   ├── index.md                    # 当前板块导航
│   │   ├── row/                        # 原始源文件（只读）
│   │   ├── jsonl/                      # 切片后 JSONL（只读）
│   │   ├── json/                       # 未迁移遗留 JSON 或迁移对照（只读）
│   │   └── wiki/                       # 快速参考（可更新）
│   │
│   │   # --- 类型B：S 家工具（Synopsys）---
│   ├── <s_tool>/                       # 例：primetime
│   │   ├── index.md                    # 当前板块导航
│   │   ├── row/                        # 原始源文件（只读）
│   │   ├── jsonl/                      # 切片后 JSONL（只读）
│   │   ├── json/                       # 未迁移遗留 JSON 或迁移对照（只读）
│   │   ├── eda_scripts/                # 可供参考的 EDA 脚本
│   │   └── wiki/                       # 快速参考（可更新）
│   │
│   │   # --- 类型C：C 家工具（Cadence，含 legacy/cui 两级）---
│   └── <c_tool>/                       # 例：innovus
│       ├── index.md                    # 当前板块导航
│       ├── legacy/
│       │   ├── row/                    # 旧版 legacy 工具手册
│       │   ├── jsonl/
│       │   ├── json/                   # 迁移对照/回滚副本
│       │   ├── eda_scripts/
│       │   └── wiki/
│       └── cui/
│           ├── row/                    # 新版 CUI 工具手册
│           ├── jsonl/
│           ├── json/                   # 迁移对照/回滚副本
│           ├── eda_scripts/
│           └── wiki/
│
├── scripts/                            # PDF 切片等工具脚本
│   ├── pdf_slicer.py
│   ├── toc_parser.py
│   ├── requirements.txt
│   └── README.md
│
└── workspace/                          # AI 输出 EDA 脚本的工作区
    └── .gitkeep
```

---

## 关键设计决策

1. **row/、jsonl/ 和 json/ 只读**：生成后不修改，保证知识库稳定可溯源
2. **wiki/ 可更新**：从 JSONL/JSON 提炼的快速参考，AI 可直接读取，人工随时补充
3. **wiki 内容按源类型区分**：工具手册用 `commands.md + concepts.md + examples.md`，技术文章用 `summary.md`
4. **三种板块类型模板**：knowledge/ 下每个子目录按所属类型套用对应模板，后续新增工具（sta、PR、Power 等）直接套用
5. **C 家工具含两级分类**：legacy / cui 为顶层，各自下面再分 row/jsonl/eda_scripts/wiki
6. **index.md 在根目录**：AI 每次对话优先读取，快速定位所需知识
7. **scripts/ 与 knowledge/ 平级**：工具脚本独立管理，不混入知识库内容
8. **workspace 单一公共目录**：个人使用无需隔离

---

## index.md 内容结构

根目录 `index.md`（总导航，保持精简）：
- 项目简介（一句话）
- 各板块入口列表：名称 → 对应 `<board>/index.md` 路径
- scripts/ 使用入口
- workspace/ 路径说明

各板块 `<board>/index.md`（板块导航）：
- 板块简介
- row/ / jsonl/ / wiki/ 路径及内容说明；未迁移遗留板块可额外说明 json/
- C 家工具额外列出 legacy / cui / shared 的区分说明

---

## 验证方式

- 目录结构创建后，手动检查层级是否清晰
- 用一个 PDF 走完完整流程：sources → 切片 → jsonl → 生成 wiki → index.md 更新
- 让 AI 只读 index.md，验证能否准确导航到目标 JSONL 文件
