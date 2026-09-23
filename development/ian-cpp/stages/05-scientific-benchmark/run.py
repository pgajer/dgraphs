"""Serial full-trace paired trajectories on the prospectively frozen scientific panel."""
import sys,json,os,hashlib,shutil,itertools,subprocess
from pathlib import Path
H=Path(__file__).resolve().parent;ROOT=H.parents[3];P=Path(sys.argv[1])
sys.path.insert(0,str(H.parent/'01-numerical-policy'));from guard import run,reserve,write
sys.path.insert(0,str(ROOT/'development/ian-cpp-phase1/phase07e'));import validate as v
v.POLICY='IAN evaluated-LP retry-power 0.1'
load=lambda p:json.loads(Path(p).read_text());sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();M=load(P/'manifest.json')
assert sha(M['engine'])==M['engine_sha256']
assert all(sha(Path(M['reference'])/n)==s for n,s in M['reference_hashes'].items())
assert all(sha(c['path'])==c['input_sha256'] and sha(c['truth'])==c['truth_sha256'] for c in M['cases'])
L=dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),processes=[],cases={},complete=False,gate=True)
assert not (P/'ledger.json').exists();save=lambda:write(P/'ledger.json',L);save()
try:
 for c in M['cases']:
  results={}
  for interface in ['native','evaluated']:
   used=sum(x['optimizer_calls'] for x in L['processes']);wall=sum(x['wall_seconds'] for x in L['processes']);assert len(L['processes'])<30 and used+250<=8000 and wall<3600 and shutil.disk_usage(P).free>20*2**30
   folder=P/'runs'/c['name']/interface;child=folder/'child'
   cmd=[M['engine'],c['path'],child,'--interval','1'] if interface=='native' else [sys.executable,'-B',Path(M['reference'])/'reference.py',c['path'],child,'evaluated']
   reserve(P/'reservations.json',30,dict(case=c['name'],interface=interface,command=list(map(str,cmd))))
   r=run(cmd,folder,P,wall_limit=min(900,3600-wall),max_attempts=250);L['processes'].append(r);save()
   assert r['state']=='reaped' and r['reason'] is None,r
   status=load(child/'status.json');assert r['exit_code'] in [0,1]
   numerical=v.retry_checks(child,folder/'certificates',allow_terminal_rejection=not status['complete']);assert numerical['attempts']==r['optimizer_calls']==status['solves']
   if status['complete']:assert v.inspect(child,c['path'],folder/'inspection')['valid']
   if interface=='native':
    for e in v.events(child/'trace.jsonl'):
     if e['event']=='solve':assert len(e['settings'])==41 and e['settings']['settings_layout_verified'] and e['settings']['max_threads']==1
   results[interface]=status
   print(c['name'],interface,'complete' if status['complete'] else 'refused',r['optimizer_calls'],flush=True)
  base=P/'runs'/c['name'];check=v.compare(base/'native/child/trace.jsonl',base/'evaluated/child/trace.jsonl',base/'comparison')
  exact=True;metadata=True
  for a,b in itertools.zip_longest(v.events(base/'native/child/trace.jsonl'),v.events(base/'evaluated/child/trace.jsonl')):
   if a is None or b is None:exact=False;metadata=False;break
   metadata &= all(a.get(k)==b.get(k) for k in v.ADDED)
   if a['event']=='solve' and b['event']=='solve':exact &= all(a[k]==b[k] for k in ['A_data','A_indices','A_indptr','A_shape','b','c','upper'])
  check.update(exact_coefficients=exact,retry_metadata_equal=metadata);paired=check['passed'] and exact and metadata and results['native']['complete']==results['evaluated']['complete']
  L['cases'][c['name']]=dict(results=results,comparison=check,paired=paired);L['gate'] &= paired;save();assert paired,'native/Python discrepancy'
 L['complete']=True;save()
except BaseException as e:L['error']=repr(e);save();raise
