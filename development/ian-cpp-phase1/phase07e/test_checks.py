"""No-solve controls for diagnostic recovery and candidate transformation checks."""
import copy,sys,math
from pathlib import Path
from support import *
sys.path.insert(0,str(HERE));from validate import check_units
root=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=False);checks=[]
for case in load(root/'fixtures-v1/manifest.json')['cases']:
 problem=load(root/'diagnostic-v1'/case/'units11/child/problem.json');r=load(root/'diagnostic-v1'/case/'units11/child/result.json');raw=load(root/'diagnostic-v1'/case/'units11/child/raw.json');original=load(problem['original']);alpha=problem['alpha']
 e=dict(original,attempt=1,scales=r['x'],dual=r['z'],objective=r['objective'],solver_units=alpha,backend_rhs=problem['b'],backend_primal=raw['x'],backend_dual=raw['z'],backend_slack=raw['s'],backend_objective=raw['objective'])
 check_units(e);assert r['external']['accepted'];checks.append(dict(name=case+'-recovery',passed=True))
 for label,mutation in [
  ('wrong-units',lambda d:d.update(solver_units=d['solver_units']*2)),
  ('unscaled-rhs',lambda d:d.update(backend_rhs=d['b'])),
  ('unrecovered-primal',lambda d:d.update(scales=d['backend_primal'])),
  ('scaled-dual',lambda d:d.update(dual=[v*alpha for v in d['dual']])),
  ('unrecovered-objective',lambda d:d.update(objective=d['backend_objective'])),
  ('missing-slack',lambda d:d.update(backend_slack=[]))]:
  bad=copy.deepcopy(e);mutation(bad);refused=False
  try:check_units(bad)
  except AssertionError:refused=True
  assert refused,(case,label);checks.append(dict(name=case+'-'+label,passed=True))
write(out/'results.json',dict(passed=True,solver_calls=0,checks=checks));print(len(checks),'no-solve transformation controls passed')
