"""Small preservation/operational controls and prospectively gated larger pairs."""
import sys,json,subprocess,itertools,shutil,time
from pathlib import Path
H=Path(__file__).resolve().parent;ROOT=H.parents[3];P=Path(sys.argv[1]);B=P/'build-v3';O=P/'supplement-v1';O.mkdir(exist_ok=False)
sys.path.insert(0,str(H.parent/'01-numerical-policy'));from guard import run,reserve,write
sys.path.insert(0,str(ROOT/'development/ian-cpp-phase1/phase07e'));import validate as v
v.POLICY='IAN evaluated-LP retry-power 0.1';load=lambda p:json.loads(Path(p).read_text());old=P.parent
prior=load(P/'panel-v2/ledger.json');assert prior['complete'] and prior['larger_gate']
L=dict(prior=prior.get('prior',[])+prior['processes'],processes=[],engine_entries=prior['engine_entries'],checks={},larger_cases=[],complete=False,conditional_executed=False);save=lambda:write(O/'ledger.json',L);save()
def check(name,x):L['checks'][name]=bool(x);save();assert x,name

def execute(name,cmd,entries=1):
 census=L['prior']+L['processes'];used=sum(x['optimizer_calls'] for x in census);wall=sum(x['wall_seconds'] for x in census)
 assert L['engine_entries']+entries<=80 and used+1500<=16000 and wall<7200 and shutil.disk_usage(P).free>20*2**30
 reserve(O/'reservations.json',80,dict(name=name,engine_entries=entries,command=list(map(str,cmd))));L['engine_entries']+=entries;save();folder=O/'runs'/name
 r=run(cmd,folder,P,wall_limit=min(900,7200-wall),max_attempts=1500);L['processes'].append(r);save();check(name+' accounting',r['state']=='reaped' and r['reason'] is None);return folder/'child',r
try:
 for name in ['nonuniform_curve','variable_density_patch','nearby_curved_arms','pressmat_hellinger_subset']:
  fixture=old/'stage01-policy/build-v1/fixtures'/(name+'-strict.json');baseline=old/'stage01-policy/supplement-v1'/('R-strict-'+name)/'child/result.rds';tag='strict-'+name
  child,r=execute(tag,['/Library/Frameworks/R.framework/Resources/bin/Rscript','--vanilla',H/'r_regression.R',P,fixture,B/'dgraphs_ian.so',O/'runs'/tag/'child',baseline]);check(tag+' exact',r['exit_code']==0)
 for name in ['square-6101','helix-6101','sphere-6101']:
  fixture=old/'connected-pruning/fixtures'/(name+'-connected.json');baseline=old/'connected-pruning/runs'/name/'R/child/result.rds';tag='saved-'+name
  child,r=execute(tag,['/Library/Frameworks/R.framework/Resources/bin/Rscript','--vanilla',H/'r_regression.R',P,fixture,B/'dgraphs_ian.so',O/'runs'/tag/'child',baseline]);check(tag+' exact',r['exit_code']==0);v.retry_checks(child,O/(tag+'-certificates'))
 child,r=execute('R-controls',['/Library/Frameworks/R.framework/Resources/bin/Rscript','--vanilla',H/'r_controls.R',P,B/'dgraphs_ian.so',O/'runs/R-controls/child'],7);check('R controls',r['exit_code']==0 and load(child/'checks.json')['passed'])
 prior_larger=[]
 for c in load(P/'fixtures.json')['cases']:
  if c['stage']=='main' and c['name']!='helix_1000':continue
  if c['stage']=='conditional':
   gate=len(prior_larger)==4 and all(r['exit_code']==0 and r['wall_seconds']<60 and r['sampled_tree_peak_rss_bytes']<2**30 for r in prior_larger) and shutil.disk_usage(P).free>20*2**30
   L['conditional_gate']=dict(passed=gate,prior_process_count=len(prior_larger),limits=dict(seconds=60,rss_bytes=2**30));save()
   if not gate:continue
   # This client emits compact solve summaries and binary affinities.
   bm=load(B/'manifest.json');base=bm['commands'][0]['argv'];base=base[:base.index('-fPIC')];lib=bm['solver_archive']['path'];cmd=base+[str(H/'summary.cpp'),str(B/'core.o'),str(B/'identity_json.o'),lib,'-framework','Security','-framework','CoreFoundation','-o',str(O/'summary')]
   with (O/'summary-build.log').open('w') as log:subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=120)
   write(O/'summary-build.json',dict(command=cmd));L['conditional_executed']=True;save()
  tag=c['name'];native=O/'runs'/tag/'native/child'
  cmd=[O/'summary',c['metadata'],native] if c['stage']=='conditional' else [B/'engine',c['connected']['path'],native,'--interval','100']
  native,nr=execute(tag+'/native',cmd)
  if c['stage']!='conditional':v.retry_checks(native,O/(tag+'-certificates'),allow_terminal_rejection=nr['exit_code']!=0)
  rr=O/'runs'/tag/'R/child';rchild,r=execute(tag+'/R',['/Library/Frameworks/R.framework/Resources/bin/Rscript','--vanilla',H/'r_case.R',P/'library-v3',c['metadata'],B/'dgraphs_ian.so',rr,'connected','summary'])
  checkfile=O/(tag+'-objects.json');cmd=['/Library/Frameworks/R.framework/Resources/bin/Rscript','--vanilla',H/'check_objects.R',P/'library-v3',native,rchild,checkfile]
  with (O/(tag+'-objects.log')).open('w') as log:subprocess.run(list(map(str,cmd)),stdout=log,stderr=subprocess.STDOUT,check=True,timeout=600)
  success=nr['exit_code']==r['exit_code']==0;L['larger_cases'].append(dict(case=tag,complete=success,exact_objects=True,attempts=nr['optimizer_calls']));save();print(tag,'complete',success,'attempts',nr['optimizer_calls'],flush=True)
  if not success:L['later_size_gate_closed']='numerical refusal';save();break
  if c['stage']=='larger':prior_larger.extend([nr,r])
 L['complete']=True;save()
except BaseException as e:L['error']=repr(e);save();raise
