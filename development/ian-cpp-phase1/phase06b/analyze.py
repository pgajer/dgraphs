"""Streaming no-solve census, checkpoint-state reconstruction, and resource summary."""
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path
import numpy as np
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'phase04'))
from support import revision,load,write,sha,check_lp
p=argparse.ArgumentParser();p.add_argument('root',type=Path);p.add_argument('output',type=Path);a=p.parse_args()
rev=revision();a.output.mkdir(parents=True,exist_ok=False)
reg1=load(a.root/'regressions-v1/checks.json');reg2=load(a.root/'regressions-v2/checks.json')
recovery=load(a.root/'recovery-v1/checks.json');schema=load(a.root/'schema-v1/checks.json')
assert all(x['complete'] for x in [reg1,reg2,recovery,schema])
raw=[];snapshots=[];stages=[];resource_records=[]
tool=a.root/'build-v3/ian_checkpoint_tool'
# Re-dumping a snapshot with the native helper checks the stored canonical payload
# digest. State-vs-trace reconstruction below is separate from that format check.
for trace in sorted(a.root.rglob('child/trace.jsonl')):
    folder=trace.parent;checkpoints={}
    for cp in sorted((folder/'checkpoints').glob('checkpoint-*.json')):
        j=load(cp);assert j['trace_file']==str(trace)
        checkpoints[j['trace_prefix_events']]=(cp,j)
    running=hashlib.sha256();byte_count=0;last_solve=None;last_ratios=None
    with trace.open('rb') as f:
        for count,line in enumerate(f,1):
            byte_count+=len(line);running.update(line);event=json.loads(line)
            if event['event']=='solve':
                last_solve=event
                raw.append(dict(path=str(trace),number=event['number'],
                    intentional_invalid='/failures/invalid_solver/' in str(trace),**check_lp(event)))
            if event['event']=='volume':last_ratios=event['ratios']
            if count not in checkpoints:continue
            cp,j=checkpoints.pop(count);state=j['payload']
            assert j['trace_prefix_bytes']==byte_count and j['trace_prefix_sha256']==running.hexdigest()
            assert event['event']==('pruned' if state['boundary']=='pruning' else 'graph_stop')
            assert state['iteration']==event['iteration'] and state['solves']==last_solve['number']+1
            assert state['multiplier']==last_solve['C'] and state['last_stats']==last_ratios and state['cache']
            for key,other in [('edges','edges'),('degrees','degrees'),('upper','upper')]:assert state[key]==event[other]
            n=len(state['degrees']);degree=np.zeros(n,dtype=int)
            edges=np.asarray(state['edges'],dtype=int).reshape(-1,2)
            assert np.all(edges[:,0]<edges[:,1]) and np.all(edges>=0) and np.all(edges<n)
            np.add.at(degree,edges.ravel(),1);assert degree.tolist()==state['degrees']
            assert state['edges']==sorted(state['edges']) and len({tuple(e) for e in state['edges']})==len(state['edges'])
            if j['parent_checkpoint']:assert sha(Path(j['parent_checkpoint']))==j['parent_checkpoint_sha256']
            checkfile=a.output/('snapshot-%05d.json'%len(snapshots))
            subprocess.run([str(tool),str(cp),str(checkfile)],check=True)
            assert load(checkfile)==j
            snapshots.append(dict(file=str(cp),boundary=state['boundary'],iteration=state['iteration'],
                solves=state['solves'],prefix_valid=True,state_matches_trace=True,digest_roundtrip=True))
    assert not checkpoints
    status=load(folder/'status.json') if (folder/'status.json').exists() else None
    for stage in ['graph','scales','affinity']:
        path=folder/(stage+'.json')
        if not path.exists():continue
        data=load(path)
        assert status and status[stage] and status[stage+'_sha256']==sha(path)
        assert data['stage']==stage and data['status']=='validated'
        stages.append(dict(file=str(path),hash_valid=True))
    if (folder/'resources.json').exists():
        data=load(folder/'resources.json')
        assert all(v>=0 for v in data['phase_wall_seconds'].values())
        assert sum(data['phase_wall_seconds'].values())<=data['elapsed_seconds']+1e-6
        resource_records.append(dict(folder=str(folder),**data))

for label in ['regressions-v1','regressions-v2']:
    path=a.root/label/'stages/legacy/child/stages.json'
    raw.append(dict(path=str(path),number=0,intentional_invalid=False,**check_lp(load(path)['disconnected']['solve'])))
assert len(raw)==460*2+recovery['total_solver_calls']+schema['total_solver_calls']==1300
assert sum(c['intentional_invalid'] for c in raw)==2
assert all(c['accepted']!=c['intentional_invalid'] for c in raw)
assert all(c['dual_valid'] for c in raw if not c['intentional_invalid'])
maxima={key:max(c[key] for c in raw if not c['intentional_invalid']) for key in
        ['normalized_primal','absolute_primal','objective_error','dual_stationarity','dual_negative','dual_relative_gap']}
resources=[]
for name in ['hellinger_256_perturbed','hellinger_300_perturbed']:
    observations=[]
    for label in ['regressions-v1','regressions-v2']:
        proc=load(a.root/label/'full'/name/'process.json')
        measurements=load(a.root/label/'full'/name/'child/resources.json')
        observations.append(dict(run=label,wall_seconds=proc['end_to_end_seconds'],peak_rss_bytes=proc['root_peak_rss_bytes'],
                                 checkpoint_seconds=measurements['phase_wall_seconds']['checkpoint_io']))
    resources.append(dict(input=name,observations=observations))
result=dict(revision=rev,total_solver_calls=len(raw),accepted_payloads=sum(c['accepted'] for c in raw),
    intentional_invalid_payloads=2,maxima=maxima,raw_checks=raw,snapshots=snapshots,
    stage_artifacts=stages,resources=resource_records,resource_comparison=resources,
    regression_workloads=2,recovery_executions=len(recovery['runs']),continuation_comparisons=len(recovery['comparisons']),
    corruption_mutations=len(recovery['mutations']),output_ownership_checks=len(recovery['output_ownership']),
    schema_cases=len(schema['cases']),complete=True)
write(a.output/'results.json',result)
print({key:result[key] for key in ['total_solver_calls','accepted_payloads','intentional_invalid_payloads','maxima',
      'recovery_executions','continuation_comparisons','corruption_mutations','output_ownership_checks','schema_cases']})
print('Validated snapshot records:',len(snapshots),'stage artifacts:',len(stages),'resource records:',len(resource_records))
