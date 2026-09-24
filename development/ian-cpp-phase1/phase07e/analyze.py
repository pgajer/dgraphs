"""Independent original-unit certificate reconstruction and physical solve census."""
import itertools,sys,subprocess
from collections import Counter
from pathlib import Path
import numpy as np
from support import *
sys.path.insert(0,str(HERE));from validate import retry_checks
root=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=False)
manifest=load(root/'fixtures-v1/manifest.json');diag=load(root/'diagnostic-v1/ledger.json');primary=load(root/'trajectory-v1/ledger.json');ops=load(root/'operational-v1/checks.json')
assert diag['complete'] and diag['regression_passed'] and len(diag['runs'])==12
assert primary['complete'] and ops['complete'] and ops['passed']
fixed=[]
for name,item in manifest['cases'].items():
 e=load(item['path']);assert sha(item['path'])==item['sha256'] and sha(item['source'])==item['source_sha256']
 for condition in ['ordinary','units11']:
  child=Path(diag['runs'][name+'/'+condition]['child']);problem=load(child/'problem.json');raw=load(child/'raw.json');r=load(child/'result.json');alpha=problem['alpha']
  assert all(problem[k]==e[k] for k in ['A_data','A_indices','A_indptr','A_shape','c'])
  assert alpha==(max(e['upper']) if condition=='units11' else 1.) and problem['b']==[v/alpha for v in e['b']]
  x=np.array(raw['x'])*alpha;z=np.array(raw['z']);objective=raw['objective']*alpha
  c=scalar_check(e,x,z,objective,raw['status']);assert c['accepted']==r['external']['accepted']==item['expected'][condition]
  assert x.tolist()==r['x'] and z.tolist()==r['z'] and objective==r['objective'] and (np.array(raw['s'])*alpha).tolist()==r['slack']
  assert r['history'] and r['reconstructed']['dual_discrepancy']<=1e-14 and r['reconstructed']['primal_discrepancy']<=1e-14
  if r['saved_exact'] is not None:assert all(r['saved_exact'].values())
  fixed.append(dict(case=name,condition=condition,accepted=c['accepted'],status=raw['status'],iterations=raw['iterations'],alpha=alpha,external=c,saved_exact=r['saved_exact']))
probe=manifest['reused_auditor_probe'];assert sha(probe['path'])==probe['sha256']
# Whole trajectories: check every optimization payload again, including rejection.
trajectories=[];stage_results={}
for name,item in primary['runs'].items():
 child=Path(item['child']);trace=child/'trace.jsonl'
 if name.startswith('stage-probes/'):
  assert item['complete'] and item['same_path']['passed']
  stage_results[name]=load(child/'stages.json');continue
 if not trace.exists():raise AssertionError('missing_trace:'+name)
 c=retry_checks(child,out/('certificates-'+name.replace('/','-')),not item['complete'])
 counts=Counter();statuses=Counter();almost=[];logical=0;last=None
 for e in events(trace):
  counts[e['event']]+=1
  if e['event']=='solve':
   statuses[e['solver_status']]+=1;logical+=e['attempt']==0;last=e
   if e['solver_status']=='AlmostSolved':almost.append(dict(number=e['number'],iteration=e['iteration'],accepted=e['accepted'],attempt=e['attempt']))
 status=load(child/'status.json') if (child/'status.json').exists() else None
 if not item['complete'] and last is not None:write(out/(name.replace('/','-')+'-terminal-problem.json'),last)
 trajectories.append(dict(name=name,complete=item['complete'],checks=c,event_counts=dict(counts),statuses=dict(statuses),almost=almost,logical_problems=logical,same_path=item['same_path'],status=status,inspection=item.get('checks')))
 assert item['same_path']['passed'],name
 assert item['checks']['valid'],name
assert all(c['passed'] for c in primary['comparisons'].values())
if primary['validation_gate']:assert len(primary['runs'])==50 and len(primary['comparisons'])==25 and not primary['gated'] and all(x['complete'] for x in primary['runs'].values())
processes=diag['processes']+primary['processes']+ops['processes'];census=[];totals=Counter()
for p in processes:
 if not p['observed_solves']:continue
 child=next(Path(a) for a in p['command'] if str(a).endswith('/child'));counts=Counter()
 for e in events(child/'trace.jsonl'):
  if e['event']=='solve':counts['attempts']+=1;counts['accepted' if e['accepted'] else 'rejected']+=1
 assert counts['attempts']==p['observed_solves'];totals.update(counts);census.append(dict(child=str(child),**counts))
assert totals['attempts']==sum(p['observed_solves'] for p in processes)<8000
operations=[]
for p in ops['processes']:
 if not p['observed_solves']:continue
 child=next(Path(a) for a in p['command'] if str(a).endswith('/child'))
 operations.append(dict(child=str(child),checks=retry_checks(child,out/('op-'+child.parent.name),True)))
assert all(p['reason'] is None for p in processes) and sum(p['wall_seconds'] for p in processes)<3600
controls={n:load(root/n) for n in ['checks-v1/results.json','eligibility-v1/results.json','trace-checks-v1/results.json','derivation-v1.json']}
assert all(c['passed'] for c in controls.values())
warning_logs=[str(p) for p in root.rglob('stderr.log') if 'Warning' in p.read_text()]
write(out/'results.json',dict(complete=True,full_panel_gate=primary['validation_gate'],fixed=fixed,stages=stage_results,trajectories=trajectories,operations=operations,operation_checks=len(ops['tests']),fixed_accepted=sum(r['accepted'] for r in fixed),census=census,total=dict(totals),guarded_wall_seconds=sum(p['wall_seconds'] for p in processes),peak_sampled_rss_bytes=max(p['sampled_tree_peak_rss_bytes'] for p in processes),gated=primary['gated'],warning_logs=warning_logs,source_revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()))
print(dict(complete=True,total=dict(totals),full_panel_gate=primary['validation_gate'],operation_checks=len(ops['tests']),gated=len(primary['gated'])))
