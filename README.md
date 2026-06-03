# EDA-LLM-KnowledgeBase

将 EDA 工具手册（PDF/HTML）转化为可问答的结构化知识库，支持检索概念、查询命令用法、生成和修改 EDA 脚本。所有操作通过自然语言与 AI 交互完成。

---

## 第一次使用

在 **Claude Code**（终端 CLI）或安装了 **Claude Code 插件**的 VS Code 中打开本项目。

> **重要：必须在项目根目录下打开**（能看到 `CLAUDE.md` 和 `.claude/` 的那一层）。如果在上一级目录或 `workspace/`、`scripts/` 等子目录下打开，AI 将无法加载 skill 和项目配置，导入文档等功能会不可用。

打开后，先用以下提示词让 AI 帮你验证环境：

> 帮我检查：当前工作目录是不是项目根目录（应该有 CLAUDE.md、INDEX.md、.claude/ 目录）？Python 环境和 scripts/requirements.txt 里的依赖是否安装好了？

之后即可直接用自然语言交互。以下是常见场景的提示词参考，直接复制修改即可。

---

## 简单使用

不需了解目录结构和索引体系，直接把文档丢进 `workspace/` 切片后提问。

切片的目的：将文档拆成结构化 JSON，让 AI 能像翻书一样在文件中自由搜索。提问时不需要你告诉 AI 去哪找、搜什么关键词——AI 会根据你的问题自己联想关键词、自己定位相关文件。

1. 将文档文件/文件夹放入 `workspace/`

2. 切片：

> 对 workspace/my_manual.pdf 进行切片，优先判断已有技能是否适用，不适用的话参考 scripts/pdf_slicer.py，把文件切片成类似 knowledge/Innovus/legacy/json/innovusUG__211 的 json 文件

> 对 workspace/my_docs/ 下的 HTML 进行切片，优先判断已有技能是否适用，不适用的话参考 scripts/html_slicer.py，把文件切片成类似 knowledge/Innovus/legacy/json/innovusUG__211 的 json 文件

3. 提问和编写 EDA 脚本（AI 自动联想关键词并搜索文件）：

提问：

> 我使用 Voltus，通过 LEF 生成了一批 PGV，但是这些 PGV 电容值为 0，可能是什么原因？

编写脚本（先出思路方案，审查通过后再写脚本）：

> 参考 workspace/my_manual_json/ 的内容，帮我写一个 Innovus proc：输入一个 pin 名，找到该 pin 驱动的所有 buffer/inverter，计算这些 buffer/inverter 所有输出 net 的总 wiring length。先参考 workspace/script_plan_refs/getConnectedBufInvNetLength_plan.md 的 markdown 结构与写法，输出一个 markdown 到 workspace/ 说明实现思路，等我审查确认后再写脚本

---

## 一、导入文档（切片）

将待导入的文档放入对应板块的 `row/` 目录下，然后告诉 AI：

### PDF 手册（官方 User Guide / Command Reference）

> 帮我切片 knowledge/Innovus/legacy/row/innovusUG__211 下的 PDF，自动解析目录，输出 json 到 knowledge/Innovus/legacy/json/innovusUG__211

> 把 knowledge/PrimeTime/row/pt_ug.pdf 切片，只切第 3 章到第 8 章

### Confluence 导出的 HTML 手册

> 切片 knowledge/Voltus/legacy/row/voltus_confluence/ 下的 HTML，TOC 在 index.html 里

### Man Page 格式的 HTML（S 家 htmlView）

> 切片 knowledge/PrimeTime/row/htmlView_20/command/ 下所有 HTML，输出到 knowledge/PrimeTime/json/htmlView_20/command/

### 切片后整理快速参考

切片完成后，可让 AI 从 JSON 提炼 wiki 快速参考（后续问答优先使用）：

> 根据 knowledge/Innovus/legacy/json/innovusUG__211 的内容，在 knowledge/Innovus/legacy/wiki/ 下整理快速参考

---

## 二、查询 EDA 知识

### 直接提问（AI 自动检索全库）

> Innovus 中 `ccopt_design` 命令的用途和关键选项是什么？

> Voltus 做 IR Drop 分析需要哪些输入？流程是怎样的？

### 指定范围提问（限定在某份文档内）

> 根据 knowledge/Innovus/legacy/json/innovusUG__211 回答：floorplan 相关的命令有哪些？

> 在 knowledge/PrimeTime/json 范围内，查一下 OCV 和 AOCV 的用法区别

---

## 三、生成/修改 EDA 脚本

生成的脚本默认输出到 `workspace/` 目录。
脚本方案/提示词参考文档放在 `workspace/script_plan_refs/`，可在提示词中明确要求 AI 参考其中范例，先输出 markdown 方案，再继续写脚本。

### 带规范要求生成

> 写一个 Voltus IR Drop 分析脚本，要求：
> - 配置、主流程、报告分开三个文件，顶层 source 引入
> - 每个文件开头注释说明功能
> - 公共变量抽到 settings.tcl
> - 输出到 workspace/voltus_flow/

### 修改已有脚本

> 帮我修改 workspace/report_global_ccopt_properties.tcl，增加对每个 clock domain 单独报告 skew 的功能

---

## 四、新增知识板块

> 我想新增一个 Genus 综合工具的知识板块，按 project-structure-plan.md 的模板帮我创建目录结构，并更新 INDEX.md
