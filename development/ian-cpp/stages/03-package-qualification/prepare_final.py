"""Preserve corrected archive and allocate fresh final libraries; no IAN calls."""
from pathlib import Path
import sys,json,hashlib,shutil,tarfile,zipfile,io
root=Path(sys.argv[1]);project=Path(__file__).resolve().parents[4];sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
source=root/'source-v2';source.mkdir();archive=project/'build/dgraphs_0.3.0.9000.tar.gz';shutil.copy2(archive,source/archive.name);shutil.copy2(archive.with_suffix('.provenance.json'),source/archive.with_suffix('.provenance.json').name)
with tarfile.open(archive) as t:
 names=t.getnames();assert not any(n.startswith(('dgraphs/development/','dgraphs/inst/ian/backend/')) for n in names)
 blob=t.extractfile('dgraphs/inst/ian/backend-sources.zip').read();manifest=json.loads(t.extractfile('dgraphs/inst/ian/backend-source-manifest.json').read());assert hashlib.sha256(blob).hexdigest()==manifest['zip_sha256']
 with zipfile.ZipFile(io.BytesIO(blob)) as z:
  assert set(z.namelist())==set(manifest['files'])
  for name,h in manifest['files'].items():assert hashlib.sha256(z.read(name)).hexdigest()==h==sha(project/'inst/ian/backend'/name)
 files={m.name:hashlib.sha256(t.extractfile(m).read()).hexdigest() for m in t.getmembers() if m.isfile()}
(root/'archive-v2.json').write_text(json.dumps(dict(archive=str(source/archive.name),sha256=sha(archive),files=files,bundled_sources=manifest,all_bundled_bytes_match_editable_sources=True),indent=2)+'\n')
p=root/'environment.json';shutil.copy2(p,root/'environment-v1.json');env=json.loads(p.read_text())
for label in ['rdevel','r45']:
 cfg=json.loads(json.dumps(env['runtimes'][label]));folder=root/(label+'-v2');folder.mkdir();lib=folder/'library';lib.mkdir();old=cfg['library'];cfg['library']=str(lib)
 for key in ['R_LIBS','R_LIBS_USER','R_LIBS_SITE']:
  if key in cfg['env']:cfg['env'][key]=cfg['env'][key].replace(old,str(lib))
 if label=='r45':shutil.copytree(Path(old)/'RcppEigen',lib/'RcppEigen')
 env['runtimes'][label+'-v2']=cfg
p.write_text(json.dumps(env,indent=2)+'\n');print('Corrected archive/source bytes verified; fresh final libraries allocated.')
