"""Public defaults and explicit legacy choices on frozen installed R regressions."""
import sys,json,os,subprocess,shutil
from pathlib import Path
H=Path(__file__).resolve().parent;ROOT=H.parents[3];P=Path(sys.argv[1]);O=P/'numerical-v1';O.mkdir(exist_ok=False)
sys.path.insert(0,str(H));from guard import run,reserve,write
sys.path.insert(0,str(ROOT/'development/ian-cpp-phase1/phase07e'));import validate as v
v.POLICY='IAN evaluated-LP retry-power 0.1';load=lambda p:json.loads(Path(p).read_text());M=load(P/'environment.json');specs=load(P/'fixtures.json')['cases']
L=dict(processes=[],entries=0,complete=False,checks={},cases=[]);save=lambda:write(O/'ledger.json',L);save()
def check(k,x):L['checks'][k]=bool(x);save();assert x,k

def execute(runtime,name,cmd,entries=1):
 used=sum(p['optimizer_calls'] for p in L['processes']);wall=sum(p['wall_seconds'] for p in L['processes']);assert L['entries']+entries<=80 and used+1500<=8000 and wall<6000 and shutil.disk_usage(P).free>20*2**30
 reserve(O/'reservations.json',80,dict(runtime=runtime,name=name,entries=entries,command=list(map(str,cmd))));L['entries']+=entries;save();folder=O/runtime/name
 r=run(cmd,folder,P,wall_limit=min(900,6000-wall),max_attempts=1500);r.update(runtime=runtime,name=name,reserved_entries=entries);L['processes'].append(r);save();check(runtime+' '+name+' accounting',r['state']=='reaped' and r['reason'] is None);check(runtime+' '+name+' checks',r['exit_code']==0);return folder/'child',r

def certificates(child):
 rows=[];summary=0
 for e in v.events(child/'trace.jsonl'):
  if e['event']!='solve':continue
  if 'A_data' not in e:summary+=1;continue
  c=v.scalar_check(e,e['scales'],e['dual'],e['objective'],'Solved' if e['status']=='optimal' else e['status']);assert bool(e['accepted'])==c['accepted'];v.check_units(e)
  rows.append(dict(number=e['number'],accepted=bool(c['accepted']),stationarity=c['dual_stationarity'],gap=c['dual_relative_gap']))
 write(child.parent/'certificates.json',dict(full=rows,summary_returns=summary));return dict(full=len(rows),accepted=sum(r['accepted'] for r in rows),rejected=sum(not r['accepted'] for r in rows),summary=summary)
try:
 for runtime,C in M['runtimes'].items():
  os.environ.pop('R_HOME',None);os.environ.update(C['env']);backend=C['backend'];lib=C['library']
  for spec in specs:
   name=spec['name'];sp=O/(runtime+'-'+name+'.json');write(sp,spec);child,r=execute(runtime,name,[C['rscript'],'--vanilla',H/'case.R',lib,sp,backend,O/runtime/name/'child'])
   cert=certificates(child)
   if spec['detail']=='full' and spec['mode']!='strict':v.retry_checks(child,child.parent/'retry-certificates')
   check(runtime+' '+name+' census',load(child/'status.json')['solves']==r['optimizer_calls']);L['cases'].append(dict(runtime=runtime,name=name,certificate_counts=cert));save();print(runtime,name,r['optimizer_calls'],flush=True)
  child,r=execute(runtime,'controls',[C['rscript'],'--vanilla',H/'controls.R',lib,backend,O/runtime/'controls/child'],11)
  cert=certificates(child);state=load(child/'status.json');check(runtime+' control census',state['engine_entries']==11 and state['solves']==r['optimizer_calls']);L['cases'].append(dict(runtime=runtime,name='controls',certificate_counts=cert));save()
 L['complete']=True;save()
except BaseException as e:L['error']=repr(e);save();raise
