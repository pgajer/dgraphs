"""Execute the prespecified 25 fixed solves, then apply the declared remedy gate."""
import subprocess,sys
from pathlib import Path
from support import *
w=Path(sys.argv[1]);root=Path(sys.argv[2]);root.mkdir(parents=True,exist_ok=False);fixtures=root.parent/'fixtures-v1'
ledger=dict(complete=False,runs={},processes=[],qualified=[],revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip())
def save():write(root/'ledger.json',ledger)
for case in load(fixtures/'manifest.json')['cases']:
 for condition in CONDITIONS:
  folder=root/case/condition
  p=run([sys.executable,'-B',HERE/'replay.py',fixtures,case,condition,folder/'child'],folder,root.parent,120,8000-sum(x['observed_solves'] for x in ledger['processes']))
  ledger['processes'].append(p);save();assert p['reason'] is None and p['exit_code']==0,'fixed_reproduction_or_resource_failure'
  r=load(folder/'child/result.json');ledger['runs'][case+'/'+condition]=dict(child=str(folder/'child'),accepted=r['external']['accepted'],stationarity=r['external']['dual_stationarity'],primal=r['external']['normalized_primal'],status=r['backend']['status'],iterations=r['backend']['iterations'],saved_exact=r['saved_exact'])
  save();print(case,condition,ledger['runs'][case+'/'+condition],flush=True)
for name in POLICIES:
 if all(ledger['runs'][case+'/'+name]['accepted'] for case in load(fixtures/'manifest.json')['cases']):ledger['qualified'].append(name)
assert sum(x['observed_solves'] for x in ledger['processes'])==25
ledger['complete']=True;save();print('Qualified remedies:',ledger['qualified'],flush=True)
