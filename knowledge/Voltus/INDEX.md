# Voltus 知识库

> Voltus 是 Cadence 的功耗分析工具，支持 CUI 和 Legacy 两个版本。

> **术语注意**：Voltus 中的 "static" 指**时间平均分析方法**（与 "dynamic" 瞬态分析对立），而非物理上的"静态功耗(leakage)"。`-method static` 计算的是时间平均总功耗（含 switching + internal + leakage 三者），不是仅算漏电。

---

## 默认版本

**默认使用 Legacy 版本。** 未特殊说明时，所有回答和脚本均基于 Legacy 语法（`dbGet`/`dbSet`）。

---

## 快速开始

### 1. 选择版本

| 版本 | 语法特征 | 适用场景 |
|------|----------|----------|
| **Legacy**（默认） | `dbGet`/`dbSet` | 旧项目、维护既有脚本 |
| **CUI** | `get_db`/`set_db` | 新项目、Stylus/Common UI 环境 |

**严禁混用！选定版本后，整个脚本必须使用同一语法。**

### 2. 进入对应版本知识库

- **[Legacy 版本](legacy/INDEX.md)**（默认）
- **[CUI 版本](cui/INDEX.md)**