import shutil
from support import *
from oneshot_guard import run,reserve
root=Path(sys.argv[1]).resolve();assert load(root/'preflight.json')['passed'];assert load(root/'guard-controls/results.json')['passed'];assert shutil.disk_usage(root).free>20*2**30
ledger=dict(schedule=['native','python','native','python'],processes=[],gated=[],reserved_invocations=0)
for i,label in enumerate(ledger['schedule']):
    remaining=600-sum(p['wall_seconds'] for p in ledger['processes'])
    if remaining<=0:ledger['gated']=list(range(i,4));break
    reserve(root/'reservations.json',4,label+str(i));ledger['reserved_invocations']+=1;write(root/'ledger.json',ledger)
    folder=root/'runs'/str(i)
    p=run([sys.executable,str(HERE/'replay.py'),str(root/'fixtures'/label),str(folder/'child')],folder,root,wall_limit=min(120,remaining));p.update(input=label,index=i);ledger['processes'].append(p);write(root/'ledger.json',ledger)
    if p['exit_code']!=0 or p['reason']:ledger['gated']=list(range(i+1,4));break
write(root/'ledger.json',ledger)
