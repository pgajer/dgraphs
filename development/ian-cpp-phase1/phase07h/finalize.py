"""Hash preserved historical evidence, unchanged runtime and the new submission."""
import hashlib,subprocess
from concurrent.futures import ThreadPoolExecutor
from support import *
root=Path(sys.argv[1]).resolve();worker=root.parent;repo=Path.cwd();base='d124f56a4c99580da6f2bafe4cabcac33fed8112'
assert not subprocess.check_output(['git','status','--porcelain'],text=True)
assert subprocess.check_output(['git','branch','--show-current'],text=True).strip()=='codex/ian-cpp-feasibility-20260917'
assert not (root/'manifest-v1.json').exists()
revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip();changed=subprocess.check_output(['git','diff','--name-only',base],text=True).splitlines()
assert all(p.startswith('development/ian-cpp-phase1/phase07h/') or p=='development/ian-cpp-phase1/coordinator/ROADMAP.md' for p in changed)
previous=load(worker/'phase07g/preservation-v1.json');paths=[]
for e in previous['preserved']:
    assert sha(e['manifest'])==e['sha256'];paths.append(Path(e['manifest']))
paths.extend([worker/'phase07g/manifest-v1.json',repo.parent/'auditor/review-7g/audit-manifest.json'])
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
assert sha(worker/'phase07g/manifest-v1.json')=='586c2f6b4dacf450a77ceb4de98b2bbfd2ba61e0840988c897f1e1eedcf3c31c'
assert sha(worker/'phase07g-implementer-handoff.md')=='855c0a7acf05d73317c18ebd7f6391835ad2672e01321660e2a7dde005337a3c'
assert sha(worker/'phase06b/build-v3/ian_engine')==previous['engine_sha256']
assert sha(previous['backend'])==previous['backend_sha256']
for phase in ['phase07e','phase07f','phase07g']:
    for name,item in load(worker/phase/'manifest-v1.json')['source_files'].items():
        if '/'+phase+'/' in name:assert sha(repo/name)==item['sha256']
for group in ['solver_sources','python_modules']:
    for name,digest in load(worker/'phase07e/fixtures-v1/manifest.json')[group].items():assert sha(name)==digest,name
for name,digest in load(root/'preflight.json')['backend_files'].items():assert sha(name)==digest
for name,digest in load(root/'fixtures/manifest.json').items():assert sha(root/'fixtures'/name)==digest
result=load(root/'results.json');assert result['complete'] and result['physical_attempts']==4 and all(result['repeat_exact'].values())
assert all(r['diagnostic_certified'] for r in result['runs']) and result['cross_input']['exact']
assert not result['resource_limits_hit'] and not result['policy_changed'] and not result['scale_gate']
assert load(root/'preflight.json')['passed'];assert load(root/'guard-controls/results.json')['passed']
assert load(root/'guard-controls/results.json')['optimizer_calls']==0
executed='2d62cde'
for name in ['support.py','prepare.py','execute.py','analyze.py','replay.py','oneshot_guard.py','test_guard.py']:
    path=str(HERE.relative_to(repo)/name);assert hashlib.sha256(subprocess.check_output(['git','show',executed+':'+path])).hexdigest()==sha(repo/path)
write(root/'preservation-v1.json',dict(revision=revision,base=base,git_status='',changed_paths=changed,preserved=records,unique_evidence_files_hashed=len(expected),historical_source_versions_hashed=len(source_cache),original_runtime_unchanged=True,engine_sha256=previous['engine_sha256'],backend=previous['backend'],backend_sha256=previous['backend_sha256'],executed_revision=executed))
sources=subprocess.check_output(['git','ls-files','development/ian-cpp-phase1/phase07h','development/ian-cpp-phase1/coordinator/ROADMAP.md'],text=True).splitlines();files={str(p.relative_to(root)):dict(sha256=sha(p),bytes=p.stat().st_size) for p in sorted(root.rglob('*')) if p.is_file()}
write(root/'manifest-v1.json',dict(revision=revision,base=base,files=files,source_files={n:dict(sha256=sha(repo/n),bytes=(repo/n).stat().st_size) for n in sources},note='Four HiGHS dual-simplex diagnostics, six synthetic child controls and a reservation refusal. Complete in-process options/model capture. No engine policy change or trajectories. Handoff outside bundle.'))
print(dict(revision=revision,files=len(files),sources=len(sources),preserved_files=sum(x['files'] for x in records),preserved_sources=sum(x['historical_sources'] for x in records),preserved_manifests=len(records)))
