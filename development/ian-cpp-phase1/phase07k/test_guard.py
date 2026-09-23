"""No numerical solver: verify the derived guard's boundary and reap behavior."""
import importlib.util,errno,signal
from common import *
root=Path(sys.argv[1]);path=root/'trajectory_guard.py'
spec=importlib.util.spec_from_file_location('tested_guard',path);g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
out=root/'guard-tests';out.mkdir(exist_ok=False);results={}
code="""import sys,time,json
from pathlib import Path
p=Path(sys.argv[1]);p.mkdir(parents=True);n=int(sys.argv[2]);(p/'trace.jsonl').write_text(''.join(json.dumps(dict(event='solve',synthetic=True))+'\\n' for _ in range(n)));time.sleep(float(sys.argv[3]));(p/'finished').write_text('yes')
"""
for name,n,delay,wall,inject in [('exact_quota',500,.4,5,None),('excess',501,.4,5,None),('wall',1,1,.15,None),('permission_race',500,.4,.15,PermissionError),('exit_race',500,.4,.15,ProcessLookupError),('empty_failure_trace',0,.1,5,None)]:
 old=g._signal_group
 if inject:
  def fake(pid,sig):raise inject(errno.EPERM if inject is PermissionError else errno.ESRCH,'injected accounting race')
  g._signal_group=fake
 try:r=g.run([sys.executable,'-c',code,str(out/name/'child'),str(n),str(delay)],out/name,out,wall_limit=wall,synthetic=True)
 finally:g._signal_group=old
 assert r['state']=='reaped' and (out/name/'process.json').exists() and r['optimizer_calls']==0
 if name=='exact_quota':assert r['exit_code']==0 and r['reason'] is None and (out/name/'child/finished').exists()
 if inject:assert r['exit_code']==0 and r['signals'][0]['error']==inject.__name__
 if name=='excess':assert r['reason']=='single_solve_contract_exceeded'
 if name=='wall':assert r['reason']=='wall_limit' and r['exit_code']==-signal.SIGTERM
 if name=='empty_failure_trace':assert r['reason'] is None # input failures need no solve
 results[name]=r
p=out/'reservation.json';g.reserve(p,1,'last permitted');blocked=False
try:g.reserve(p,1,'forbidden extra')
except RuntimeError:blocked=True
assert blocked
write(out/'results.json',dict(passed=True,controls=results,exhausted_budget_refused=True,optimizer_calls=0,guard_sha256=sha(path)))
print('Six synthetic process controls and reservation boundary passed; zero solves.')
