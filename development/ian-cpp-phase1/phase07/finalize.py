"""Read-only preservation verification and final Phase07 source/evidence inventory."""
import hashlib
import subprocess
import sys
from pathlib import Path
from checks import load,write,sha

root=Path(sys.argv[1]); repo=Path.cwd(); worker=root.parent
assert not subprocess.check_output(['git','status','--porcelain'],text=True)
assert subprocess.check_output(['git','branch','--show-current'],text=True).strip()=='codex/ian-cpp-feasibility-20260917'
revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
base='e31f3f20692e738c6c4ca9c56f8a9f26518c4216'
changed=subprocess.check_output(['git','diff','--name-only',base],text=True).splitlines()
assert all(n.startswith('development/ian-cpp-phase1/phase07/') or n=='development/ian-cpp-phase1/coordinator/ROADMAP.md' for n in changed)
assert not (root/'manifest-v1.json').exists()
previous=load(worker/'phase06b/final-checks-v1.json')['preserved']
paths=[]
for item in previous:
    assert sha(item['manifest'])==item['sha256']; paths.append(Path(item['manifest']))
paths.extend([worker/'phase06b/manifest-v1.json',repo.parent/'auditor/review-6b/audit-manifest.json'])
preserved=[]
for manifest in paths:
    data=load(manifest); files=data.get('files',data)
    for name,item in files.items():
        assert sha(manifest.parent/name)==(item['sha256'] if isinstance(item,dict) else item),str(manifest.parent/name)
    sources=data.get('source_files',{})
    commit=data.get('revision') or data.get('final_revision') or data.get('candidate')
    for name,item in sources.items():
        raw=subprocess.check_output(['git','show',commit+':'+name])
        assert hashlib.sha256(raw).hexdigest()==(item['sha256'] if isinstance(item,dict) else item),name
    preserved.append(dict(manifest=str(manifest),sha256=sha(manifest),files=len(files),historical_sources=len(sources)))
assert sha(worker/'phase06b-implementer-handoff.md')=='a91eab3f075cf8928d149cbc7c5b7c22e5cb7eefdb498d6e06b5e930b03964c8'
analysis=load(root/'analysis-v2/results.json')
assert analysis['study_complete'] and analysis['total_solver_calls']==1028 and analysis['numerically_valid_payloads']==1025
assert load(root/'harness-v2/results.json')['passed']
fixtures=load(root/'fixtures-v1/manifest.json')
for item in fixtures['files'].values(): assert sha(item['path'])==item['sha256']
ledger=load(root/'ladder-v2/ledger.json')
assert sha(ledger['engine'])==ledger['engine_sha256']
backend=worker/'phase06a/clean-v2/prefix/lib/libclarabel_c.dylib'
assert sha(backend)=='3896f365f5267b2591f56b0631deacf8c9693f9a488e5dde13295b8ec85d1d60'
write(root/'preservation-v1.json',dict(revision=revision,base=base,git_status='',preserved=preserved,
    backend=str(backend),backend_sha256=sha(backend),engine_sha256=sha(ledger['engine']),
    binary_linkage=subprocess.check_output(['/usr/bin/otool','-L',ledger['engine']],text=True),
    accepted_runtime_unchanged=True,changed_paths=changed))
names=subprocess.check_output(['git','ls-files','development/ian-cpp-phase1/phase07','development/ian-cpp-phase1/coordinator/ROADMAP.md'],text=True).splitlines()
files={str(f.relative_to(root)):dict(sha256=sha(f),bytes=f.stat().st_size) for f in sorted(root.rglob('*')) if f.is_file()}
sources={n:dict(sha256=sha(repo/n),bytes=(repo/n).stat().st_size) for n in names}
write(root/'manifest-v1.json',dict(revision=revision,base=base,files=files,source_files=sources,
    note='Includes shared numerical refusals, both original ledgers, harness/census failures and unused frozen 1000-profile fixtures. Handoff outside bundle.'))
print(dict(revision=revision,files=len(files),sources=len(sources),preserved_files=sum(x['files'] for x in preserved),preserved_sources=sum(x['historical_sources'] for x in preserved)))
