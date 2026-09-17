"""No-solve falsification controls for the retry trace verifier."""
import copy,sys,json
from pathlib import Path
from checks import events,write
from validate import retry_checks
root=Path(sys.argv[1]);source=Path(sys.argv[2]);root.mkdir(parents=True,exist_ok=False)
original=list(events(source));first=next(i for i,e in enumerate(original) if e['event']=='solve');retry=next(i for i,e in enumerate(original) if e['event']=='solve' and e['attempt']==1)
controls=[]
def check(name,edit):
 data=copy.deepcopy(original);edit(data);folder=root/name;folder.mkdir();(folder/'trace.jsonl').write_text(''.join(json.dumps(e)+'\n' for e in data))
 refused=False;error=None
 try:retry_checks(folder,folder/'checks',True)
 except (AssertionError,ValueError,TypeError,IndexError,KeyError) as exc:refused=True;error=repr(exc)
 controls.append(dict(name=name,refused=refused,error=error));assert refused,name
check('missing-rejected-attempt',lambda d:d.pop(retry-1))
check('missing-retry',lambda d:d.pop(retry))
check('wrong-retry-tolerance',lambda d:d[retry].update(solver_tolerance=1e-9))
check('wrong-logical-problem',lambda d:d[retry].update(logical_solve=0))
check('wrong-policy',lambda d:d[retry].update(numerical_policy='IAN evaluated-LP 1.0'))
check('false-acceptance',lambda d:d[retry-1].update(accepted=True))
check('changed-problem',lambda d:d[retry]['b'].__setitem__(0,d[retry]['b'][0]+1e-12))
check('false-eligibility',lambda d:d[retry-1].update(retry_eligible=False))
check('zero-primal',lambda d:d[first].update(scales=[0.]*len(d[first]['scales'])))
check('zero-dual',lambda d:d[first].update(dual=[0.]*len(d[first]['dual'])))
check('outer-event-before-acceptance',lambda d:d.insert(retry,dict(event='retune_eval')))
def third(d):
 e=copy.deepcopy(d[-1]);assert e['event']=='solve';e.update(number=e['number']+1,attempt=2);d.append(e)
check('third-attempt',third)
write(root/'results.json',dict(passed=True,solver_calls=0,synthetic_trace_controls=controls,source=str(source)))
print(len(controls),'no-solve trace controls passed')
