#!/usr/bin/env python3
"""Create deterministic package source assets; editable backend files remain canonical."""
import hashlib,json,zipfile
from pathlib import Path
root=Path(__file__).resolve().parents[2];folder=root/'inst/ian';source=folder/'backend'
archive=folder/'backend-sources.zip';manifest=folder/'backend-source-manifest.json'
if archive.exists() or manifest.exists():raise SystemExit('Remove only the previous generated IAN source assets before rebuilding.')
files={str(p.relative_to(source)):p.read_bytes() for p in sorted(source.rglob('*')) if p.is_file()}
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
 for name,data in files.items():
  info=zipfile.ZipInfo(name,date_time=(1980,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o644<<16;z.writestr(info,data,compresslevel=9)
manifest.write_text(json.dumps(dict(format=1,zip_sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),files={k:hashlib.sha256(v).hexdigest() for k,v in files.items()},purpose='Unchanged editable backend source bytes and license notices for the optional installed-source build'),indent=2)+'\n')
print('Bundled',len(files),'IAN source/license files.')
