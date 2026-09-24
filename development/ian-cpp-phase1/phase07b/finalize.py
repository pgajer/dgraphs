"""Preserve previous accepted evidence and freeze the completed diagnostic bundle."""
import hashlib
import importlib.metadata
import platform
import subprocess
import sys
from pathlib import Path
from common import load,write,sha

root=Path(sys.argv[1]);worker=root.parent;repo=Path.cwd()
assert not subprocess.check_output(['git','status','--porcelain'],text=True)
assert subprocess.check_output(['git','branch','--show-current'],text=True).strip()=='codex/ian-cpp-feasibility-20260917'
assert not (root/'manifest-v1.json').exists()
revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip();base='c2330c8ed1e9b307700b51dc919391090f4f0ec6'
changed=subprocess.check_output(['git','diff','--name-only',base],text=True).splitlines()
assert all(p.startswith('development/ian-cpp-phase1/phase07b/') or p=='development/ian-cpp-phase1/coordinator/ROADMAP.md' for p in changed)
previous=load(worker/'phase07/preservation-v1.json');paths=[]
for entry in previous['preserved']:
    assert sha(entry['manifest'])==entry['sha256'];paths.append(Path(entry['manifest']))
paths.extend([worker/'phase07/manifest-v1.json',repo.parent/'auditor/review-7/audit-manifest.json'])
preserved=[]
for p in paths:
    data=load(p);files=data.get('files',data)
    for name,item in files.items():assert sha(p.parent/name)==(item['sha256'] if isinstance(item,dict) else item),str(p.parent/name)
    sources=data.get('source_files',{});commit=data.get('revision') or data.get('final_revision') or data.get('candidate')
    for name,item in sources.items():
        raw=subprocess.check_output(['git','show',commit+':'+name])
        assert hashlib.sha256(raw).hexdigest()==(item['sha256'] if isinstance(item,dict) else item),name
    preserved.append(dict(manifest=str(p),sha256=sha(p),files=len(files),historical_sources=len(sources)))
assert sha(worker/'phase07-implementer-handoff.md')=='ecbfae01c139c2ef89ff787b926b416718a8fc3286e0b0f741240dd9fdf50751'
assert sha(worker/'phase06b/build-v3/ian_engine')==previous['engine_sha256']
assert sha(previous['backend'])==previous['backend_sha256']
fixtures=load(root/'fixtures-v1/manifest.json')
for item in fixtures['cases'].values():
    assert sha(item['path'])==item['sha256']
    assert sha(item['source'])==item['source_sha256']
for group in ['source_files','wheel_files']:
    for name,digest in fixtures[group].items():assert sha(name)==digest
analysis=load(root/'analysis-v1/results.json');ledger=load(root/'replays-v1/ledger.json')
assert analysis['complete'] and analysis['solver_calls']==33 and analysis['accepted']==29 and len(analysis['rejected'])==4
assert len(ledger['runs'])==33 and not ledger['gated']
assert load(root/'checks-v1/results.json')['passed'] and load(root/'witness-v1/results.json')['all_feasible']
assert len(list((root/'replays-v1').glob('*/*/child/raw-solution.json')))==33
for label in ['prepare','check','replay','analysis','witness']:
    assert load(root/(label+'-driver-v1')/'process.json')['exit_code']==0
write(root/'preservation-v1.json',dict(revision=revision,base=base,git_status='',preserved=preserved,changed_paths=changed,
    original_runtime_unchanged=True,environment=dict(python=sys.version,platform=platform.platform(),
        packages={n:importlib.metadata.version(n) for n in ['numpy','scipy','clarabel','cvxpy','psutil']}),
    engine_sha256=previous['engine_sha256'],backend_sha256=previous['backend_sha256']))
sources=subprocess.check_output(['git','ls-files','development/ian-cpp-phase1/phase07b','development/ian-cpp-phase1/coordinator/ROADMAP.md'],text=True).splitlines()
files={str(p.relative_to(root)):dict(sha256=sha(p),bytes=p.stat().st_size) for p in sorted(root.rglob('*')) if p.is_file()}
write(root/'manifest-v1.json',dict(revision=revision,base=base,files=files,
    source_files={n:dict(sha256=sha(repo/n),bytes=(repo/n).stat().st_size) for n in sources},
    note='All 33 prescribed diagnostics, including four numerical refusals; no adopted policy or complete IAN experimental run. Handoff outside bundle.'))
print(dict(revision=revision,files=len(files),sources=len(sources),preserved_files=sum(x['files'] for x in preserved),
    preserved_sources=sum(x['historical_sources'] for x in preserved)))
