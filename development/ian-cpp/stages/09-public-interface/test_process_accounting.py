"""Deterministic controls of actual build/command functions; no child processes."""
import ast,fcntl,json,os,signal,subprocess,sys,tempfile,time,types,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4];OUT=Path(sys.argv[1]);OUT.mkdir(exist_ok=False)
CASES={'success':([0],[], 'reaped',0), 'nonzero':([7],[],'reaped',7),
 'launch_failure':([],[],'launch_failed',None),
 'timeout':(['timeout',-15],[],'reaped',-15),
 'kill_escalation':(['timeout','timeout',-9],[],'reaped',-9),
 'signal_race':(['timeout',0],['gone'],'reaped',0),
 'interruption':(['interrupt',-15],[],'reaped',-15),
 'interruption_race':(['interrupt',0],['gone'],'reaped',0),
 'unconfirmed':(['timeout','timeout','timeout'],['gone','gone'],'termination_unconfirmed',None),
 'signal_error':(['timeout','timeout',-9],['permission'],'reaped',-9),
 'cleanup_interruption':(['interrupt','interrupt',-9],[],'reaped',-9)}
results=[]
for kind,path in [('builder',ROOT/'inst/ian/build_backend.py'),('supervisor',ROOT/'development/ian-cpp/stages/09-public-interface/command.py')]:
 tree=ast.parse(path.read_text());functions=ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef)],type_ignores=[])
 for name,(waits,signals,state,code) in CASES.items():
  folder=OUT/(kind+'-'+name);folder.mkdir();calls=[];sent=[]
  class Process:
   pid=999999999;returncode=None
   def wait(self,timeout=None):
    assert timeout is not None and timeout<=1800
    item=waits[len(calls)];calls.append(timeout)
    if item=='timeout':raise subprocess.TimeoutExpired(['synthetic'],timeout)
    if item=='interrupt':raise KeyboardInterrupt('synthetic interrupt')
    self.returncode=item;return item
  proc=Process()
  def launch(*a,**kw):
   if name=='launch_failure':raise FileNotFoundError('synthetic missing executable')
   return proc
  def kill(pid,sig):
   assert pid==proc.pid
   i=len(sent);sent.append(int(sig));item=signals[i] if i<len(signals) else None
   if item=='gone':raise ProcessLookupError('synthetic signal race')
   if item=='permission':raise PermissionError('synthetic cleanup error')
  fakeos=types.SimpleNamespace(**{k:getattr(os,k) for k in dir(os)});fakeos.killpg=kill
  env=dict(out=folder,record={'commands':[],'complete':False},Path=Path,json=json,time=time,signal=signal,os=fakeos,fcntl=fcntl,tempfile=tempfile,subprocess=types.SimpleNamespace(Popen=launch,TimeoutExpired=subprocess.TimeoutExpired,STDOUT=subprocess.STDOUT))
  if kind=='supervisor':
   (folder/'runtime').mkdir();(folder/'environment.json').write_text(json.dumps({'runtimes':{'runtime':{'env':{}}}}));env['sys']=types.SimpleNamespace(argv=['command.py',str(folder),'runtime',name,'synthetic'])
  exec(compile(functions,str(path),'exec'),env);exception=None
  try:
   if kind=='builder':env['call'](name,['synthetic'])
   else:env['main']()
  except BaseException as e:exception=type(e).__name__
  rows=json.loads((folder/('build-record.json' if kind=='builder' else 'runtime/commands.json')).read_text());row=rows['commands'][0] if kind=='builder' else rows[0]
  assert row['state']==state and row['returncode']==code,(kind,name,row)
  assert len(calls)==len(waits) and all(t==5 for t in calls[1:])
  if name.startswith('interruption') or name=='cleanup_interruption':assert exception=='KeyboardInterrupt'
  if name=='signal_race':assert row['signal_races']==[int(signal.SIGTERM)]
  results.append(dict(kind=kind,case=name,state=state,returncode=code,wait_timeouts=calls,signals=sent,exception=exception))
result=dict(passed=True,controls=len(results),child_processes_launched=0,engine_calls=0,source_sha256={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [ROOT/'inst/ian/build_backend.py',Path(__file__).parent/'command.py']},results=results)
(OUT/'checks.json').write_text(json.dumps(result,indent=2)+'\n');print(len(results),'process accounting controls passed; zero children or engine calls')
