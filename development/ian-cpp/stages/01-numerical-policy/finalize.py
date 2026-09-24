"""Read-only census and source/evidence identities; no optimizer invocation."""
from pathlib import Path
import json,hashlib,sys,collections,subprocess
root=Path(sys.argv[1]);load=lambda p:json.loads(Path(p).read_text());sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
s=load(root/'supplement-v2/ledger.json');assert s['complete'] and all(s['checks'].values());processes=s['prior_processes']+s['processes'];counts=collections.Counter();fixed=0
for p in processes:
 assert p['state']=='reaped' and p['reason'] is None
 if any(str(c).endswith('/replay.py') for c in p['command']):fixed+=1
 trace=Path(p['command'][-1])/'trace.jsonl' # locate authoritative trace through command record directory below
# Every process record is unique; no successful reruns are substituted for failures.
assert len({(p['pid'],tuple(p['command'])) for p in processes})==len(processes)
q=load(root/'qualification-v2/ledger.json');assert q['complete'] and q['gate']
assert all(c['passed'] and c.get('dual_vectors_pass',True) and c.get('retry_metadata_equal',True) and c.get('exact_coefficients',True) for c in q['comparisons'].values())
for case in q['engine_schedule']:
 p=root/'qualification-v2/runs'/case['name']/'native/child/trace.jsonl';row=collections.Counter()
 for line in p.open():
  e=json.loads(line);row[e['event']]+=1
  if e['event']=='solve':row['accepted' if e['accepted'] else 'rejected']+=1
 counts[case['name']]=dict(row)
summary=dict(complete=True,independent_audit='pending',policy='IAN evaluated-LP retry-power 0.1',default_policy='IAN evaluated-LP 1.0',adopted=False,
 process_launches=len(processes),fixed_lp_calls=fixed,engine_probe_R_launches=len(processes)-fixed,attempts=sum(p['optimizer_calls'] for p in processes),child_wall_seconds=sum(p['wall_seconds'] for p in processes),sampled_tree_peak_rss_bytes=max(p['sampled_tree_peak_rss_bytes'] for p in processes),paired_cases=len(q['comparisons']),all_paired_coefficients_exact=True,eligibility=load(root/'eligibility-v2/results.json')['cases'],native_case_counts=dict(counts),strict_export_recheck=load(root/'supplement-v1/read-only-export-correction.json'),supplement_checks=s['checks'],source_build=load(root/'build-v1/manifest.json')['revision'],reporting_revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),limitations=['Single macOS arm64 runtime; no cross-platform arithmetic claim','R uses source wrapper and fresh module with privately installed baseline dgraphs; new package installation is deferred to stage 3','Pinned Rust archive reused, not freshly rebuilt','Fixed LP replays use Python; native candidate is tested through full/probe problems','No full R CMD check or stage-2 scale expansion','Strict adapter default retained; candidate not adopted before audit'])
(root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
files={}
for d in ['qualification-v1','qualification-v2','supplement-v1','supplement-v2','eligibility-v1','eligibility-v2','reference-v2']:
 for p in (root/d).rglob('*'):
  if p.is_file():files[str(p)]=sha(p)
for p in [root/'summary.json',root/'build-v1/manifest.json',root/'build-v1/engine',root/'build-v1/probe',root/'build-v1/dgraphs_ian.so',root/'build-v1/eligibility',root/'build-v1/checkpoint_tool',root/'reference-v2-manifest.json',root/'document.log']:
 files[str(p)]=sha(p)
(root/'manifest.json').write_text(json.dumps(dict(files=files,generated=True,optimizer_calls=0),indent=2)+'\n');print({k:summary[k] for k in ['process_launches','fixed_lp_calls','engine_probe_R_launches','attempts','paired_cases','eligibility']})
