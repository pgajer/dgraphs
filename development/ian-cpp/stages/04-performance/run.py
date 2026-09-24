"""Bounded serial qualification and persistent measurements, immutable run folders."""
import sys,os,json,hashlib,subprocess,shutil,itertools
from pathlib import Path
H=Path(__file__).resolve().parent;ROOT=H.parents[3]
sys.path.insert(0,str(H.parent/'01-numerical-policy'));import guard
sys.path.insert(0,str(ROOT/'development/ian-cpp-phase1/phase07e'));import validate as v
v.POLICY='IAN evaluated-LP retry-power 0.1'
P=Path(sys.argv[1]);mode=sys.argv[2];load=lambda p:json.loads(Path(p).read_text());m=load(P/'manifest.json');write=guard.write
assert not subprocess.check_output(['git','status','--porcelain'],text=True)
assert hashlib.sha256((P/'native').read_bytes()).hexdigest()==m['native_sha256']
for c in m['cases']:assert hashlib.sha256(Path(c['path']).read_bytes()).hexdigest()==c['sha256']
ledger=load(P/'ledger.json') if (P/'ledger.json').exists() else dict(processes=[],reservations=[],entries=0,attempts=0,complete=False)
save=lambda:write(P/'ledger.json',ledger)
def execute(label,cmd,entries):
 assert label not in [p['label'] for p in ledger['reservations']]
 seconds=sum(p['wall_seconds'] for p in ledger['processes'])
 assert sum(p['entries'] for p in ledger['reservations'])+entries<=128 and ledger['attempts']+250*entries<=20000 and seconds<3600 and shutil.disk_usage(P).free>20*2**30
 ledger['reservations'].append(dict(label=label,entries=entries,command=list(map(str,cmd))));save()
 r=guard.run(cmd,P/label,P,wall_limit=min(900,3600-seconds),max_attempts=250*entries)
 child=P/label/'child';account=child/'account.jsonl';rows=[json.loads(s) for s in account.read_text().splitlines()] if account.exists() else []
 observed=sum(s['event']=='entry' for s in rows);returned=[s for s in rows if s['event']=='returned'];attempts=sum(s['solves'] for s in returned)
 if not account.exists():observed=1;attempts=r['optimizer_calls']
 r.update(label=label,engine_entries=observed,optimizer_calls=attempts,unknown_unreturned_entries=observed-len(returned) if account.exists() else 0)
 ledger['processes'].append(r);ledger['entries']+=observed;ledger['attempts']+=attempts+250*r['unknown_unreturned_entries'];save()
 assert r['exit_code']==0 and r['state']=='reaped' and r['reason'] is None,r
 assert observed==entries and r['unknown_unreturned_entries']==0
 return child

def worker(label,interface,cases,full,repeats):
 schedule={**m,'cases':cases,'full':full,'repeats':repeats};sp=P/(label+'.json');write(sp,schedule)
 for k in ['R_HOME','R_LIBS','R_LIBS_USER','R_LIBS_SITE']:os.environ.pop(k,None)
 if interface=='R':os.environ.update(m['r_environment']);cmd=[m['rscript'],'--vanilla',H/'r_worker.R',sp,P/label/'child']
 elif interface=='native':cmd=[P/'native',sp,P/label/'child']
 else:cmd=[sys.executable,'-B',H/'python_worker.py',sp,P/label/'child']
 return execute(label,cmd,len(cases)*repeats)

def compare_results(a,b):
 import numpy as np
 assert a['complete'] and b['complete']
 for k in ['initial_edges','edges']:assert sorted(map(tuple,a[k]))==sorted(map(tuple,b[k])),k
 for k in ['scales','affinity']:assert np.array_equal(np.asarray(a[k]),np.asarray(b[k])),k
 assert a['history']==b['history'],'history'

if mode=='qualify':
 for c in m['cases']:
  for interface in ['native','evaluated']+(['R'] if c['name']!='quadform_d4_1000' else []):
   label='qual-'+interface+'-'+c['name'];child=worker(label,interface,[c],True,1);trace=child/'0/trace.jsonl'
   baseline=Path(c['baseline'])/('native' if interface=='R' else interface)/'child/trace.jsonl'
   check=v.compare(baseline,trace,P/label/'comparison');assert check['passed'],check
   checks=v.retry_checks(child/'0',P/label/'certificates');
   for a,b in itertools.zip_longest(v.events(baseline),v.events(trace)):
    assert a is not None and b is not None
    if a['event']=='solve':assert all(a[k]==b[k] for k in ['A_data','A_indices','A_indptr','A_shape','b','c','upper','scales','dual']), 'exact solve payload'
   print(label,'passed',flush=True)
 ledger['qualification_complete']=True;save()
elif mode=='measure':
 assert ledger.get('qualification_complete')
 for block,order in enumerate([['native','evaluated','R'],['evaluated','R','native'],['R','native','evaluated']]):
  for interface in order:
   cases=m['cases'][:2] if interface=='R' else m['cases'];label=f'block-{block}-{interface}';child=worker(label,interface,cases,False,4)
   for i,c in enumerate(cases):
    b=load(P/('qual-'+interface+'-'+c['name'])/'child/0/result.json')
    for rep in range(4):compare_results(load(child/str(i*4+rep)/'result.json'),b)
   print(label,'all repetitions exact',flush=True)
 # JSON is a rounded R projection; binary objects are the exact R regression evidence.
 cmd=[m['rscript'],'--vanilla',str(H/'check_rds.R'),str(P),str(P/'exact-rds-checks')]
 with (P/'exact-rds-checks.log').open('w') as stream:subprocess.run(cmd,stdout=stream,stderr=subprocess.STDOUT,check=True,timeout=300)
 ledger['exact_RDS_check_command']=cmd
 ledger['measurement_complete']=True;save()
elif mode=='checkpoint':
 assert ledger.get('measurement_complete');c=m['cases'][1];engine=P.parent/'stage01-policy/build-v1/engine'
 for rep in range(3):
  for interval in ([1,2000] if rep%2==0 else [2000,1]):
   label=f'checkpoint-{rep}-{interval}';child=execute(label,[engine,c['path'],P/label/'child','--interval',str(interval)],1)
   check=v.compare(P/('qual-native-'+c['name'])/'child/0/trace.jsonl',child/'trace.jsonl',P/label/'comparison');assert check['passed']
 ledger['checkpoint_complete']=True;ledger['complete']=True;save()
else:raise ValueError(mode)
