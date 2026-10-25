#!/usr/bin/env python3
"""Check the static files that are eligible for the App Store Pages deployment."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

SITE = Path(__file__).resolve().parent / "site-template"
PUBLIC_FILES = {"index.html", "privacy.html", "support.html", "styles.css", ".nojekyll"}
CONTACT = "mailto:qmkhaust@gmail.com"
BASE_URL = "https://qmkcamel.github.io/photo-cleaner/"


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self.ids = set()
        self.canonical = []
        self.languages = set()
        self.title = False
        self.viewport = False
        self.h1_count = 0
        self.active_content = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if attrs.get("id"):
            self.ids.add(attrs["id"])
        if attrs.get("lang"):
            self.languages.add(attrs["lang"])
        if tag == "title":
            self.title = True
        if tag == "h1":
            self.h1_count += 1
        if tag in {"script", "iframe", "form"}:
            self.active_content = True
        if tag == "meta" and attrs.get("name") == "viewport":
            self.viewport = "width=device-width" in attrs.get("content", "")
        if tag == "link" and attrs.get("rel") == "canonical":
            self.canonical.append(attrs.get("href"))
        for key in ("href", "src"):
            if attrs.get(key):
                self.links.append(attrs[key])


def main():
    errors = []
    pages = {}
    for name in sorted(PUBLIC_FILES):
        path = SITE / name
        if not path.is_file() or path.is_symlink():
            errors.append(f"Missing or non-regular public file: {name}")
            continue
        if path.suffix != ".html":
            continue
        text = path.read_text(encoding="utf-8")
        page = Page()
        page.feed(text)
        pages[name] = page
        for marker in ("pending", "replace before", "before hosting", "static hosting template", "TODO", "TBD"):
            if marker.lower() in text.lower():
                errors.append(f"{name}: unresolved placeholder {marker}")
        if CONTACT not in page.links:
            errors.append(f"{name}: missing approved support contact")
        if page.canonical != [BASE_URL + name]:
            errors.append(f"{name}: incorrect canonical URL")
        if not page.title or not page.viewport or page.h1_count != 1:
            errors.append(f"{name}: title, viewport, or h1 is invalid")
        if not {"zh-Hans", "en"}.issubset(page.languages):
            errors.append(f"{name}: Chinese and English language markers required")
        if page.active_content:
            errors.append(f"{name}: unexpected script, iframe, or form")
    for name, page in pages.items():
        for link in page.links:
            target = urlsplit(link)
            if target.scheme in {"https", "mailto"}:
                continue
            if target.scheme or target.netloc:
                errors.append(f"{name}: unsupported link {link}")
                continue
            target_name = unquote(target.path) or name
            if target_name not in PUBLIC_FILES:
                errors.append(f"{name}: link is outside deployment allowlist: {link}")
            if target.fragment and (target_name not in pages or target.fragment not in pages[target_name].ids):
                errors.append(f"{name}: missing link fragment: {link}")
    if errors:
        print("\n".join(f"FAIL: {error}" for error in errors))
        return 1
    print("PASS: 3 bilingual pages; contact, canonical URLs, local links, fragments, viewport and deployment allowlist verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
