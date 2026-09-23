"""Restart, strict-policy preservation and R failure controls under cumulative bounds."""
import sys,json,subprocess,itertools,shutil
from pathlib import Path
H=Path(__file__).resolve().parent;ROOT=H.parents[3];P=Path(sys.argv[1]);B=P/'build-v2';O=Path(sys.argv[2]);O.mkdir(parents=True,exist_ok=False)
sys.path.insert(0,str(H.parent/'01-numerical-policy'));from guard import run,reserve,write
sys.path.insert(0,str(ROOT/'development/ian-cpp-phase1/phase07e'));import validate as v
v.POLICY='IAN evaluated-LP retry-power 0.1';load=lambda p:json.loads(Path(p).read_text())
L=dict(prior=load(P/'ledger.json')['processes'],processes=[],checks={},engine_entries=38,complete=False)
def save():write(O/'ledger.json',L)
def check(k,x):L['checks'][k]=bool(x);save();assert x,k

def execute(name,cmd,entries=1):
 census=L['prior']+L['processes'];used=sum(p['optimizer_calls'] for p in census);wall=sum(p['wall_seconds'] for p in census)
 assert L['engine_entries']+entries<=80 and used+1500<=10000 and wall<7200 and shutil.disk_usage(P).free>20*2**30
 L['engine_entries']+=entries;save();reserve(O/'reservations.json',80,dict(name=name,engine_entries=entries,command=list(map(str,cmd))))
 r=run(cmd,O/name,P,wall_limit=min(900,7200-wall),max_attempts=1500);L['processes'].append(r);save();check(name+' accounting',r['state']=='reaped' and r['reason'] is None);return O/name/'child',r
try:
 child,r=execute('R-controls',['/Library/Frameworks/R.framework/Resources/bin/Rscript','--vanilla',H/'r_controls.R',P,B/'dgraphs_ian.so',O/'R-controls/child'],6)
 check('R controls passed',r['exit_code']==0 and load(child/'checks.json')['passed'])
 f=P/'fixtures/helix-6101-connected.json'
 # Select first accepted pruning checkpoint with cached bridges, without tuning outcomes.
 full=P/'runs/helix-6101/native/child';cps=sorted((full/'checkpoints').glob('checkpoint-*.json'))
 cp=next(p for p in cps if load(p)['payload']['boundary']=='pruning' and load(p)['payload']['pruning']['protected_bridges'])
 iteration=load(cp)['payload']['iteration'];L['cancellation_iteration']=iteration;save()
 child,r=execute('cancel',[B/'engine',f,O/'cancel/child','--cancel-after',iteration,'--interval','100'])
 check('cancelled after protected pruning',r['exit_code']==3);v.retry_checks(child,O/'cancel-certificates')
 saved=next((child/'checkpoints').glob('checkpoint-*.json'))
 resumed,r=execute('resume',[B/'engine',f,O/'resume/child','--resume',saved])
 check('pruning resume result exact',r['exit_code']==0 and load(resumed/'result.json')==load(full/'result.json'))
 v.retry_checks(resumed,O/'resume-certificates')
 joined=O/'joined.jsonl'
 with joined.open('wb') as dest:
  for path in [child/'trace.jsonl',resumed/'trace.jsonl']:
   with path.open('rb') as src:shutil.copyfileobj(src,dest)
 check('pruning resume trace exact',v.exact(joined,full/'trace.jsonl')['passed'])
 graph=next(p for p in cps if load(p)['payload']['boundary']=='graph')
 resumed,r=execute('graph-resume',[B/'engine',f,O/'graph-resume/child','--resume',graph])
 check('constrained graph resume exact',r['exit_code']==0 and load(resumed/'result.json')==load(full/'result.json'));v.retry_checks(resumed,O/'graph-certificates')
 base=['clang++','-std=c++17','-O2','-I'+str(B/'source/core/include'),'-I'+str(B/'source/core/src')]
 cmd=base+[str(H.parent/'01-numerical-policy/checkpoint_tool.cpp'),'-o',str(O/'checkpoint_tool')]
 with (O/'checkpoint-build.log').open('w') as log:subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=120)
 write(O/'checkpoint-build.json',dict(command=cmd))
 def remove_mode(j):j['payload'].pop('pruning_policy');j['payload'].pop('pruning')
 def bad_edge(j):j['payload']['pruning']['protected_bridges'][0]['edge']=[0,199]
 def bad_margin(j):j['payload']['pruning']['protected_bridges'][0]['margin']+=1
 def bad_count(j):j['payload']['pruning']['protected_bridges'][0]['encounters']+=1
 def bad_history(j):j['payload']['pruning']['history'][-1]['examined']+=1
 for name,mutate in [('mode',remove_mode),('edge',bad_edge),('margin',bad_margin),('encounters',bad_count),('history',bad_history)]:
  j=load(saved);mutate(j);raw=O/(name+'-raw.json');dest=O/(name+'.json');write(raw,j);subprocess.run([O/'checkpoint_tool',raw,dest],check=True)
  rejected,r=execute('reject-'+name,[B/'engine',f,O/('reject-'+name)/'child','--resume',dest])
  status=load(rejected/'status.json');check(name+' rejected before solve',r['exit_code']==1 and r['optimizer_calls']==0 and status['error'] in ['invalid_restart','incompatible_restart'])
 old=Path('/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage01-policy')
 for name in ['nonuniform_curve','variable_density_patch','nearby_curved_arms','pressmat_hellinger_subset']:
  fixture=old/'build-v1/fixtures'/(name+'-strict.json')
  child,r=execute('strict-'+name,[B/'engine',fixture,O/('strict-'+name)/'child','--interval','100'])
  baseline=old/'supplement-v1'/('strict-'+name)/'child'
  check(name+' strict trace unchanged',r['exit_code']==0 and v.exact(child/'trace.jsonl',baseline/'trace.jsonl')['passed'])
 L['complete']=True;save();print('All supplementary checks passed',flush=True)
except BaseException as e:L['error']=repr(e);save();raise
