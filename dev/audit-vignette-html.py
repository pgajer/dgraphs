"""Check links and self-contained assets in rendered vignette previews."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit
import sys

class Page(HTMLParser):
    def __init__(self, path):
        super().__init__()
        self.ids, self.links, self.assets = set(), [], []
        self.feed(path.read_text())

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            self.ids.add(attrs["id"])
        if "href" in attrs:
            self.links.append(attrs["href"])
        if "src" in attrs:
            self.assets.append(attrs["src"])

root = Path(sys.argv[1] if len(sys.argv) > 1 else "build/validation/vignettes")
expected = ["function-guide.html", "synthetic-geometry.html", "data-derived-graph-workflow.html"]
pages = {name: Page(root / name) for name in expected}
checked = 0
for name, page in pages.items():
    for value in page.links + page.assets:
        url = urlsplit(value)
        assert not any(x in value for x in ("file:", "/Users/", "/private/", "localhost", "127.0.0.1")), value
        if url.scheme or url.netloc:
            continue
        target = unquote(url.path) or name
        assert target in pages, (name, value)
        if url.fragment:
            assert unquote(url.fragment) in pages[target].ids, (name, value)
        checked += 1
    assert all(urlsplit(value).scheme == "data" for value in page.assets), (name, "nonembedded asset")
print(f"Validated {checked} local links across {len(pages)} HTML guides; assets embedded; no local/private URLs.")
