"""Frozen serial panel, including accepted same-path and cross-path comparisons."""
import os,shutil,subprocess,sys
from pathlib import Path
from checks import load,write,sha
from guard import run,tree_bytes
H=Path(__file__).resolve().parent;w=Path(sys.argv[1]);root=Path(sys.argv[2]);root.mkdir(parents=True,exist_ok=False)
ledger=dict(complete=False,runs={},comparisons={},processes=[],gated=[],revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),engine_sha256=sha(w/'phase07c/build-v2/ian_engine'),plan_sha256=sha(H/'PLAN.md'))
prior=load(Path(sys.argv[3])/'ledger.json') if len(sys.argv)>3 else None
ledger['prior_processes']=prior['processes'] if prior else []
ledger['prior_panel']=sys.argv[3] if prior else None
from provenance import build_identity
ledger['build_identity']=build_identity(w/'phase07c/build-v2')
def save():write(root/'ledger.json',ledger)
def execute(cmd,folder):
 wall=3600-sum(p['wall_seconds'] for p in ledger['prior_processes']+ledger['processes']);solves=8000-sum(p['observed_solves'] for p in ledger['prior_processes']+ledger['processes'])
 assert wall>0 and solves>0 and tree_bytes(root.parent)<16*2**30 and shutil.disk_usage(root).free>20*2**30,'study_budget_exhausted'
 p=run(cmd,folder,root.parent,wall,solves);ledger['processes'].append(p);save();assert p['reason'] is None,p['reason'];return p
save()
try:
 gate=True
 for case in load(w/'phase07c/fixtures-v1/manifest.json')['cases']:
  n=case['name'];kind=case['kind'];fixture=Path(case['input']);paths={};case_ok=True
  if not gate:ledger['gated'].append(dict(name=n,reason='earlier_discrepancy'));save();continue
  for condition in ['native','evaluated']:
   folder=root/n/condition;child=folder/'child';paths[condition]=child
   probe=kind in ['probe','stage']
   cmd=([w/('phase07c/build-v2/ian_probe' if probe else 'phase07c/build-v2/ian_engine'),fixture,child]+([] if probe else ['--interval','100']) if condition=='native' else [sys.executable,'-B',H/('reference_probe.py' if probe else 'reference.py'),fixture,child,'evaluated'])
   proc=execute(cmd,folder)
   item=dict(input=str(fixture),process=proc,child=str(child),complete=load(child/'status.json').get('complete',False) if (child/'status.json').exists() else False)
   if kind=='stage':item['complete']=proc['exit_code']==0 and (child/'stages.json').exists()
   if kind!='stage':
    args=['probe',child,folder/'checks'] if kind=='probe' else ['inspect',child,fixture,folder/'checks']
    diagnostic=execute([sys.executable,'-B',H/'validate.py',*args],folder/'diagnostic')
    item['checks']=load(folder/'checks/summary.json') if diagnostic['exit_code']==0 else dict(valid=False)
    case_ok &= item['checks']['valid']
    old=Path(case['baseline'][condition]);args=['exact',old/'trace.jsonl',child/'trace.jsonl',folder/'same-path.json']
    if n=='helix_500':args+=['prefix']
    check=execute([sys.executable,'-B',H/'validate.py',*args],folder/'same-path-process')
    item['same_path']=load(folder/'same-path.json') if check['exit_code']==0 else dict(passed=False)
    case_ok &= item['same_path']['passed']
   else:
    item['same_path']=dict(passed=load(Path(case['baseline'][condition])/'stages.json')==load(child/'stages.json'));case_ok &= item['same_path']['passed']
   item['passed']=proc['exit_code']==0 and item['complete']
   ledger['runs'][n+'/'+condition]=item;save()
   print(n,condition,'complete' if item['complete'] else 'REFUSED',proc['observed_solves'],'attempts',round(proc['wall_seconds'],2),'seconds',flush=True)
  if kind!='stage':
   folder=root/n/'comparison';p=execute([sys.executable,'-B',H/'validate.py','compare',paths['native']/'trace.jsonl',paths['evaluated']/'trace.jsonl',folder/'checks'],folder)
   c=load(folder/'checks/summary.json') if p['exit_code']==0 else dict(passed=False);ledger['comparisons'][n]=c;case_ok &= c['passed']
  else:
   c=dict(passed=load(paths['native']/'stages.json')==load(paths['evaluated']/'stages.json'));ledger['comparisons'][n]=c;case_ok &= c['passed']
  # A shared, verified numerical refusal is an accounted negative result;
  # unexplained discrepancies close subsequent execution.
  gate=bool(case_ok);save()
 ledger['complete']=True;ledger['comparison_gate']=gate;save()
except Exception as e:
 ledger['error']=repr(e);save();raise
print('Panel accounted for.',flush=True)
