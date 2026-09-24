"""Verify old evidence read-only, then inventory the completed bounded experiment."""
import hashlib,importlib.metadata,platform,subprocess,sys
from pathlib import Path
from checks import load,write,sha
from provenance import build_identity
root=Path(sys.argv[1]);worker=root.parent;repo=Path.cwd();base='61da3139e1cbecfa995ec061f2d926b6cc04bb4f'
assert not subprocess.check_output(['git','status','--porcelain'],text=True)
assert subprocess.check_output(['git','branch','--show-current'],text=True).strip()=='codex/ian-cpp-feasibility-20260917'
assert not (root/'manifest-v1.json').exists()
revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
changed=subprocess.check_output(['git','diff','--name-only',base],text=True).splitlines()
assert all(p.startswith('development/ian-cpp-phase1/phase07c/') or p=='development/ian-cpp-phase1/coordinator/ROADMAP.md' for p in changed)
previous=load(worker/'phase07b/preservation-v1.json');paths=[]
for e in previous['preserved']:
 assert sha(e['manifest'])==e['sha256'];paths.append(Path(e['manifest']))
paths.extend([worker/'phase07b/manifest-v1.json',repo.parent/'auditor/review-7b/audit-manifest.json'])
preserved=[]
for p in paths:
 data=load(p);files=data.get('files',data)
 for name,item in files.items():assert sha(p.parent/name)==(item['sha256'] if isinstance(item,dict) else item),str(p.parent/name)
 sources=data.get('source_files',{});commit=data.get('revision') or data.get('final_revision') or data.get('candidate')
 for name,item in sources.items():
  raw=subprocess.check_output(['git','show',commit+':'+name]);assert hashlib.sha256(raw).hexdigest()==(item['sha256'] if isinstance(item,dict) else item),name
 preserved.append(dict(manifest=str(p),sha256=sha(p),files=len(files),historical_sources=len(sources)))
assert sha(worker/'phase07b/manifest-v1.json')=='e2ae47375b6f7d884dfe5020c5f9eb65d1ff682df824d07a75019e04605a7e88'
assert sha(worker/'phase07b-implementer-handoff.md')=='e095160b0ecd158dcd526dd9a30fbb88ac75691c97d19481016923e337c2dd57'
assert sha(worker/'phase06b/build-v3/ian_engine')==previous['engine_sha256']
backend=worker/'phase06a/clean-v2/prefix/lib/libclarabel_c.dylib';assert sha(backend)==previous['backend_sha256']
analysis=load(root/'analysis-v3/results.json');assert analysis['complete'] and analysis['primary_attempts']==1882 and analysis['primary_rejected']==18
assert analysis['total']['attempts']==3789 and analysis['operation_attempts']==25
assert load(root/'checks-v1/results.json')['passed'] and load(root/'derivation-v1.json')['passed']
identity=build_identity(root/'build-v2');assert identity==analysis['build_provenance']['final']
write(root/'preservation-v1.json',dict(revision=revision,base=base,git_status='',changed_paths=changed,preserved=preserved,
 original_runtime_unchanged=True,engine_sha256=previous['engine_sha256'],backend=str(backend),backend_sha256=sha(backend),
 environment=dict(python=sys.version,platform=platform.platform(),machine=platform.machine(),packages={n:importlib.metadata.version(n) for n in ['numpy','scipy','clarabel','cvxpy','psutil']})))
sources=subprocess.check_output(['git','ls-files','development/ian-cpp-phase1/phase07c','development/ian-cpp-phase1/coordinator/ROADMAP.md'],text=True).splitlines()
files={str(p.relative_to(root)):dict(sha256=sha(p),bytes=p.stat().st_size) for p in sorted(root.rglob('*')) if p.is_file()}
write(root/'manifest-v1.json',dict(revision=revision,base=base,files=files,source_files={n:dict(sha256=sha(repo/n),bytes=(repo/n).stat().st_size) for n in sources},note='Experimental bounded retry study; the natural helix still fails. Preliminary build/panel and failed census retained. No policy adoption or scale expansion. Handoff outside bundle.'))
print(dict(revision=revision,files=len(files),sources=len(sources),preserved_files=sum(x['files'] for x in preserved),preserved_sources=sum(x['historical_sources'] for x in preserved),preserved_manifests=len(preserved)))
