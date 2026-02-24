#!/usr/bin/env python3
"""
Merge feedly.opml and follow.opml: combine, deduplicate by normalized URL,
validate feeds (retry + discover from htmlUrl), drop still-invalid, write flat rss.opml.
"""
from __future__ import annotations

import argparse
import re
import sys
import time
import xml.etree.ElementTree as ET
from html import unescape
from pathlib import Path
from urllib.parse import urljoin, urlparse, urlunparse

try:
    import requests
except ImportError:
    print("pip install requests", file=sys.stderr)
    sys.exit(1)
try:
    import feedparser
except ImportError:
    print("pip install feedparser", file=sys.stderr)
    sys.exit(1)

# Constants
REQUEST_TIMEOUT = 12
RETRY_TIMEOUT = 6
REQUEST_DELAY_SEC = 0.5
USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; rv:109.0) Gecko/20100101 Firefox/115.0"
)
FEED_LINK_RE = re.compile(
    r'<link\s+[^>]*rel\s*=\s*["\']?(?:alternate|alternate\s+[^"\']*)["\']?[^>]*'
    r'type\s*=\s*["\']?(?:application/(?:rss|atom)\+xml)["\']?[^>]*href\s*=\s*["\']([^"\']+)["\']',
    re.I,
)
FEED_LINK_RE_2 = re.compile(
    r'<link\s+[^>]*href\s*=\s*["\']([^"\']+)["\'][^>]*'
    r'type\s*=\s*["\']?(?:application/(?:rss|atom)\+xml)["\']?',
    re.I,
)


def normalize_feed_url(url: str) -> str:
    """Normalize xmlUrl for dedup: lowercase scheme/host, strip trailing slash, no fragment."""
    parsed = urlparse(url)
    if not parsed.scheme or not parsed.netloc:
        return url
    path = parsed.path.rstrip("/") or "/"
    normalized = urlunparse(
        (
            parsed.scheme.lower(),
            parsed.netloc.lower(),
            path,
            parsed.params,
            parsed.query,
            "",  # no fragment
        )
    )
    return normalized


def canonical_dedup_key(url: str) -> str:
    """Canonical key for dedup: same host+path+query => same key (use https for key so http/https merge)."""
    parsed = urlparse(url)
    if not parsed.scheme or not parsed.netloc:
        return url
    path = parsed.path.rstrip("/") or "/"
    return urlunparse(
        ("https", parsed.netloc.lower(), path, parsed.params, parsed.query, "")
    )


def collect_outlines(element: ET.Element, acc: list[dict]) -> None:
    """Recursively collect outline nodes with type=rss and xmlUrl."""
    for child in element:
        if child.tag.endswith("outline"):
            xml_url = child.get("xmlUrl") or child.get("xmlurl")
            outline_type = (child.get("type") or child.get("Type") or "").lower()
            if outline_type == "rss" and xml_url:
                text = child.get("text") or child.get("title") or ""
                title = child.get("title") or child.get("text") or text
                html_url = child.get("htmlUrl") or child.get("htmlurl") or ""
                if isinstance(text, str):
                    text = unescape(text)
                if isinstance(title, str):
                    title = unescape(title)
                acc.append(
                    {
                        "xmlUrl": xml_url.strip(),
                        "htmlUrl": (html_url or "").strip(),
                        "text": text,
                        "title": title,
                    }
                )
            collect_outlines(child, acc)


def parse_opml(path: Path) -> list[dict]:
    """Parse OPML file and return list of feed entries."""
    tree = ET.parse(path)
    root = tree.getroot()
    body = root.find(".//{*}body") or root.find("body")
    if body is None:
        return []
    entries = []
    collect_outlines(body, entries)
    return entries


def deduplicate(entries: list[dict]) -> list[dict]:
    """Deduplicate by canonical key (host+path+query); prefer https and richer htmlUrl."""
    by_key: dict[str, dict] = {}
    for ent in entries:
        key = canonical_dedup_key(ent["xmlUrl"])
        existing = by_key.get(key)
        if existing is None:
            by_key[key] = ent
            continue
        # Prefer https
        if ent["xmlUrl"].lower().startswith("https:") and not existing["xmlUrl"].lower().startswith("https:"):
            by_key[key] = ent
            continue
        if existing["xmlUrl"].lower().startswith("https:") and not ent["xmlUrl"].lower().startswith("https:"):
            continue
        # Prefer longer htmlUrl
        if len((ent.get("htmlUrl") or "")) > len((existing.get("htmlUrl") or "")):
            by_key[key] = ent
    return list(by_key.values())


def is_valid_feed(content: bytes, url: str) -> bool:
    """Check if response body is a valid RSS/Atom feed."""
    try:
        text = content.decode("utf-8", errors="replace")
        parsed = feedparser.parse(text)
    except Exception:
        return False
    if getattr(parsed, "bozo", True) and not (parsed.get("entries") or parsed.get("feed")):
        return False
    return bool(parsed.get("entries") is not None or parsed.get("feed") is not None)


def fetch_feed(session: requests.Session, url: str, timeout: int = REQUEST_TIMEOUT) -> tuple[bool, bytes | None]:
    """GET url; return (success, body or None)."""
    try:
        resp = session.get(url, timeout=timeout, allow_redirects=True)
        if not resp.ok:
            return False, None
        return True, resp.content
    except Exception:
        return False, None


def discover_feed_url_from_html(session: requests.Session, html_url: str) -> str | None:
    """GET htmlUrl and find first alternate RSS/Atom link."""
    if not html_url or not html_url.startswith(("http://", "https://")):
        return None
    ok, content = fetch_feed(session, html_url, timeout=RETRY_TIMEOUT)
    if not ok or not content:
        return None
    text = content.decode("utf-8", errors="ignore")
    for pattern in (FEED_LINK_RE, FEED_LINK_RE_2):
        m = pattern.search(text)
        if m:
            href = m.group(1).strip()
            if href.startswith("http://") or href.startswith("https://"):
                return href
            return urljoin(html_url, href)
    return None


def validate_and_update(
    session: requests.Session,
    entry: dict,
    removed: list[str],
    updated: list[tuple[str, str]],
) -> dict | None:
    """
    Validate entry's xmlUrl; if invalid, retry then try discover from htmlUrl.
    Return updated entry (with possibly new xmlUrl) or None to drop.
    """
    url = entry["xmlUrl"]
    time.sleep(REQUEST_DELAY_SEC)

    ok, content = fetch_feed(session, url)
    if ok and content and is_valid_feed(content, url):
        return entry

    # Retry once
    time.sleep(REQUEST_DELAY_SEC)
    ok, content = fetch_feed(session, url, timeout=RETRY_TIMEOUT)
    if ok and content and is_valid_feed(content, url):
        return entry

    # Try discover from htmlUrl
    html_url = entry.get("htmlUrl") or ""
    if html_url:
        discovered = discover_feed_url_from_html(session, html_url)
        if discovered and discovered != url:
            time.sleep(REQUEST_DELAY_SEC)
            ok, content = fetch_feed(session, discovered, timeout=RETRY_TIMEOUT)
            if ok and content and is_valid_feed(content, discovered):
                updated.append((url, discovered))
                return {**entry, "xmlUrl": discovered}

    removed.append(url)
    return None


def write_opml(entries: list[dict], out_path: Path) -> None:
    """Write flat OPML to out_path."""
    def escape(s: str) -> str:
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")

    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<opml version="2.0">',
        "  <head>",
        "    <title>Merged RSS</title>",
        "  </head>",
        "  <body>",
    ]
    for e in entries:
        text = escape(e.get("text") or "")
        title = escape(e.get("title") or text)
        xml_url = escape(e.get("xmlUrl") or "")
        html_url = escape(e.get("htmlUrl") or "")
        lines.append(
            f'    <outline type="rss" text="{text}" title="{title}" xmlUrl="{xml_url}" htmlUrl="{html_url}"/>'
        )
    lines.append("  </body>")
    lines.append("</opml>")
    out_path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Merge OPML files and write rss.opml")
    parser.add_argument(
        "--no-validate",
        action="store_true",
        help="Skip feed validation (merge and dedup only)",
    )
    parser.add_argument(
        "--opml-dir",
        type=Path,
        default=None,
        help="Directory containing feedly.opml and follow.opml (default: repo opml/)",
    )
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    opml_dir = args.opml_dir or repo_root / "opml"
    feedly_path = opml_dir / "feedly.opml"
    follow_path = opml_dir / "follow.opml"
    out_path = opml_dir / "rss.opml"

    if not feedly_path.is_file():
        print(f"Missing: {feedly_path}", file=sys.stderr)
        return 1
    if not follow_path.is_file():
        print(f"Missing: {follow_path}", file=sys.stderr)
        return 1

    entries_feedly = parse_opml(feedly_path)
    entries_follow = parse_opml(follow_path)
    merged = entries_feedly + entries_follow
    entries = deduplicate(merged)
    print(f"Merged: {len(merged)} -> dedup: {len(entries)}", file=sys.stderr)

    if not args.no_validate:
        removed: list[str] = []
        updated: list[tuple[str, str]] = []
        session = requests.Session()
        session.headers["User-Agent"] = USER_AGENT
        valid_entries = []
        for i, ent in enumerate(entries):
            result = validate_and_update(session, ent, removed, updated)
            if result is not None:
                valid_entries.append(result)
            if (i + 1) % 20 == 0:
                print(f"  Checked {i + 1}/{len(entries)} ...", file=sys.stderr)
        entries = valid_entries
        for old_u, new_u in updated:
            print(f"Updated: {old_u} -> {new_u}", file=sys.stderr)
        for u in removed:
            print(f"Removed (invalid): {u}", file=sys.stderr)
        print(f"Valid: {len(entries)}", file=sys.stderr)

    write_opml(entries, out_path)
    print(f"Written: {out_path}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
