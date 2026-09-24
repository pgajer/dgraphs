"""Read-only stage-2 census and checkpoint binding checks; no optimization."""
import sys,json,hashlib,subprocess,collections
from pathlib import Path
root=Path(sys.argv[1]).resolve();load=lambda p:json.loads(Path(p).read_text());sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
write=lambda p,v:Path(p).write_text(json.dumps(v,indent=2)+'\n')
ledger=load(root/'panel-v1/ledger.json');fm=load(root/'fixtures-v1/manifest.json');build=Path(fm['build']);bm=load(build/'manifest.json');tool=build/'checkpoint_tool'
assert sha(tool)==load(build.parent/'manifest.json')['files'][str(tool)]
assert ledger['complete'] and ledger['gate'] and len(ledger['processes'])==12 and len(ledger['comparisons'])==6
assert all(p['state']=='reaped' and p['reason'] is None and p['exit_code']==0 for p in ledger['processes'])
assert all(c['passed'] and c['exact_coefficients'] for c in ledger['comparisons'].values())
checks=[];counts={};cpout=root/'checkpoint-checks';cpout.mkdir(exist_ok=True)
for case in fm['fixtures']:
 name=case['name'];child=root/'panel-v1/runs'/name/'native/child';counts[name]=collections.Counter()
 for line in (child/'trace.jsonl').open():
  e=json.loads(line);counts[name][e['event']]+=1
  if e['event']=='solve':counts[name]['accepted' if e['accepted'] else 'rejected']+=1;counts[name]['retry']+=e['attempt']==1
 counts[name]=dict(counts[name]);graph=load(child/'graph.json');counts[name]['final_edges']=len(graph['edges'])
 for cp in sorted((child/'checkpoints').glob('checkpoint-*.json')):
  j=load(cp);dst=cpout/(name+'-'+cp.name);subprocess.run([str(tool),str(cp),str(dst)],check=True)
  assert load(dst)['payload_sha256']==j['payload_sha256']
  running=hashlib.sha256();size=0;count=0
  with Path(j['trace_file']).open('rb') as f:
   for line in f:
    if count==j['trace_prefix_events']:break
    running.update(line);size+=len(line);count+=1
  assert count==j['trace_prefix_events'] and size==j['trace_prefix_bytes'] and running.hexdigest()==j['trace_prefix_sha256']
  assert j['input_file_sha256']==sha(case['path']) and j['payload']['policy']=='IAN evaluated-LP retry-power 0.1'
  assert j['payload']['source']==bm['source_identity'] and j['payload']['configuration']==bm['configuration_identity']
  if j['parent_checkpoint']:assert sha(j['parent_checkpoint'])==j['parent_checkpoint_sha256']
  checks.append(dict(path=str(cp),valid=True,boundary=j['payload']['boundary'],iteration=j['payload']['iteration'],solves=j['payload']['solves']))
summary=dict(execution_complete=True,independent_audit='pending',policy='IAN evaluated-LP retry-power 0.1',process_launches=len(ledger['processes']),attempts=sum(p['optimizer_calls'] for p in ledger['processes']),child_wall_seconds=sum(p['wall_seconds'] for p in ledger['processes']),sampled_tree_peak_rss_bytes=max(p['sampled_tree_peak_rss_bytes'] for p in ledger['processes']),case_counts=counts,checkpoint_checks=checks,all_paired_checks_pass=True,all_coefficients_exact=True,prior_helix=fm['prior_helix'],limits='Single macOS arm64 native/Python panel at 1,000 rows; R >500 rows and larger sizes not qualified; no scientific utility or performance gain claim',reporting_revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip())
summary['warning_study']=load(root/'warning-study-v2/summary.json')
write(root/'summary.json',summary)
files={str(p):sha(p) for d in ['fixtures-v1','panel-v1','checkpoint-checks','warning-study-v1','warning-study-v2'] for p in (root/d).rglob('*') if p.is_file()}
files[str(root/'summary.json')]=sha(root/'summary.json');files[str(root/'run-v1.log')]=sha(root/'run-v1.log');write(root/'manifest.json',dict(files=files,optimizer_calls=0))
print(json.dumps({k:summary[k] for k in ['process_launches','attempts','child_wall_seconds','sampled_tree_peak_rss_bytes','case_counts']}))
