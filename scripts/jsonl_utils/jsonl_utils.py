from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Iterable, Mapping


REQUIRED_ENTRY_FIELDS = ("index", "title", "depth", "content")
TEXT_LIKE_TYPES = {"text", "code"}
VALID_CONTENT_TYPES = TEXT_LIKE_TYPES | {"table"}


class JsonlValidationError(ValueError):
    """Raised when a JSONL entry cannot satisfy the shared schema."""


def _is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _stringify(value: Any) -> str:
    return "" if value is None else str(value)


def _normalize_lines(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, str):
        return value.splitlines() or ([value] if value else [])
    if isinstance(value, list):
        return [_stringify(item) for item in value]
    return [_stringify(value)]


def _normalize_table_data(value: Any) -> list[list[str]]:
    if value is None:
        return []
    if not isinstance(value, list):
        return [[_stringify(value)]]

    rows: list[list[str]] = []
    for row in value:
        if isinstance(row, (list, tuple)):
            rows.append([_stringify(cell) for cell in row])
        else:
            rows.append([_stringify(row)])
    return rows


def normalize_content(content: Any) -> list[Any]:
    """Normalize content blocks into the JSONL content-block shape."""
    if content is None:
        return []
    if not isinstance(content, list):
        return content

    normalized: list[Any] = []
    table_index = 0
    for block in content:
        if not isinstance(block, Mapping):
            normalized.append(block)
            continue

        item = dict(block)
        block_type = item.get("type")
        if block_type in TEXT_LIKE_TYPES:
            if "lines" in item:
                item["lines"] = _normalize_lines(item["lines"])
            elif "text" in item:
                item["lines"] = _normalize_lines(item["text"])
                item.pop("text", None)
        elif block_type == "table":
            item["table_index"] = table_index
            table_index += 1
            item["data"] = _normalize_table_data(item.get("data"))

        normalized.append(item)

    return normalized


def normalize_entry(entry: Mapping[str, Any]) -> dict[str, Any]:
    """Normalize one entry before validation and JSONL writing."""
    if not isinstance(entry, Mapping):
        raise TypeError("entry must be a mapping")

    normalized = dict(entry)
    if "file" in normalized:
        if not normalized.get("source_file"):
            normalized["source_file"] = normalized["file"]
        normalized.pop("file", None)

    normalized["content"] = normalize_content(normalized.get("content", []))
    return normalized


def validate_entry(entry: Mapping[str, Any]) -> list[str]:
    """Return schema errors for one normalized JSONL entry."""
    errors: list[str] = []

    if not isinstance(entry, Mapping):
        return ["entry must be a JSON object"]

    for field in REQUIRED_ENTRY_FIELDS:
        if field not in entry:
            errors.append(f"missing required field: {field}")

    if "index" in entry and not _is_int(entry["index"]):
        errors.append("index must be an integer")
    if "title" in entry and not isinstance(entry["title"], str):
        errors.append("title must be a string")
    if "depth" in entry and not _is_int(entry["depth"]):
        errors.append("depth must be an integer")
    if "source_file" in entry and not isinstance(entry["source_file"], str):
        errors.append("source_file must be a string when present")

    content = entry.get("content")
    if not isinstance(content, list):
        errors.append("content must be an array")
        return errors

    for idx, block in enumerate(content):
        prefix = f"content[{idx}]"
        if not isinstance(block, Mapping):
            errors.append(f"{prefix} must be an object")
            continue

        block_type = block.get("type")
        if block_type not in VALID_CONTENT_TYPES:
            errors.append(f"{prefix}.type must be one of text/table/code")
            continue

        if block_type in TEXT_LIKE_TYPES:
            lines = block.get("lines")
            if not isinstance(lines, list):
                errors.append(f"{prefix}.lines must be an array")
            elif not all(isinstance(line, str) for line in lines):
                errors.append(f"{prefix}.lines must contain only strings")
            continue

        table_index = block.get("table_index")
        if not _is_int(table_index):
            errors.append(f"{prefix}.table_index must be an integer")
        data = block.get("data")
        if not isinstance(data, list):
            errors.append(f"{prefix}.data must be an array")
        else:
            for row_idx, row in enumerate(data):
                if not isinstance(row, list):
                    errors.append(f"{prefix}.data[{row_idx}] must be an array")
                elif not all(isinstance(cell, str) for cell in row):
                    errors.append(f"{prefix}.data[{row_idx}] must contain only strings")

    return errors


def write_jsonl(entries: Iterable[Mapping[str, Any]], output_path: str | Path) -> int:
    """Validate entries, sort by index, and write one compact JSON object per line."""
    normalized_entries = [normalize_entry(entry) for entry in entries]

    seen: set[int] = set()
    for entry in normalized_entries:
        errors = validate_entry(entry)
        if errors:
            entry_id = entry.get("index", "<unknown>")
            raise JsonlValidationError(
                f"entry {entry_id} failed validation: " + "; ".join(errors)
            )

        index = entry["index"]
        if index in seen:
            raise JsonlValidationError(f"duplicate index: {index}")
        seen.add(index)

    sorted_entries = sorted(normalized_entries, key=lambda item: item["index"])
    path = Path(output_path)
    path.parent.mkdir(parents=True, exist_ok=True)

    with path.open("w", encoding="utf-8", newline="\n") as handle:
        for entry in sorted_entries:
            handle.write(json.dumps(entry, ensure_ascii=False, separators=(",", ":")))
            handle.write("\n")

    return len(sorted_entries)
