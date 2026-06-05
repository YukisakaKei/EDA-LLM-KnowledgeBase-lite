# INDEX

EDA-LLM 知识库导航。AI 从此处出发定位所需内容。

## 知识库板块

| 板块 | 类型 | 说明 | 导航 |
|------|------|------|------|
| PrimeTime | S 家工具 | Synopsys PrimeTime STA 工具 | [knowledge/PrimeTime/INDEX.md](knowledge/PrimeTime/INDEX.md) |
| Innovus | C 家工具 | Cadence Innovus 布局布线工具 | [knowledge/Innovus/INDEX.md](knowledge/Innovus/INDEX.md) |
| Voltus | C 家工具 | Cadence Voltus 功耗分析工具 | [knowledge/Voltus/INDEX.md](knowledge/Voltus/INDEX.md) |
| eda_formats | 通用知识 | EDA 标准文件格式（SPICE、SPEF 等）语法参考 | [knowledge/eda_formats/INDEX.md](knowledge/eda_formats/INDEX.md) |

## 目录结构

```
knowledge/
├── PrimeTime/            # Synopsys 工具
│   ├── INDEX.md
│   ├── row/
│   ├── json/             # 未迁移遗留切片
│   ├── wiki/
│   └── eda_scripts/      # 可参考的 EDA 脚本
│
├── Innovus/              # Cadence 工具（含 legacy/cui 两级）
│   ├── INDEX.md
│   ├── legacy/
│   │   ├── row/  jsonl/  wiki/  eda_scripts/
│   └── cui/
│       ├── row/  jsonl/  wiki/  eda_scripts/
│
├── eda_formats/          # 通用知识（EDA 标准文件格式语法）
│   ├── INDEX.md
│   ├── row/
│   ├── jsonl/
│   └── wiki/
│
└── Voltus/               # Cadence 工具（含 legacy/cui 两级）
    ├── INDEX.md
    ├── legacy/
    │   ├── row/  jsonl/  wiki/  eda_scripts/
    └── cui/
        ├── row/  jsonl/  wiki/  eda_scripts/
```

已迁移板块的完整切片位于 `jsonl/`，旧 `json/` 仅作为迁移对照和回滚依据，不作为默认导航入口。PrimeTime 未纳入本轮迁移，仍保留旧 `json/`。
