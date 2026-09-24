"""Independent certificate, retry sequencing and frozen trace validation."""
import itertools,math,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent.parent/'phase07c'))
from checks import load,write,sha,events,compare,inspect
sys.path.insert(0,str(Path(__file__).resolve().parent.parent/'phase07b'))
from common import scalar_check
POLICY='IAN evaluated-LP retry units11 almost 0.1'
ADDED={'attempt','logical_solve','numerical_policy','solver_tolerance','retry_eligible','solver_status'}
COEFFICIENTS=['A_data','A_indices','A_indptr','A_shape','b','c','upper','active','C','site','phase','iteration']
def check_units(e):
 if e['attempt']==0:
  assert 'solver_units' not in e,'unexpected_first_attempt_scaling'
  return
 alpha=float(max(e['upper']));assert math.isfinite(alpha) and alpha>0 and e['solver_units']==alpha
 assert e['backend_rhs']==[float(b)/alpha for b in e['b']],'wrong_transformed_rhs'
 original=e.get('before_test_fault',e)
 assert original['scales']==[alpha*float(v) for v in e['backend_primal']],'wrong_primal_recovery'
 assert e['dual']==e['backend_dual'],'wrong_dual_recovery'
 assert original['objective']==alpha*e['backend_objective'],'wrong_objective_recovery'
 assert len(e['backend_slack'])==len(e['b']) and all(math.isfinite(v) for v in e['backend_slack'])
def stripped(e):return {k:v for k,v in e.items() if k not in ADDED|{'seconds'}}
def exact(left,right,prefix=False):
 count=0
 pairs=zip(events(left),events(right)) if prefix else itertools.zip_longest(events(left),events(right))
 for x,y in pairs:
  if x is None or y is None or stripped(x)!=stripped(y):return dict(passed=False,event=count)
  count+=1
 if prefix:
  expected=sum(1 for _ in events(left))
  if count!=expected:return dict(passed=False,event=count)
 return dict(passed=True,events=count,prefix=prefix)
def retry_checks(child,out,allow_terminal_rejection=False):
 pending=None;count=0;accepted=0;rejected=[];retry=[];ok=True;maxima={};first_number=None
 out=Path(out);out.mkdir(parents=True,exist_ok=False)
 with (out/'certificates.jsonl').open('w') as stream:
  for index,e in enumerate(events(Path(child)/'trace.jsonl')):
   if e['event']!='solve':
    if pending is not None:ok=False
    continue
   check_units(e)
   c=scalar_check(e,e['scales'],e['dual'],e['objective'],'Solved' if e['status']=='optimal' else e['status'])
   usable=c['finite'] and e['solver_status'] in ['Solved','AlmostSolved'] and all(v>0 for v,a in zip(e['scales'],e['active']) if a) and c['objective_error']<=1e-7
   eligible=bool(usable and not c['accepted'] and all(math.isfinite(c[k]) for k in ['normalized_primal','absolute_primal','dual_stationarity','dual_negative','dual_relative_gap']))
   assert bool(e['accepted'])==c['accepted'],(index,'certificate_acceptance')
   assert e['retry_eligible']==eligible,(index,'eligibility')
   assert e['numerical_policy']==POLICY
   assert (e['solver_status']=='Solved') == (e['status']=='optimal')
   if first_number is None:first_number=e['number']
   assert e['number']==first_number+count
   if pending is None:
    assert e['attempt']==0 and e['logical_solve']==e['number'] and e['solver_tolerance']==1e-9
   else:
    assert e['attempt']==1 and e['logical_solve']==pending['number'] and e['solver_tolerance']==1e-11
    assert pending['attempt']==0 and pending['retry_eligible']
    assert all(e[k]==pending[k] for k in COEFFICIENTS),'retry_changed_problem'
    retry.append(dict(number=e['number'],logical_solve=e['logical_solve'],iteration=e['iteration'],phase=e['phase'],accepted=e['accepted']))
   stream.write(__import__('json').dumps(dict(event=index,number=e['number'],attempt=e['attempt'],**{k:v.tolist() if hasattr(v,'tolist') else v for k,v in c.items()}))+'\n')
   count+=1;accepted+=int(c['accepted'])
   if not c['accepted']:rejected.append(dict(number=e['number'],attempt=e['attempt'],iteration=e['iteration'],phase=e['phase'],normalized_primal=c['normalized_primal'],dual_gap=c['dual_relative_gap']))
   for k in ['normalized_primal','objective_error','dual_stationarity','dual_negative','dual_relative_gap']:
    if c['accepted']:maxima[k]=max(maxima.get(k,0),c[k])
   pending=None if c['accepted'] else e
 assert ok,'outer_event_after_rejection'
 assert pending is None or allow_terminal_rejection,'unaccounted_terminal_rejection'
 result=dict(valid=True,attempts=count,accepted=accepted,rejected=rejected,retries=retry,accepted_maxima=maxima,terminal_rejection=pending is not None)
 write(out/'summary.json',result);return result
if __name__=='__main__':
 import json
 mode=sys.argv[1]
 if mode=='inspect':
  child,fixture,out=sys.argv[2:5];r=inspect(child,fixture,out)
  r['retry_checks']=retry_checks(child,Path(out)/'retry',allow_terminal_rejection=not r['complete'])
  write(Path(out)/'summary.json',r);print(json.dumps(dict(valid=r['valid'],complete=r['complete'],attempts=r['retry_checks']['attempts'])))
 elif mode=='probe':
  print(retry_checks(sys.argv[2],sys.argv[3]))
 elif mode=='compare':
  r=compare(sys.argv[2],sys.argv[3],sys.argv[4]);extra=True
  for x,y in itertools.zip_longest(events(sys.argv[2]),events(sys.argv[3])):
   if x is None or y is None:extra=False;break
   extra &= all(x.get(k)==y.get(k) for k in ADDED)
  r['retry_metadata_equal']=extra;r['passed'] &= extra;write(Path(sys.argv[4])/'summary.json',r);print(r['passed'])
 elif mode=='prefix07d':
  count=0;changed=[]
  for x,y in zip(events(sys.argv[2]),events(sys.argv[3])):
   omitted={'seconds','numerical_policy'}
   if x['event']=='solve' and x['solver_status']=='AlmostSolved':
    assert not x['accepted'] and not y['accepted'] and not x['retry_eligible'] and y['retry_eligible']
    omitted.add('retry_eligible');changed.append(x['number'])
   assert {k:v for k,v in x.items() if k not in omitted}=={k:v for k,v in y.items() if k not in omitted},count
   count+=1
  assert count==sum(1 for _ in events(sys.argv[2])) and changed==[29]
  write(sys.argv[4],dict(passed=True,events=count,changed_eligibility=changed))
 elif mode=='exact':
  r=exact(sys.argv[2],sys.argv[3],len(sys.argv)>5);write(sys.argv[4],r);print(r)
