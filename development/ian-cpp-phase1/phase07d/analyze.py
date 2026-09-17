"""Reconstruct numerical findings and account for every actual execution."""
import itertools,sys,subprocess,hashlib
from collections import Counter
from fractions import Fraction
from pathlib import Path
import numpy as np
from support import *
sys.path.insert(0,str(HERE));from validate import retry_checks
root=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=False)
manifest=load(root/'fixtures-v1/manifest.json');diag=load(root/'diagnostic-v1/ledger.json');first=load(root/'trajectory-v1/ledger.json');primary=load(root/'trajectory-v2/ledger.json');ops=load(root/'operational-v1/checks.json')
assert diag['complete'] and diag['qualified']==['units11'] and len(diag['runs'])==25
assert primary['complete'] and first['complete'] and not primary['validation_gate'] and len(primary['gated'])==24
assert primary['comparisons']['helix_500']['passed'] and first['comparisons']['helix_500']['passed']
assert ops['complete'] and ops['passed'] and len(ops['tests'])==19 and not ops['uninterrupted_complete']
fixed=[];witnesses=[]
def witness(name,e):
 u=list(map(Fraction,e['upper']));worst=Fraction(0);at=None
 for i,bi in enumerate(e['b']):
  value=sum((Fraction(e['A_data'][k])*u[e['A_indices'][k]] for k in range(e['A_indptr'][i],e['A_indptr'][i+1])),Fraction(0))-Fraction(bi)
  if value>worst:worst=value;at=i
 good=worst<=0 and all(v>0 for v,a in zip(u,e['active']) if a)
 assert good,(name,str(worst));return dict(name=name,exact_upper_witness_feasible=True,max_positive_violation=str(worst))
for name,item in manifest['cases'].items():
 e=load(item['path']);assert sha(item['path'])==item['sha256'] and sha(item['source'])==item['source_sha256'];witnesses.append(witness(name,e))
 for condition in CONDITIONS:
  child=Path(diag['runs'][name+'/'+condition]['child']);problem=load(child/'problem.json');raw=load(child/'raw.json');r=load(child/'result.json');A=matrix(e);alpha=problem['alpha']
  assert all(problem[k]==e[k] for k in ['A_data','A_indices','A_indptr','A_shape','c'])
  assert alpha==(max(e['upper']) if condition=='units11' else 1.) and problem['b']==[v/alpha for v in e['b']]
  x=np.array(raw['x'])*alpha;z=np.array(raw['z']);s=np.array(raw['s']);objective=raw['objective']*alpha
  c=scalar_check(e,x,z,objective,raw['status']);assert c['accepted']==r['external']['accepted']
  assert x.tolist()==r['x'] and z.tolist()==r['z'] and objective==r['objective'] and (s*alpha).tolist()==r['slack']
  reconstructed=r['reconstructed'];assert reconstructed['dual_discrepancy']<=1e-14 and reconstructed['primal_discrepancy']<=1e-14
  assert r['history'] and all(np.isfinite(e[k]) for e in r['history'] for k in ['res_primal','res_dual','gap_abs','gap_rel'])
  if r['saved_exact'] is not None:assert all(r['saved_exact'].values())
  fixed.append(dict(case=name,condition=condition,accepted=c['accepted'],status=raw['status'],iterations=raw['iterations'],alpha=alpha,external=c,reconstruction=reconstructed,history_length=len(r['history'])))
# Check both observed versions. Only the newly added raw status and timing may differ.
trajectory=[]
for condition in ['native','evaluated']:
 old=Path(first['runs']['helix_500/'+condition]['child']);new=Path(primary['runs']['helix_500/'+condition]['child']);count=0
 for x,y in itertools.zip_longest(events(old/'trace.jsonl'),events(new/'trace.jsonl')):
  assert x is not None and y is not None
  assert {k:v for k,v in x.items() if k!='seconds'}=={k:v for k,v in y.items() if k not in ['seconds','solver_status']}
  count+=1
 c=retry_checks(new,out/(condition+'-certificates'),True);assert c['attempts']==30 and c['accepted']==16 and len(c['retries'])==13 and all(x['accepted'] for x in c['retries'])
 data=list(events(new/'trace.jsonl'));solves=[e for e in data if e['event']=='solve'];last=solves[-1]
 assert last['solver_status']=='AlmostSolved' and not last['retry_eligible'] and last['number']==29 and last['iteration']==2
 status=load(new/'status.json');assert 'invalid_solver_result' in status['error'] and not any(status[k] for k in ['graph','scales','affinity','complete'])
 assert sum(e['event']=='pruned' for e in data)==2
 write(out/(condition+'-terminal-problem.json'),last)
 assert primary['runs']['helix_500/'+condition]['same_path']['passed']
 trajectory.append(dict(condition=condition,events=count,checks=c,terminal_status=last['solver_status'],terminal_number=29,logical_problems=sum(e['attempt']==0 for e in solves),pruned=2,terminal_stationarity=scalar_check(last,last['scales'],last['dual'],last['objective'],'AlmostSolved')['dual_stationarity'],first_source_fields_exact=True))
 if condition=='native':witnesses.append(witness('terminal_post_prune_problem',last))
# Physical attempts, not diagnostic reads or concatenated/copied traces.
processes=diag['processes']+first['processes']+primary['processes']+ops['processes'];census=[];totals=Counter()
for p in processes:
 if not p['observed_solves']:continue
 child=next(Path(a) for a in p['command'] if str(a).endswith('/child'));counts=Counter()
 for e in events(child/'trace.jsonl'):
  if e['event']=='solve':counts['attempts']+=1;counts['accepted' if e['accepted'] else 'rejected']+=1
 assert counts['attempts']==p['observed_solves'];totals.update(counts);census.append(dict(child=str(child),**counts))
assert totals['attempts']==180 and sum(p['observed_solves'] for p in processes)==180
operation_checks=[]
for p in ops['processes']:
 if not p['observed_solves']:continue
 child=next(Path(a) for a in p['command'] if str(a).endswith('/child'))
 operation_checks.append(dict(child=str(child),checks=retry_checks(child,out/('op-'+child.parent.name),True)))
assert all(p['reason'] is None for p in processes) and sum(p['wall_seconds'] for p in processes)<3600
warning_logs=[]
for p in root.rglob('stderr.log'):
 if 'Warning' in p.read_text():warning_logs.append(str(p))
write(out/'results.json',dict(complete=True,fixed=fixed,witnesses=witnesses,trajectories=trajectory,operations=operation_checks,operation_checks=len(ops['tests']),fixed_accepted=sum(r['accepted'] for r in fixed),census=census,total=dict(totals),guarded_wall_seconds=sum(p['wall_seconds'] for p in processes),peak_sampled_rss_bytes=max(p['sampled_tree_peak_rss_bytes'] for p in processes),gated=primary['gated'],warning_logs=warning_logs,source_revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()))
print(dict(complete=True,total=dict(totals),fixed_accepted=sum(r['accepted'] for r in fixed),operational_checks=len(ops['tests']),gated=len(primary['gated'])))
