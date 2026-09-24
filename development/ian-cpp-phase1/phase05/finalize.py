"""Preserve previous submissions and freeze this bounded evidence bundle."""
import argparse
import hashlib
import importlib.metadata
import platform
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent/'phase04'))
from support import revision, load, write, sha

p = argparse.ArgumentParser()
p.add_argument('root', type=Path)
p.add_argument('label')
a = p.parse_args()
rev = revision()
repo, worker = Path.cwd(), a.root.parent
assert str(repo) == '/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree'
assert subprocess.check_output(['git','branch','--show-current'],text=True).strip() == 'codex/ian-cpp-feasibility-20260917'
assert not (a.root/f'final-manifest-{a.label}.json').exists()
preserved=[]
manifests=[(worker,worker/'evidence-manifest.json',False)]
for n,filename in [('phase02','evidence-manifest-v1.json'),('phase03','final-manifest-v1.json'),('phase04','final-manifest-v1.json')]:
    manifests.append((worker/n,worker/n/filename,True))
for i in range(1,5):
    folder=repo.parent/f'auditor/review-{i}'
    manifests.append((folder,folder/'audit-manifest.json',False))
for root,path,source_check in manifests:
    data=load(path)
    files=data.get('files',data)
    for name,item in files.items():
        assert sha(root/name)==(item['sha256'] if isinstance(item,dict) else item), name
    sources=data.get('source_files',{}) if source_check else {}
    for name,item in sources.items():
        assert sha(repo/name)==(item['sha256'] if isinstance(item,dict) else item), name
    preserved.append(dict(path=str(path),sha256=sha(path),files=len(files),sources=len(sources)))
fixtures=load(a.root/'fixtures-v1/manifest.json')
for name,digest in fixtures['files'].items():
    assert sha(a.root/'fixtures-v1'/name)==digest
for item in fixtures['state_selection'].values():
    assert sha(item['provenance']['source'])==item['provenance']['sha256']
for name,key in [('PLAN.md','plan_sha256'),('CONTRACT.md','contract_sha256')]:
    frozen=subprocess.check_output(['git','show',fixtures['revision']+':development/ian-cpp-phase1/phase05/'+name])
    assert hashlib.sha256(frozen).hexdigest()==fixtures[key]
calibration=load(a.root/'calibration-v1/manifest.json')
assert calibration['fixtures_sha256']==sha(a.root/'fixtures-v1/manifest.json')
assert calibration['total_calibration_solves']==28
for case in calibration['cases']:
    assert sha(case['input'])==case['sha256']
for name in ['reference_probe.py','probe.cpp','CMakeLists.txt','calibrate.py','launch.py']:
    relative=str((HERE/name).relative_to(repo))
    assert (HERE/name).read_bytes()==subprocess.check_output(['git','show','419e9b9:'+relative])
assert (HERE/'fixtures.py').read_bytes()==subprocess.check_output(['git','show','6f8ec7b:development/ian-cpp-phase1/phase05/fixtures.py'])
for namespace in ['probes-v2','full-v1','stages-v1']:
    ledger=load(a.root/namespace/'ledger.json')
    assert ledger['complete']
    for item in ledger['runs'].values():
        assert sha(item['input'])==item['input_sha256']
        for name,digest in item['files'].items():
            assert sha(Path(item['folder'])/name)==digest
expected=load(worker/'phase03/cases-v1/nonuniform_curve/original/child/source/provenance.json')
provenance=list(a.root.rglob('child/source/provenance.json'))
assert provenance and all(load(f)==expected for f in provenance)
reference_files={name:dict(sha256=sha(name)) for name in [
    worker/'phase04/build-v1/ian_engine',worker/'phase05/build-v1/ian_probe',
    worker/'build-v2/rust-target/release/libclarabel_c.dylib',worker/'phase03/deps/json.hpp']}
results=load(a.root/'analysis-v1/results.json')
assert results['raw_count']==1330 and results['valid_raw_count']==1330
assert results['all_native_comparisons_passed'] and results['all_historical_discrete_agreed']
env=dict(python=sys.version,platform=platform.platform(),machine=platform.machine(),
    packages={k:importlib.metadata.version(k) for k in ['numpy','scipy','cvxpy','clarabel','psutil']})
assert env['packages']==dict(numpy='2.2.6',scipy='1.15.3',cvxpy='1.6.7',clarabel='0.11.1',psutil='7.0.0')
write(a.root/f'final-checks-{a.label}.json',dict(revision=rev,base=subprocess.check_output(['git','rev-parse','9022e32'],text=True).strip(),
    cwd=str(repo),branch='codex/ian-cpp-feasibility-20260917',git_status='',preserved=preserved,
    reference_files={str(k):v for k,v in reference_files.items()}, reference_provenance=expected,
    reference_executions=len(provenance),environment=env,analysis_sha256=sha(a.root/'analysis-v1/results.json'),
    notes='No new solves. Historical intermediate-array failures and warning logs remain preserved. This is implementer validation, not independent audit.'))
files={str(f.relative_to(a.root)):dict(sha256=sha(f),bytes=f.stat().st_size)
    for f in sorted(a.root.rglob('*')) if f.is_file() and not f.name.startswith('final-manifest-')}
names=subprocess.check_output(['git','ls-files',str(HERE.relative_to(repo)),
    'development/ian-cpp-phase1/coordinator/ROADMAP.md'],text=True).splitlines()
sources={n:dict(sha256=sha(repo/n),bytes=(repo/n).stat().st_size) for n in names}
write(a.root/f'final-manifest-{a.label}.json',dict(revision=rev,files=files,source_files=sources,
    note='Excludes final-manifest files and the later handoff outside phase05. All failed comparisons retained.'))
print(dict(revision=rev,files=len(files),sources=len(sources),preserved=preserved))
