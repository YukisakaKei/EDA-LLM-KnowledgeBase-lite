# 子知识库规范

## 1. 目录结构模板

### 类型 A：通用知识类（技术文章、概念、格式参考等）

```
knowledge/<topic>/
├── INDEX.md         # 板块导航
├── row/             # 原始源文件（只读）
├── jsonl/           # 切片后 JSONL（只读）
└── wiki/            # 快速参考（可更新）
```

### 类型 B：S 家工具（Synopsys，如 PrimeTime）

```
knowledge/<s_tool>/
├── INDEX.md         # 板块导航
├── row/             # 原始源文件（只读）
├── jsonl/           # 切片后 JSONL（只读）
├── eda_scripts/     # 可供参考的 EDA 脚本
└── wiki/            # 快速参考（可更新）
```

### 类型 C：C 家工具（Cadence，如 Innovus、Voltus）

```
knowledge/<c_tool>/
├── INDEX.md                     # 顶层导航（版本选择器 + 严禁混用声明）
├── legacy/
│   ├── INDEX.md                 # Legacy 版本导航
│   ├── row/                     # 原始源文件（只读）
│   ├── jsonl/                   # 切片后 JSONL（只读）
│   ├── eda_scripts/
│   └── wiki/                    # 快速参考（可更新）
└── cui/
    ├── INDEX.md                 # CUI 版本导航
    ├── row/                     # 原始源文件（只读）
    ├── jsonl/                   # 切片后 JSONL（只读）
    ├── eda_scripts/
    └── wiki/                    # 快速参考（可更新）
```

> **Legacy** 使用 `dbGet`/`dbSet` 语法，**CUI** (Common UI/Stylus) 使用 `get_db`/`set_db` 语法。二者严禁混用。

---

## 2. 文件命名规范

### 2.1 JSONL 与 row/ 的对应

唯一规则：**`jsonl/<name>.jsonl` 与 `row/<name>/` 目录名一致**，文件名去掉 `.jsonl` 后缀即可定位对应 row 目录。

例如：`legacy/jsonl/innovusUG__211.jsonl` 对应 `legacy/row/innovusUG__211/`，依此类推。

### 2.2 INDEX.md 文件名

板块级导航文件统一命名为 **`INDEX.md`**（全大写）。

---

## 3. INDEX.md 编写规范

### 3.1 根目录 INDEX.md

位于项目根路径，包含：
- 项目简介（一句话）
- 各板块入口表格（板块名、类型、说明、导航路径）
- 目录结构概览（代码块展示）

### 3.2 板块级 INDEX.md

#### S 家工具 / 通用知识类

```
# <板块名> 知识库索引

## JSONL 切片内容（完整参考）

### <文档名>
简要描述。

## Wiki 快速参考（优先阅读）

### <类别名>
- [文件名](路径) — 简要描述
```

#### C 家工具顶层 INDEX.md

作为版本选择器：
```markdown
# <工具名> 知识库

> 版本差异说明

| 版本 | 语法特征 | 适用场景 |
|------|----------|----------|
| CUI | get_db/set_db | 新项目 |
| Legacy | dbGet/dbSet | 旧项目 |

**严禁混用！**

- **[CUI 版本](cui/INDEX.md)**
- **[Legacy 版本](legacy/INDEX.md)**
```

#### C 家工具版本级 INDEX.md (cui/INDEX.md, legacy/INDEX.md)

与 S 家板块 INDEX.md 结构相同，列出该版本各自的 jsonl 文件和 wiki。

---

## 4. JSONL 切片规范

### 记录格式

每行一条 JSON 记录，字段由切片工具生成，常见字段：

```json
{
  "index": 1,
  "title": "Chapter Title",
  "depth": 0,
  "source_file": "About_This_Manual.html",
  "content": [{"type": "text", "lines": ["..."]}]
}
```

- `index`：数字编号，从 1 开始递增
- `title`：章节/条目标题
- `depth`：标题层级深度（0 表示顶级标题）
- `source_file`：来源文件名
- `content`：内容块数组，每块含 `type`（如 `text`、`table`）及对应数据
- PDF 来源的记录可能额外包含 `page_start`、`page_end`

---

## 5. Wiki 快速参考规范

### 文件头声明

每个 wiki 文件开头须声明来源：

```markdown
---
source: knowledge/Innovus/legacy/jsonl/innovusUG__211.jsonl | entries: [0122, 0123]
---
```

- `source` 可多行，每行列出一个来源 JSONL 文件路径（相对于项目根目录）
- `entries` 列出引用的记录编号

---

## 6. eda_scripts 规范

### 6.1 占位文件

每个 `eda_scripts/` 目录包含 `.gitkeep` 确保空目录被跟踪。

### 6.2 脚本内容

- 脚本使用 Tcl 编写
- 每个脚本文件自包含，顶部注释说明用途、适用的工具和版本

---

## 7. 新增板块检查清单

1. 确定板块类型（A/B/C），按对应模板创建目录
2. 空目录中创建 `.gitkeep` 占位文件
3. 编写 `INDEX.md` 导航
4. 更新根目录 `INDEX.md` 添加板块入口
5. 完成 PDF/HTML 切片后更新 `jsonl/` 和 `wiki/`
6. 确认 wiki 文件头声明了正确的 `source` 路径
