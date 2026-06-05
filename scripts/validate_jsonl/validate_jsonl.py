from __future__ import annotations

import argparse
import io
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


CURRENT_DIR = Path(__file__).resolve().parent
SCRIPTS_DIR = CURRENT_DIR.parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from jsonl_utils.jsonl_utils import validate_entry  # noqa: E402


BOM_UTF8 = b"\xef\xbb\xbf"


@dataclass
class ValidationIssue:
    path: Path
    message: str
    line_number: int | None = None

    def format(self) -> str:
        if self.line_number is None:
            return f"{self.path}: {self.message}"
        return f"{self.path}:{self.line_number}: {self.message}"


@dataclass
class FileReport:
    path: Path
    entries: int = 0
    issues: list[ValidationIssue] | None = None

    def __post_init__(self) -> None:
        if self.issues is None:
            self.issues = []

    @property
    def ok(self) -> bool:
        return not self.issues


def ensure_utf8_stdio() -> None:
    """Keep progress output readable on Windows terminals using GBK."""
    if sys.stdout.encoding and sys.stdout.encoding.lower() in ("gbk", "cp936", "gb2312"):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Validate JSONL knowledge-base slices."
    )
    parser.add_argument(
        "paths",
        nargs="+",
        help="JSONL files or directories. Directories are scanned recursively for *.jsonl.",
    )
    parser.add_argument(
        "--check-source-file",
        action="store_true",
        help="Check each entry source_file against the inferred row directory.",
    )
    parser.add_argument(
        "--source-root",
        type=Path,
        default=None,
        help=(
            "Optional source repository root used for source_file checks. "
            "Useful when JSONL files live in the lite repo but row files live elsewhere."
        ),
    )
    parser.add_argument(
        "--target-root",
        type=Path,
        default=None,
        help=(
            "Optional target repository root. When set with --source-root, JSONL paths "
            "are mapped to source paths by their relative path under this root."
        ),
    )
    parser.add_argument(
        "--max-errors",
        type=int,
        default=100,
        help="Maximum number of issues to print. Use 0 for unlimited. Default: 100.",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Only print failures and the final summary.",
    )
    return parser


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.max_errors < 0:
        parser.error("--max-errors must be >= 0")
    return args


def collect_jsonl_files(paths: Iterable[str]) -> tuple[list[Path], list[ValidationIssue]]:
    files: list[Path] = []
    issues: list[ValidationIssue] = []

    for raw_path in paths:
        path = Path(raw_path)
        if not path.exists():
            issues.append(ValidationIssue(path, "path does not exist"))
            continue

        if path.is_dir():
            files.extend(sorted(item for item in path.rglob("*.jsonl") if item.is_file()))
            continue

        if path.is_file():
            files.append(path)
            continue

        issues.append(ValidationIssue(path, "path is neither a file nor a directory"))

    return files, issues


def read_utf8_no_bom(path: Path) -> tuple[str | None, list[ValidationIssue]]:
    issues: list[ValidationIssue] = []
    try:
        data = path.read_bytes()
    except OSError as exc:
        return None, [ValidationIssue(path, f"cannot read file: {exc}")]

    if data.startswith(BOM_UTF8):
        issues.append(ValidationIssue(path, "file must be UTF-8 without BOM"))

    if data and not data.endswith(b"\n"):
        issues.append(ValidationIssue(path, "file must end with a newline"))

    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as exc:
        issues.append(
            ValidationIssue(
                path,
                f"file is not valid UTF-8: byte {exc.start}: {exc.reason}",
            )
        )
        return None, issues

    return text, issues


def strip_line_ending(line: str) -> str:
    if line.endswith("\n"):
        line = line[:-1]
    if line.endswith("\r"):
        line = line[:-1]
    return line


def is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def replace_last_path_part(path: Path, old: str, new: str) -> Path | None:
    parts = list(path.parts)
    for index in range(len(parts) - 1, -1, -1):
        if parts[index] == old:
            parts[index] = new
            return Path(*parts)
    return None


def relative_from_part(path: Path, part_name: str) -> Path | None:
    parts = list(path.parts)
    for index, part in enumerate(parts):
        if part == part_name:
            return Path(*parts[index:])
    return None


def relative_to_root(path: Path, root: Path | None) -> Path | None:
    if root is None:
        return None

    try:
        return path.resolve().relative_to(root.resolve())
    except ValueError:
        return None


def infer_row_container(
    jsonl_path: Path,
    source_root: Path | None = None,
    target_root: Path | None = None,
) -> Path | None:
    jsonl_abs = jsonl_path.resolve()

    if source_root is not None:
        relative_path = relative_to_root(jsonl_abs, target_root)
        if relative_path is None:
            relative_path = relative_from_part(jsonl_abs, "knowledge")

        if relative_path is not None:
            row_relative_parent = replace_last_path_part(relative_path.parent, "jsonl", "row")
            if row_relative_parent is not None:
                return source_root.resolve() / row_relative_parent

    return replace_last_path_part(jsonl_abs.parent, "jsonl", "row")


def source_file_to_path(source_file: Any) -> Path | None:
    if not isinstance(source_file, str) or not source_file.strip():
        return None

    normalized = source_file.strip().replace("\\", "/")
    candidate = Path(normalized)
    if candidate.is_absolute():
        return candidate

    parts = [part for part in normalized.split("/") if part and part != "."]
    if not parts or any(part == ".." for part in parts):
        return None
    return Path(*parts)


def build_source_candidates(row_container: Path, jsonl_path: Path, source_file: Any) -> list[Path]:
    source_path = source_file_to_path(source_file)
    if source_path is None:
        return []
    if source_path.is_absolute():
        return [source_path]

    doc_stem = jsonl_path.stem
    candidates = [
        row_container / doc_stem / source_path,
        row_container / source_path,
    ]

    unique: list[Path] = []
    seen: set[str] = set()
    for candidate in candidates:
        key = str(candidate)
        if key not in seen:
            unique.append(candidate)
            seen.add(key)
    return unique


def validate_source_file(
    report: FileReport,
    entry: dict[str, Any],
    line_number: int,
    row_container: Path | None,
    source_cache: dict[str, bool],
) -> None:
    source_file = entry.get("source_file")
    if not isinstance(source_file, str) or not source_file.strip():
        report.issues.append(
            ValidationIssue(report.path, "source_file is required for --check-source-file", line_number)
        )
        return

    if source_file in source_cache:
        return

    if row_container is None:
        report.issues.append(
            ValidationIssue(report.path, "cannot infer row directory from JSONL path", line_number)
        )
        source_cache[source_file] = False
        return

    candidates = build_source_candidates(row_container, report.path, source_file)
    if not candidates:
        report.issues.append(
            ValidationIssue(report.path, f"invalid source_file path: {source_file!r}", line_number)
        )
        source_cache[source_file] = False
        return

    if any(candidate.exists() for candidate in candidates):
        source_cache[source_file] = True
        return

    tried = "; ".join(str(candidate) for candidate in candidates)
    report.issues.append(
        ValidationIssue(
            report.path,
            f"source_file not found: {source_file!r}; tried: {tried}",
            line_number,
        )
    )
    source_cache[source_file] = False


def validate_json_line(report: FileReport, line: str, line_number: int) -> dict[str, Any] | None:
    line_body = strip_line_ending(line)
    if not line_body.strip():
        report.issues.append(ValidationIssue(report.path, "blank lines are not allowed", line_number))
        return None

    try:
        entry = json.loads(line_body)
    except json.JSONDecodeError as exc:
        report.issues.append(
            ValidationIssue(report.path, f"invalid JSON: column {exc.colno}: {exc.msg}", line_number)
        )
        return None

    entry_errors = validate_entry(entry)
    for error in entry_errors:
        report.issues.append(ValidationIssue(report.path, error, line_number))

    if not isinstance(entry, dict):
        return None
    return entry


def validate_jsonl_file(
    path: Path,
    check_source_file: bool = False,
    source_root: Path | None = None,
    target_root: Path | None = None,
) -> FileReport:
    report = FileReport(path)
    text, file_issues = read_utf8_no_bom(path)
    report.issues.extend(file_issues)
    if text is None:
        return report

    seen_indexes: set[int] = set()
    previous_index: int | None = None
    row_container = infer_row_container(path, source_root, target_root) if check_source_file else None
    source_cache: dict[str, bool] = {}

    physical_lines = text.split("\n")
    for line_number, line in enumerate(physical_lines, start=1):
        if line_number == len(physical_lines) and line == "":
            continue
        entry = validate_json_line(report, line, line_number)
        if entry is None:
            continue

        report.entries += 1
        index = entry.get("index")
        if is_int(index):
            if index in seen_indexes:
                report.issues.append(
                    ValidationIssue(report.path, f"duplicate index: {index}", line_number)
                )
            if previous_index is not None and index <= previous_index:
                report.issues.append(
                    ValidationIssue(
                        report.path,
                        f"index order violation: previous={previous_index}, current={index}",
                        line_number,
                    )
                )
            seen_indexes.add(index)
            previous_index = index

        if check_source_file:
            validate_source_file(report, entry, line_number, row_container, source_cache)

    return report


def print_reports(reports: list[FileReport], quiet: bool, max_errors: int) -> None:
    printed_errors = 0
    unlimited = max_errors == 0

    for report in reports:
        if report.ok:
            if not quiet:
                print(f"OK   {report.path} ({report.entries} entries)")
            continue

        print(f"FAIL {report.path} ({len(report.issues)} issue(s), {report.entries} parsed entries)")
        for issue in report.issues:
            if not unlimited and printed_errors >= max_errors:
                continue
            print(f"  {issue.format()}")
            printed_errors += 1

    total_issues = sum(len(report.issues) for report in reports)
    if not unlimited and total_issues > printed_errors:
        print(f"... {total_issues - printed_errors} additional issue(s) hidden by --max-errors")


def main(argv: list[str] | None = None) -> int:
    ensure_utf8_stdio()
    args = parse_args(argv)

    files, path_issues = collect_jsonl_files(args.paths)
    reports = [FileReport(issue.path, issues=[issue]) for issue in path_issues]

    if not files and not reports:
        reports.append(FileReport(Path("."), issues=[ValidationIssue(Path("."), "no JSONL files found")]))

    for path in files:
        reports.append(
            validate_jsonl_file(
                path,
                check_source_file=args.check_source_file,
                source_root=args.source_root,
                target_root=args.target_root,
            )
        )

    print_reports(reports, quiet=args.quiet, max_errors=args.max_errors)

    total_files = len(reports)
    total_entries = sum(report.entries for report in reports)
    total_issues = sum(len(report.issues) for report in reports)
    status = "PASS" if total_issues == 0 else "FAIL"
    print(f"{status}: {total_files} file(s), {total_entries} parsed entries, {total_issues} issue(s)")
    return 0 if total_issues == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
