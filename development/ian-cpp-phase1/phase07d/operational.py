"""Targeted retry failure and restart tests; all solver calls join the study budget."""
import subprocess,sys,shutil
from pathlib import Path
from support import *
sys.path.insert(0,str(HERE))
from validate import exact,retry_checks
H=Path(__file__).resolve().parent;w=Path(sys.argv[1]);root=Path(sys.argv[2]);panel=Path(sys.argv[3]);root.mkdir(parents=True,exist_ok=False)
engine=w/'phase07d/build-v1/ian_engine';test=engine.with_name('ian_retry_tests');tool=engine.with_name('ian_checkpoint_tool')
fixtures={e['name']:e for e in load(w/'phase07d/engine-fixtures-v1/manifest.json')['cases']}
small=Path(fixtures['pressmat_hellinger_subset']['input']);helix=Path(fixtures['helix_500']['input'])
previous=load(panel/'ledger.json');assert previous['validation_gate'];record=dict(complete=False,processes=[],tests=[],panel=str(panel))
def save():write(root/'checks.json',record)
def execute(name,cmd):
 used=previous.get('prior_processes',[])+previous['processes']+record['processes'];wall=3600-sum(p['wall_seconds'] for p in used);solves=8000-sum(p['observed_solves'] for p in used)
 assert wall>0 and solves>0 and tree_bytes(root.parent)<16*2**30 and shutil.disk_usage(root).free>20*2**30
 p=run(cmd,root/name,root.parent,wall,solves);record['processes'].append(p);save();assert p['reason'] is None;return p,root/name/'child'
def check(name,ok,**details):
 record['tests'].append(dict(name=name,passed=bool(ok),**details));save();assert ok,name
save()
p,_=execute('truth-table',[test]);check('eligibility_truth_table',p['exit_code']==0,checks=20)
for label,data in [('missing-policy',{k:v for k,v in load(small).items() if k!='numerical_policy'}),('wrong-policy',dict(load(small),numerical_policy='IAN evaluated-LP 1.0'))]:
 f=root/(label+'.json');write(f,data)
 for condition in ['native','evaluated']:
  name=label+'-'+condition;child=root/name/'child';cmd=[engine,f,child] if condition=='native' else [sys.executable,'-B',H/'candidate/reference.py',f,child,'evaluated']
  p,child=execute(name,cmd);s=load(child/'status.json');check(name,p['exit_code']!=0 and p['observed_solves']==0 and 'unsupported_policy' in s['error'],status=s)
for fault,number,error in [('invalid_solver',1,'invalid_solver_result'),('retry_exhausted',2,'retry_exhausted')]:
 p,child=execute(fault,[engine,small,root/fault/'child',fault]);s=load(child/'status.json');c=retry_checks(child,root/(fault+'-certificates'),True)
 solves=[e for e in events(child/'trace.jsonl') if e['event']=='solve']
 check(fault,p['exit_code']==1 and s['solves']==number and s['error']==error and c['accepted']==0 and len(solves)==number and not any(s[k] for k in ['graph','scales','affinity','complete']),checks=c,status=s)
 if fault=='retry_exhausted':check('damage_explicitly_labeled',all(e['test_fault']=='halved_primal_and_objective' and e['before_test_fault']['scales']==[2*x for x in e['scales']] for e in solves))
p,child=execute('observer-rejection',[test,helix,root/'observer-rejection/child']);check('observer_stops_retry',p['exit_code']==0 and p['observed_solves']==2,result=load(child/'result.json'))
full=Path(previous['runs']['helix_500/native']['child']);status=load(full/'status.json')
record['natural_retry_checkpoint_available']=bool(status['complete'])
assert status['complete'],'no_completed_natural_helix'
if True:
 p,child=execute('cancel-after-retry',[engine,helix,root/'cancel-after-retry/child','--interval','100','--cancel-after','0']+([] if status['complete'] else ['--test-solver-fault','retry_once']))
 s=load(child/'status.json');c=retry_checks(child,root/'cancel-certificates')
 saved=sorted((child/'checkpoints').glob('*.json'));check('cancel_after_retry',p['exit_code']==3 and s['error']=='cancelled' and len(saved)==1 and len(c['retries'])>0,status=s,retry_checks=c)
 checkpoint=saved[0];payload=load(checkpoint)['payload']
 check('checkpoint_policy_and_counter',payload['policy']=='IAN evaluated-LP retry units11 0.1' and payload['solves']==s['solves'],payload_summary={k:payload[k] for k in ['policy','solves','iteration','source','configuration']})
 p,resumed=execute('resumed',[engine,helix,root/'resumed/child','--interval','100','--resume',checkpoint]);rs=load(resumed/'status.json')
 joined=root/'joined-trace.jsonl'
 with joined.open('wb') as out:
  for f in [child/'trace.jsonl',resumed/'trace.jsonl']:
   with f.open('rb') as inp:shutil.copyfileobj(inp,out)
 equality=exact(full/'trace.jsonl',joined)
 check('resume_exact',p['exit_code']==0 and rs['complete'] and equality['passed'] and load(full/'result.json')==load(resumed/'result.json'),trace=equality)
 for label,key,value in [('policy','policy','IAN evaluated-LP 1.0'),('source','source','0'*64),('configuration','configuration','0'*64),('counter-bound','solves',(payload['iteration']+1)*42+1),('counter-schema','solves',84001),('counter-float','solves',float(payload['solves'])),('counter-negative','solves',-1)]:
  changed=load(checkpoint);changed['payload'][key]=value;temp=root/('altered-'+label+'.json');write(temp,changed)
  altered=checkpoint.parent/('altered-'+label+'.json')
  # A sibling envelope retains the original trace-relative provenance. Keep each
  # altered file explicitly separate from its immutable original checkpoint.
  result=subprocess.run([str(tool),str(temp),str(altered)],capture_output=True,text=True);assert result.returncode==0
  name='resume-wrong-'+label;p,fail=execute(name,[engine,helix,root/name/'child','--resume',altered]);s=load(fail/'status.json')
  check(name,p['exit_code']==1 and p['observed_solves']==0 and s['error']==('invalid_restart' if label=='counter-bound' else 'invalid_checkpoint_integer' if label.startswith('counter-') else 'incompatible_restart'),status=s)

record['complete']=True;record['passed']=all(e['passed'] for e in record['tests']);save();print('Operational checks complete.',flush=True)
