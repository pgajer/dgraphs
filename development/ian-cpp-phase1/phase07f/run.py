"""Serial scale/coverage panel with explicit stop gates and one larger restart."""
import hashlib,itertools,shutil,subprocess,sys
from pathlib import Path
from support import *
w=Path(sys.argv[1]);root=Path(sys.argv[2]);root.mkdir(parents=True,exist_ok=False);study=root.parent
m=load(study/'fixtures-v1/manifest.json');assert load(study/'preflight-v2/results.json')['passed']
engine=w/'phase07e/build-v1/ian_engine';tool=engine.with_name('ian_checkpoint_tool')
assert sha(engine)==m['runtime']['engine_sha256']
ledger=dict(complete=False,runs={},comparisons={},processes=[],gated=[],restart={},policy=POLICY,runtime=m['runtime'],revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip())
def save():write(root/'ledger.json',ledger)
def execute(cmd,folder):
 wall=3600-sum(p['wall_seconds'] for p in ledger['processes']);solves=10000-sum(p['observed_solves'] for p in ledger['processes'])
 if wall<=0 or solves<=0 or tree_bytes(study)>=16*2**30 or shutil.disk_usage(study).free<=20*2**30:
  ledger['budget_closed']=True;save();return None
 p=run(cmd,folder,study,wall,solves);ledger['processes'].append(p);save();return p
save();gate=True
for case in m['cases']:
 name=case['name'];fixture=Path(case['input']);paths={};ok=True;both=True
 if not gate:ledger['gated'].append(dict(name=name,conditions=['native','evaluated'],reason='previous_case_or_resource_gate'));save();continue
 for condition in ['native','evaluated']:
  folder=root/name/condition;child=folder/'child';paths[condition]=child
  cmd=[engine,fixture,child,'--interval','100'] if condition=='native' else [sys.executable,'-B',CANDIDATE/'reference.py',fixture,child,'evaluated']
  p=execute(cmd,folder)
  if p is None:
   ledger['gated'].append(dict(name=name,conditions=[condition]+(['evaluated'] if condition=='native' else []),reason='budget_closed'));gate=False;break
  status=load(child/'status.json') if (child/'status.json').exists() else dict(complete=False,error='missing_status')
  item=dict(child=str(child),input=str(fixture),complete=bool(status.get('complete')),status=status,process=p);ledger['runs'][name+'/'+condition]=item;save()
  if p['reason']:
   gate=False
   if condition=='native':ledger['gated'].append(dict(name=name,conditions=['evaluated'],reason='resource_failure_before_counterpart'))
   save();break
  q=execute([sys.executable,'-B',HERE/'validate.py',child,fixture,folder/'checks',tool],folder/'diagnostic')
  item['checks']=load(folder/'checks/summary.json') if q and q['exit_code']==0 and not q['reason'] else dict(valid=False)
  ok &= item['checks']['valid'];both &= item['complete'] and p['exit_code']==0;save()
  print(name,condition,'complete' if item['complete'] else 'REFUSED',p['observed_solves'],'attempts',round(p['wall_seconds'],2),'seconds',flush=True)
  if not ok:
   gate=False
   if condition=='native':ledger['gated'].append(dict(name=name,conditions=['evaluated'],reason='validation_or_resource_failure_before_counterpart'))
   save();break
 if not gate:continue
 folder=root/name/'comparison';p=execute([sys.executable,'-B',E/'validate.py','compare',paths['native']/'trace.jsonl',paths['evaluated']/'trace.jsonl',folder/'checks'],folder)
 comparison=load(folder/'checks/summary.json') if p and p['exit_code']==0 and not p['reason'] else dict(passed=False)
 ledger['comparisons'][name]=comparison;gate=bool(ok and both and comparison['passed']);save()
ledger['panel_gate']=gate
# Select first completed, paired, agreeing case with pruning. No additional input.
selection=next((c for c in m['cases'] if ledger['comparisons'].get(c['name'],{}).get('passed') and all(ledger['runs'].get(c['name']+'/'+s,{}).get('complete') for s in ['native','evaluated']) and ledger['runs'][c['name']+'/native'].get('checks',{}).get('counts',{}).get('pruned',0)>0),None)
if selection is None:ledger['restart']=dict(executed=False,reason='no_completed_pruning_case');save()
else:
 name=selection['name'];fixture=Path(selection['input']);full=Path(ledger['runs'][name+'/native']['child']);restart=dict(executed=False,selected=name);ledger['restart']=restart;save()
 folder=root/'restart/cancel';child=folder/'child';p=execute([engine,fixture,child,'--interval','100','--cancel-after','0'],folder)
 if p is None or p['reason']:restart.update(reason='resource_gate');save()
 else:
  s=load(child/'status.json');saved=sorted((child/'checkpoints').glob('checkpoint-*.json'))
  assert p['exit_code']==3 and s['error']=='cancelled' and len(saved)==1
  checkpoint=saved[0];restart.update(executed=True,checkpoint=str(checkpoint),cancel_solves=s['solves']);save()
  folder=root/'restart/resume';resumed=folder/'child';p=execute([engine,fixture,resumed,'--interval','100','--resume',checkpoint],folder)
  if p is None or p['reason']:restart.update(passed=False,reason='resource_gate');save()
  else:
   rs=load(resumed/'status.json');joined=root/'restart/joined-trace.jsonl'
   with joined.open('wb') as f:
    for source in [child/'trace.jsonl',resumed/'trace.jsonl']:
     with source.open('rb') as g:shutil.copyfileobj(g,f)
   count=0;exact=True
   for x,y in itertools.zip_longest(events(full/'trace.jsonl'),events(joined)):
    exact &= x is not None and y is not None and {k:v for k,v in x.items() if k!='seconds'}=={k:v for k,v in y.items() if k!='seconds'};count+=1
   same=load(full/'result.json')==load(resumed/'result.json')
   restart.update(passed=bool(p['exit_code']==0 and rs['complete'] and exact and same),trace_exact=exact,result_exact=same,events=count,total_solves=rs['solves'],resume_attempts=p['observed_solves']);save()
   for label,path in [('cancel',child),('resume',resumed)]:
    folder=root/'restart'/label;q=execute([sys.executable,'-B',HERE/'validate.py',path,fixture,folder/'checks',tool],folder/'diagnostic')
    checks=load(folder/'checks/summary.json') if q and q['exit_code']==0 and not q['reason'] else dict(valid=False)
    restart[label+'_checks']=checks;restart['passed'] &= checks['valid'];save()
ledger['complete']=True;save();print(dict(panel_gate=gate,executions=len(ledger['runs']),gated=ledger['gated'],restart=ledger['restart'].get('passed')),flush=True)
