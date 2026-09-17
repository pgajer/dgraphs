"""Recompute every raw payload and derive coverage tables without new solves."""
import argparse
from pathlib import Path
import numpy as np
from support import (revision, load, write, sha, traces, check_lp, inspect_run,
                     checked_comparison, graph_units, HERE)

p = argparse.ArgumentParser()
p.add_argument('root', type=Path)
p.add_argument('output', type=Path)
a = p.parse_args()
rev = revision()
a.output.mkdir(parents=True, exist_ok=False)
selection = load(a.root / 'search-v1/selection.json')
continuation = load(a.root / 'selected-continuation-v1/checks.json')
assert continuation['completed'] and continuation['all_implementation_comparisons_passed']
inventory = []
for item in selection['inventory']:
    row = inspect_run(Path(item['reference_child']))
    row.update(name=item['name'], vertices=len(load(item['input'])['features']),
               selected=item['name'] in [x['name'] for x in selection['selected']],
               process=load(Path(item['reference_child']).parent / 'process.json'))
    inventory.append(row)
comparisons = []
for row in continuation['selected']:
    comparison = dict(name=row['name'])
    for label, left, right in [('representation', row['original'], row['evaluated']),
                                ('implementation', row['evaluated'], row['native'])]:
        comparison[label] = checked_comparison(Path(left), Path(right), a.output / (row['name'] + '-' + label))
        final_a = np.asarray(load(Path(left) / 'affinity.json')['affinity'])
        final_b = np.asarray(load(Path(right) / 'affinity.json')['affinity'])
        comparison[label]['final_affinity_max_difference'] = float(abs(final_a - final_b).max())
        comparison[label]['final_affinity_support_exact'] = bool(np.array_equal(final_a == 0, final_b == 0))
    comparison['conditions'] = []
    for condition in ['original', 'evaluated', 'native']:
        folder = Path(row[condition])
        data = inspect_run(folder)
        data.update(condition=condition, path=str(folder), process=load(folder.parent / 'process.json'))
        comparison['conditions'].append(data)
    comparisons.append(comparison)

raw = []
for file in sorted(a.root.rglob('child/trace.jsonl')):
    for e in traces(file.parent):
        if e['event'] == 'solve':
            raw.append(dict(file=str(file), number=e['number'],
                            intentional_invalid='/failures/invalid_solver/' in str(file), **check_lp(e)))
stage = a.root / 'regressions-v1/stages/child/stages.json'
raw.append(dict(file=str(stage), number=0, intentional_invalid=False,
                **check_lp(load(stage)['disconnected']['solve'])))
assert len(raw) == 1343, len(raw)
assert sum(x['intentional_invalid'] for x in raw) == 1
assert all(x['accepted'] != x['intentional_invalid'] for x in raw)
assert all(x['dual_valid'] for x in raw if not x['intentional_invalid'])
maxima = {k: max(x[k] for x in raw if not x['intentional_invalid']) for k in
          ['normalized_primal', 'absolute_primal', 'objective_error', 'dual_stationarity',
           'dual_negative', 'dual_relative_gap', 'lower_violation', 'upper_violation']}

checkpoints = []
for file in sorted(a.root.rglob('child/graph.json')):
    folder = file.parent
    graph, status = load(file), load(folder / 'status.json')
    coverage = inspect_run(folder)
    assert coverage['topology'][-1]['edges'] == len(graph['edges'])
    event = next(x for x in traces(folder) if x['event'] == 'graph_stop')
    for key in ['edges', 'degrees', 'components', 'isolates', 'upper']:
        assert graph[key] == event[key]
    for stage in ['graph', 'scales', 'affinity']:
        path = folder / (stage + '.json')
        assert path.exists() == status[stage]
        if path.exists():
            data = load(path)
            assert data['stage'] == stage and data['status'] == 'validated'
            assert status[stage + '_sha256'] == sha(path)
            assert data['configuration_sha256'] == sha(HERE / 'config.json')
            for key in ['input_sha256', 'source_sha256', 'mapping']:
                assert data[key] == graph[key]
    native_metadata = graph_units(folder) if 'upper_units' in graph else None
    affinity_error = None
    if status['affinity']:
        processed = next(e for e in traces(folder) if e['event'] == 'processed')
        D2 = np.asarray(processed['D2'])
        scales = np.asarray(load(folder / 'scales.json')['internal_scales'])
        degree = np.asarray(graph['degrees'])
        inv = np.ones(len(scales))
        inv[degree > 0] = 1 / scales[degree > 0]
        power = (inv[None, :] * D2) * inv[:, None]
        expected = np.zeros_like(D2)
        np.exp(-power, where=power < -np.log(2 * np.finfo(float).eps), out=expected)
        expected[expected < 1e-8] = 0
        expected[degree == 0, :] = 0
        expected[:, degree == 0] = 0
        expected = np.maximum(expected, expected.T)
        K = np.asarray(load(folder / 'affinity.json')['affinity'])
        assert np.array_equal(K == 0, expected == 0)
        assert np.allclose(K, expected, rtol=1e-7, atol=1e-7)
        assert np.array_equal(K, K.T) and np.array_equal(np.diag(K), (degree > 0).astype(float))
        affinity_error = float(abs(K - expected).max())
    checkpoints.append(dict(path=str(file), stages={k: status[k] for k in ['graph', 'scales', 'affinity', 'complete']},
                            native_metadata=native_metadata, reconstructed_affinity_max_error=affinity_error))
assert len(checkpoints) == 17
assert sum(x['native_metadata'] is not None for x in checkpoints) == 9
write(a.output / 'results.json', dict(revision=rev, inventory=inventory, comparisons=comparisons,
      raw_checks=raw, raw_count=len(raw), valid_raw_count=len(raw) - 1,
      intentional_invalid_count=1, raw_maxima=maxima, checkpoints=checkpoints,
      regression_checks_sha256=sha(a.root / 'regressions-v1/checks.json'),
      all_implementation_comparisons_passed=all(x['implementation']['passed'] for x in comparisons),
      all_representation_comparisons_passed=all(x['representation']['passed'] for x in comparisons)))

lines = ['# Derived adaptive-trajectory coverage', '',
         'All six attempts used the original-expression Python control. Selection was frozen before selected native execution.', '',
         '| Candidate | Profiles | Pruning iterations | Removed edges | Extra retuning solves during pruning | Final retuning solves | Final components / isolates | Selected |',
         '|---|---:|---:|---:|---:|---:|---:|---|']
for row in inventory:
    topology = row['topology'][-1]
    lines.append(f"| {row['name']} | {row['vertices']} | {row['pruning_iterations']} | {row['removed_edges']} | {row['additional_pruning_retune_solves']} | {row['final_retuning_solves']} | {topology['components']} / {len(topology['isolates'])} | {row['selected']} |")
lines += ['', 'An extra retuning solve is a solve beyond the first in a post-pruning outer iteration; initial and final retuning are separate.', '',
          '| Selected input | Comparison | Paired events | Maximum scale difference (internal units) | Maximum ratio difference | Maximum final affinity difference | Array/discrete comparison passed |',
          '|---|---|---:|---:|---:|---:|---|']
for row in comparisons:
    for label in ['representation', 'implementation']:
        c = row[label]
        lines.append(f"| {row['name']} | {label} | {c['events_a']} | {c['maxima'].get('scales',0):.9g} | {c['maxima'].get('ratios',0):.9g} | {c['final_affinity_max_difference']:.9g} | {c['passed']} |")
lines += ['', 'Representation = original-expression/evaluated Python. Implementation = evaluated Python/native. Failed intermediate limits remain failed despite matching final outputs.', '',
          '| Input | Condition | Solves | Process seconds | OS peak resident MiB |', '|---|---|---:|---:|---:|']
for row in comparisons:
    for c in row['conditions']:
        lines.append(f"| {row['name']} | {c['condition']} | {c['solves']} | {c['process']['end_to_end_seconds']:.4f} | {c['process']['root_peak_rss_bytes']/2**20:.1f} |")
lines += ['', 'Resources are single-run diagnostics; no comparative engine-performance estimate is made.']
(a.output / 'tables.md').write_text('\n'.join(lines) + '\n')
print(dict(raw_count=len(raw), valid=len(raw) - 1, checkpoints=len(checkpoints), maxima=maxima))
