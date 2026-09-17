"""Freeze source/build identities and preserve every previous submitted bundle."""
import argparse
import hashlib
import subprocess
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'phase04'))
from support import revision,load,write,sha

p=argparse.ArgumentParser();p.add_argument('root',type=Path);p.add_argument('label');a=p.parse_args()
rev=revision();repo=Path.cwd();worker=a.root.parent
assert str(repo)=='/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree'
assert subprocess.check_output(['git','branch','--show-current'],text=True).strip()=='codex/ian-cpp-feasibility-20260917'
assert not (a.root/f'final-manifest-{a.label}.json').exists()
subprocess.run([sys.executable,'-B',str(HERE/'extract.py'),'--check'],check=True)
preserved=[]
items=[(worker,worker/'evidence-manifest.json',False)]
for name,filename in [('phase02','evidence-manifest-v1.json'),('phase03','final-manifest-v1.json'),
                      ('phase04','final-manifest-v1.json'),('phase05','final-manifest-v1.json')]:
    items.append((worker/name,worker/name/filename,True))
for i in range(1,6):
    root=repo.parent/f'auditor/review-{i}';items.append((root,root/'audit-manifest.json',False))
for root,path,check_sources in items:
    data=load(path);files=data.get('files',data)
    for name,item in files.items():assert sha(root/name)==(item['sha256'] if isinstance(item,dict) else item),str(root/name)
    sources=data.get('source_files',{}) if check_sources else {}
    historic=[]
    for name,item in sources.items():
        expected=item['sha256'] if isinstance(item,dict) else item
        if name=='development/ian-cpp-phase1/coordinator/ROADMAP.md':
            content=subprocess.check_output(['git','show',data['revision']+':'+name])
            assert hashlib.sha256(content).hexdigest()==expected
            historic.append(name)
        else:assert sha(repo/name)==expected,name
    preserved.append(dict(manifest=str(path),sha256=sha(path),generated=len(files),sources=len(sources),historical_commit_sources=historic))

def gitbytes(revision,name):
    return subprocess.check_output(['git','show',revision+':development/ian-cpp-phase1/phase06a/'+name])
def identity(files,read):
    names=sorted(n for n in files if n.startswith(('include/','src/','tests/')) and n.endswith(('.hpp','.cpp')))
    hashes=''.join(hashlib.sha256(read(n)).hexdigest() for n in names)
    hashes+=hashlib.sha256(read('CMakeLists.txt')).hexdigest()
    return hashlib.sha256(hashes.encode()).hexdigest()
names=subprocess.check_output(['git','ls-tree','-r','--name-only','67bb6ce','development/ian-cpp-phase1/phase06a'],text=True).splitlines()
names=[n.split('/phase06a/',1)[1] for n in names]
development_identity=identity(names,lambda n:gitbytes('67bb6ce',n))
for n in names:
    if n.startswith(('src/','include/')) or n in ['CMakeLists.txt','config.json','tests/probe.cpp']:
        assert (HERE/n).read_bytes()==gitbytes('67bb6ce',n),n
clean=a.root/'clean-v2';build=load(clean/'build-record.json');assert build['complete']
for name,digest in build['source_files'].items():assert sha(clean/'source'/name)==digest
for name,digest in build['dependency_sources'].items():assert sha(clean/'dependencies'/name)==digest
clean_identity=identity(build['source_files'],lambda n:(clean/'source'/n).read_bytes())
for graph in a.root.rglob('child/graph.json'):
    expected=clean_identity if '/feasibility-v1/' in str(graph) else development_identity
    payload=load(graph)
    assert payload['source_sha256']==expected,str(graph)
    assert payload['configuration_sha256']==sha(HERE/'config.json')
for name in ['src/core.cpp','src/engine.hpp','src/input.hpp','src/numeric.hpp','src/solver.hpp','include/ian/core.hpp']:
    assert sha(HERE/name)==sha(clean/'source'/name)
for name in ['src/r_bridge.cpp','tests/consumer/main.cpp','tests/r_smoke.R']:
    assert sha(HERE/name)==sha(clean/'source'/name)
assert sha(HERE/'config.json')==sha(HERE.parent/'phase04/config.json')
assert (clean/'vendor-command/stdout.log').exists() and (clean/'vendor-command/stderr.log').exists()
assert sha(clean/'prefix/lib/libclarabel_c.dylib')==build['backend_sha256']
analysis=load(a.root/'analysis-v1/results.json')
assert analysis['total_solver_calls']==560 and analysis['traced_payloads']==491 and analysis['accepted_payloads']==490
assert analysis['intentional_invalid_payloads']==1 and analysis['untraced_interface_calls']==69
assert load(a.root/'regressions-v1/checks.json')['complete'] and load(a.root/'feasibility-v1/checks.json')['complete']
write(a.root/f'final-checks-{a.label}.json',dict(revision=rev,base=subprocess.check_output(['git','rev-parse','68eded5'],text=True).strip(),
    cwd=str(repo),branch='codex/ian-cpp-feasibility-20260917',git_status='',preserved=preserved,
    development_build_revision='67bb6ce',development_source_identity=development_identity,clean_source_identity=clean_identity,
    clean_build_revision=build['revision'],analysis_sha256=sha(a.root/'analysis-v1/results.json'),
    extraction_verified=True,compiled_algorithm_sources_unchanged=True,
    note='No new numerical execution. Previous coordinator roadmap bytes are verified at the frozen Phase05 commit; the live roadmap intentionally advances.'))
files={str(f.relative_to(a.root)):dict(sha256=sha(f),bytes=f.stat().st_size) for f in sorted(a.root.rglob('*'))
    if f.is_file() and not f.name.startswith('final-manifest-')}
names=subprocess.check_output(['git','ls-files',str(HERE.relative_to(repo)),
    'development/ian-cpp-phase1/coordinator/ROADMAP.md'],text=True).splitlines()
sources={n:dict(sha256=sha(repo/n),bytes=(repo/n).stat().st_size) for n in names}
write(a.root/f'final-manifest-{a.label}.json',dict(revision=rev,files=files,source_files=sources,
    note='Includes superseded clean-v1 build, corrected clean-v2, all logs still available, and intentional invalid-vector evidence. Excludes this manifest and later external handoff.'))
print(dict(revision=rev,files=len(files),sources=len(sources),preserved=preserved))
