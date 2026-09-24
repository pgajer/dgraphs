"""Checker falsification and supervisor smoke checks; no optimization calls."""
import copy
import sys
from pathlib import Path
from checks import compare,check_lp,events,load,write
from guard import run

worker=Path(sys.argv[1]); root=Path(sys.argv[2]); root.mkdir(parents=True,exist_ok=False)
old=worker/'phase05/full-v1/helix_120/evaluated/child/trace.jsonl'
data=list(events(old)); solve=next(e for e in data if e['event']=='solve')
checks={}
checks['self_comparison']=compare(old,old,root/'same')['passed']
for label,mutate in [
    ('changed_scale',lambda e:e['scales'].__setitem__(0,e['scales'][0]+1)),
    ('nonfinite_scale',lambda e:e['scales'].__setitem__(0,float('nan'))),
    ('missing_scale',lambda e:e.__delitem__('scales')),
    ('changed_dual',lambda e:e['dual'].__setitem__(0,e['dual'][0]+1))]:
    altered=copy.deepcopy(solve); mutate(altered)
    try:
        result=check_lp(altered); refused=not(result.get('accepted') and result.get('dual_valid'))
    except (KeyError,ValueError): refused=True
    checks[label+'_external_refusal']=refused
    if label!='changed_dual':
        path=root/(label+'.jsonl')
        import json
        path.write_text(''.join(json.dumps(altered if e is solve else e)+'\n' for e in data))
        checks[label+'_comparison_refusal']=not compare(old,path,root/(label+'-comparison'))['passed']
altered=copy.deepcopy(data); next(e for e in altered if e['event']=='decision')['selected']=[]
# Ensure a real decision mutation even if the first decision was originally empty.
target=next(e for e in altered if e['event']=='decision'); target['selected']=[-1]
path=root/'decision.jsonl'; path.write_text(''.join(json.dumps(e)+'\n' for e in altered))
r=compare(old,path,root/'decision-comparison'); checks['branch_stops_pairing']=r['first_discrete_divergence'] is not None
result=run([sys.executable,'-c','import time; time.sleep(30)'],root/'wall-guard',root,remaining_wall=.15)
checks['wall_guard_terminated']=result['reason']=='wall_limit' and result['exit_code']!=0
write(root/'results.json',dict(checks=checks,passed=all(checks.values()),new_solver_calls=0))
assert all(checks.values()),checks
print(checks)
