"""Read-only reconciliation and saved-problem diagnosis; no new optimization."""
import itertools,math,subprocess,sys
from collections import Counter
from fractions import Fraction
from pathlib import Path
import numpy as np
from support import *
root=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=False)
l=load(root/'ladder-v1/ledger.json');assert l['complete'];manifest=load(root/'fixtures-v1/manifest.json')
census=[];total=Counter();runs=[];fixed=[]
for name,item in l['runs'].items():
 child=Path(item['child']);counts=Counter();status=Counter();last=None;maxima={};accepted_count=0;retries=0;logical=0
 with (out/(name.replace('/','-')+'-certificates.jsonl')).open('w') as f:
  for e in events(child/'trace.jsonl'):
   counts[e['event']]+=1
   if e['event']!='solve':continue
   check=scalar_check(e,e['scales'],e['dual'],e['objective'],e['solver_status'])
   assert check['accepted']==e['accepted'],(name,e['number'])
   f.write(__import__('json').dumps(dict(number=e['number'],status=e['solver_status'],accepted=e['accepted'],**{k:v.tolist() if hasattr(v,'tolist') else v for k,v in check.items() if k!='accepted'}))+'\n')
   total['attempts']+=1;total['accepted' if e['accepted'] else 'rejected']+=1;status[e['solver_status']]+=1;retries+=e['attempt']==1;logical+=e['attempt']==0;accepted_count+=e['accepted'];last=e
   if e['accepted']:
    for k in ['normalized_primal','objective_error','dual_stationarity','dual_negative','dual_relative_gap']:maxima[k]=max(maxima.get(k,0),check[k])
 assert counts['solve']==item['process']['observed_solves']
 if not item['complete'] and last and not last['accepted']:
  p=out/(name.replace('/','-')+'-terminal-problem.json');write(p,last);fixed.append(dict(name=name,path=str(p),sha256=sha(p),source=str(child/'trace.jsonl'),source_sha256=sha(child/'trace.jsonl'),number=last['number'],fresh_remedy_executions=0))
 runs.append(dict(name=name,complete=item['complete'],status=item['status'],events=dict(counts),attempts=counts['solve'],logical_problems=logical,accepted=accepted_count,rejected=counts['solve']-accepted_count,retries=retries,status_counts=dict(status),accepted_maxima=maxima,minimum_relative_limit_margin=1-max(maxima.values())/1e-7 if maxima else None,checks=item.get('checks'),process=item['process']))
# Reconcile all physical child invocations, excluding diagnostic copies.
for p in l['processes']:
 if not p['observed_solves']:continue
 child=next(Path(a) for a in p['command'] if str(a).endswith('/child'));counts=Counter()
 for e in events(child/'trace.jsonl'):
  if e['event']=='solve':counts['attempts']+=1;counts['accepted' if e['accepted'] else 'rejected']+=1
 assert counts['attempts']==p['observed_solves'];census.append(dict(child=str(child),**counts))
assert sum(p['observed_solves'] for p in l['processes'])==total['attempts'] # This submission has no restart execution.
# Numerical mismatch diagnosis at paired events, without changing or solving LPs.
paired=[];identical_prefix=0;first_accepted_difference=None;terminal=None
if all('helix_1000/'+s in l['runs'] for s in ['native','evaluated']):
 a=Path(l['runs']['helix_1000/native']['child'])/'trace.jsonl';b=Path(l['runs']['helix_1000/evaluated']['child'])/'trace.jsonl'
 for index,(x,y) in enumerate(zip(events(a),events(b))):
  if x['event']!='solve' or y['event']!='solve':continue
  assert x['number']==y['number']
  row=dict(event=index,number=x['number'],native_status=x['solver_status'],python_status=y['solver_status'],native_accepted=x['accepted'],python_accepted=y['accepted'],attempt=x['attempt'],same_problem_structure=all(x[k]==y[k] for k in ['A_indices','A_indptr','A_shape','upper','active','c','C']))
  for key in ['A_data','b','scales','dual']+(['backend_rhs','backend_primal'] if x['attempt'] else []):
   u=np.asarray(x[key]);v=np.asarray(y[key]);assert u.shape==v.shape
   row[key]=dict(exact=bool(np.array_equal(u,v)),different_values=int(np.count_nonzero(u!=v)),max_absolute=float(np.max(abs(u-v))))
  paired.append(row)
  if x['accepted'] and y['accepted'] and first_accepted_difference is None and not np.all(abs(np.array(x['scales'])-np.array(y['scales']))<=1e-7+1e-7*np.maximum(abs(np.array(x['scales'])),abs(np.array(y['scales'])))):first_accepted_difference=x['number']
  if x['number']==25:
   write(out/'matched-python-terminal-problem.json',y)
   terminal=dict(number=x['number'],iteration=x['iteration'],C=x['C'],native=scalar_check(x,x['scales'],x['dual'],x['objective'],x['solver_status']),python=scalar_check(y,y['scales'],y['dual'],y['objective'],y['solver_status']),native_status=x['solver_status'],python_status=y['solver_status'],native_iterations=x['iterations'],python_iterations=y['iterations'],native_alpha=x['solver_units'],python_alpha=y['solver_units'])
   # Separately labeled arithmetic check only: does not relabel the actual return.
   terminal['native_numeric_checks_without_status']=scalar_check(x,x['scales'],x['dual'],x['objective'],'Solved')['accepted']
   for side,e in [('native',x),('python',y)]:
    u=list(map(Fraction,e['upper']));worst=Fraction(0)
    for i,rhs in enumerate(e['b']):
     residual=sum((Fraction(e['A_data'][k])*u[e['A_indices'][k]] for k in range(e['A_indptr'][i],e['A_indptr'][i+1])),Fraction(0))-Fraction(rhs)
     worst=max(worst,residual)
    terminal[side+'_exact_upper_feasible']=worst<=0
# This analysis records the observed negative result and exposes later new outcomes.
assert len(runs)==2 and total['attempts']==138 and total['accepted']==78 and total['rejected']==60
assert not l['panel_gate'] and len(l['gated'])==6 and not l['restart']['executed']
assert terminal and terminal['native_numeric_checks_without_status'] and not terminal['native']['accepted'] and terminal['python']['accepted']
write(out/'fixed-collection-extension.json',dict(previous=str(root.parent/'phase07e/fixtures-v1/manifest.json'),previous_sha256=sha(root.parent/'phase07e/fixtures-v1/manifest.json'),new_failures=fixed,matched_python=str(out/'matched-python-terminal-problem.json'),solver_calls=0))
write(out/'results.json',dict(complete=True,panel_gate=l['panel_gate'],runs=runs,total=dict(total),census=census,paired_solve_diagnostics=paired,first_accepted_scale_limit_failure=first_accepted_difference,terminal=terminal,gated=l['gated'],restart=l['restart'],guarded_wall_seconds=sum(p['wall_seconds'] for p in l['processes']),peak_sampled_rss_bytes=max(p['sampled_tree_peak_rss_bytes'] for p in l['processes']),resource_limits_hit=[p['reason'] for p in l['processes'] if p['reason']],processes=len(l['processes']),revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),additional_solver_calls=0))
print(dict(total=dict(total),panel_gate=False,gated=len(l['gated']),terminal=terminal,additional_solver_calls=0))
