#!/usr/bin/env python3
"""
HTMLView Slicer Script

Converts PrimeTime htmlView_20 format HTML manual to JSON files.
Each HTML file corresponds to one entry_NNNN.json file.

Usage:
    python htmlview_slicer.py <html_dir> <output_dir>

Example:
    python htmlview_slicer.py \
        knowledge/PrimeTime/row/htmlView_20/command \
        knowledge/PrimeTime/json/htmlView_20/command
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import List, Dict, Any, Tuple

try:
    from bs4 import BeautifulSoup, NavigableString, Tag
except ImportError:
    print("Error: beautifulsoup4 is required")
    print("Run: pip install beautifulsoup4 lxml")
    sys.exit(1)


def clean_text(text: str) -> str:
    """Clean text: remove zero-width chars, HTML entities, extra whitespace"""
    if not text:
        return ""

    # Remove zero-width characters
    zero_width_chars = [
        '​',  # zero-width space
        '‌',  # zero-width non-joiner
        '‍',  # zero-width joiner
        '﻿',  # zero-width no-break space
        '­',  # soft hyphen
        '⁠',  # word joiner
        '᠎',  # mongolian vowel separator
    ]
    for char in zero_width_chars:
        text = text.replace(char, '')

    # Replace &nbsp; with regular space
    text = text.replace('\xa0', ' ')
    text = text.replace(' ', ' ')

    # Merge consecutive whitespace into single space
    text = re.sub(r'[ \t]+', ' ', text)

    # Strip leading/trailing whitespace
    text = text.strip()

    return text


def extract_text_from_element(element: Tag) -> str:
    """Extract plain text from element, preserving inline code"""
    if isinstance(element, NavigableString):
        return clean_text(str(element))

    # Recursively extract all text
    texts = []
    for child in element.children:
        if isinstance(child, NavigableString):
            texts.append(clean_text(str(child)))
        elif child.name in ['strong', 'em', 'code', 'span', 'a']:
            texts.append(extract_text_from_element(child))
        elif child.name == 'br':
            texts.append(' ')
        else:
            texts.append(extract_text_from_element(child))

    result = ' '.join(texts).strip()

    # Replace newlines with spaces (for multi-line paragraphs)
    result = result.replace('\n', ' ')

    # Merge consecutive spaces
    result = re.sub(r' +', ' ', result)

    return result


def extract_code_block(pre_tag: Tag) -> List[str]:
    """Extract code block, preserving newlines and indentation"""
    # Get raw text without adding separators at tags
    # This preserves the original line structure
    text = pre_tag.get_text()

    # Split by lines
    lines = text.split('\n')

    # Clean each line (remove zero-width chars, but keep indentation)
    cleaned_lines = []
    for line in lines:
        # Only remove zero-width chars, keep spaces and tabs
        for char in ['​', '‌', '‍', '﻿', '­', '⁠', '᠎']:
            line = line.replace(char, '')
        # Replace &nbsp;
        line = line.replace('\xa0', ' ')
        # Strip trailing whitespace
        line = line.rstrip()
        cleaned_lines.append(line)

    # Remove leading and trailing empty lines
    while cleaned_lines and not cleaned_lines[0]:
        cleaned_lines.pop(0)
    while cleaned_lines and not cleaned_lines[-1]:
        cleaned_lines.pop()

    return cleaned_lines


def extract_table(table_tag: Tag) -> Dict[str, Any]:
    """Extract table data"""
    headers = []
    rows = []

    # Find all rows
    all_rows = table_tag.find_all('tr')

    if not all_rows:
        return {"type": "table", "headers": [], "rows": []}

    # First row as headers
    first_row = all_rows[0]
    header_cells = first_row.find_all(['th', 'td'])
    for cell in header_cells:
        text = extract_text_from_element(cell)
        headers.append(text)

    # Subsequent rows as data
    for row in all_rows[1:]:
        cells = row.find_all(['th', 'td'])
        row_data = []
        for cell in cells:
            text = extract_text_from_element(cell)
            row_data.append(text)
        if row_data:  # Skip empty rows
            rows.append(row_data)

    return {
        "type": "table",
        "headers": headers,
        "rows": rows
    }


def extract_list_items(list_tag: Tag, prefix: str = "- ") -> List[str]:
    """Extract list items"""
    items = []
    list_items = list_tag.find_all('li', recursive=False)

    for i, li in enumerate(list_items, 1):
        # Choose prefix based on list type
        if list_tag.name == 'ol':
            item_prefix = f"{i}. "
        else:
            item_prefix = prefix

        text = extract_text_from_element(li)
        if text:
            items.append(f"{item_prefix}{text}")

    return items


def parse_html_content(soup: BeautifulSoup) -> List[Dict[str, Any]]:
    """Parse HTML content, extract text, code, table"""
    content = []

    # Find body tag
    body = soup.find('body')
    if not body:
        return content

    # Skip TOC links at the beginning (<p><a href="#NAME">...</a></p>)
    skip_toc = True

    # Traverse direct children of body
    for element in body.children:
        if isinstance(element, NavigableString):
            continue

        if not isinstance(element, Tag):
            continue

        # Skip hr separator
        if element.name == 'hr':
            skip_toc = False
            continue

        # Skip TOC links at the beginning
        if skip_toc and element.name == 'p':
            # Check if it only contains links
            links = element.find_all('a')
            if links and all(link.get('href', '').startswith('#') for link in links):
                continue
            else:
                skip_toc = False

        # Process headings h1, h2, h3
        if element.name in ['h1', 'h2', 'h3']:
            text = extract_text_from_element(element)
            if text:
                content.append({
                    "type": "text",
                    "lines": [text]
                })

        # Process paragraphs
        elif element.name == 'p':
            text = extract_text_from_element(element)
            if text:
                content.append({
                    "type": "text",
                    "lines": [text]
                })

        # Process code blocks
        elif element.name == 'pre':
            lines = extract_code_block(element)
            if lines:
                content.append({
                    "type": "code",
                    "lines": lines
                })

        # Process lists
        elif element.name in ['ul', 'ol']:
            items = extract_list_items(element)
            if items:
                content.append({
                    "type": "text",
                    "lines": items
                })

        # Process tables
        elif element.name == 'table':
            table_data = extract_table(element)
            if table_data['headers'] or table_data['rows']:
                content.append(table_data)

        # Process div containers (recursively process internal elements)
        elif element.name == 'div':
            # Recursively process elements inside div
            for child in element.children:
                if isinstance(child, NavigableString):
                    continue
                if not isinstance(child, Tag):
                    continue

                if child.name in ['h2', 'h3', 'h4']:
                    text = extract_text_from_element(child)
                    if text:
                        content.append({
                            "type": "text",
                            "lines": [text]
                        })

                elif child.name == 'p':
                    text = extract_text_from_element(child)
                    if text:
                        content.append({
                            "type": "text",
                            "lines": [text]
                        })

                elif child.name == 'pre':
                    lines = extract_code_block(child)
                    if lines:
                        content.append({
                            "type": "code",
                            "lines": lines
                        })

                elif child.name in ['ul', 'ol']:
                    items = extract_list_items(child)
                    if items:
                        content.append({
                            "type": "text",
                            "lines": items
                        })

                elif child.name == 'table':
                    table_data = extract_table(child)
                    if table_data['headers'] or table_data['rows']:
                        content.append(table_data)

    return content


def parse_html_file(html_path: Path) -> Dict[str, Any]:
    """Parse a single HTML file"""
    # Try multiple encodings
    encodings = ['utf-8', 'latin-1', 'cp1252', 'iso-8859-1']
    html_content = None

    for encoding in encodings:
        try:
            with open(html_path, 'r', encoding=encoding) as f:
                html_content = f.read()
            break
        except UnicodeDecodeError:
            continue
        except Exception as e:
            print(f"Error: Cannot read file {html_path}: {e}")
            return None

    if html_content is None:
        print(f"Error: Cannot decode file {html_path} with any known encoding")
        return None

    try:
        soup = BeautifulSoup(html_content, 'lxml')
    except Exception as e:
        print(f"Error: Cannot parse HTML {html_path}: {e}")
        return None

    # Extract title
    h1 = soup.find('h1')
    if h1:
        title = extract_text_from_element(h1)
    else:
        # Use filename as title
        title = html_path.stem

    # Extract content
    content = parse_html_content(soup)

    return {
        'title': title,
        'content': content
    }


def collect_html_files(html_dir: Path) -> List[Tuple[str, Path]]:
    """Collect all HTML files, return list of (relative_path, absolute_path)"""
    html_files = []

    for root, dirs, files in os.walk(html_dir):
        for file in files:
            if file.endswith('.html'):
                full_path = Path(root) / file
                rel_path = full_path.relative_to(html_dir)
                html_files.append((str(rel_path), full_path))

    # Sort by relative path
    html_files.sort(key=lambda x: x[0])

    return html_files


def main():
    parser = argparse.ArgumentParser(
        description='Convert htmlView format HTML manual to JSON files'
    )
    parser.add_argument('html_dir', help='Directory containing HTML files')
    parser.add_argument('output_dir', help='Output directory for JSON files')

    args = parser.parse_args()

    html_dir = Path(args.html_dir)
    output_dir = Path(args.output_dir)

    if not html_dir.exists():
        print(f"Error: Input directory does not exist: {html_dir}")
        sys.exit(1)

    # Create output directory
    output_dir.mkdir(parents=True, exist_ok=True)

    # Collect all HTML files
    print(f"Scanning {html_dir} ...")
    html_files = collect_html_files(html_dir)
    print(f"Found {len(html_files)} HTML files")

    if not html_files:
        print("Warning: No HTML files found")
        return

    # Process each file
    success_count = 0
    error_count = 0

    for index, (rel_path, full_path) in enumerate(html_files, 1):
        print(f"[{index}/{len(html_files)}] Processing {rel_path} ...")

        # Parse HTML
        result = parse_html_file(full_path)

        if result is None:
            error_count += 1
            continue

        # Build output JSON
        output_json = {
            "index": index,
            "title": result['title'],
            "depth": 0,
            "file": rel_path.replace('\\', '/'),  # Use / separator
            "content": result['content']
        }

        # Output filename
        output_file = output_dir / f"entry_{index:04d}.json"

        # Write JSON
        try:
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(output_json, f, ensure_ascii=False, indent=2)
            success_count += 1
        except Exception as e:
            print(f"Error: Cannot write file {output_file}: {e}")
            error_count += 1

    print(f"\nComplete!")
    print(f"Success: {success_count} files")
    print(f"Failed: {error_count} files")
    print(f"Output directory: {output_dir}")


if __name__ == '__main__':
    main()
