"""Recompute all saved numerical evidence and regenerate full trajectory comparisons."""
import argparse,json,subprocess,sys
from pathlib import Path
import numpy as np
from compare import compare,traces,check_lp,kernel_checks
from reference import write,sha
p=argparse.ArgumentParser();p.add_argument('root',type=Path);p.add_argument('output',type=Path);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
manifest=json.loads((a.root/'fixtures-v1/manifest.json').read_text());rows=[];comparisons=[];all_numerics={}
for name in manifest['ordinary']:
 base=a.root/'cases-v1'/name;native=a.root/'native-verification-v1'/name/'child'
 for label,left,right in [('representation',base/'original/child',base/'evaluated/child'),('implementation',base/'evaluated/child',native)]:
  comp=compare(left,right,a.output/(name+'-'+label));assert comp['passed'];assert all(k['valid'] for k in comp['kernel_checks_a']+comp['kernel_checks_b'])
  summary=dict(case=name,comparison=label,events=comp['events_a'],passed=comp['passed'],maxima={})
  for r in comp['checks']:
   for key,v in r['numeric'].items():
    summary['maxima'][key]=max(summary['maxima'].get(key,0),v['max_absolute'])
  comparisons.append(summary)
 for condition,path in [('original',base/'original'),('evaluated',base/'evaluated'),('native',native.parent)]:
  events=traces(path/'child');process=json.loads((path/'process.json').read_text());final=events[-1];status=json.loads((path/'child/status.json').read_text());assert status['complete']
  for stage in ['graph','scales','affinity']:
   artifact=path/'child'/(stage+'.json');assert status[stage] and sha(artifact)==status[stage+'_sha256']
   data=json.loads(artifact.read_text());assert data['stage']==stage and data['status']=='validated' and all(k in data for k in ['input_sha256','configuration_sha256','source_sha256','mapping'])
  row=dict(case=name,condition=condition,vertices=len(final['scales']),initial_edges=len(next(e for e in events if e['event']=='processed')['initial_edges']),final_edges=len(final['edges']),pruning_iterations=sum(e['event']=='pruned' for e in events),removed_edges=sum(len(e['removed']) for e in events if e['event']=='pruned'),solve_count=sum(e['event']=='solve' for e in events),solver_iterations=sum(e['iterations'] for e in events if e['event']=='solve'),events=len(events),isolates=len(final['isolates']),components=len(set(next(e for e in events if e['event']=='graph_stop')['components'])),end_to_end_seconds=process['end_to_end_seconds'],peak_rss_bytes=process['root_peak_rss_bytes'],recorded_solve_wall_seconds=sum(e['seconds'] for e in events if e['event']=='solve'),retune_C=[e['C'] for e in events if e['event']=='solve'],status=status)
  rows.append(row)
# Count every actual solve once, including initial native runs, stage rechecks,
# rejected injected payload, final verification and explicitly changed cap tests.
raw=[]
for trace in sorted(a.root.rglob('trace.jsonl')):
 if trace.parent.name!='child':continue
 for e in traces(trace.parent):
  if e['event']=='solve':raw.append(dict(path=str(trace),number=e['number'],intentional_invalid='failures-v1/invalid_solver/' in str(trace),**check_lp(e)))
for bundle in ['stages-v1','stages-supplement-v1']:
 path=a.root/bundle/'native/child/stages.json';e=json.loads(path.read_text())['disconnected']['solve'];raw.append(dict(path=str(path),number=0,intentional_invalid=False,**check_lp(e)))
assert len(raw)==81,len(raw)
assert sum(r['intentional_invalid'] for r in raw)==1
assert all(r['accepted']!=r['intentional_invalid'] for r in raw)
assert all(r['dual_valid'] for r in raw if not r['intentional_invalid'])
passed=[r for r in raw if not r['intentional_invalid']]
maxima={key:max(r[key] for r in passed) for key in ['normalized_primal','absolute_primal','objective_error','dual_stationarity','dual_negative','dual_relative_gap','lower_violation','upper_violation']}
stage_results=[]
for bundle in ['stages-v1','stages-supplement-v1']:
 d=json.loads((a.root/bundle/'checks.json').read_text());assert all(p['exit_code']==0 for p in d['processes'].values())
 for check in d['checks']:assert check.get('passed',check.get('pass_limit',check.get('accepted',False))) and check.get('same_support',True)
 assert all(c['passed'] for c in d['refusals']);stage_results.append(dict(bundle=bundle,checks=len(d['checks']),refusals=len(d['refusals'])))
supp=json.loads((a.root/'stages-supplement-v1/evaluated/child/stages.json').read_text())['decisions'][-1]
assert supp['threshold']==supp['floored_threshold'] and supp['cap']<supp['threshold']<max(supp['stats'])
failures=json.loads((a.root/'failures-v1/checks.json').read_text());assert failures['all_passed']
verification=json.loads((a.root/'native-verification-v1/checks.json').read_text());assert verification['cap_passed'] and all(x['passed'] for x in verification['empty_refusals'])
result=dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),rows=rows,comparisons=comparisons,raw_solve_checks=raw,raw_numerical_maxima=maxima,total_optimizations=len(raw),valid_raw_payloads=len(passed),intentional_invalid_payloads=1,stage_results=stage_results,failures=failures,final_native_verification=verification)
write(a.output/'results.json',result)
lines=['# Derived small-engine comparison tables','','Twelve canonical rows: original/evaluated Python initial runs, final native verification runs. Initial native runs are retained separately; all their raw solves are checked.','','| Fixture | Condition | Initial/final edges | Pruning iterations | Solves | Solver iterations | Trace events | Process seconds | Peak MiB |','|---|---|---:|---:|---:|---:|---:|---:|---:|']
for r in rows:lines.append(f'| {r["case"]} | {r["condition"]} | {r["initial_edges"]}/{r["final_edges"]} | {r["pruning_iterations"]} | {r["solve_count"]} | {r["solver_iterations"]} | {r["events"]} | {r["end_to_end_seconds"]:.4f} | {r["peak_rss_bytes"]/2**20:.1f} |')
lines+=['','Times and memory are diagnostics, one run per condition and fixture; no speed or full-engine memory benefit is inferred.','','| Fixture | Comparison | Events checked | Max scale difference (see event-specific units) | Max ratio difference | Max affinity difference | Passed |','|---|---|---:|---:|---:|---:|---|']
for c in comparisons:lines.append(f'| {c["case"]} | {c["comparison"]} | {c["events"]} | {c["maxima"].get("scales",0):.9g} | {c["maxima"].get("ratios",0):.9g} | {c["maxima"].get("affinity",0):.9g} | {c["passed"]} |')
(a.output/'tables.md').write_text('\n'.join(lines)+'\n')
print(json.dumps(dict(optimizations=len(raw),valid_payloads=len(passed),intentional_invalid=1,comparisons_passed=len(comparisons),maxima=maxima),indent=2))
