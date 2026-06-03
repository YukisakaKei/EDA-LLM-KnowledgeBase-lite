# toc_parser.py — 使用说明

适用于没有 PDF 书签的文档，从目录页解析章节结构，可单独运行验证，也可通过 `pdf_slicer.py` 的 TOC 参数组自动调用。

## 单独运行（验证解析结果）

```bash
python toc_parser.py <pdf_path>
    --toc-start N       目录起始页（1-based 印刷页码）
    --toc-end M         目录结束页（1-based 印刷页码）
    --header-bottom H   页眉底部 y 坐标，低于此值的行跳过
    --footer-top F      页脚顶部 y 坐标，高于此值的行跳过
    --page-x1-1 X       个位数页码（1–9）的最小 x0
    --page-x1-2 X       两位数页码（10–99）的最小 x0
    --page-x1-3 X       三位数页码（100–999）的最小 x0
    --page-x1-4 X       四位数页码（1000+）的最小 x0
    [--skip-x0-max S]   无页码行中，x0 ≤ S 的行直接丢弃（用于排除目录大标题等）
```

所有参数均为必填（`--skip-x0-max` 可选），需根据实际 PDF 测量后传入。

输出：打印解析到的条目总数、前 10 条和末 5 条，所有 WARNING 行打印到 stderr。

## 如何测量参数值

用以下脚本查看目录页的词级坐标：

```python
import pdfplumber
from collections import defaultdict

with pdfplumber.open('manual.pdf') as pdf:
    page = pdf.pages[N]  # 目录页 0-based 索引
    words = page.extract_words()
    lines = defaultdict(list)
    for w in words:
        lines[round(w['top'], 0)].append(w)
    for top, ws in sorted(lines.items()):
        print(f"top={top:.0f} x0={ws[0]['x0']:.0f} last_x1={ws[-1]['x1']:.0f} texts={[w['text'] for w in ws]}")
```

- `header_bottom`：页眉最后一行的 bottom 值（加几点余量）
- `footer_top`：页脚第一行的 top 值
- `page-x1-N`：页码列的 x0（观察不同位数页码所在列的 x0）
- `skip-x0-max`：无页码行中需要丢弃的行的 x0（如目录大标题 `Contents`）

## 集成到 pdf_slicer.py

`pdf_slicer.py` 在书签为空时自动回退，只需在原有命令后追加 TOC 参数组：

```bash
python pdf_slicer.py manual.pdf out/ --strip-headers --merge-cross-page \
    --toc-start 4 --toc-end 22 \
    --header-bottom 50 --footer-top 740 \
    --page-x1-1 558 --page-x1-2 558 --page-x1-3 550 --page-x1-4 540 \
    --skip-x0-max 36
```

注意：TOC 解析模式下 `top=None`，不支持 `--precise`。

## WARNING 说明

| WARNING 类型 | 含义 | 处理方式 |
|---|---|---|
| `skipping no-page-num line (x0=X <= S)` | 无页码行被 `--skip-x0-max` 丢弃 | 确认是目录标题，正常 |
| `no page number on line, accumulating as prefix` | 无页码行被累积为下一条的标题前缀 | 确认是多行标题续行，正常；若不是则调整参数 |
