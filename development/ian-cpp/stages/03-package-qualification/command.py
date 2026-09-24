"""Serialize and atomically account for build/check commands across one evidence root."""
import fcntl,json,os,signal,subprocess,sys,tempfile,time
from pathlib import Path

def atomic_json(path,value):
 fd,name=tempfile.mkstemp(prefix=path.name+'.',suffix='.tmp',dir=path.parent)
 try:
  with os.fdopen(fd,'w') as stream:
   json.dump(value,stream,indent=2);stream.write('\n');stream.flush();os.fsync(stream.fileno())
  os.replace(name,path)
 finally:
  if os.path.exists(name):os.unlink(name)

def main():
 root=Path(sys.argv[1]).resolve();runtime,label=sys.argv[2:4];args=sys.argv[4:]
 # One global lock is held from budget reservation through child reaping and final save.
 # Waiting callers cannot launch children or take stale ledger snapshots.
 with (root/'command.lock').open('a') as lock:
  fcntl.flock(lock,fcntl.LOCK_EX)
  manifest=json.loads((root/'environment.json').read_text());cfg=manifest['runtimes'][runtime]
  folder=root/runtime;ledger=folder/'commands.json';records=json.loads(ledger.read_text()) if ledger.exists() else []
  assert label not in [r['label'] for r in records]
  env=os.environ.copy();env.pop('R_HOME',None);env.update(cfg['env'])
  elapsed=sum(r['seconds'] if r.get('state')=='reaped' and 'seconds' in r else r.get('time_limit',7200) for log in root.glob('*/commands.json') for r in json.loads(log.read_text()))
  # Historical lost records have no recoverable duration: debit their full declared limit.
  if (root/'command-budget-reconciliation.json').exists():elapsed+=json.loads((root/'command-budget-reconciliation.json').read_text())['additional_conservative_seconds']
  limit=min(7200,28800-elapsed);assert limit>0
  rec=dict(label=label,command=args,cwd=str(Path.cwd()),environment={k:env[k] for k in set(cfg['env'])|{'R_PROFILE_USER','R_TIDYCMD'} if k in env},state='reserved',time_limit=limit,serialization='root command.lock held through completion');records.append(rec)
  save=lambda:atomic_json(ledger,records)
  save();start=time.monotonic();proc=None
  try:
   with (folder/(label+'.log')).open('w') as stream:
    proc=subprocess.Popen(args,stdout=stream,stderr=subprocess.STDOUT,env=env,start_new_session=True);rec.update(pid=proc.pid,state='running');save()
    try:code=proc.wait(timeout=limit)
    except subprocess.TimeoutExpired:
     rec['reason']='wall_limit';os.killpg(proc.pid,signal.SIGTERM)
     try:code=proc.wait(timeout=5)
     except subprocess.TimeoutExpired:os.killpg(proc.pid,signal.SIGKILL);code=proc.wait(timeout=5)
   rec.update(state='reaped',returncode=code)
  except BaseException as error:
   rec['exception']=repr(error)
   if proc is not None and proc.poll() is None:
    os.killpg(proc.pid,signal.SIGTERM)
    try:proc.wait(timeout=5)
    except subprocess.TimeoutExpired:os.killpg(proc.pid,signal.SIGKILL);proc.wait(timeout=5)
   rec.update(state='reaped' if proc else 'launch_failed',returncode=proc.returncode if proc else None)
   raise
  finally:
   rec['seconds']=time.monotonic()-start;save()
  print(label,code,flush=True);return code
if __name__=='__main__':raise SystemExit(main())
