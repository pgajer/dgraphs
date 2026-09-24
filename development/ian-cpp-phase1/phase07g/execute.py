import shutil,subprocess
from support import *
root=Path(sys.argv[1]).resolve();assert load(root/'preflight.json')['passed'];assert shutil.disk_usage(root).free>20*2**30
for name,digest in load(root/'fixtures/manifest.json').items():assert sha(root/'fixtures'/name)==digest
schedule=[('native','native'),('python','python'),('python','native'),('native','python')];schedule+=list(reversed(schedule));ledger=dict(schedule=schedule,processes=[],gated=[],solver_calls=0)
for index,(interface,input_name) in enumerate(schedule):
    folder=root/'runs'/str(index);out=folder/'child';fixture=root/'fixtures'/input_name
    command=[str(root/'build/ian_fixed_replay'),str(fixture),str(out)] if interface=='native' else [sys.executable,str(HERE/'python_replay.py'),str(fixture),str(out)]
    remaining=600-sum(p['wall_seconds'] for p in ledger['processes'])
    if remaining<=0:ledger['gated']=list(range(index,8));break
    p=run(command,folder,root,remaining_wall=min(120,remaining),remaining_solves=8-ledger['solver_calls']);p.update(interface=interface,input=input_name,index=index);ledger['processes'].append(p);ledger['solver_calls']+=p['observed_solves'];write(root/'ledger.json',ledger)
    if p['exit_code'] or p['reason']:ledger['gated']=list(range(index+1,8));break
write(root/'ledger.json',ledger)
assert not ledger['gated'] and ledger['solver_calls']==8
