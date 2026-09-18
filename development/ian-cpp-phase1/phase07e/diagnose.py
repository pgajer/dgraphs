"""Twelve prespecified fixed-problem regression solves, without settings search."""
import subprocess,sys,shutil
from pathlib import Path
from support import *
w=Path(sys.argv[1]);root=Path(sys.argv[2]);root.mkdir(parents=True,exist_ok=False);fixtures=root.parent/'fixtures-v1'
ledger=dict(complete=False,runs={},processes=[],revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip())
def save():write(root/'ledger.json',ledger)
for case,item in load(fixtures/'manifest.json')['cases'].items():
 for condition in ['ordinary','units11']:
  folder=root/case/condition
  assert shutil.disk_usage(root).free>20*2**30
  p=run([sys.executable,'-B',HERE/'replay.py',fixtures,case,condition,folder/'child'],folder,root.parent,3600-sum(x['wall_seconds'] for x in ledger['processes']),8000-sum(x['observed_solves'] for x in ledger['processes']))
  ledger['processes'].append(p);save();assert p['reason'] is None and p['exit_code']==0
  r=load(folder/'child/result.json');assert bool(r['external']['accepted'])==item['expected'][condition]
  ledger['runs'][case+'/'+condition]=dict(child=str(folder/'child'),accepted=r['external']['accepted'],stationarity=r['external']['dual_stationarity'],status=r['backend']['status'],iterations=r['backend']['iterations'],saved_exact=r['saved_exact'])
  save();print(case,condition,ledger['runs'][case+'/'+condition],flush=True)
assert sum(x['observed_solves'] for x in ledger['processes'])==12
ledger.update(complete=True,regression_passed=True);save()
