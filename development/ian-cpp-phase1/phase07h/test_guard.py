"""Real child-process controls with synthetic events only; no optimizer imported."""
import sys,signal,errno,json
from pathlib import Path
import oneshot_guard as g
root=Path(sys.argv[1]);root.mkdir(parents=True,exist_ok=False);results={}
code="""import sys,time,json
from pathlib import Path
p=Path(sys.argv[1]);p.mkdir(parents=True);n=int(sys.argv[2]);(p/'trace.jsonl').write_text(''.join(json.dumps(dict(event='solve',synthetic=True))+'\\n' for _ in range(n)));time.sleep(float(sys.argv[3]));(p/'finished').write_text('yes')
"""
for name,n,delay,wall,inject in [('exact_quota',1,1.3,5,None),('excess',2,1.3,5,None),('wall',1,1.3,.15,None),('permission_race',1,.4,.15,PermissionError),('exit_race',1,.4,.15,ProcessLookupError),('missing',0,.1,5,None)]:
    old=g._signal_group
    if inject:
        def fake(pid,sig):raise inject(errno.EPERM if inject is PermissionError else errno.ESRCH,'injected finalization race')
        g._signal_group=fake
    try:r=g.run([sys.executable,'-c',code,str(root/name/'child'),str(n),str(delay)],root/name,root,wall_limit=wall,synthetic=True)
    finally:g._signal_group=old
    assert r['state']=='reaped' and (root/name/'process.json').exists()
    if name=='exact_quota':assert r['exit_code']==0 and r['reason'] is None and (root/name/'child/finished').exists()
    if inject:assert r['exit_code']==0 and r['signals'][0]['error']==inject.__name__
    if name=='excess':assert r['reason']=='single_solve_contract_exceeded'
    if name=='wall':assert r['reason']=='wall_limit' and r['exit_code']==-signal.SIGTERM
    if name=='missing':assert r['reason']=='single_solve_contract_count'
    results[name]=r
p=root/'reservation.json';g.reserve(p,1,'last permitted');blocked=False
try:g.reserve(p,1,'forbidden extra')
except RuntimeError:blocked=True
assert blocked and len(json.loads(p.read_text())['reservations'])==1
g.write(root/'results.json',dict(passed=True,controls=results,exhausted_budget_refused=True,optimizer_calls=0,synthetic_events=sum(x['observed_events'] for x in results.values())))
