"""Account for nonnumerical build/check commands and enforce per-command wall limit."""
import sys,json,os,subprocess,time,signal
from pathlib import Path
root=Path(sys.argv[1]);runtime,label=sys.argv[2:4];args=sys.argv[4:];manifest=json.loads((root/'environment.json').read_text());cfg=manifest['runtimes'][runtime]
folder=root/runtime;ledger=folder/'commands.json';records=json.loads(ledger.read_text()) if ledger.exists() else []
assert label not in [r['label'] for r in records]
env=os.environ.copy();env.pop('R_HOME',None);env.update(cfg['env']);elapsed=sum(r.get('seconds',0) for log in root.glob('*/commands.json') for r in json.loads(log.read_text()));limit=min(7200,28800-elapsed);assert limit>0
rec=dict(label=label,command=args,cwd=str(Path.cwd()),environment={k:env[k] for k in set(cfg['env'])|{'R_PROFILE_USER','R_TIDYCMD'} if k in env},state='reserved',time_limit=limit);records.append(rec)
save=lambda:ledger.write_text(json.dumps(records,indent=2)+'\n');save();start=time.monotonic()
with (folder/(label+'.log')).open('w') as f:
 p=subprocess.Popen(args,stdout=f,stderr=subprocess.STDOUT,env=env,start_new_session=True);rec.update(pid=p.pid,state='running');save()
 try:code=p.wait(timeout=limit)
 except subprocess.TimeoutExpired:
  os.killpg(p.pid,signal.SIGTERM)
  try:code=p.wait(timeout=5)
  except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);code=p.wait(timeout=5)
  rec['reason']='wall_limit'
rec.update(state='reaped',returncode=code,seconds=time.monotonic()-start);save();print(label,code,flush=True);raise SystemExit(code)
