"""Bounded serial reference regression and native/R connected trajectories."""
import sys,json,itertools,shutil
from pathlib import Path
H=Path(__file__).resolve().parent;ROOT=H.parents[3];P=Path(sys.argv[1]);B=Path(sys.argv[2]);load=lambda p:json.loads(Path(p).read_text())
sys.path.insert(0,str(H.parent/'01-numerical-policy'));from guard import run,reserve,write
sys.path.insert(0,str(ROOT/'development/ian-cpp-phase1/phase07e'));import validate as v
v.POLICY='IAN evaluated-LP retry-power 0.1'
L=dict(processes=[],cases={},complete=False);assert not (P/'ledger.json').exists();save=lambda:write(P/'ledger.json',L);save()
def execute(cmd,folder):
 used=sum(r['optimizer_calls'] for r in L['processes']);wall=sum(r['wall_seconds'] for r in L['processes']);assert used+1500<=10000 and wall<7200 and shutil.disk_usage(P).free>20*2**30
 reserve(P/'reservations.json',80,dict(command=list(map(str,cmd))))
 r=run(cmd,folder,P,wall_limit=min(900,7200-wall),max_attempts=1500);L['processes'].append(r);save();assert r['state']=='reaped' and r['reason'] is None and r['exit_code']==0,r
 return r
try:
 for c in load(P/'fixtures.json')['cases']:
  result={};name=c['name']
  if c['baseline']:
   folder=P/'runs'/name/'reference';execute([B/'engine',c['reference']['path'],folder/'child','--interval','100'],folder)
   exact=v.exact(Path(c['baseline'])/'trace.jsonl',folder/'child/trace.jsonl');assert exact['passed'],(name,exact);result['reference']=exact
   certificate=v.retry_checks(folder/'child',folder/'certificates');result['reference_attempts']=certificate['attempts']
   print(name,'reference exact',certificate['attempts'],flush=True)
  if c['variant']:
   for interface in ['native','R']:
    folder=P/'runs'/name/interface;child=folder/'child'
    cmd=[B/'engine',c['connected']['path'],child,'--interval','1'] if interface=='native' else ['/Library/Frameworks/R.framework/Resources/bin/Rscript','--vanilla',H/'r_case.R',P/'library',c['connected']['path'],B/'dgraphs_ian.so',child]
    execute(cmd,folder);check=v.retry_checks(child,folder/'certificates');result[interface]=check['attempts'];print(name,interface,check['attempts'],flush=True)
   exact=v.exact(P/'runs'/name/'native/child/trace.jsonl',P/'runs'/name/'R/child/trace.jsonl');assert exact['passed'],(name,exact);result['native_R_exact']=exact
  L['cases'][name]=result;save()
 L['complete']=True;save()
except BaseException as e:L['error']=repr(e);save();raise
