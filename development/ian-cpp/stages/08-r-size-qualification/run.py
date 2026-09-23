"""Serial 1000-profile native/R interface qualification with cumulative reservations."""
import sys,json,subprocess,itertools,shutil
from pathlib import Path
H=Path(__file__).resolve().parent;ROOT=H.parents[3];P=Path(sys.argv[1]);B=P/'build-v1';O=P/'panel-v1';O.mkdir(exist_ok=False)
sys.path.insert(0,str(H.parent/'01-numerical-policy'));from guard import run,reserve,write
sys.path.insert(0,str(ROOT/'development/ian-cpp-phase1/phase07e'));import validate as v
v.POLICY='IAN evaluated-LP retry-power 0.1';load=lambda p:json.loads(Path(p).read_text())
L=dict(processes=[],cases=[],engine_entries=0,complete=False,larger_gate=False);save=lambda:write(O/'ledger.json',L);save()
def execute(name,cmd):
 used=sum(x['optimizer_calls'] for x in L['processes']);wall=sum(x['wall_seconds'] for x in L['processes']);assert L['engine_entries']<64 and used+1500<=16000 and wall<7200 and shutil.disk_usage(P).free>20*2**30
 reserve(O/'reservations.json',64,dict(name=name,command=list(map(str,cmd))));L['engine_entries']+=1;save();folder=O/'runs'/name
 r=run(cmd,folder,P,wall_limit=min(900,7200-wall),max_attempts=1500);L['processes'].append(r);save();assert r['state']=='reaped' and r['reason'] is None,r;return folder/'child',r

def exact(a,b):
 count=0
 for x,y in itertools.zip_longest(v.events(a),v.events(b)):
  assert x is not None and y is not None and {k:z for k,z in x.items() if k!='seconds'}=={k:z for k,z in y.items() if k!='seconds'},count
  count+=1
 return count
try:
 for c in load(P/'fixtures.json')['cases']:
  if c['stage']!='main':continue
  for mode in ['reference','connected']:
   tag=c['name']+'-'+mode;row=dict(case=c['name'],mode=mode)
   native,nr=execute(tag+'/native',[B/'engine',c[mode]['path'],O/'runs'/tag/'native/child','--interval','100'])
   row['native']=v.retry_checks(native,O/'checks'/(tag+'-native'),allow_terminal_rejection=nr['exit_code']!=0)
   rr=O/'runs'/tag/'R/child';rchild,r=execute(tag+'/R',['/Library/Frameworks/R.framework/Resources/bin/Rscript','--vanilla',H/'r_case.R',P/'library',c['metadata'],B/'dgraphs_ian.so',rr,mode,'full'])
   row['R']=v.retry_checks(rchild,O/'checks'/(tag+'-R'),allow_terminal_rejection=r['exit_code']!=0);row['exact_events']=exact(native/'trace.jsonl',rchild/'trace.jsonl')
   if mode=='reference':row['baseline_events']=exact(native/'trace.jsonl',Path(c['baseline'])/'trace.jsonl')
   check=O/'checks'/(tag+'-objects.json');cmd=['/Library/Frameworks/R.framework/Resources/bin/Rscript','--vanilla',H/'check_objects.R',P/'library',native,rchild,check]
   with (O/'checks'/(tag+'-objects.log')).open('w') as log:subprocess.run(list(map(str,cmd)),stdout=log,stderr=subprocess.STDOUT,check=True,timeout=600)
   row['complete']=load(native/'status.json')['complete'] and load(rchild/'status.json')['complete'];L['cases'].append(row);save();print(tag,'complete',row['complete'],'attempts',nr['optimizer_calls'],flush=True)
   if not row['complete']:raise RuntimeError('matching_refusal_closes_larger_gate')
 L['complete']=True;L['larger_gate']=True;save()
except BaseException as e:L['error']=repr(e);save();raise
