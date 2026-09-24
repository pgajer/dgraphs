"""Hash preserved historical evidence, unchanged runtime and the new submission."""
import hashlib,subprocess
from concurrent.futures import ThreadPoolExecutor
from support import *
root=Path(sys.argv[1]).resolve();worker=root.parent;repo=Path.cwd();base='ec65a871e5f06c5a6e6c6ecccd947d4b0970ff7f'
assert not subprocess.check_output(['git','status','--porcelain'],text=True)
assert subprocess.check_output(['git','branch','--show-current'],text=True).strip()=='codex/ian-cpp-feasibility-20260917'
assert not (root/'manifest-v1.json').exists()
revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip();changed=subprocess.check_output(['git','diff','--name-only',base],text=True).splitlines()
assert all(p.startswith('development/ian-cpp-phase1/phase07g/') or p=='development/ian-cpp-phase1/coordinator/ROADMAP.md' for p in changed)
previous=load(worker/'phase07f/preservation-v1.json');paths=[]
for e in previous['preserved']:
    assert sha(e['manifest'])==e['sha256'];paths.append(Path(e['manifest']))
paths.extend([worker/'phase07f/manifest-v1.json',repo.parent/'auditor/review-7f/audit-manifest.json'])
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
assert sha(worker/'phase07f/manifest-v1.json')=='9b2dab01e53db482dfb6fa6f4819ed0b807f37e69c5dab1cf6cd26d8e7bcaabf'
assert sha(worker/'phase07f-implementer-handoff.md')=='a901c8c512b043495a3abf2b3a8e992427639c841e51c66da55d0613b661b25a'
assert sha(worker/'phase06b/build-v3/ian_engine')==previous['engine_sha256']
assert sha(previous['backend'])==previous['backend_sha256']
for phase in ['phase07e','phase07f']:
    for name,item in load(worker/phase/'manifest-v1.json')['source_files'].items():
        if '/'+phase+'/' in name:assert sha(repo/name)==item['sha256']
for group in ['solver_sources','python_modules']:
    for name,digest in load(worker/'phase07e/fixtures-v1/manifest.json')[group].items():assert sha(name)==digest,name
for group in ['files','python_modules']:
    for name,digest in load(root/'environment.json')[group].items():assert sha(name)==digest,name
for name,digest in load(root/'fixtures/manifest.json').items():assert sha(root/'fixtures'/name)==digest
supplement=load(root/'settings-supplement-v2/record.json')
for name,digest in supplement['build_receipts'].items():assert sha(name)==digest
assert sha(root/'build/ian_fixed_replay')==supplement['replay_executable_sha256']
result=load(root/'results-v2.json');assert result['complete'] and result['solver_calls']==8 and result['own_baseline_gate'] and all(result['repeat_exact'].values())
assert not result['resource_limits_hit'] and not result['policy_changed'] and not result['scale_gate']
assert load(root/'preflight.json')['passed'];assert supplement['solver_calls']==0 and supplement['all_match_python']
# Executed replay/analysis/fixture code is unchanged since the eight solves.
executed='446ff96'
for name in ['replay.cpp','settings.inc','python_replay.py','support.py','prepare.py','execute.py','analyze.py','CMakeLists.txt']:
    path=str(HERE.relative_to(repo)/name);assert hashlib.sha256(subprocess.check_output(['git','show',executed+':'+path])).hexdigest()==sha(repo/path)
write(root/'preservation-v1.json',dict(revision=revision,base=base,git_status='',changed_paths=changed,preserved=records,unique_evidence_files_hashed=len(expected),historical_source_versions_hashed=len(source_cache),original_runtime_unchanged=True,engine_sha256=previous['engine_sha256'],backend=previous['backend'],backend_sha256=previous['backend_sha256'],executed_revision=executed))
sources=subprocess.check_output(['git','ls-files','development/ian-cpp-phase1/phase07g','development/ian-cpp-phase1/coordinator/ROADMAP.md'],text=True).splitlines();files={str(p.relative_to(root)):dict(sha256=sha(p),bytes=p.stat().st_size) for p in sorted(root.rglob('*')) if p.is_file()}
write(root/'manifest-v1.json',dict(revision=revision,base=base,files=files,source_files={n:dict(sha256=sha(repo/n),bytes=(repo/n).stat().st_size) for n in sources},note='Eight fixed-problem solves; no engine trajectories or policy changes. Original settings capture incomplete; separately reconstructed without solving. Handoff outside bundle.'))
print(dict(revision=revision,files=len(files),sources=len(sources),preserved_files=sum(x['files'] for x in records),preserved_sources=sum(x['historical_sources'] for x in records),preserved_manifests=len(records)))
