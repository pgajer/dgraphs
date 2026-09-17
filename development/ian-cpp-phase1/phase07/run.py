"""Run frozen Phase07 ladder; preserve failures and explicitly account for gates."""
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path
import numpy as np
import scipy
import cvxpy
import clarabel
import psutil
from checks import load,write,sha
from guard import run,tree_bytes

HERE=Path(__file__).resolve().parent
worker=Path(sys.argv[1]); root=Path(sys.argv[2]); root.mkdir(parents=True,exist_ok=False)
engine=worker/'phase06b/build-v3/ian_engine'; tool=engine.with_name('ian_checkpoint_tool')
fixtures=load(root.parent/'fixtures-v1/manifest.json')['files']
ledger=dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),complete=False,runs={},comparisons={},gated=[],
    environment=dict(python=sys.version,numpy=np.__version__,scipy=scipy.__version__,cvxpy=cvxpy.__version__,clarabel=clarabel.__version__,psutil=psutil.__version__,platform=platform.platform(),machine=platform.machine(),cpu_count=os.cpu_count()),
    engine=str(engine),engine_sha256=sha(engine),plan_sha256=sha(HERE/'PLAN.md'),native_checkpoint_interval=100)
def save(): write(root/'ledger.json',ledger)
def remaining():
    procs=[v for v in ledger.get('processes',[])]
    return 3600-sum(v['wall_seconds'] for v in procs),10000-sum(v['observed_solves'] for v in procs)
def execute(command,folder):
    wall,solves=remaining()
    if wall<=0 or solves<=0 or tree_bytes(root.parent)>=16*2**30 or shutil.disk_usage(root).free<20*2**30: raise RuntimeError('study_budget_exhausted')
    result=run(command,folder,root.parent,wall,solves)
    ledger.setdefault('processes',[]).append(result); save(); return result
def one(name,fixture,condition):
    folder=root/name/condition
    command=([engine,fixture,folder/'child','--interval','100'] if condition=='native' else
        [sys.executable,'-B',HERE.parent/'phase03/reference.py',fixture,folder/'child',condition])
    proc=execute(command,folder)
    d=execute([sys.executable,'-B',HERE/'diagnose.py','inspect',folder/'child',fixture,folder/'checks',tool],folder/'diagnostic-process')
    result=load(folder/'checks/summary.json') if d['exit_code']==0 else dict(valid=False,complete=False)
    item=dict(fixture=str(fixture),input_sha256=sha(fixture),process=proc,checks=result,
        passed=proc['exit_code']==0 and proc['reason'] is None and result['valid'] and result['complete'])
    ledger['runs'][name+'/'+condition]=item; save()
    print(name,condition,'passed' if item['passed'] else 'FAILED',proc['observed_solves'],'solves',round(proc['wall_seconds'],2),'seconds',flush=True)
    return item['passed']
def comparison(name,left,right,label):
    folder=root/name/label
    proc=execute([sys.executable,'-B',HERE/'diagnose.py','compare',left/'trace.jsonl',right/'trace.jsonl',folder/'checks'],folder)
    result=load(folder/'checks/summary.json') if proc['exit_code']==0 else dict(passed=False,error='diagnostic_process_failed')
    ledger['comparisons'][name+'/'+label]=result; save(); return result['passed']
def pair(name,fixture):
    a=one(name,fixture,'native'); b=one(name,fixture,'evaluated')
    c=comparison(name,root/name/'native/child',root/name/'evaluated/child','native-evaluated')
    return a and b and c

save()
try:
    fixture=worker/'phase05/fixtures-v1/helix_120.json'
    gate=pair('regression_helix_120',fixture)
    for condition in ['native','evaluated']:
        gate &= comparison('regression_helix_120',worker/'phase05/full-v1/helix_120'/condition/'child',
            root/'regression_helix_120'/condition/'child','saved-'+condition)
    ledger['regression_gate']=gate; save()
    small=['helix_500','cloud_500','lobes_500','pressmat_500']
    large=['helix_1000','cloud_1000','lobes_1000']
    for name in small:
        if not gate:
            ledger['gated'].append(dict(name=name,conditions=['native','evaluated'],reason='earlier_gate_failure')); save(); continue
        gate=pair(name,Path(fixtures[name]['path']))
    ledger['expansion_gate']=gate; save()
    # Historical controls do not change the evaluated-reference gate.
    for name in ['helix_500','lobes_500']:
        if name+'/evaluated' not in ledger['runs']:
            ledger['gated'].append(dict(name=name,conditions=['original'],reason='principal_input_not_executed'));save();continue
        one(name,Path(fixtures[name]['path']),'original')
        comparison(name,root/name/'original/child',root/name/'evaluated/child','original-evaluated')
    for name in large:
        if not gate:
            ledger['gated'].append(dict(name=name,conditions=['native','evaluated'],reason='smaller_size_or_earlier_1000_failure'));save();continue
        gate=pair(name,Path(fixtures[name]['path']))
    ledger['complete']=True; ledger['final_gate']=gate; save()
except Exception as exc:
    ledger['driver_error']=repr(exc); save(); raise
print('Bounded attempts accounted for; independent acceptance remains separate.',flush=True)
