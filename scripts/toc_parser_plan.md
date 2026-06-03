# TOC 解析器 — 实现计划

## 背景

`InnovusUserGuide.pdf` 等文档没有 PDF 书签（outline 为空），无法直接用 `pdf_slicer.py` 切片。但文档包含目录页（Table of Contents），可从中解析出 `(标题, 页码)` 对，构建等价的 outlines 列表，再交给 `pdf_slicer.py` 的切片逻辑处理。

---

## 目录页结构（实测）

- 目录页范围：第 4–22 页（0-based index 3–21）
- 每行格式：`标题文字 ... 页码`，页码为纯数字，位于行末，x 坐标约 550–575
- 页眉（`Innovus User Guide` + `Table of Contents`）位于每页顶部，top < 50
- 页脚（`Last Updated ... Product Version ...`）位于每页底部，top > 740
- 几乎所有条目为单行，实测无多行标题（末尾无页码的行仅有目录标题 `Contents` 本身）
- 缩进层级通过 x0 区分（约 36 / 48 / 61），但本解析器**不区分层级**，全部视为同级

---

## 命令行接口

```bash
python toc_parser.py <pdf路径>
    --toc-start N       目录起始页（1-based 印刷页码，必填）
    --toc-end M         目录结束页（1-based 印刷页码，必填）
    --header-bottom H   页眉底部 y 坐标，低于此值的行跳过（必填）
    --footer-top F      页脚顶部 y 坐标，高于此值的行跳过（必填）
    --page-x1-1 X       个位数页码（1–9）的最小 x0 坐标（必填）
    --page-x1-2 X       两位数页码（10–99）的最小 x0 坐标（必填）
    --page-x1-3 X       三位数页码（100–999）的最小 x0 坐标（必填）
    --page-x1-4 X       四位数页码（1000+）的最小 x0 坐标（必填）
```

所有参数均为必填，无自动检测，由使用者根据实际 PDF 测量后传入。

---

## 实现步骤

### Step 1 — 逐行提取

对每个目录页（`toc_start` 到 `toc_end`，含），用 pdfplumber 提取词级数据，按 `round(top, 0)` 分组为行，跳过：
- 页眉行（行内任意词的 top < `header_bottom`）
- 页脚行（行内任意词的 top > `footer_top`）

### Step 2 — 识别页码

每行中，检查最后一个词是否为有效页码：
- 词文本为纯数字
- 根据数字位数选对应阈值：1位用 `page_x1_1`，2位用 `page_x1_2`，3位用 `page_x1_3`，4位及以上用 `page_x1_4`
- 该词的 x0 ≥ 对应阈值

满足以上条件则识别为页码，其余词拼接为标题文字。否则该行为**无页码行**。

### Step 3 — 多行标题合并

若当前行无页码，将其文字暂存为"待合并前缀"。下一行若有页码，则将前缀与当前行标题拼接（空格连接），使用当前行页码，清空前缀。若连续多行无页码，继续累积前缀。

### Step 4 — 构建 outlines

每条有效条目输出：

```python
{
    'title': str,   # 标题文字（去除首尾空格）
    'depth': 0,     # 不区分层级，全部为 0
    'page': int,    # 0-based 页索引（印刷页码 - 1）
    'top': None,    # 无坐标，不使用 --precise 模式
}
```

### Step 5 — 与 pdf_slicer.py 集成

`toc_parser.py` 导出 `parse_toc(pdf_path, toc_start, toc_end, header_bottom, footer_top, page_x1_1, page_x1_2, page_x1_3, page_x1_4) -> list` 函数。

`pdf_slicer.py` 新增一组参数（`--toc-start`、`--toc-end`、`--header-bottom`、`--footer-top`、`--page-x1-1/2/3/4`），当 `extract_outlines()` 返回空且这些参数已提供时，自动调用 `parse_toc()` 作为回退。

---

## 输出格式

解析结果示例：

```json
[
  {"title": "About This Manual", "depth": 0, "page": 22, "top": null},
  {"title": "Audience",          "depth": 0, "page": 22, "top": null},
  {"title": "Introduction and Setup Guide", "depth": 0, "page": 29, "top": null}
]
```

---

## 验证方法

```bash
cd workspcace/scripts

# 先单独验证解析结果
python toc_parser.py ../row/InnovusUserGuide.pdf \
    --toc-start 4 --toc-end 22 \
    --header-bottom 50 --footer-top 740 \
    --page-x1-1 558 --page-x1-2 558 --page-x1-3 550 --page-x1-4 540

# 再运行完整切片
python pdf_slicer.py ../row/InnovusUserGuide.pdf ../wiki/InnovusUserGuide \
    --strip-headers --merge-cross-page \
    --toc-start 4 --toc-end 22 \
    --header-bottom 50 --footer-top 740 \
    --page-x1-1 558 --page-x1-2 558 --page-x1-3 550 --page-x1-4 540
```

（无 `--precise`，因为 `top=None`）
