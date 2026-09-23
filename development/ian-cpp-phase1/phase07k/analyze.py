"""No optimizer calls: validate all payloads and compare complete trajectories."""
import itertools,collections
from common import *
root=Path(sys.argv[1]);out=root/'analysis-v1';out.mkdir(exist_ok=False)
ledger=load(root/'ledger.json');assert ledger['complete'] and len(ledger['processes'])==14
assert len(load(root/'reservations.json')['reservations'])==14
summary=dict(solver_calls=ledger['optimizer_calls'],runs=[],comparisons={},read_only_analysis=True)
def command(args,folder):
 folder.mkdir(parents=True,exist_ok=False)
 cmd=[sys.executable,'-B',str(E/'validate.py'),*map(str,args)]
 with (folder/'stdout.log').open('w') as f:
  p=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT)
 assert p.returncode==0,folder
 return cmd
def trace(index):return root/f'runs/{index}/child/trace.jsonl'
def compare(label,a,b):
 folder=out/label
 command(['compare',a,b,folder/'checks'],folder)
 r=load(folder/'checks/summary.json');summary['comparisons'][label]=r
 return r
for i,p in enumerate(ledger['processes']):
 assert p['state']=='reaped' and p['reason'] is None
 child=trace(i).parent;folder=out/f'inspect-{i}'
 command(['inspect',child,p['cell']['fixture'],folder/'checks'],folder)
 checks=load(folder/'checks/summary.json');assert checks['valid']
 count=collections.Counter();trajectory=[];endpoint=None
 for e in events(trace(i)):
  count[e['event']]+=1
  if e['event']=='pruned':trajectory.append(dict(iteration=e['iteration'],edges=len(e['edges']),removed=len(e['removed'])))
  if e['event']=='complete':endpoint=dict(edges=len(e['edges']),profiles=len(e['scales']),isolates=len(e['isolates']))
 assert count['solve']==p['optimizer_calls']
 summary['runs'].append(dict(index=i,**p['cell'],status=load(child/'status.json'),counts=dict(count),retry_checks=checks['retry_checks'],trajectory=trajectory,endpoint=endpoint,wall_seconds=p['wall_seconds']))
 print('validated',i,count['solve'],flush=True)
for label,i,j in [('historical-pair',0,1),('multiply-pair',2,3),('power-pair',4,5),('native-multiply-control',0,2),('python-power-control',1,5),('power-native-vs-historical-python',4,1),('curve-pair',6,7),('patch-pair',8,9),('arms-pair',10,11),('pressmat-pair',12,13)]:
 r=compare(label,trace(i),trace(j));print(label,r['passed'],r['failures'],flush=True)
for i,interface in [(0,'native'),(1,'evaluated')]:
 r=compare('historical-reproduction-'+interface,W/f'phase07f/ladder-v1/helix_1000/{interface}/child/trace.jsonl',trace(i))
 # The unmodified baseline should reproduce every numerical/event value exactly.
 assert r['passed'] and r['exact_except_seconds']
cases={x['name']:x for x in load(W/'phase07e/engine-fixtures-v1/manifest.json')['cases']}
for i in range(6,14):
 cell=ledger['schedule'][i];baseline=Path(cases[cell['name']]['baseline'][cell['interface']])/'trace.jsonl'
 compare('small-historical-'+str(i),baseline,trace(i))
# Inspect every event, even when a historical comparison branches.
detail={}
for name,i,j in [('multiply',2,3),('power',4,5),('power-vs-python',4,1)]:
 counts=collections.Counter();maximum=0.;errors=[]
 for k,(a,b) in enumerate(itertools.zip_longest(events(trace(i)),events(trace(j)))):
  if a is None or b is None:errors.append([k,'length']);continue
  if a['event']!=b['event']:errors.append([k,'event']);continue
  counts['events']+=1
  if a['event']=='solve':
   counts['solves']+=1
   for key in ['A_data','A_indices','A_indptr','A_shape','b','c','upper','active','C']:
    if a[key]!=b[key]:errors.append([k,key])
   counts['accepted_scales_exact' if a['accepted'] else 'rejected_scales_exact']+=a['scales']==b['scales']
   counts['dual_exact']+=a['dual']==b['dual']
   maximum=max(maximum,max(abs(x-y) for x,y in zip(a['scales'],b['scales'])))
  if a['event'] in ['decision','pruned','retune_eval','retune_stop','complete']:
   keys={'decision':['candidates'],'pruned':['selected','removed','edges'],'retune_eval':['C','minC','maxC','bisection_index'],'retune_stop':['C','minC','maxC','bisection_updates','boundary_stop','median_target_met'],'complete':['edges']}[a['event']]
   for key in keys:
    if a[key]!=b[key]:errors.append([k,key])
  if a['event']=='complete':
   counts['final_scales_exact']=a['scales']==b['scales'];counts['final_affinities_exact']=a['affinity']==b['affinity']
 detail[name]=dict(counts=dict(counts),coefficient_and_decision_errors=errors,max_internal_scale_difference=maximum)
summary['full_detail']=detail
summary['accounting']=dict(reserved_processes=14,reaped_processes=14,wall_seconds=sum(p['wall_seconds'] for p in ledger['processes']),maximum_tree_rss_bytes=max(p['sampled_tree_peak_rss_bytes'] for p in ledger['processes']),source_revision=ledger['revision'])
summary['all_accepted_payloads_valid']=True
summary['bounded_power_compatibility_passed']=all(summary['comparisons'][k]['passed'] for k in ['power-pair','python-power-control','power-native-vs-historical-python','curve-pair','patch-pair','arms-pair','pressmat-pair']) and not detail['power']['coefficient_and_decision_errors']
write(out/'summary.json',summary)
print(json.dumps(dict(solver_calls=summary['solver_calls'],full_detail=detail,bounded_power_compatibility_passed=summary['bounded_power_compatibility_passed']),indent=2))
