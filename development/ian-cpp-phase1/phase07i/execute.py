import shutil
from support import *
sys.path.insert(0,str(HERE.parent/'phase07h'))
from oneshot_guard import run,reserve
root=Path(sys.argv[1]).resolve();assert load(root/'preflight.json')['passed'];assert shutil.disk_usage(root).free>20*2**30
for path,digest in load(root/'fixtures-manifest.json').items():assert sha(root/path)==digest
ledger=dict(schedule=load(root/'schedule.json')['schedule'],processes=[],gated=[],reserved_invocations=0)
for i,name in enumerate(ledger['schedule']):
    remaining=720-sum(p['wall_seconds'] for p in ledger['processes'])
    if remaining<=0:ledger['gated']=list(range(i,6));break
    reserve(root/'reservations.json',6,name);ledger['reserved_invocations']+=1;write(root/'ledger.json',ledger);folder=root/'runs'/str(i)
    p=run([sys.executable,str(HERE/'replay.py'),str(root/'fixtures'/name),str(folder/'child')],folder,root,wall_limit=min(120,remaining));p.update(case=name,index=i);ledger['processes'].append(p);write(root/'ledger.json',ledger)
    if p['exit_code']!=0 or p['reason']:ledger['gated']=list(range(i+1,6));break
write(root/'ledger.json',ledger)
