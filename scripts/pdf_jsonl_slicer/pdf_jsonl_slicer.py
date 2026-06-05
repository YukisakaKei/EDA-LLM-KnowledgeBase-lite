from __future__ import annotations

import argparse
import io
import random
import sys
from pathlib import Path
from typing import Any

import pdfplumber


CURRENT_DIR = Path(__file__).resolve().parent
SCRIPTS_DIR = CURRENT_DIR.parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from jsonl_utils.jsonl_utils import write_jsonl  # noqa: E402
from pdf_slicer import (  # noqa: E402
    _build_ocr_engine,
    build_chapters_pages,
    build_chapters_precise,
    detect_header_footer_margins,
    extract_chapter_pages,
    extract_chapter_precise,
    extract_outlines,
)


def ensure_utf8_stdio() -> None:
    """Keep progress output readable on Windows terminals using GBK."""
    if sys.stdout.encoding and sys.stdout.encoding.lower() in ("gbk", "cp936", "gb2312"):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Slice a PDF by bookmarks or TOC fallback into one JSONL file."
    )
    parser.add_argument("pdf_path", help="Input PDF file path.")
    parser.add_argument(
        "output_jsonl",
        help="Output .jsonl path. If a directory is given, <pdf-stem>.jsonl is used.",
    )
    parser.add_argument("--from", dest="from_ch", type=int, default=1)
    parser.add_argument("--to", dest="to_ch", type=int, default=None)
    parser.add_argument("--merge-cross-page", action="store_true")
    parser.add_argument("--strip-headers", action="store_true")
    parser.add_argument(
        "--precise",
        action="store_true",
        help="Use bookmark /Top y-coordinate for exact slicing; aborts if any bookmark lacks /Top.",
    )

    backend = parser.add_mutually_exclusive_group()
    backend.add_argument(
        "--ocr-text",
        action="store_true",
        help="Use offline OCR for text extraction. Tables are flattened into OCR text lines.",
    )
    backend.add_argument(
        "--fitz-text",
        action="store_true",
        help="Use PyMuPDF text extraction while keeping pdfplumber table extraction.",
    )
    parser.add_argument(
        "--ocr-scale",
        type=float,
        default=2.0,
        help="Render scale for OCR mode. Default: 2.0.",
    )

    parser.add_argument("--toc-start", type=int, default=None)
    parser.add_argument("--toc-end", type=int, default=None)
    parser.add_argument("--header-bottom", type=float, default=None)
    parser.add_argument("--footer-top", type=float, default=None)
    parser.add_argument("--page-x1-1", type=float, default=None)
    parser.add_argument("--page-x1-2", type=float, default=None)
    parser.add_argument("--page-x1-3", type=float, default=None)
    parser.add_argument("--page-x1-4", type=float, default=None)
    parser.add_argument("--skip-x0-max", type=float, default=None)
    return parser


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.from_ch < 1:
        parser.error("--from must be >= 1")
    if args.to_ch is not None and args.to_ch < args.from_ch:
        parser.error("--to must be >= --from")
    if args.ocr_scale <= 0:
        parser.error("--ocr-scale must be > 0")
    return args


def resolve_output_path(pdf_path: str | Path, output_arg: str | Path) -> Path:
    path = Path(output_arg)
    if path.suffix.lower() == ".jsonl":
        return path
    if path.exists() and path.is_file():
        return path
    return path / f"{Path(pdf_path).stem}.jsonl"


def load_outlines(args: argparse.Namespace) -> list[dict[str, Any]]:
    print("Extracting TOC...")
    outlines = extract_outlines(args.pdf_path)
    if outlines:
        print(f"  Found {len(outlines)} bookmark entries")
        return outlines

    toc_args = [
        args.toc_start,
        args.toc_end,
        args.header_bottom,
        args.footer_top,
        args.page_x1_1,
        args.page_x1_2,
        args.page_x1_3,
        args.page_x1_4,
    ]
    if any(value is None for value in toc_args):
        raise SystemExit(
            "Error: no bookmarks found. Provide --toc-start/--toc-end/--header-bottom/"
            "--footer-top/--page-x1-1/2/3/4 to parse TOC pages instead."
        )

    from toc_parser import parse_toc

    print("No bookmarks found, falling back to TOC page parsing...")
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
    if not outlines:
        raise SystemExit("Error: TOC parsing returned no entries.")
    print(f"  Parsed {len(outlines)} entries from TOC pages")
    return outlines


def validate_precise_outlines(outlines: list[dict[str, Any]]) -> None:
    missing = [(idx + 1, item) for idx, item in enumerate(outlines) if item.get("top") is None]
    if missing:
        index, outline = missing[0]
        title = outline.get("title", "")
        raise SystemExit(
            f'Error: bookmark "{title}" (index {index}) has no /Top coordinate. '
            "--precise requires all bookmarks to have /Top. Aborting."
        )


def prepare_text_backend(args: argparse.Namespace):
    ocr_doc = None
    ocr_engine = None
    fitz_doc = None

    if args.fitz_text:
        try:
            import fitz
        except ImportError as exc:
            raise SystemExit("Error: --fitz-text requires the 'PyMuPDF' package.") from exc
        fitz_doc = fitz.open(args.pdf_path)
        print("PyMuPDF text mode enabled.")

    if args.ocr_text:
        try:
            import fitz
        except ImportError as exc:
            raise SystemExit("Error: OCR mode requires the 'PyMuPDF' package.") from exc
        try:
            ocr_engine = _build_ocr_engine()
        except RuntimeError as exc:
            raise SystemExit(f"Error: {exc}") from exc
        ocr_doc = fitz.open(args.pdf_path)
        print(f"OCR mode enabled: render_scale={args.ocr_scale}.")

    return ocr_doc, ocr_engine, fitz_doc


def close_text_backend(ocr_doc: Any, fitz_doc: Any) -> None:
    if ocr_doc is not None:
        ocr_doc.close()
    if fitz_doc is not None:
        fitz_doc.close()


def build_selected_chapters(args: argparse.Namespace, outlines: list[dict[str, Any]], pdf):
    total_pages = len(pdf.pages)
    if args.precise:
        chapters = build_chapters_precise(outlines, pdf, total_pages)
    else:
        chapters = build_chapters_pages(outlines, total_pages)

    to_ch = args.to_ch if args.to_ch is not None else len(chapters)
    selected = [chapter for chapter in chapters if args.from_ch <= chapter["index"] <= to_ch]
    mode = "precise" if args.precise else "page-range"
    print(f"Found {len(chapters)} chapters, processing {len(selected)} ({args.from_ch}-{to_ch}) mode={mode}")
    return chapters, selected, to_ch


def detect_strip_margins(args: argparse.Namespace, pdf, chapters: list[dict[str, Any]]):
    if not args.strip_headers:
        return None

    print("Detecting header/footer margins...")
    body_pages: list[int] = []
    for chapter in chapters:
        page_index = chapter.get("start_page", chapter.get("page_start", 0))
        if page_index not in body_pages:
            body_pages.append(page_index)

    if not body_pages:
        return None

    rng = random.Random(len(body_pages))
    sample = rng.sample(body_pages, min(20, len(body_pages)))
    margins = detect_header_footer_margins(pdf, sample)
    print(f"  header_bottom={margins[0]}, footer_top={margins[1]}")
    return margins


def extract_content_for_chapter(
    args: argparse.Namespace,
    pdf,
    chapter: dict[str, Any],
    strip_margins,
    ocr_doc,
    ocr_engine,
    fitz_doc,
) -> list[dict[str, Any]]:
    if args.precise:
        return extract_chapter_precise(
            pdf,
            chapter["start_page"],
            chapter["start_y"],
            chapter["end_page"],
            chapter["end_y"],
            strip_margins=strip_margins,
            merge_cross_page=args.merge_cross_page,
            ocr_doc=ocr_doc,
            ocr_engine=ocr_engine,
            ocr_scale=args.ocr_scale,
            fitz_doc=fitz_doc,
        )

    return extract_chapter_pages(
        pdf,
        chapter["page_start"],
        chapter["page_end"],
        strip_margins=strip_margins,
        merge_cross_page=args.merge_cross_page,
        ocr_doc=ocr_doc,
        ocr_engine=ocr_engine,
        ocr_scale=args.ocr_scale,
        fitz_doc=fitz_doc,
    )


def build_entry(chapter: dict[str, Any], content: list[dict[str, Any]], source_file: str) -> dict[str, Any]:
    return {
        "index": chapter["index"],
        "title": chapter["title"],
        "depth": chapter["depth"],
        "source_file": source_file,
        "page_start": chapter["page_start"] + 1,
        "page_end": chapter["page_end"] + 1,
        "content": content,
    }


def slice_pdf_to_entries(args: argparse.Namespace) -> list[dict[str, Any]]:
    outlines = load_outlines(args)
    if args.precise:
        validate_precise_outlines(outlines)

    ocr_doc, ocr_engine, fitz_doc = prepare_text_backend(args)
    try:
        entries: list[dict[str, Any]] = []
        with pdfplumber.open(args.pdf_path) as pdf:
            chapters, selected, _ = build_selected_chapters(args, outlines, pdf)
            strip_margins = detect_strip_margins(args, pdf, chapters)
            source_file = Path(args.pdf_path).name

            for chapter in selected:
                print(
                    f"[{chapter['index']}/{len(chapters)}] {chapter['title'][:60]} "
                    f"pages {chapter['page_start'] + 1}-{chapter['page_end'] + 1}"
                )
                content = extract_content_for_chapter(
                    args,
                    pdf,
                    chapter,
                    strip_margins,
                    ocr_doc,
                    ocr_engine,
                    fitz_doc,
                )
                entries.append(build_entry(chapter, content, source_file))

        return entries
    finally:
        close_text_backend(ocr_doc, fitz_doc)


def main(argv: list[str] | None = None) -> int:
    ensure_utf8_stdio()
    args = parse_args(argv)
    output_path = resolve_output_path(args.pdf_path, args.output_jsonl)
    entries = slice_pdf_to_entries(args)
    line_count = write_jsonl(entries, output_path)
    print(f"Written {output_path} ({line_count} entries)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
