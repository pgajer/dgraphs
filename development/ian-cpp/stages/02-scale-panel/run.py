"""Serial fixed-problem, decision-boundary and full-trajectory qualification."""
import sys,json,subprocess,shutil,importlib.util,itertools,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent.parent/'01-numerical-policy'))
from guard import run,reserve,write,tree_bytes
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
W=Path('/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker')
E=ROOT/'development/ian-cpp-phase1/phase07e'
sys.path.insert(0,str(E));import validate as v
v.POLICY='IAN evaluated-LP retry-power 0.1'
load=lambda p:json.loads(Path(p).read_text())
fixtures=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=False)
manifest=load(fixtures/'manifest.json');schedule=manifest['fixtures'];build=Path(manifest['build']);reference=Path(manifest['reference'])
import hashlib
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
assert sha(build/'engine')==manifest['engine_sha256']
assert all(sha(reference/k)==h for k,h in manifest['reference_sha256'].items())
assert all(sha(c['path'])==c['sha256'] for c in schedule)
ledger=dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),fixture_manifest=str(fixtures/'manifest.json'),fixture_manifest_sha256=sha(fixtures/'manifest.json'),build=str(build),engine_schedule=schedule,processes=[],comparisons={},complete=False,gate=True,reference=str(reference))
write(out/'ledger.json',ledger)
def execute(cmd,folder):
 census=ledger['processes'];used=sum(p['optimizer_calls'] for p in census);wall=sum(p['wall_seconds'] for p in census)
 assert len(census)<12 and used<10000 and wall<3600 and shutil.disk_usage(out).free>20*2**30
 reserve(out/'reservations.json',12,dict(command=list(map(str,cmd))))
 r=run(cmd,folder,out.parent,wall_limit=min(900,3600-wall),max_attempts=min(1000,10000-used))
 ledger['processes'].append(r);write(out/'ledger.json',ledger)
 assert r['state']=='reaped' and r['reason'] is None,r
 return r
try:
 for case in schedule:
  name=case['name'];kind=case['kind'];probe=kind in ['probe','stage'];paths={}
  for interface in ['native','evaluated']:
   folder=out/'runs'/name/interface;child=folder/'child';paths[interface]=child
   cmd=[build/('probe' if probe else 'engine'),case['path'],child]+([] if probe else ['--interval','100']) if interface=='native' else [sys.executable,'-B',reference/('reference_probe.py' if probe else 'reference.py'),case['path'],child,'evaluated']
   r=execute(cmd,folder)
   complete=(child/'stages.json').exists() if kind=='stage' else load(child/'status.json')['complete']
   print(name,interface,'complete' if complete else 'REFUSED',r['optimizer_calls'],flush=True)
   if kind!='stage':
    if not probe:
     check=v.inspect(child,case['path'],folder/'inspect');assert check['valid']
    checks=v.retry_checks(child,folder/'certificates',allow_terminal_rejection=not complete)
    if interface=='native':
     for e in v.events(child/'trace.jsonl'):
      if e['event']=='solve':
       s=e['settings'];assert len(s)==41 and s['settings_layout_verified'] and not s['input_sparse_dropzeros'] and s['tol_feas']==e['solver_tolerance'] and s['max_threads']==1
   if not complete or r['exit_code']!=0:ledger['gate']=False
  if kind=='stage':passed=all((p/'stages.json').exists() for p in paths.values()) and load(paths['native']/'stages.json')==load(paths['evaluated']/'stages.json');check=dict(passed=passed)
  else:
   check=v.compare(paths['native']/'trace.jsonl',paths['evaluated']/'trace.jsonl',out/'runs'/name/'comparison')
   # Compare retry identity and recovered duals as well as historical field checks.
   metadata=True;duals=True;exact_coefficients=True
   for a,b in itertools.zip_longest(v.events(paths['native']/'trace.jsonl'),v.events(paths['evaluated']/'trace.jsonl')):
    if a is None or b is None:metadata=False;break
    metadata &= all(a.get(k)==b.get(k) for k in v.ADDED)
    if a['event']=='solve' and b['event']=='solve':
     duals &= len(a['dual'])==len(b['dual']) and all(abs(x-y)<=1e-7+1e-7*max(abs(x),abs(y)) for x,y in zip(a['dual'],b['dual']))
     exact_coefficients &= all(a[k]==b[k] for k in ['A_data','A_indices','A_indptr','A_shape','b','c','upper'])
   check.update(retry_metadata_equal=metadata,dual_vectors_pass=duals,exact_coefficients=exact_coefficients);check['passed'] &= metadata and duals and exact_coefficients
  ledger['comparisons'][name]=check;ledger['gate'] &= check['passed'];write(out/'ledger.json',ledger)
  if not ledger['gate']:raise RuntimeError('qualification_gate_closed:'+name)
 ledger['complete']=True;write(out/'ledger.json',ledger)
except Exception as e:
 ledger['error']=repr(e);ledger['gate']=False;write(out/'ledger.json',ledger);raise
print('Frozen paired schedule passed.',flush=True)
