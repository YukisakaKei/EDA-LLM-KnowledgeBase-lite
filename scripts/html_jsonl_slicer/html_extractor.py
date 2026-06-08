"""
Extraction helpers for Confluence HTML manuals.

"""

import re

from bs4 import BeautifulSoup, NavigableString, Tag

# Zero-width and invisible characters
_INVISIBLE = re.compile(r'[\u200b\u200c\u200d\ufeff\u00ad\u2060\u180e\u00a0]')

MACRO_TYPE_MAP = {
    'confluence-information-macro-note': '[NOTE]',
    'confluence-information-macro-warning': '[WARNING]',
    'confluence-information-macro-tip': '[TIP]',
    'confluence-information-macro-information': '[INFO]',
}


# ---------------------------------------------------------------------------
# Text cleaning
# ---------------------------------------------------------------------------

def clean_text(text: str) -> str:
    text = _INVISIBLE.sub(' ', text)
    text = re.sub(r' +', ' ', text)
    return text.strip()


def cell_text(td: Tag) -> str:
    """Extract cell text; replace <br> with space."""
    for br in td.find_all('br'):
        br.replace_with(' ')
    return clean_text(td.get_text(' ', strip=False))


# ---------------------------------------------------------------------------
# TOC parsing
# ---------------------------------------------------------------------------

def parse_toc(toc_path: str) -> list:
    """
    Parse TOC HTML and return a list of chapter entries.
    Each entry: {index, title, file, anchor, depth, parent}

    Depth mapping:
      h2  -> 0  (top-level chapter)
      p   -> 1  (section)
      dd  -> 1+ (subsection, increases with dl nesting)
    """
    with open(toc_path, encoding='utf-8') as f:
        soup = BeautifulSoup(f, 'lxml')

    # Find main content container
    container = soup.find('div', style=lambda s: s and 'margin-left' in s)
    if not container:
        container = soup.body

    chapters = []
    index = 0
    parent_stack = []  # list of (depth, title)
    seen_keys = set()

    for elem in container.find_all(['h2', 'p', 'dd', 'dl']):
        # Collect direct <a href> children; fall back to first descendant
        a_tags = [a for a in elem.find_all('a', href=True, recursive=False) if a.get('href')]
        if not a_tags:
            a = elem.find('a', href=True)
            if a:
                a_tags = [a]

        for a in a_tags:
            href = a['href']
            title = clean_text(a.get_text())
            if not title:
                continue
            if '.html' not in href:
                continue
            # Skip Confluence chapter-number decorators (bare digits like "1", "2", ...)
            if elem.name == 'h2' and re.fullmatch(r'\d+', title):
                continue

            # Split filename and anchor
            if '#' in href:
                file_part, anchor = href.split('#', 1)
            else:
                file_part, anchor = href, None

            key = (file_part, anchor or '')
            if key in seen_keys:
                continue
            seen_keys.add(key)

            # Determine depth from tag name and dl nesting
            tag = elem.name
            if tag == 'h2':
                depth = 0
            elif tag == 'p':
                depth = 1
            else:
                # dd: count ancestor <dl> elements
                dl_count = sum(1 for p in elem.parents if p.name == 'dl')
                depth = max(1, dl_count)

            # Maintain parent stack
            while parent_stack and parent_stack[-1][0] >= depth:
                parent_stack.pop()
            parent = parent_stack[-1][1] if parent_stack else None

            index += 1
            chapters.append({
                'index': index,
                'title': title,
                'file': file_part,
                'anchor': anchor,
                'depth': depth,
                'parent': parent,
            })

            # Push to parent stack for h2 and p (section-level)
            if tag in ('h2', 'p'):
                parent_stack.append((depth, title))

    return chapters


# ---------------------------------------------------------------------------
# Content extraction
# ---------------------------------------------------------------------------

def _is_boilerplate(tag: Tag) -> bool:
    if tag.name in ('header', 'footer', 'script', 'style'):
        return True
    if tag.get('id') == 'cad_image_modal':
        return True
    if 'toc-macro' in tag.get('class', []):
        return True
    return False


def _extract_list(ul: Tag, ordered: bool = False, indent: int = 0) -> str:
    lines = []
    for i, li in enumerate(ul.find_all('li', recursive=False)):
        prefix = ('  ' * indent) + (f'{i+1}. ' if ordered else '- ')
        # Handle nested list
        nested = li.find(['ul', 'ol'], recursive=False)
        if nested:
            nested.extract()
        text = clean_text(li.get_text(' '))
        if text:
            lines.append(prefix + text)
        if nested:
            lines.append(_extract_list(nested, nested.name == 'ol', indent + 1))
    return '\n'.join(lines)


def _extract_table(table: Tag, table_index: int):
    rows = []
    for tr in table.find_all('tr'):
        cells = tr.find_all(['th', 'td'])
        if not cells:
            continue
        rows.append([cell_text(c) for c in cells])
    if not rows:
        return None
    return {'type': 'table', 'table_index': table_index, 'data': rows}


def _macro_prefix(div: Tag) -> str:
    for cls, prefix in MACRO_TYPE_MAP.items():
        if cls in div.get('class', []):
            return prefix
    return '[NOTE]'


def _iter_content(container: Tag) -> list:
    """Walk container DOM in order and produce content items."""
    items = []
    table_index = 0

    def process(node: Tag):
        nonlocal table_index
        if not isinstance(node, Tag):
            return
        if _is_boilerplate(node):
            return

        tag = node.name
        classes = node.get('class', [])

        # Headings
        if tag in ('h1', 'h2', 'h3', 'h4', 'h5', 'h6'):
            text = clean_text(node.get_text(' '))
            if text:
                items.append({'type': 'text', 'lines': [text]})
            return

        # Paragraph
        if tag == 'p':
            text = clean_text(node.get_text(' '))
            if text:
                items.append({'type': 'text', 'lines': [text]})
            return

        # Lists
        if tag in ('ul', 'ol'):
            text = _extract_list(node, ordered=(tag == 'ol'))
            if text:
                items.append({'type': 'text', 'lines': [text]})
            return

        # Table (direct)
        if tag == 'table':
            item = _extract_table(node, table_index)
            if item:
                items.append(item)
                table_index += 1
            return

        # table-wrap div
        if tag == 'div' and 'table-wrap' in classes:
            tbl = node.find('table')
            if tbl:
                item = _extract_table(tbl, table_index)
                if item:
                    items.append(item)
                    table_index += 1
            return

        # Confluence info macros (NOTE / WARNING / TIP / INFO)
        if tag == 'div' and any(c in classes for c in MACRO_TYPE_MAP):
            prefix = _macro_prefix(node)
            body = node.find(class_='confluence-information-macro-body')
            text = clean_text((body or node).get_text(' '))
            if text:
                items.append({'type': 'text', 'lines': [f'{prefix} {text}']})
            return

        # Generic div / section: recurse into children
        for child in node.children:
            if isinstance(child, Tag):
                process(child)

    for child in container.children:
        if isinstance(child, Tag):
            process(child)

    return items


def extract_chapter_content(html_path: str, anchor: str = None) -> list:
    with open(html_path, encoding='utf-8') as f:
        soup = BeautifulSoup(f, 'lxml')

    main = soup.find(id='main-content')
    if not main:
        return []

    if not anchor:
        return _iter_content(main)

    # Locate anchor element.
    # Confluence emits anchors as <span class="confluence-anchor-link" id="...">
    # inside a <p> before the actual <h2 id="...">.  We prefer the heading.
    start_elem = soup.find(id=anchor) or soup.find(attrs={'name': anchor})
    if not start_elem:
        return _iter_content(main)

    # If the found element is not a heading, look for a sibling heading with same id
    heading_tags = {'h1', 'h2', 'h3', 'h4', 'h5', 'h6'}
    if start_elem.name not in heading_tags:
        heading = main.find(heading_tags, id=anchor)
        if heading:
            start_elem = heading

    start_level = int(start_elem.name[1]) if start_elem.name in heading_tags else 2

    # Find the direct child of main that contains start_elem (may be start_elem itself)
    def top_level_ancestor(elem):
        for parent in elem.parents:
            if parent == main:
                return elem
            elem = parent
        return None

    start_top = top_level_ancestor(start_elem)
    if not start_top:
        return _iter_content(main)

    # When start_elem is a direct child of main, use it as the boundary.
    # When start_elem is nested inside a container (e.g. a <p> or <div> wrapping
    # multiple headings), top_level_ancestor returns that container, which would
    # include content from sibling headings.  In that case we work at the level of
    # start_elem's own parent container and then continue collecting subsequent
    # top-level siblings of that container.
    if start_top is start_elem:
        # Standard path: heading is a direct child of main
        fragment_nodes = []
        collecting = False
        for child in main.children:
            if not isinstance(child, Tag):
                continue
            if child == start_top:
                collecting = True
            if collecting:
                if child != start_top and child.name in heading_tags:
                    if int(child.name[1]) <= start_level:
                        break
                fragment_nodes.append(child)
    else:
        # Nested path: start_elem lives inside a container that is a child of main.
        # Step 1 — collect siblings within the same container, starting from start_elem.
        container = start_elem.parent
        fragment_nodes = []
        collecting = False
        for sibling in container.children:
            if not isinstance(sibling, Tag):
                continue
            if sibling is start_elem:
                collecting = True
            if collecting:
                if sibling is not start_elem and sibling.name in heading_tags:
                    if int(sibling.name[1]) <= start_level:
                        # A same/higher heading inside the container ends this section
                        collecting = False
                        break
                fragment_nodes.append(sibling)

        # Step 2 — continue with subsequent top-level siblings of start_top in main,
        # until a top-level heading of same or higher level is encountered.
        if collecting:
            past_start = False
            for child in main.children:
                if not isinstance(child, Tag):
                    continue
                if child is start_top:
                    past_start = True
                    continue
                if not past_start:
                    continue
                if child.name in heading_tags and int(child.name[1]) <= start_level:
                    break
                fragment_nodes.append(child)

    if not fragment_nodes:
        return _iter_content(main)

    # Build a temporary container and extract
    fragment_html = ''.join(str(n) for n in fragment_nodes)
    tmp_soup = BeautifulSoup(f'<div id="tmp">{fragment_html}</div>', 'lxml')
    tmp = tmp_soup.find(id='tmp')

    return _iter_content(tmp)


