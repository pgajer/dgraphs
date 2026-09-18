"""Preserve prior evidence and freeze the bounded Phase07E submission."""
import hashlib,importlib.metadata,platform,subprocess,sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from support import *
root=Path(sys.argv[1]);worker=root.parent;repo=Path.cwd();base='d30573a32b64fc184493192d4657ad924a464a0b'
assert not subprocess.check_output(['git','status','--porcelain'],text=True)
assert subprocess.check_output(['git','branch','--show-current'],text=True).strip()=='codex/ian-cpp-feasibility-20260917'
assert not (root/'manifest-v1.json').exists()
revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip();changed=subprocess.check_output(['git','diff','--name-only',base],text=True).splitlines()
assert all(p.startswith('development/ian-cpp-phase1/phase07e/') or p=='development/ian-cpp-phase1/coordinator/ROADMAP.md' for p in changed)
previous=load(worker/'phase07d/preservation-v1.json');paths=[]
for e in previous['preserved']:
 assert sha(e['manifest'])==e['sha256'];paths.append(Path(e['manifest']))
paths.extend([worker/'phase07d/manifest-v1.json',repo.parent/'auditor/review-7d/audit-manifest.json'])
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
assert sha(worker/'phase07d/manifest-v1.json')=='be19f265af3b0ba9504d42ec1cfb6c5d8bf650299b036cf4435ff9b07ecb4a3a'
assert sha(worker/'phase07d-implementer-handoff.md')=='ff8b2eb5d140ae0f02f9d9978b3e0d8d4dc779126ab1dc1d1ac3cf1e11cb3109'
assert sha(worker/'phase06b/build-v3/ian_engine')==previous['engine_sha256'];assert sha(previous['backend'])==previous['backend_sha256']
for group in ['solver_sources','python_modules']:
 for name,digest in load(root/'fixtures-v1/manifest.json')[group].items():assert sha(name)==digest,name
for e in load(root/'engine-fixtures-v1/manifest.json')['cases']:
 assert sha(e['input'])==e['sha256'] and sha(e['source'])==e['source_sha256'];a=load(e['input']);b=load(e['source']);a.pop('numerical_policy');b.pop('numerical_policy');assert a==b
analysis=load(root/'analysis-v2/results.json');assert analysis['complete'] and analysis['full_panel_gate']
assert not analysis['gated'] and analysis['operation_checks']==19
for f in ['checks-v1/results.json','eligibility-v1/results.json','trace-checks-v1/results.json','derivation-v1.json']:assert load(root/f)['passed']
# Independently reconstruct the compiled source/configuration identities.
candidate=HERE/'candidate';names=sorted(str(p.relative_to(candidate)) for d in ['include','src','tests'] for p in (candidate/d).rglob('*') if p.suffix in ['.hpp','.cpp','.inc'])
identity=hashlib.sha256((''.join(sha(candidate/n) for n in names)+sha(candidate/'CMakeLists.txt')).encode()).hexdigest();ledger=load(root/'trajectory-v1/ledger.json')
assert identity==ledger['source_identity'] and sha(candidate/'config.json')==ledger['configuration_identity'] and sha(root/'build-v1/ian_engine')==ledger['engine_sha256']
write(root/'preservation-v1.json',dict(revision=revision,base=base,git_status='',changed_paths=changed,preserved=records,unique_evidence_files_hashed=len(expected),historical_source_versions_hashed=len(source_cache),original_runtime_unchanged=True,engine_sha256=previous['engine_sha256'],backend=previous['backend'],backend_sha256=previous['backend_sha256'],environment=dict(python=sys.version,platform=platform.platform(),machine=platform.machine(),packages={n:importlib.metadata.version(n) for n in ['numpy','scipy','clarabel','cvxpy','psutil']})))
sources=subprocess.check_output(['git','ls-files','development/ian-cpp-phase1/phase07e','development/ian-cpp-phase1/coordinator/ROADMAP.md'],text=True).splitlines();files={str(p.relative_to(root)):dict(sha256=sha(p),bytes=p.stat().st_size) for p in sorted(root.rglob('*')) if p.is_file()}
write(root/'manifest-v1.json',dict(revision=revision,base=base,files=files,source_files={n:dict(sha256=sha(repo/n),bytes=(repo/n).stat().st_size) for n in sources},note='Twelve fixed solves, complete native/Python panel and operational continuation. Experimental policy is not adopted. Handoff outside bundle.'))
print(dict(revision=revision,files=len(files),sources=len(sources),preserved_files=sum(x['files'] for x in records),preserved_sources=sum(x['historical_sources'] for x in records),preserved_manifests=len(records)))
