"""Hash preserved historical evidence, unchanged runtime and the new submission."""
import hashlib,subprocess
from concurrent.futures import ThreadPoolExecutor
from support import *
root=Path(sys.argv[1]).resolve();worker=root.parent;repo=Path.cwd();base='c777ca5c2e275a68aae4c87a3034799952d7c525'
assert not subprocess.check_output(['git','status','--porcelain'],text=True)
assert subprocess.check_output(['git','branch','--show-current'],text=True).strip()=='codex/ian-cpp-feasibility-20260917'
assert not (root/'manifest-v1.json').exists()
revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip();changed=subprocess.check_output(['git','diff','--name-only',base],text=True).splitlines()
assert all(p.startswith('development/ian-cpp-phase1/phase07i/') or p=='development/ian-cpp-phase1/coordinator/ROADMAP.md' for p in changed)
previous=load(worker/'phase07h/preservation-v1.json');paths=[]
for e in previous['preserved']:
    assert sha(e['manifest'])==e['sha256'];paths.append(Path(e['manifest']))
paths.extend([worker/'phase07h/manifest-v1.json',repo.parent/'auditor/review-7h/audit-manifest.json'])
expected={};records=[];source_cache={}
for p in paths:
    data=load(p);files=data.get('files',data);sources=data.get('source_files',{});commit=data.get('revision') or data.get('final_revision') or data.get('candidate')
    for name,item in files.items():
        path=(p.parent/name).resolve();digest=item['sha256'] if isinstance(item,dict) else item
        if path in expected:assert expected[path]==digest
        expected[path]=digest
    for name,item in sources.items():
        key=(commit,name)
        if key not in source_cache:source_cache[key]=hashlib.sha256(subprocess.check_output(['git','show',commit+':'+name])).hexdigest()
        assert source_cache[key]==(item['sha256'] if isinstance(item,dict) else item),name
    records.append(dict(manifest=str(p),sha256=sha(p),files=len(files),historical_sources=len(sources)))
with ThreadPoolExecutor(max_workers=4) as pool:
    for path,digest in zip(expected,pool.map(sha,expected)):assert digest==expected[path],str(path)
assert sha(worker/'phase07h/manifest-v1.json')=='ed959b14bf219c3ea507467b1cc6b0d61f991212ec226729431f15a6e1381bf1'
assert sha(worker/'phase07h-implementer-handoff.md')=='73774d4df7e0fb76bda68c49f321bfa6cefc322bcabc7ba0bf0879feb1177661'
assert sha(worker/'phase06b/build-v3/ian_engine')==previous['engine_sha256']
assert sha(previous['backend'])==previous['backend_sha256']
for phase in ['phase07e','phase07f','phase07g','phase07h']:
    for name,item in load(worker/phase/'manifest-v1.json')['source_files'].items():
        if '/'+phase+'/' in name:assert sha(repo/name)==item['sha256']
for group in ['solver_sources','python_modules']:
    for name,digest in load(worker/'phase07e/fixtures-v1/manifest.json')[group].items():assert sha(name)==digest,name
for name,digest in load(root/'preflight.json')['backend_files'].items():assert sha(name)==digest
for name,digest in load(root/'fixtures-manifest.json').items():assert sha(root/name)==digest
result=load(root/'results.json');assert result['complete'] and result['physical_attempts']==6
assert all(r['repair']['exact_feasible'] for r in result['endpoints'])
assert all(not r['raw_exact_original_feasible'] for r in result['endpoints'])
assert sum(not r['raw_exact_band_pass'] for r in result['endpoints'])==3
assert load(root/'saved-span.json')['both_saved_witnesses_exactly_feasible']
assert not result['resource_limits_hit'] and not result['policy_changed'] and not result['scale_gate']
assert load(root/'preflight.json')['passed'] and load(root/'bounds.json')['auditor_agreement']
executed='ad5fad6'
for name in ['support.py','prepare.py','execute.py','analyze.py','replay.py','exact.py']:
    path=str(HERE.relative_to(repo)/name);assert hashlib.sha256(subprocess.check_output(['git','show',executed+':'+path])).hexdigest()==sha(repo/path)
write(root/'preservation-v1.json',dict(revision=revision,base=base,git_status='',changed_paths=changed,preserved=records,unique_evidence_files_hashed=len(expected),historical_source_versions_hashed=len(source_cache),original_runtime_unchanged=True,engine_sha256=previous['engine_sha256'],backend=previous['backend'],backend_sha256=previous['backend_sha256'],executed_revision=executed))
sources=subprocess.check_output(['git','ls-files','development/ian-cpp-phase1/phase07i','development/ian-cpp-phase1/coordinator/ROADMAP.md'],text=True).splitlines();files={str(p.relative_to(root)):dict(sha256=sha(p),bytes=p.stat().st_size) for p in sorted(root.rglob('*')) if p.is_file()}
write(root/'manifest-v1.json',dict(revision=revision,base=base,files=files,source_files={n:dict(sha256=sha(repo/n),bytes=(repo/n).stat().st_size) for n in sources},note='Six range solves with strict exact band checks, separate feasible repairs, exact dual bounds and saved-vector witnesses. Raw endpoints remain unresolved; no tolerance relaxation or trajectory. Handoff outside bundle.'))
print(dict(revision=revision,files=len(files),sources=len(sources),preserved_files=sum(x['files'] for x in records),preserved_sources=sum(x['historical_sources'] for x in records),preserved_manifests=len(records)))
