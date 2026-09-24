"""Preserve prior evidence and freeze the bounded Phase07F submission."""
import hashlib,importlib.metadata,platform,subprocess,sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from support import *
root=Path(sys.argv[1]);worker=root.parent;repo=Path.cwd();base='eac10a31a66da10daedf175093a8b6d2e7202cd1'
assert not subprocess.check_output(['git','status','--porcelain'],text=True)
assert subprocess.check_output(['git','branch','--show-current'],text=True).strip()=='codex/ian-cpp-feasibility-20260917'
assert not (root/'manifest-v1.json').exists()
revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip();changed=subprocess.check_output(['git','diff','--name-only',base],text=True).splitlines()
assert all(p.startswith('development/ian-cpp-phase1/phase07f/') or p=='development/ian-cpp-phase1/coordinator/ROADMAP.md' for p in changed)
previous=load(worker/'phase07e/preservation-v1.json');paths=[]
for e in previous['preserved']:
 assert sha(e['manifest'])==e['sha256'];paths.append(Path(e['manifest']))
paths.extend([worker/'phase07e/manifest-v1.json',repo.parent/'auditor/review-7e/audit-manifest.json'])
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
assert sha(worker/'phase07e/manifest-v1.json')=='d8071dc5489e2e30850681408cc406db5368a6820effd20475bf2d00d20e938c'
assert sha(worker/'phase07e-implementer-handoff.md')=='ed731ae7b012eb5dc250559803214be8165d81ad9a4d6b67948d47ba49f54954'
assert sha(worker/'phase06b/build-v3/ian_engine')==previous['engine_sha256']
assert sha(previous['backend'])==previous['backend_sha256']
old=load(worker/'phase07e/manifest-v1.json')
for name,item in old['source_files'].items():
 if '/phase07e/' in name:assert sha(repo/name)==item['sha256']
for group in ['solver_sources','python_modules']:
 for name,digest in load(worker/'phase07e/fixtures-v1/manifest.json')[group].items():assert sha(name)==digest,name
fixtures=load(root/'fixtures-v1/manifest.json')
for name,digest in fixtures['r_sources'].items():assert sha(repo/name)==digest
for e in fixtures['cases']:
 assert sha(e['input'])==e['sha256']
 if e.get('source'):
  assert sha(e['source'])==e['source_sha256'];a=load(e['input']);b=load(e['source']);a.pop('numerical_policy');assert a==b
analysis=load(root/'analysis-v1/results.json');assert analysis['complete'] and not analysis['panel_gate'] and analysis['total']==dict(attempts=138,accepted=78,rejected=60)
assert len(analysis['gated'])==6 and not analysis['restart']['executed']
assert load(root/'preflight-v2/results.json')['passed']
assert load(root/'terminal-difference.json')['solver_calls']==0
candidate=HERE.parent/'phase07e/candidate'
names=sorted(str(p.relative_to(candidate)) for d in ['include','src','tests'] for p in (candidate/d).rglob('*') if p.suffix in ['.hpp','.cpp','.inc'])
identity=hashlib.sha256((''.join(sha(candidate/n) for n in names)+sha(candidate/'CMakeLists.txt')).encode()).hexdigest();ledger=load(root/'ladder-v1/ledger.json')
assert identity==ledger['runtime']['source_identity'] and sha(candidate/'config.json')==ledger['runtime']['configuration_identity'] and sha(worker/'phase07e/build-v1/ian_engine')==ledger['runtime']['engine_sha256']
write(root/'preservation-v1.json',dict(revision=revision,base=base,git_status='',changed_paths=changed,preserved=records,unique_evidence_files_hashed=len(expected),historical_source_versions_hashed=len(source_cache),original_runtime_unchanged=True,engine_sha256=previous['engine_sha256'],backend=previous['backend'],backend_sha256=previous['backend_sha256'],environment=dict(python=sys.version,platform=platform.platform(),machine=platform.machine(),packages={n:importlib.metadata.version(n) for n in ['numpy','scipy','clarabel','cvxpy','psutil']})))
sources=subprocess.check_output(['git','ls-files','development/ian-cpp-phase1/phase07f','development/ian-cpp-phase1/coordinator/ROADMAP.md'],text=True).splitlines();files={str(p.relative_to(root)):dict(sha256=sha(p),bytes=p.stat().st_size) for p in sorted(root.rglob('*')) if p.is_file()}
write(root/'manifest-v1.json',dict(revision=revision,base=base,files=files,source_files={n:dict(sha256=sha(repo/n),bytes=(repo/n).stat().st_size) for n in sources},note='Two helix-1000 executions; native refusal and Python completion; six inputs gated. Quadform inputs generated but unexecuted. No numerical policy change. Handoff outside bundle.'))
print(dict(revision=revision,files=len(files),sources=len(sources),preserved_files=sum(x['files'] for x in records),preserved_sources=sum(x['historical_sources'] for x in records),preserved_manifests=len(records)))
