import argparse
import json
import sys
from collections import defaultdict

import pdfplumber


def parse_toc(pdf_path, toc_start, toc_end, header_bottom, footer_top,
              page_x1_1, page_x1_2, page_x1_3, page_x1_4, skip_x0_max=None):
    """Parse Table of Contents pages and return outlines list.

    toc_start / toc_end: 1-based printed page numbers (inclusive).
    header_bottom / footer_top: y-coordinate thresholds to skip headers/footers.
    page_x1_N: minimum x0 for a word to be considered a page number with N digits.
    skip_x0_max: lines without a page number whose x0 <= this value are discarded
                 (not accumulated as prefix). Useful for section dividers / TOC title rows.
    Returns list of {'title', 'depth', 'page', 'top'} dicts (top is always None).
    """
    x1_thresholds = {1: page_x1_1, 2: page_x1_2, 3: page_x1_3}

    def _page_x1(n_digits):
        if n_digits <= 3:
            return x1_thresholds[n_digits]
        return page_x1_4

    def _is_page_num(word):
        text = word['text']
        if not text.isdigit():
            return False
        return word['x0'] >= _page_x1(len(text))

    outlines = []
    pending_prefix = []

    with pdfplumber.open(pdf_path) as pdf:
        for pg_idx in range(toc_start - 1, toc_end):
            if pg_idx >= len(pdf.pages):
                break
            page = pdf.pages[pg_idx]
            words = page.extract_words()

            lines = defaultdict(list)
            for w in words:
                if w['top'] < header_bottom or w['top'] > footer_top:
                    continue
                lines[round(w['top'], 0)].append(w)

            for top in sorted(lines):
                ws = lines[top]
                if _is_page_num(ws[-1]):
                    page_num = int(ws[-1]['text'])
                    title_words = ws[:-1]
                    title = ' '.join(w['text'] for w in title_words).strip()
                    if pending_prefix:
                        title = ' '.join(pending_prefix) + ' ' + title
                        pending_prefix = []
                    if title:
                        outlines.append({
                            'title': title,
                            'depth': 0,
                            'page': page_num - 1,  # 0-based
                            'top': None,
                        })
                else:
                    text = ' '.join(w['text'] for w in ws).strip()
                    if not text:
                        continue
                    if skip_x0_max is not None and ws[0]['x0'] <= skip_x0_max:
                        print(f"WARNING: skipping no-page-num line (x0={ws[0]['x0']:.0f} <= {skip_x0_max}): {text!r}",
                              file=sys.stderr)
                    else:
                        print(f"WARNING: no page number on line, accumulating as prefix: {text!r}",
                              file=sys.stderr)
                        pending_prefix.append(text)

    return outlines


def main():
    if sys.stdout.encoding and sys.stdout.encoding.lower() in ('gbk', 'cp936', 'gb2312'):
        import io
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

    parser = argparse.ArgumentParser(description='Parse PDF Table of Contents into outlines JSON')
    parser.add_argument('pdf_path')
    parser.add_argument('--toc-start',    type=int, required=True)
    parser.add_argument('--toc-end',      type=int, required=True)
    parser.add_argument('--header-bottom', type=float, required=True)
    parser.add_argument('--footer-top',    type=float, required=True)
    parser.add_argument('--page-x1-1',    type=float, required=True)
    parser.add_argument('--page-x1-2',    type=float, required=True)
    parser.add_argument('--page-x1-3',    type=float, required=True)
    parser.add_argument('--page-x1-4',    type=float, required=True)
    parser.add_argument('--skip-x0-max',  type=float, default=None,
                        help='Lines without a page number whose x0 <= this value are discarded')
    args = parser.parse_args()

    outlines = parse_toc(
        args.pdf_path,
        toc_start=args.toc_start,
        toc_end=args.toc_end,
        header_bottom=args.header_bottom,
        footer_top=args.footer_top,
        page_x1_1=args.page_x1_1,
        page_x1_2=args.page_x1_2,
        page_x1_3=args.page_x1_3,
        page_x1_4=args.page_x1_4,
        skip_x0_max=args.skip_x0_max,
    )

    print(f"Parsed {len(outlines)} entries")
    print(json.dumps(outlines[:10], ensure_ascii=False, indent=2))
    print("...")
    print(json.dumps(outlines[-5:], ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
