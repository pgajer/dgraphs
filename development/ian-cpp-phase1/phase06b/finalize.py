"""Freeze Phase06B evidence and verify all accepted prior bundles read-only."""
import argparse
import hashlib
import subprocess
import sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'phase04'))
from support import revision,load,write,sha
p=argparse.ArgumentParser();p.add_argument('root',type=Path);a=p.parse_args()
rev=revision();repo=Path.cwd();worker=a.root.parent
base='e098461c803926bdbe7888f4f37c7a1607c0e948'
assert not (a.root/'manifest-v1.json').exists()
assert subprocess.check_output(['git','branch','--show-current'],text=True).strip()=='codex/ian-cpp-feasibility-20260917'
subprocess.run([sys.executable,'-B',str(HERE/'extract.py'),'--check'],check=True)
changed=subprocess.check_output(['git','diff','--name-only',base],text=True).splitlines()
assert all(n.startswith('development/ian-cpp-phase1/phase06b/') or n=='development/ian-cpp-phase1/coordinator/ROADMAP.md' for n in changed)
def gitbytes(commit,name):return subprocess.check_output(['git','show',commit+':'+name])
names=subprocess.check_output(['git','ls-files',str(HERE)],text=True).splitlines()
relative=str(HERE.relative_to(repo))+'/'
runtime=[n for n in names if n.startswith(tuple(relative+d for d in ['include/','src/','tests/'])) and n.endswith(('.cpp','.hpp','.inc'))]
for n in runtime+[relative+'CMakeLists.txt',relative+'config.json']:
    assert (repo/n).read_bytes()==gitbytes('bab88cc',n),n
def identity(commit):
    names=subprocess.check_output(['git','ls-tree','-r','--name-only',commit,relative],text=True).splitlines()
    files=sorted(n for n in names if n.startswith(tuple(relative+d for d in ['include/','src/','tests/'])) and n.endswith(('.cpp','.hpp','.inc')))
    value=''.join(hashlib.sha256(gitbytes(commit,n)).hexdigest() for n in files)
    value+=hashlib.sha256(gitbytes(commit,relative+'CMakeLists.txt')).hexdigest()
    return hashlib.sha256(value.encode()).hexdigest()
identities={label:identity(commit) for label,commit in [('initial','bc9a3ef'),('corrected','bab88cc')]}
for graph in a.root.rglob('child/graph.json'):
    j=load(graph);label='initial' if '/regressions-v1/' in str(graph) else 'corrected'
    assert j['source_sha256']==identities[label],str(graph)
    assert j['configuration_sha256']==sha(HERE/'config.json')
for checkpoint in a.root.rglob('child/checkpoints/checkpoint-*.json'):
    label='initial' if '/regressions-v1/' in str(checkpoint) else 'corrected'
    assert load(checkpoint)['payload']['source']==identities[label]
assert sha(HERE/'config.json')==sha(HERE.parent/'phase06a/config.json')
items=[]
previous=worker/'phase06a-correction-f1'
for entry in load(previous/'preservation-v1.json')['preserved']:
    path=Path(entry['manifest']);assert sha(path)==entry['sha256'];items.append(path)
items += [previous/'manifest-v1.json',repo.parent/'auditor/review-6a-f1/audit-manifest.json']
preserved=[]
for manifest in items:
    data=load(manifest);root=manifest.parent;files=data.get('files',data)
    for name,item in files.items():assert sha(root/name)==(item['sha256'] if isinstance(item,dict) else item),str(root/name)
    sources=data.get('source_files',{})
    for name,item in sources.items():
        commit=data.get('revision') or data.get('final_revision') or data.get('candidate')
        assert hashlib.sha256(gitbytes(commit,name)).hexdigest()==(item['sha256'] if isinstance(item,dict) else item),name
    preserved.append(dict(manifest=str(manifest),sha256=sha(manifest),files=len(files),historical_sources=len(sources)))
for name,digest in [('phase06a-implementer-handoff.md','5c14d0583e3ce729d150cf975e547514d723236029b2d3dde3977cfe812e4898'),
                    ('phase06a-correction-f1-handoff.md','47379e8fe2da9466db703b4f6c1e8af7080ca7653defdf196cd3645034f7e5ff')]:
    assert sha(worker/name)==digest
analysis=load(a.root/'analysis-v3/results.json')
assert analysis['complete'] and analysis['total_solver_calls']==1318 and analysis['accepted_payloads']==1316
assert analysis['intentional_invalid_payloads']==2
write(a.root/'final-checks-v1.json',dict(revision=rev,base=base,git_status='',identities=identities,
    compiled_runtime_matches_commit='bab88cc',preserved=preserved,analysis_sha256=sha(a.root/'analysis-v3/results.json')))
files={str(f.relative_to(a.root)):dict(sha256=sha(f),bytes=f.stat().st_size) for f in sorted(a.root.rglob('*'))
       if f.is_file() and f.name!='manifest-v1.json'}
names+=['development/ian-cpp-phase1/coordinator/ROADMAP.md']
sources={n:dict(sha256=sha(repo/n),bytes=(repo/n).stat().st_size) for n in names}
write(a.root/'manifest-v1.json',dict(revision=rev,base=base,files=files,source_files=sources,
    note='Retains original resource-heavy workload, corrected workload, all failures and operational tests. Handoff outside bundle.'))
print(dict(revision=rev,generated_files=len(files),sources=len(sources),identities=identities,preserved=preserved))
