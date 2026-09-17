"""Freeze original-only state selections and four prescribed complete inputs."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

import numpy as np
from scipy.spatial.distance import pdist, squareform


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path, data):
    path.write_text(json.dumps(data, allow_nan=False) + '\n')


p = argparse.ArgumentParser()
p.add_argument('old', type=Path)
p.add_argument('output', type=Path)
a = p.parse_args()
assert not subprocess.check_output(['git', 'status', '--porcelain'], text=True)
a.output.mkdir(parents=True, exist_ok=False)
order = json.loads((a.old / 'fixtures-v1/manifest.json').read_text())['order']
best_prune = best_retune = None
known = {}
for rank, name in enumerate(order):
    file = a.old / 'search-v1' / name / 'child/trace.jsonl'
    mapping = processed = graph = solved = None
    trace_hash = sha(file)
    for index, line in enumerate(file.open()):
        event = json.loads(line)
        if event['event'] == 'mapping':
            mapping = {k: v for k, v in event.items() if k not in ['event', 'phase', 'iteration']}
        if event['event'] == 'processed':
            processed = event
        if 'edges' in event:
            graph = event
        if event['event'] == 'solve':
            solved = dict(D1=processed['D1'], D2=processed['D2'], scl=processed['scl'],
                mapping=mapping, edges=graph['edges'], degrees=graph['degrees'],
                upper=event['upper'], C=event['C'], action='solve',
                provenance=dict(source=str(file), sha256=trace_hash, input_name=name,
                    event=index, iteration=event['iteration'], site=event['site'], phase=event['phase']))
            if (name, index) in [('hellinger_256', 31), ('hellinger_300', 4)]:
                known[name] = solved
        if event['event'] == 'decision':
            margins = np.abs(np.asarray(event['threshold_margins']))
            allowed = (np.asarray(event['stats']) > 0) & (margins > 0)
            if np.any(allowed):
                vertex = int(np.argmin(np.where(allowed, margins, np.inf)))
                key = (float(margins[vertex]), rank, index, vertex)
                if best_prune is None or key < best_prune[0]:
                    best_prune = (key, dict(solved, target_vertex=vertex,
                                  selected_margin=float(margins[vertex]), selected_event=index))
        if event['event'] == 'retune_eval' and event['phase'] != 'final_affinity_retuning':
            margin = abs(event['median_margin'])
            key = (margin, rank, index)
            if margin > 0 and (best_retune is None or key < best_retune[0]):
                best_retune = (key, dict(solved, selected_margin=margin, selected_event=index))
assert set(known) == {'hellinger_256', 'hellinger_300'}
states = dict(known_256=known['hellinger_256'], known_300=known['hellinger_300'],
              pruning_boundary=best_prune[1], retuning_boundary=best_retune[1])
for name, state in states.items():
    state['name'] = name
    write(a.output / (name + '.json'), state)

full = []
for n, sign in [(256, 1), (300, -1)]:
    source = a.old / 'fixtures-v1' / f'hellinger_{n}.json'
    old = json.loads(source.read_text())
    X = np.asarray(old['features'])
    exponent = sign * 2.0 ** -24 * np.sin(np.arange(len(X)) + 1)[:, None] * np.cos(np.arange(X.shape[1]) + 1)[None, :]
    X = X * np.exp(exponent)
    X /= X.sum(axis=1, keepdims=True)
    D = squareform(pdist(np.sqrt(X))) / np.sqrt(2)
    name = f'hellinger_{n}_perturbed'
    write(a.output / (name + '.json'), dict(kind='full', name=name, features=X.tolist(),
          distances=D.tolist(), ids=old['ids'], provenance=dict(source=str(source),
          sha256=sha(source), perturbation='multiplicative exp(sign*2^-24*sin(i+1)*cos(j+1)); row normalize', sign=sign)))
    full.append(name)
t = 4 * np.pi * np.linspace(0, 1, 120) ** 1.6
X = np.column_stack((np.cos(t), np.sin(t), .12 * t))
synthetics = [('helix_120', X, dict(turns=2, sampling_power=1.6, pitch_coefficient=.12))]
u, v = np.meshgrid(np.linspace(-1, 1, 12), np.linspace(-1, 1, 12))
X = np.column_stack((u.ravel(), v.ravel(), .6 * (u.ravel() ** 2 - v.ravel() ** 2)))
X += .002 * np.random.default_rng(2026091705).normal(size=X.shape)
synthetics.append(('saddle_144', X, dict(grid=[12, 12], coefficient=.6, jitter_sd=.002, seed=2026091705)))
for name, X, provenance in synthetics:
    write(a.output / (name + '.json'), dict(kind='full', name=name, features=X.tolist(),
          distances=squareform(pdist(X)).tolist(), ids=[f'{name}-{i}' for i in range(len(X))], provenance=provenance))
    full.append(name)
# Stage-only vectors with supplied circular metric and adjacency; no Gabriel claim.
n = 32
idx = np.arange(n)
D = np.minimum(abs(idx[:, None] - idx[None, :]), n - abs(idx[:, None] - idx[None, :]))
edges = sorted([[i, i + 1] for i in range(n - 1)] + [[0, n - 1]])
stage = []
for family in ['threshold', 'tie']:
    for delta in [-1e-7, 0., 1e-7]:
        stats = np.ones(n)
        stats[:2] = [2.75 + delta, 1] if family == 'threshold' else [4, 4 + delta]
        stage.append(dict(name=f'{family}_{delta}', stats=stats.tolist(), median=1.,
                          D1=D.tolist(), edges=edges))
write(a.output / 'stage-probes.json', dict(cases=stage))
write(a.output / 'manifest.json', dict(revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
    states=list(states), complete_inputs=full,
    state_selection={k:dict(provenance=v['provenance'], selected_margin=v.get('selected_margin'), selected_event=v.get('selected_event'), target_vertex=v.get('target_vertex')) for k,v in states.items()},
    files={f.name:sha(f) for f in sorted(a.output.glob('*.json'))},
    plan_sha256=sha(Path(__file__).with_name('PLAN.md')),
    contract_sha256=sha(Path(__file__).with_name('CONTRACT.md'))))
print(json.dumps({k:dict(source=v['provenance'], margin=v.get('selected_margin')) for k,v in states.items()}, indent=2))
