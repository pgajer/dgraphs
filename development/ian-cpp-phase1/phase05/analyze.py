"""Recompute numerical evidence and derive phase05 tables, without optimization."""
import argparse
import math
import sys
import warnings
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent/'phase04'))
from support import load, write, sha, revision, traces, check_lp, inspect_run, graph_units
from compare import arrays

p = argparse.ArgumentParser()
p.add_argument('root', type=Path)
p.add_argument('output', type=Path)
a = p.parse_args()
rev = revision()
a.output.mkdir(parents=True, exist_ok=False)
ledgers = {name:load(a.root/path/'ledger.json') for name,path in
           [('probes','probes-v2'), ('full','full-v1'), ('stages','stages-v1')]}
assert all(l['complete'] for l in ledgers.values())
assert [len(ledgers[k]['runs']) for k in ['probes','full','stages']] == [36,12,3]
raw, dot_checks = [], []
for file in sorted(a.root.rglob('child/trace.jsonl')):
    with file.open() as stream:
        for line in stream:
            import json
            e = json.loads(line)
            if e['event'] != 'solve':
                continue
            raw.append(dict(file=str(file), number=e['number'], **check_lp(e)))
            # Re-evaluate dense diagnostics using saved finite vectors; no new solve.
            with warnings.catch_warnings(record=True) as caught:
                warnings.simplefilter('always')
                primal = float(np.asarray(e['c']) @ np.asarray(e['scales']))
                dual = float(np.asarray(e['b']) @ np.asarray(e['dual']))
            fsp = math.fsum(float(x)*float(y) for x,y in zip(e['c'],e['scales']))
            fsd = math.fsum(float(x)*float(y) for x,y in zip(e['b'],e['dual']))
            dot_checks.append(dict(file=str(file), number=e['number'],
                finite=bool(np.isfinite([primal,dual,fsp,fsd]).all()),
                relative_difference=max(abs(primal-fsp)/max(1,abs(fsp)),abs(dual-fsd)/max(1,abs(fsd))),
                warnings=[str(w.message) for w in caught]))
assert raw and all(c['accepted'] and c['dual_valid'] for c in raw)
assert all(c['finite'] and c['relative_difference'] <= 1e-7 for c in dot_checks)
maxima = {k:max(c[k] for c in raw) for k in ['normalized_primal','absolute_primal',
    'objective_error','dual_stationarity','dual_negative','dual_relative_gap','lower_violation','upper_violation']}
warning_logs = []
for file in sorted(a.root.rglob('stderr.log')):
    if 'RuntimeWarning' in file.read_text():
        warning_logs.append(dict(file=str(file), sha256=sha(file), text=file.read_text()))
write(a.output/'dense-dot-diagnostic.json',dict(checks=dot_checks, original_logs=warning_logs,
    note='No-solve recomputation of saved dot products, compared to math.fsum. Does not identify the origin of floating-point warnings during execution.'))

full = []
checkpoints = []
for key,item in ledgers['full']['runs'].items():
    folder = Path(item['folder'])
    coverage = inspect_run(folder)
    assert coverage['eligible']
    status, graph = load(folder/'status.json'), load(folder/'graph.json')
    events = traces(folder)
    stopped = next(e for e in events if e['event']=='graph_stop')
    for k in ['edges','degrees','components','isolates','upper']:
        assert graph[k] == stopped[k]
    for stage in ['graph','scales','affinity']:
        f = folder/(stage+'.json')
        assert status[stage] and status[stage+'_sha256'] == sha(f)
        payload = load(f)
        assert payload['stage']==stage and payload['status']=='validated'
        assert payload['input_sha256']==item['input_sha256']==sha(item['input'])
        for field in ['source_sha256','configuration_sha256','mapping']:
            assert payload[field]==graph[field]
    D2 = np.asarray(next(e['D2'] for e in events if e['event']=='processed'))
    scales = np.asarray(load(folder/'scales.json')['internal_scales'])
    degree = np.asarray(graph['degrees'])
    inv = np.ones(len(scales))
    inv[degree>0] = 1/scales[degree>0]
    power = (inv[None,:]*D2)*inv[:,None]
    expected = np.zeros_like(D2)
    np.exp(-power,where=power < -np.log(2*np.finfo(float).eps),out=expected)
    expected[expected<1e-8]=0
    expected[degree==0,:]=0
    expected[:,degree==0]=0
    expected=np.maximum(expected,expected.T)
    K = np.asarray(load(folder/'affinity.json')['affinity'])
    assert np.array_equal(K==0,expected==0) and arrays(K,expected,1e-7,1e-7)['pass_limit']
    checkpoints.append(dict(key=key, path=str(folder), all_stage_hashes=True,
        reconstructed_affinity_max_error=float(abs(K-expected).max()),
        native_units=graph_units(folder) if key.endswith('/native') else None))
    full.append(dict(key=key, solves=coverage['solves'], pruning_iterations=coverage['pruning_iterations'],
        removed_edges=coverage['removed_edges'], extra_pruning_solves=coverage['additional_pruning_retune_solves'],
        final_retuning_solves=coverage['final_retuning_solves'], topology=coverage['topology'][-1],
        topology_changes=coverage['topology_changes'], process=item['process']))

probes = []
for key,item in ledgers['probes']['runs'].items():
    folder = Path(item['folder'])
    events, result = traces(folder), load(folder/'result.json')
    probes.append(dict(key=key, solves=item['check']['solves'], C=result['C'], median=result['median'],
        candidates=result['decision']['candidates'], selected=result['selected'], removed=result['removed'],
        active_minimum_threshold_margin=min(abs(m) for r,m in zip(result['ratios'],result['decision']['threshold_margins']) if r>0),
        retune_events=[e for e in events if e['event'] in ['retune_eval','retune_stop','predicate']]))
stage_values = load(Path(ledgers['stages']['runs']['stage-probes/original']['folder'])/'stages.json')
comparisons = {name:l['comparisons'] for name,l in ledgers.items()}
summary = dict(revision=rev, raw_count=len(raw), valid_raw_count=len(raw), raw_maxima=maxima,
    calibration=load(a.root/'calibration-v1/manifest.json')['calibrations'],
    calibration_solves=28, probe_solves=sum(r['solves'] for r in probes),
    full_solves=sum(r['solves'] for r in full), raw_checks=raw, full=full, probes=probes,
    stages=stage_values, comparisons=comparisons, checkpoints=checkpoints,
    all_native_comparisons_passed=all(v['passed'] for l in comparisons.values() for k,v in l.items() if k.endswith('/implementation')),
    all_historical_discrete_agreed=all(v.get('discrete_agreement',v['passed']) for l in comparisons.values() for k,v in l.items() if k.endswith('/historical')),
    original_warning_log_count=len(warning_logs), dot_recheck_warning_count=sum(len(c['warnings']) for c in dot_checks),
    dot_recheck_max_relative_difference=max(c['relative_difference'] for c in dot_checks))
assert summary['raw_count']==summary['calibration_solves']+summary['probe_solves']+summary['full_solves']
write(a.output/'results.json',summary)
lines=['# Derived phase05 results','',
    '| Complete input | Condition | Solves | Pruning iterations | Removed edges | Extra pruning solves | Final retuning solves | Isolates |',
    '|---|---|---:|---:|---:|---:|---:|---:|']
for r in full:
    name,condition=r['key'].split('/')
    lines.append(f"| {name} | {condition} | {r['solves']} | {r['pruning_iterations']} | {r['removed_edges']} | {r['extra_pruning_solves']} | {r['final_retuning_solves']} | {len(r['topology']['isolates'])} |")
lines += ['', '| Case | Comparison | Strict comparison passed | Discrete agreement | Failed events |', '|---|---|---|---|---:|']
for group in ['probes','full']:
    for key,c in comparisons[group].items():
        name,pair=key.split('/')
        lines.append(f"| {name} | {pair} | {c['passed']} | {c['discrete_agreement']} | {len(c['failing_events'])} |")
(a.output/'tables.md').write_text('\n'.join(lines)+'\n')
print({k:summary[k] for k in ['raw_count','probe_solves','full_solves','raw_maxima','all_native_comparisons_passed','all_historical_discrete_agreed','original_warning_log_count','dot_recheck_warning_count']})
