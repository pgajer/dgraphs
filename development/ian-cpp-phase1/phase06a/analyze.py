"""No-solve evidence census and raw/checkpoint reconstruction for Phase06A."""
import argparse
import sys
from pathlib import Path
import numpy as np

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'phase04'))
from support import revision,load,write,sha,traces,check_lp,inspect_run

p=argparse.ArgumentParser();p.add_argument('root',type=Path);p.add_argument('output',type=Path);a=p.parse_args()
rev=revision();a.output.mkdir(parents=True,exist_ok=False)
reg=load(a.root/'regressions-v1/checks.json');feas=load(a.root/'feasibility-v1/checks.json')
assert reg['complete'] and feas['complete']
raw=[]
for file in sorted(a.root.rglob('child/trace.jsonl')):
    for event in traces(file.parent):
        if event['event']=='solve':
            raw.append(dict(path=str(file),number=event['number'],intentional_invalid='/failures/invalid_solver/' in str(file),**check_lp(event)))
stage=a.root/'regressions-v1/stages/legacy/child/stages.json'
raw.append(dict(path=str(stage),number=0,intentional_invalid=False,**check_lp(load(stage)['disconnected']['solve'])))
assert sum(r['intentional_invalid'] for r in raw)==1
assert all(r['accepted'] != r['intentional_invalid'] for r in raw)
assert all(r['dual_valid'] for r in raw if not r['intentional_invalid'])
maxima={key:max(r[key] for r in raw if not r['intentional_invalid']) for key in
    ['normalized_primal','absolute_primal','objective_error','dual_stationarity','dual_negative','dual_relative_gap']}
checkpoints=[]
for graph_file in sorted(a.root.rglob('child/graph.json')):
    folder=graph_file.parent;graph=load(graph_file);status=load(folder/'status.json');events=traces(folder)
    stop=next(e for e in events if e['event']=='graph_stop')
    for key in ['edges','degrees','upper','components','isolates']:assert stop[key]==graph[key]
    coverage=inspect_run(folder)
    stages=[]
    for name in ['graph','scales','affinity']:
        f=folder/(name+'.json');assert f.exists()==status[name]
        if f.exists():
            data=load(f);assert data['stage']==name and data['status']=='validated'
            assert status[name+'_sha256']==sha(f)
            for key in ['input_sha256','source_sha256','configuration_sha256','mapping']:assert data[key]==graph[key]
            stages.append(name)
    kernel_error=None
    if status['affinity']:
        D2=np.asarray(next(e['D2'] for e in events if e['event']=='processed'))
        scales=np.asarray(load(folder/'scales.json')['internal_scales']);degree=np.asarray(graph['degrees'])
        inv=np.ones(len(scales));inv[degree>0]=1/scales[degree>0]
        power=(inv[None,:]*D2)*inv[:,None]
        expected=np.zeros_like(D2)
        np.exp(-power,where=power < -np.log(2*np.finfo(float).eps),out=expected)
        expected[expected<1e-8]=0;expected[degree==0,:]=0;expected[:,degree==0]=0;expected=np.maximum(expected,expected.T)
        K=np.asarray(load(folder/'affinity.json')['affinity'])
        assert np.array_equal(K==0,expected==0) and np.allclose(K,expected,atol=1e-7,rtol=1e-7)
        kernel_error=float(abs(K-expected).max())
    checkpoints.append(dict(folder=str(folder),stages=stages,topology_checks=len(coverage['topology']),affinity_error=kernel_error))
untraced=sum(c['total_solves'] for c in feas['clients'])+feas['r']['solves']
total=len(raw)+untraced
assert total<=700
full=[dict(name=r['name'],solves=r['coverage']['solves'],pruning=r['coverage']['pruning_iterations'],
    removed=r['coverage']['removed_edges'],exact=r['exact_except_seconds'],native=r['native']['passed'],evaluated=r['evaluated']['passed']) for r in reg['full']]
result=dict(revision=rev,total_solver_calls=total,traced_payloads=len(raw),accepted_payloads=sum(r['accepted'] for r in raw),
    intentional_invalid_payloads=1,untraced_interface_calls=untraced,
    untraced_validation='Typed output comparisons, repeated-call/duplicate invariants and explicit partial/error tests; no saved primal/dual payloads for observer-free C++/R calls.',
    maxima=maxima,raw_checks=raw,checkpoints=checkpoints,checkpoint_artifacts=sum(len(c['stages']) for c in checkpoints),
    complete_runs=full,probe_cases=len(reg['probes']),probe_solves=sum(len(c['raw']) for c in reg['probes']),
    r_checks=(a.root/'feasibility-v1/r-result/checks.txt').read_text(),
    feasibility_sha256=sha(a.root/'feasibility-v1/checks.json'),regression_sha256=sha(a.root/'regressions-v1/checks.json'))
write(a.output/'results.json',result)
lines=['# Phase06A derived regression results','',
    '| Input | Solves | Pruning iterations | Edges removed | Native trace exact except time | Evaluated-Python limits |',
    '|---|---:|---:|---:|---|---|']
for r in full:lines.append(f"| {r['name']} | {r['solves']} | {r['pruning']} | {r['removed']} | {r['exact']} | {r['evaluated']} |")
lines += ['',f'Total new solver calls: {total}. Saved payloads: {len(raw)}, including one intentional invalid-vector test. Observer-free interface calls: {untraced}.',
          f'Validated saved stage artifacts: {result["checkpoint_artifacts"]}. No new resume or process-death test.']
(a.output/'tables.md').write_text('\n'.join(lines)+'\n')
print({k:result[k] for k in ['total_solver_calls','traced_payloads','accepted_payloads','untraced_interface_calls','checkpoint_artifacts','maxima']})
