"""Read-only census, certificate checks and descriptive performance summaries."""
import sys,json,statistics,hashlib,itertools
from pathlib import Path
H=Path(__file__).resolve().parent;ROOT=H.parents[3]
sys.path.insert(0,str(ROOT/'development/ian-cpp-phase1/phase07e'));import validate as v
v.POLICY='IAN evaluated-LP retry-power 0.1'
P=Path(sys.argv[1]);load=lambda p:json.loads(Path(p).read_text());write=lambda p,v:Path(p).write_text(json.dumps(v,indent=2)+'\n');L=load(P/'ledger.json');M=load(P/'manifest.json')
assert L['complete'] and L['entries']==110 and L['attempts']==5166
assert len(L['processes'])==23 and all(x['state']=='reaped' and x['exit_code']==0 and x['reason'] is None for x in L['processes'])
assert len(L['reservations'])==23 and sum(x['entries'] for x in L['reservations'])==110
stats=lambda x:dict(n=len(x),median=statistics.median(x),minimum=min(x),maximum=max(x))
rows=[]
for f in sorted(P.glob('block-*/child/*/timing.json')):
 d=load(f);d['interface']=f.parents[2].name.split('-')[-1];d['block']=int(f.parents[2].name.split('-')[1]);rows.append(d)
assert len(rows)==96
summary=dict(entries=L['entries'],attempts=L['attempts'],processes=23,qualification_entries=8,qualification_attempts=360,persistent_entries=96,persistent_attempts=4320,checkpoint_entries=6,checkpoint_attempts=486,wall_seconds=sum(x['wall_seconds'] for x in L['processes']),peak_rss_bytes=max(x['root_peak_rss_bytes'] for x in L['processes']),steady={},warmup={},memory={},setup={},checkpoint={},full_payloads_checked=0,source_revision=M['revision'])
for interface in ['native','evaluated','R']:
 summary['steady'][interface]={};summary['warmup'][interface]={}
 for c in M['cases']:
  sample=[r for r in rows if r['interface']==interface and r['fixture']==c['name']]
  if not sample:continue
  steady=[r for r in sample if r['rep']>0];assert len(steady)==9
  fields=['total','initialization','pruning','final','solver_recorded'] if interface!='R' else ['total','native_bridge','graph_conversion','wrapper_other']
  summary['steady'][interface][c['name']]={k:stats([r[k] for r in steady]) for k in fields}
  summary['warmup'][interface][c['name']]=stats([r['total'] for r in sample if r['rep']==0])
 procs=[x for x in L['processes'] if x['label'].startswith('block-') and x['label'].endswith('-'+interface)]
 summary['memory'][interface]=stats([x['root_peak_rss_bytes']/2**20 for x in procs])
 summary['setup'][interface]=stats([load(P/x['label']/'child/setup.json')['seconds'] for x in procs])
for interval in [1,2000]:
 samples=[load(p/'child/resources.json') for p in P.glob(f'checkpoint-*-{interval}') if p.is_dir()]
 summary['checkpoint'][str(interval)]=samples
# Every newly retained full payload, including checkpoint diagnostic attempts.
for rec in L['processes']:
 if rec['label'].startswith('block'):continue
 child=P/rec['label']/'child';child=child/'0' if rec['label'].startswith('qual') else child
 out=P/'certificate-census'/rec['label'];checks=v.retry_checks(child,out);summary['full_payloads_checked']+=checks['attempts']
 if rec['label'].startswith('checkpoint'):
  baseline=P/'qual-native-helix_500/child/0/trace.jsonl'
  for a,b in itertools.zip_longest(v.events(baseline),v.events(child/'trace.jsonl')):
   assert a is not None and b is not None
   if a['event']=='solve':assert {k:x for k,x in a.items() if k!='seconds'}=={k:x for k,x in b.items() if k!='seconds'}
assert summary['full_payloads_checked']==846
write(P/'summary.json',summary);write(P/'timing-rows.json',rows)
print(json.dumps({k:summary[k] for k in ['entries','attempts','processes','wall_seconds','full_payloads_checked','memory','setup']},indent=2))
