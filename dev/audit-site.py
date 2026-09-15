"""Check generated site links and image descriptions without a browser/server."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit, unquote
import sys
class Page(HTMLParser):
    def __init__(self,p):
        super().__init__();self.ids=set();self.links=[];self.images=[];self.feed(p.read_text())
    def handle_starttag(self,tag,attrs):
        a=dict(attrs)
        if 'id' in a:self.ids.add(a['id'])
        if tag=='a' and 'href' in a:self.links.append(a['href'])
        if tag=='img':self.images.append(a)
root=Path(sys.argv[1] if len(sys.argv)>1 else 'build/site').resolve()
pages={p.resolve():Page(p) for p in root.rglob('*.html')};bad=[];count=0
for path,page in pages.items():
    for href in page.links:
        if any(s in href for s in ('file:', '/Users/', '/private/', 'localhost', '127.0.0.1')):bad.append((path.name,href,'private URL'))
        u=urlsplit(href)
        if u.scheme or u.netloc:continue
        target=(path.parent/unquote(u.path)).resolve() if u.path else path
        if target.is_dir():target=target/'index.html'
        if not target.exists():bad.append((str(path.relative_to(root)),href,'missing file'));continue
        if u.fragment and target in pages and unquote(u.fragment) not in pages[target].ids:
            bad.append((str(path.relative_to(root)),href,'missing anchor'))
        count+=1
for name in ('function-guide','synthetic-geometry'):
    page=pages[root/'articles'/f'{name}.html']
    for img in page.images:
        if 'logo' not in img.get('class','') and not img.get('alt','').strip():bad.append((name,img.get('src','')[:70],'empty alt'))
if bad:
    for item in bad:print(item)
    raise SystemExit(f'{len(bad)} invalid links/images')
print(f'Validated {count} local links on {len(pages)} pages; guide images have alt text.')
