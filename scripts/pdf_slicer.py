import argparse
import json
import os
import re
import sys
from pathlib import Path

import pdfplumber
from pypdf import PdfReader

SENTENCE_ENDINGS = {'.', ':', ';', '?', '!'}
_ZERO_WIDTH = re.compile(r'[\u200b\u200c\u200d\ufeff\u00ad]')


# ---------------------------------------------------------------------------
# Bookmark extraction
# ---------------------------------------------------------------------------

def extract_outlines(pdf_path):
    """Return list of {'title', 'depth', 'page', 'top'} from PDF bookmarks.

    page: 0-based page index (int, as returned by pypdf)
    top:  PDF-native y coordinate from page bottom (float), or None
    """
    reader = PdfReader(pdf_path)

    # Build indirect object id -> page index map (handles IndirectObject /Page refs)
    page_id_to_idx = {}
    for i, page in enumerate(reader.pages):
        if hasattr(page, 'indirect_reference') and page.indirect_reference:
            page_id_to_idx[page.indirect_reference.idnum] = i

    results = []

    def walk(items, depth=0):
        for item in items:
            if isinstance(item, list):
                walk(item, depth + 1)
                continue
            if not isinstance(item, dict):
                continue
            title = item.get('/Title', '')
            raw_page = item.get('/Page')
            top = item.get('/Top')
            if isinstance(raw_page, (int, float)):
                page_idx = int(raw_page)
            elif hasattr(raw_page, 'idnum'):
                page_idx = page_id_to_idx.get(raw_page.idnum)
            else:
                page_idx = None
            top_val = float(top) if top is not None else None
            results.append({
                'title': title,
                'depth': depth,
                'page': page_idx,
                'top': top_val,
            })

    walk(reader.outline)
    return results


# ---------------------------------------------------------------------------
# Header/footer detection
# ---------------------------------------------------------------------------

def detect_header_footer_margins(pdf, page_indices):
    import math
    from collections import Counter
    top_lines = Counter()
    bot_lines = Counter()
    n = 0

    for idx in page_indices:
        if idx >= len(pdf.pages):
            continue
        page = pdf.pages[idx]
        words = page.extract_words()
        if not words:
            continue
        n += 1
        page_h = page.height
        for w in words:
            if w['top'] < page_h * 0.08:
                top_lines[math.ceil(w['bottom'])] += 1
            if w['top'] > page_h * 0.92:
                bot_lines[math.floor(w['top'])] += 1

    threshold = n * 0.7
    header_bottom = max((y for y, c in top_lines.items() if c >= threshold), default=0)
    footer_top = min((y for y, c in bot_lines.items() if c >= threshold), default=None)
    return header_bottom, footer_top


# ---------------------------------------------------------------------------
# Cell / merge helpers
# ---------------------------------------------------------------------------

def clean_cell(cell):
    text = _ZERO_WIDTH.sub('', "" if cell is None else str(cell).strip())
    return text.replace('\n', ' ')


def _normalize_ocr_text(text):
    text = _ZERO_WIDTH.sub('', "" if text is None else str(text))
    text = re.sub(r'\s+', ' ', text)
    return text.strip()


def _should_merge_text(prev_text, next_text):
    p = prev_text.rstrip()
    n = next_text.lstrip()
    return p and n and p[-1] not in SENTENCE_ENDINGS and n[0].islower()


def _should_merge_table(prev_table, next_table):
    return (prev_table and next_table
            and len(prev_table[0]) == len(next_table[0])
            and prev_table[0] == next_table[0])


# ---------------------------------------------------------------------------
# OCR helpers
# ---------------------------------------------------------------------------

def _build_ocr_engine():
    try:
        import rapidocr
        from rapidocr import RapidOCR
    except ImportError as exc:
        raise RuntimeError(
            "OCR mode requires the 'rapidocr' package to be installed."
        ) from exc

    model_root = Path(rapidocr.__file__).resolve().parent / 'models'
    model_paths = {
        'Det.model_path': model_root / 'ch_PP-OCRv4_det_infer.onnx',
        'Cls.model_path': model_root / 'ch_ppocr_mobile_v2.0_cls_infer.onnx',
        'Rec.model_path': model_root / 'ch_PP-OCRv4_rec_infer.onnx',
        'Rec.rec_keys_path': model_root / 'ppocr_keys_v1.txt',
    }
    missing = [str(path) for path in model_paths.values() if not path.exists()]
    if missing:
        raise RuntimeError(
            "OCR mode requires RapidOCR local model files. Missing: "
            + ", ".join(missing)
        )

    params = {
        'Global.model_root_dir': str(model_root),
        'Global.log_level': 'warning',
        'Det.model_path': str(model_paths['Det.model_path']),
        'Cls.model_path': str(model_paths['Cls.model_path']),
        'Rec.model_path': str(model_paths['Rec.model_path']),
        'Rec.rec_keys_path': str(model_paths['Rec.rec_keys_path']),
    }
    return RapidOCR(params=params)


def _render_page_clip(ocr_page, crop_bbox, render_scale):
    import fitz

    clip = fitz.Rect(*crop_bbox)
    matrix = fitz.Matrix(render_scale, render_scale)
    pix = ocr_page.get_pixmap(matrix=matrix, clip=clip, alpha=False)
    return pix.tobytes('png')


def _cluster_ocr_lines(lines):
    items = []
    current = None
    prev_line = None

    for line in lines:
        text = _normalize_ocr_text(line['text'])
        if not text:
            continue

        if current is None:
            current = {'_top': line['top'], 'type': 'text', 'lines': [text]}
        else:
            prev_height = max(prev_line['bottom'] - prev_line['top'], 1.0)
            cur_height = max(line['bottom'] - line['top'], 1.0)
            gap = line['top'] - prev_line['bottom']
            if gap > max(prev_height, cur_height) * 0.8:
                items.append(current)
                current = {'_top': line['top'], 'type': 'text', 'lines': [text]}
            else:
                current['lines'].append(text)

        prev_line = line

    if current is not None:
        items.append(current)

    return [{k: v for k, v in item.items() if k != '_top'} for item in items]


def _extract_page_content_ocr(page, page_idx, ocr_page, ocr_engine, render_scale):
    crop_bbox = page.bbox
    image_bytes = _render_page_clip(ocr_page, crop_bbox, render_scale)
    result = ocr_engine(image_bytes)
    if result is None or len(result) == 0 or result.boxes is None:
        return []

    lines = []
    clip_x0, clip_top, _, _ = crop_bbox
    for box, text in zip(result.boxes, result.txts):
        if not text:
            continue
        xs = [pt[0] for pt in box]
        ys = [pt[1] for pt in box]
        lines.append({
            'page': page_idx + 1,
            'x0': clip_x0 + (min(xs) / render_scale),
            'x1': clip_x0 + (max(xs) / render_scale),
            'top': clip_top + (min(ys) / render_scale),
            'bottom': clip_top + (max(ys) / render_scale),
            'text': text,
        })

    lines.sort(key=lambda item: (item['top'], item['x0']))
    return _cluster_ocr_lines(lines)


def _normalize_fitz_text(text):
    text = _ZERO_WIDTH.sub('', "" if text is None else str(text))
    lines = []
    for line in text.splitlines():
        line = re.sub(r'\s+', ' ', line).strip()
        if line:
            lines.append(line)
    return '\n'.join(lines)


def _extract_page_content_fitz(page, page_idx, fitz_page, tables):
    import fitz

    def overlaps_table(block_bbox):
        bx0, btop, bx1, bbot = block_bbox
        for table in tables:
            tx0, ttop, tx1, tbot = table.bbox
            if bx0 < tx1 and bx1 > tx0 and btop < tbot and bbot > ttop:
                return True
        return False

    clip = fitz.Rect(*page.bbox)
    blocks = fitz_page.get_text('blocks', clip=clip, sort=True)
    items = []
    for block in blocks:
        if len(block) >= 7 and block[6] != 0:
            continue
        if overlaps_table(block[:4]):
            continue
        text = _normalize_fitz_text(block[4] if len(block) > 4 else '')
        if not text:
            continue
        items.append({
            '_top': float(block[1]),
            'type': 'text',
            'lines': text.split('\n'),
        })

    items.sort(key=lambda item: item['_top'])
    return items


def _extract_table_items(tables, page_idx):
    items = []
    for t_idx, table in enumerate(tables):
        rows = table.extract()
        if not rows:
            continue
        cleaned = [[clean_cell(c) for c in row] for row in rows]
        items.append({
            '_top': table.bbox[1],
            'type': 'table',
            'page': page_idx + 1,
            'table_index': t_idx,
            'data': cleaned,
        })

    return items


# ---------------------------------------------------------------------------
# Single-page content extraction (after crop)
# ---------------------------------------------------------------------------

def _extract_page_content(page, page_idx, ocr_doc=None, ocr_engine=None,
                          ocr_scale=2.0, fitz_doc=None):
    """Extract ordered text+table items from an already-cropped pdfplumber page."""
    if ocr_engine is not None:
        return _extract_page_content_ocr(
            page, page_idx, ocr_doc[page_idx], ocr_engine, ocr_scale
        )

    tables = page.find_tables()
    table_bboxes = [t.bbox for t in tables]

    if fitz_doc is not None:
        items = _extract_page_content_fitz(page, page_idx, fitz_doc[page_idx], tables)
        items.extend(_extract_table_items(tables, page_idx))
        items.sort(key=lambda x: x['_top'])
        return [{k: v for k, v in it.items() if k != '_top'} for it in items]

    def outside_tables(obj):
        for bbox in table_bboxes:
            if (obj['x0'] >= bbox[0] and obj['x1'] <= bbox[2]
                    and obj['top'] >= bbox[1] and obj['bottom'] <= bbox[3]):
                return False
        return True

    # Word-level filter keeps precision; words are then bucketed by table y-intervals
    # so text above and below each table becomes separate items rather than one merged block.
    filtered = page.filter(outside_tables)
    words = filtered.extract_words()

    items = []
    if words:
        x0, page_top, x1, page_bot = page.bbox
        # Build y-interval boundaries: [page_top, t0.top, t0.bot, t1.top, t1.bot, ..., page_bot]
        sorted_tables = sorted(tables, key=lambda t: t.bbox[1])
        boundaries = [page_top]
        for t in sorted_tables:
            boundaries.append(t.bbox[1])   # table top
            boundaries.append(t.bbox[3])   # table bottom
        boundaries.append(page_bot)

        # Pair boundaries into (band_top, band_bot) slots between tables
        for i in range(0, len(boundaries) - 1, 2):
            band_top = boundaries[i]
            band_bot = boundaries[i + 1]
            band_words = [w for w in words if w['top'] >= band_top and w['bottom'] <= band_bot]
            if not band_words:
                continue
            band_text = filtered.crop((x0, band_top, x1, band_bot)).extract_text() or ""
            band_text = _ZERO_WIDTH.sub('', band_text.strip())
            if band_text:
                items.append({
                    '_top': band_words[0]['top'],
                    'type': 'text',
                    'lines': band_text.split('\n'),
                })

    items.extend(_extract_table_items(tables, page_idx))

    items.sort(key=lambda x: x['_top'])
    return [{k: v for k, v in it.items() if k != '_top'} for it in items]


# ---------------------------------------------------------------------------
# Chapter extraction — default (page-range) mode
# ---------------------------------------------------------------------------

def extract_chapter_pages(pdf, start_page, end_page, strip_margins=None,
                           merge_cross_page=False, ocr_doc=None,
                           ocr_engine=None, ocr_scale=2.0, fitz_doc=None):
    content = []
    prev_last = None

    for page_idx in range(start_page, end_page):
        if page_idx >= len(pdf.pages):
            break
        page = pdf.pages[page_idx]

        if strip_margins:
            hb, ft = strip_margins
            x0, y0, x1, y1 = page.bbox
            page = page.crop((x0, hb or y0, x1, ft or y1))

        page_items = _extract_page_content(
            page, page_idx, ocr_doc=ocr_doc, ocr_engine=ocr_engine,
            ocr_scale=ocr_scale, fitz_doc=fitz_doc
        )
        content, prev_last = _apply_merge(content, page_items, prev_last,
                                          merge_cross_page)

    return content


# ---------------------------------------------------------------------------
# Chapter extraction — precise (coordinate) mode
# ---------------------------------------------------------------------------

def extract_chapter_precise(pdf, start_page, start_y, end_page, end_y,
                             strip_margins=None, merge_cross_page=False,
                             ocr_doc=None, ocr_engine=None, ocr_scale=2.0,
                             fitz_doc=None):
    """Extract content between (start_page, start_y) and (end_page, end_y).

    start_y / end_y are pdfplumber coordinates (from page top).
    """
    content = []
    prev_last = None

    for page_idx in range(start_page, end_page + 1):
        if page_idx >= len(pdf.pages):
            break
        page = pdf.pages[page_idx]
        x0, _, x1, _ = page.bbox
        page_h = page.height

        # Determine crop bounds for this page
        if start_page == end_page:
            crop_top, crop_bot = start_y, end_y
        elif page_idx == start_page:
            crop_top, crop_bot = start_y, page_h
        elif page_idx == end_page:
            crop_top, crop_bot = 0, end_y
        else:
            crop_top, crop_bot = 0, page_h

        # Overlay strip-headers margins
        if strip_margins:
            hb, ft = strip_margins
            crop_top = max(crop_top, hb or 0)
            crop_bot = min(crop_bot, ft or page_h)

        if crop_top >= crop_bot:
            continue

        page = page.crop((x0, crop_top, x1, crop_bot))
        page_items = _extract_page_content(
            page, page_idx, ocr_doc=ocr_doc, ocr_engine=ocr_engine,
            ocr_scale=ocr_scale, fitz_doc=fitz_doc
        )
        content, prev_last = _apply_merge(content, page_items, prev_last,
                                          merge_cross_page)

    return content


# ---------------------------------------------------------------------------
# Cross-page merge helper
# ---------------------------------------------------------------------------

def _apply_merge(content, page_items, prev_last, merge_cross_page):
    if merge_cross_page and prev_last is not None and page_items:
        first = page_items[0]
        if prev_last['type'] == 'text' and first['type'] == 'text':
            prev_text = '\n'.join(prev_last['lines'])
            first_text = '\n'.join(first['lines'])
            if _should_merge_text(prev_text, first_text):
                merged = prev_text.rstrip() + ' ' + first_text.lstrip()
                content[-1]['lines'] = merged.split('\n')
                page_items = page_items[1:]
        elif prev_last['type'] == 'table' and first['type'] == 'table':
            if _should_merge_table(prev_last['data'], first['data']):
                content[-1]['data'] = prev_last['data'] + first['data'][1:]
                page_items = page_items[1:]

    content.extend(page_items)
    prev_last = content[-1] if content else None
    return content, prev_last


# ---------------------------------------------------------------------------
# Chapter list builders
# ---------------------------------------------------------------------------

def build_chapters_pages(outlines, total_pages):
    valid = [o for o in outlines if o['page'] is not None]
    chapters = []
    for i, o in enumerate(valid):
        start = o['page']
        next_start = valid[i + 1]['page'] if i + 1 < len(valid) else total_pages
        end = next_start + 1 if next_start < total_pages else total_pages
        chapters.append({
            'index': i + 1,
            'title': o['title'],
            'depth': o['depth'],
            'page_start': start,
            'page_end': end,
        })
    return chapters


def build_chapters_precise(outlines, pdf, total_pages):
    """Build chapter list with pdfplumber y coordinates."""
    valid = [o for o in outlines if o['page'] is not None]
    chapters = []
    for i, o in enumerate(valid):
        sp = o['page']
        page_h = pdf.pages[sp].height
        # Convert PDF-native top (from bottom) → pdfplumber top (from top)
        sy = page_h - o['top']

        if i + 1 < len(valid):
            ep = valid[i + 1]['page']
            ep_h = pdf.pages[ep].height
            ey = ep_h - valid[i + 1]['top']
        else:
            ep = total_pages - 1
            ey = pdf.pages[ep].height

        chapters.append({
            'index': i + 1,
            'title': o['title'],
            'depth': o['depth'],
            'start_page': sp,
            'start_y': sy,
            'end_page': ep,
            'end_y': ey,
            # for toc / display
            'page_start': sp,
            'page_end': ep,
        })
    return chapters


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    if sys.stdout.encoding and sys.stdout.encoding.lower() in ('gbk', 'cp936', 'gb2312'):
        import io
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

    parser = argparse.ArgumentParser(
        description='Slice PDF by TOC into per-chapter JSON files')
    parser.add_argument('pdf_path')
    parser.add_argument('output_dir')
    parser.add_argument('--from', dest='from_ch', type=int, default=1)
    parser.add_argument('--to', dest='to_ch', type=int, default=None)
    parser.add_argument('--merge-cross-page', action='store_true')
    parser.add_argument('--strip-headers', action='store_true')
    parser.add_argument('--precise', action='store_true',
                        help='Use bookmark /Top y-coordinate for exact slicing. '
                             'Aborts if any bookmark lacks /Top.')
    parser.add_argument('--ocr-text', action='store_true',
                        help='Use offline OCR on rendered page images for text '
                             'extraction. Useful for PDFs whose embedded text '
                             'layer is garbled due to bad font mapping. '
                             'Tables are flattened into text lines in this mode.')
    parser.add_argument('--fitz-text', action='store_true',
                        help='Use PyMuPDF text extraction instead of pdfplumber. '
                             'Useful when pdfplumber sees words but extracts '
                             'blank text for a PDF.')
    parser.add_argument('--ocr-scale', type=float, default=2.0,
                        help='Render scale for OCR mode. Higher values improve '
                             'accuracy but run slower. Default: 2.0')
    # TOC parser fallback (for PDFs without bookmarks)
    parser.add_argument('--toc-start',     type=int,   default=None)
    parser.add_argument('--toc-end',       type=int,   default=None)
    parser.add_argument('--header-bottom', type=float, default=None)
    parser.add_argument('--footer-top',    type=float, default=None)
    parser.add_argument('--page-x1-1',    type=float, default=None)
    parser.add_argument('--page-x1-2',    type=float, default=None)
    parser.add_argument('--page-x1-3',    type=float, default=None)
    parser.add_argument('--page-x1-4',    type=float, default=None)
    parser.add_argument('--skip-x0-max',  type=float, default=None)
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)

    if args.ocr_text and args.fitz_text:
        print("Error: --ocr-text and --fitz-text are mutually exclusive.",
              file=sys.stderr)
        sys.exit(1)

    print("Extracting TOC...")
    outlines = extract_outlines(args.pdf_path)
    if not outlines:
        toc_args = [args.toc_start, args.toc_end, args.header_bottom,
                    args.footer_top, args.page_x1_1, args.page_x1_2,
                    args.page_x1_3, args.page_x1_4]
        if any(a is None for a in toc_args):
            print("Error: no bookmarks found. Provide --toc-start/--toc-end/--header-bottom/"
                  "--footer-top/--page-x1-1/2/3/4 to parse TOC pages instead.",
                  file=sys.stderr)
            sys.exit(1)
        from toc_parser import parse_toc
        print("No bookmarks found, falling back to TOC page parsing...")
        outlines = parse_toc(
            args.pdf_path,
            toc_start=args.toc_start, toc_end=args.toc_end,
            header_bottom=args.header_bottom, footer_top=args.footer_top,
            page_x1_1=args.page_x1_1, page_x1_2=args.page_x1_2,
            page_x1_3=args.page_x1_3, page_x1_4=args.page_x1_4,
            skip_x0_max=args.skip_x0_max,
        )
        if not outlines:
            print("Error: TOC parsing returned no entries.", file=sys.stderr)
            sys.exit(1)
        print(f"  Parsed {len(outlines)} entries from TOC pages")

    # --precise: validate all bookmarks have /Top
    if args.precise:
        missing = [(i + 1, o) for i, o in enumerate(outlines) if o['top'] is None]
        if missing:
            idx, o = missing[0]
            print(
                f'Error: bookmark "{o["title"]}" (index {idx}) has no /Top coordinate. '
                f'--precise requires all bookmarks to have /Top. Aborting.',
                file=sys.stderr)
            sys.exit(1)

    ocr_doc = None
    ocr_engine = None
    fitz_doc = None
    if args.fitz_text:
        try:
            import fitz
        except ImportError as exc:
            print("Error: --fitz-text requires the 'PyMuPDF' package.",
                  file=sys.stderr)
            raise SystemExit(1) from exc
        fitz_doc = fitz.open(args.pdf_path)
        print("PyMuPDF text mode enabled. Text is extracted from the embedded "
              "PDF text layer with fitz.")

    if args.ocr_text:
        if args.ocr_scale <= 0:
            print("Error: --ocr-scale must be > 0.", file=sys.stderr)
            sys.exit(1)
        try:
            import fitz
        except ImportError as exc:
            print("Error: OCR mode requires the 'PyMuPDF' package.", file=sys.stderr)
            raise SystemExit(1) from exc
        try:
            ocr_engine = _build_ocr_engine()
        except RuntimeError as exc:
            print(f"Error: {exc}", file=sys.stderr)
            sys.exit(1)
        ocr_doc = fitz.open(args.pdf_path)
        print(f"OCR mode enabled: render_scale={args.ocr_scale}. "
              f"Text is extracted from page images to avoid garbled font maps.")

    try:
        with pdfplumber.open(args.pdf_path) as pdf:
            total_pages = len(pdf.pages)

            if args.precise:
                chapters = build_chapters_precise(outlines, pdf, total_pages)
            else:
                chapters = build_chapters_pages(outlines, total_pages)

            to_ch = args.to_ch if args.to_ch else len(chapters)
            selected = [c for c in chapters if args.from_ch <= c['index'] <= to_ch]
            mode = 'precise' if args.precise else 'page-range'
            print(f"Found {len(chapters)} chapters, processing {len(selected)} "
                  f"({args.from_ch}–{to_ch})  mode={mode}")

            strip_margins = None
            if args.strip_headers:
                import random
                print("Detecting header/footer margins...")
                body_pages = []
                for ch in chapters:
                    p = ch.get('start_page', ch.get('page_start', 0))
                    if p not in body_pages:
                        body_pages.append(p)
                rng = random.Random(len(body_pages))
                sample = rng.sample(body_pages, min(20, len(body_pages)))
                strip_margins = detect_header_footer_margins(pdf, sample)
                print(f"  header_bottom={strip_margins[0]}, footer_top={strip_margins[1]}")

            toc = []
            parent_stack = {}  # depth -> title
            for ch in selected:
                d = ch['depth']
                parent = parent_stack.get(d - 1) if d > 0 else None
                parent_stack[d] = ch['title']
                # invalidate deeper levels
                for k in list(parent_stack):
                    if k > d:
                        del parent_stack[k]
                toc.append({
                    'index': ch['index'],
                    'title': ch['title'],
                    'depth': d,
                    'parent': parent,
                    'page_start': ch['page_start'] + 1,
                    'page_end': ch['page_end'] + 1,
                    'file': f"chapter_{ch['index']:04d}.json",
                })

            toc_path = os.path.join(args.output_dir, 'toc.json')
            with open(toc_path, 'w', encoding='utf-8') as f:
                json.dump(toc, f, ensure_ascii=False, indent=2)
            print(f"Written {toc_path}")

            for ch in selected:
                print(f"[{ch['index']}/{len(chapters)}] {ch['title'][:60]}  "
                      f"pages {ch['page_start']+1}–{ch['page_end']+1}")

                if args.precise:
                    content = extract_chapter_precise(
                        pdf,
                        ch['start_page'], ch['start_y'],
                        ch['end_page'],   ch['end_y'],
                        strip_margins=strip_margins,
                        merge_cross_page=args.merge_cross_page,
                        ocr_doc=ocr_doc,
                        ocr_engine=ocr_engine,
                        ocr_scale=args.ocr_scale,
                        fitz_doc=fitz_doc,
                    )
                else:
                    content = extract_chapter_pages(
                        pdf,
                        ch['page_start'], ch['page_end'],
                        strip_margins=strip_margins,
                        merge_cross_page=args.merge_cross_page,
                        ocr_doc=ocr_doc,
                        ocr_engine=ocr_engine,
                        ocr_scale=args.ocr_scale,
                        fitz_doc=fitz_doc,
                    )

                out = {
                    'index': ch['index'],
                    'title': ch['title'],
                    'depth': ch['depth'],
                    'page_start': ch['page_start'] + 1,
                    'page_end': ch['page_end'] + 1,
                    'content': content,
                }
                out_path = os.path.join(args.output_dir, f"chapter_{ch['index']:04d}.json")
                with open(out_path, 'w', encoding='utf-8') as f:
                    json.dump(out, f, ensure_ascii=False, indent=2)
                del content, out
    finally:
        if ocr_doc is not None:
            ocr_doc.close()
        if fitz_doc is not None:
            fitz_doc.close()

    print("Done.")


if __name__ == '__main__':
    main()
