from __future__ import annotations

import argparse
import io
import sys
from pathlib import Path
from typing import Any


CURRENT_DIR = Path(__file__).resolve().parent
SCRIPTS_DIR = CURRENT_DIR.parent
if str(CURRENT_DIR) not in sys.path:
    sys.path.insert(0, str(CURRENT_DIR))
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from html_extractor import extract_chapter_content, parse_toc  # noqa: E402
from jsonl_utils.jsonl_utils import write_jsonl  # noqa: E402


def ensure_utf8_stdio() -> None:
    """Keep progress output readable on Windows terminals using GBK."""
    if sys.stdout.encoding and sys.stdout.encoding.lower() in ("gbk", "cp936", "gb2312"):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Slice a Confluence HTML manual into one JSONL file."
    )
    parser.add_argument("html_dir", help="Directory containing HTML chapter files.")
    parser.add_argument(
        "output_jsonl",
        help="Output .jsonl path. If a directory is given, <html-dir-name>.jsonl is used.",
    )
    parser.add_argument("--toc", required=True, help="Path to TOC HTML file.")
    parser.add_argument(
        "--from",
        dest="from_n",
        type=int,
        default=1,
        metavar="N",
        help="Start from chapter N (1-based, default: 1).",
    )
    parser.add_argument(
        "--to",
        dest="to_n",
        type=int,
        default=None,
        metavar="M",
        help="End at chapter M, inclusive (default: all).",
    )
    parser.add_argument(
        "--skip-empty",
        action="store_true",
        help="Skip chapters with no extracted content without renumbering remaining indexes.",
    )
    return parser


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.from_n < 1:
        parser.error("--from must be >= 1")
    if args.to_n is not None and args.to_n < args.from_n:
        parser.error("--to must be >= --from")
    return args


def resolve_output_path(html_dir: str | Path, output_arg: str | Path) -> Path:
    path = Path(output_arg)
    if path.suffix.lower() == ".jsonl":
        return path
    if path.exists() and path.is_file():
        return path
    return path / f"{Path(html_dir).name}.jsonl"


def select_chapters(
    chapters: list[dict[str, Any]],
    from_n: int,
    to_n: int | None,
) -> list[dict[str, Any]]:
    end = to_n if to_n is not None else len(chapters)
    return [chapter for chapter in chapters if from_n <= chapter["index"] <= end]


def build_entry(chapter: dict[str, Any], content: list[dict[str, Any]]) -> dict[str, Any]:
    entry = {
        "index": chapter["index"],
        "title": chapter["title"],
        "depth": chapter["depth"],
        "source_file": chapter["file"],
        "content": content,
    }
    if chapter.get("anchor"):
        entry["anchor"] = chapter["anchor"]
    return entry


def slice_html_to_entries(args: argparse.Namespace) -> tuple[list[dict[str, Any]], int]:
    html_dir = Path(args.html_dir)
    print(f"Parsing TOC: {args.toc}")
    chapters = parse_toc(args.toc)
    print(f"Found {len(chapters)} chapter entries")

    selected = select_chapters(chapters, args.from_n, args.to_n)
    entries: list[dict[str, Any]] = []
    skipped = 0

    for chapter in selected:
        html_file = html_dir / chapter["file"]
        if not html_file.exists():
            print(f'  [WARN] file not found, skipping: {chapter["file"]}')
            skipped += 1
            continue

        content = extract_chapter_content(str(html_file), chapter.get("anchor"))
        if args.skip_empty and not content:
            print(f'  [SKIP] empty chapter: {chapter["title"]}')
            skipped += 1
            continue

        entries.append(build_entry(chapter, content))
        print(f'  [{chapter["index"]:04d}] {chapter["title"]} ({len(content)} items)')

    return entries, skipped


def main(argv: list[str] | None = None) -> int:
    ensure_utf8_stdio()
    args = parse_args(argv)
    output_path = resolve_output_path(args.html_dir, args.output_jsonl)
    entries, skipped = slice_html_to_entries(args)
    line_count = write_jsonl(entries, output_path)
    print(f"\nDone: {line_count} written, {skipped} skipped -> {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
