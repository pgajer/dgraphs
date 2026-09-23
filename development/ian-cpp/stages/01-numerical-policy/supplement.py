"""Strict-baseline, R/native, natural restart and failure checks; cumulative limits."""
from pathlib import Path
import sys,json,subprocess,itertools,shutil,hashlib
from guard import run,reserve,write
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
E=ROOT/'development/ian-cpp-phase1/phase07e';sys.path.insert(0,str(E));import validate as v
v.POLICY='IAN evaluated-LP retry-power 0.1'
load=lambda p:json.loads(Path(p).read_text())
build,panel,out=map(Path,sys.argv[1:4]);out.mkdir(parents=True,exist_ok=False);prior=load(panel/'ledger.json');assert prior['complete'] and prior['gate']
ledger=dict(prior_processes=prior.get('prior_processes',[])+prior['processes'],processes=[],checks={},complete=False)
def save():write(out/'ledger.json',ledger)
def check(name,x):ledger['checks'][name]=bool(x);save();assert x,name
def execute(name,cmd):
 census=ledger['prior_processes']+ledger['processes'];used=sum(p['optimizer_calls'] for p in census);wall=sum(p['wall_seconds'] for p in census)
 fixed=sum(any(str(c).endswith('/replay.py') for c in p['command']) for p in census)
 assert len(census)-fixed<100 and used<8000 and wall<3600 and shutil.disk_usage(out).free>20*2**30
 reserve(out/'reservations.json',100,dict(name=name,command=list(map(str,cmd))))
 r=run(cmd,out/name,out.parent,wall_limit=min(900,3600-wall),max_attempts=min(1000,8000-used));ledger['processes'].append(r);save();check(name+' accounting',r['state']=='reaped' and r['reason'] is None);return out/name/'child',r
try:
 small=['nonuniform_curve','variable_density_patch','nearby_curved_arms','pressmat_hellinger_subset']
 for name in small:
  f=build/'fixtures'/(name+'-strict.json');child,r=execute('strict-'+name,[build/'engine',f,out/('strict-'+name)/'child','--interval','100'])
  check(name+' strict complete',r['exit_code']==0 and load(child/'status.json')['complete'])
  old=Path('/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase03/runs')
  # Compare to the exact typed baseline's stored full R traces below; historical
  # unchanged strict controls retain the ordinary numerical policy.
  rr=out/('R-strict-'+name)/'child';baseline=Path('/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/typed-core/evidence')/'candidate-traces'/(name+'.rds')
  rchild,r=execute('R-strict-'+name,['Rscript','--vanilla',HERE/'r_case.R',ROOT/'R/ian_graph.R',f,build/'dgraphs_ian.so',rr,baseline])
  check(name+' R strict preservation',r['exit_code']==0)
  cmp=v.compare(child/'trace.jsonl',rchild/'trace.jsonl',out/('strict-compare-'+name));check(name+' strict native/R trace',cmp['passed'])
 for name in small+['helix_500']:
  f=build/'fixtures'/(name+'.json');rr=out/('R-candidate-'+name)/'child'
  child,r=execute('R-candidate-'+name,['Rscript','--vanilla',HERE/'r_case.R',ROOT/'R/ian_graph.R',f,build/'dgraphs_ian.so',rr,'none'])
  check(name+' R candidate complete',r['exit_code']==0)
  v.retry_checks(child,out/('R-certificates-'+name))
  cmp=v.compare(panel/'runs'/name/'native/child/trace.jsonl',child/'trace.jsonl',out/('R-compare-'+name));check(name+' candidate native/R trace',cmp['passed'])
 f=build/'fixtures/helix_500.json';child,r=execute('cancel',[build/'engine',f,out/'cancel/child','--interval','100','--cancel-after','0']);c=v.retry_checks(child,out/'cancel-checks')
 check('natural cancel after successful retry',r['exit_code']==3 and len(c['retries'])>0)
 checkpoint=next((child/'checkpoints').glob('checkpoint-*.json'));saved=load(checkpoint)
 continued,r=execute('resume',[build/'engine',f,out/'resume/child','--resume',checkpoint,'--interval','100'])
 full=panel/'runs/helix_500/native/child'
 check('resumed result exact',r['exit_code']==0 and load(continued/'result.json')==load(full/'result.json'))
 joined=out/'joined.jsonl'
 with joined.open('wb') as dest:
  for p in [child/'trace.jsonl',continued/'trace.jsonl']:
   with p.open('rb') as source:shutil.copyfileobj(source,dest)
 check('resumed every event exact',all(a is not None and b is not None and {k:z for k,z in a.items() if k!='seconds'}=={k:z for k,z in b.items() if k!='seconds'} for a,b in itertools.zip_longest(v.events(joined),v.events(full/'trace.jsonl'))))
 for label,key,value in [('policy','policy','IAN evaluated-LP 1.0'),('source','source','0'*64),('configuration','configuration','0'*64),('counter-bound','solves',(saved['payload']['iteration']+1)*42+1),('counter-float','solves',float(saved['payload']['solves'])),('counter-negative','solves',-1)]:
  j=load(checkpoint);j['payload'][key]=value;p=out/(label+'-unhashed.json');write(p,j);hashed=out/(label+'.json')
  subprocess.run([build/'checkpoint_tool',p,hashed],check=True)
  rejected,r=execute('invalid-'+label,[build/'engine',f,out/('invalid-'+label)/'child','--resume',hashed]);check(label+' refused before solve',r['exit_code']==1 and r['optimizer_calls']==0)
 child,r=execute('invalid-solver',[build/'engine',build/'fixtures/pressmat_hellinger_subset.json',out/'invalid-solver/child','invalid_solver']);check('invalid scales not retried',r['exit_code']==1 and r['optimizer_calls']==1 and not load(child/'status.json')['complete'])
 child,r=execute('observer',[build/'eligibility',f,out/'observer/child']);check('observer stops before retry',r['exit_code']==0 and r['optimizer_calls']==2)
 ledger['complete']=True;save();print('Supplement checks passed.',flush=True)
except Exception as exc:ledger['error']=repr(exc);save();raise
