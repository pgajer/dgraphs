"""Phase 04 evidence helpers; the phase 03 algorithm and tolerances stay unchanged."""
import json
import subprocess
import sys
from collections import Counter
from pathlib import Path

import numpy as np
from scipy import sparse
from scipy.sparse.csgraph import connected_components

HERE = Path(__file__).resolve().parent
OLD = HERE.parent / 'phase03'
sys.path.insert(0, str(OLD))
from compare import compare, check_lp, traces, kernel_checks
from reference import sha, write
sys.path.insert(0, str(HERE.parent / 'phase02'))
from supervise import supervise, one_thread_environment


def revision():
    assert not subprocess.check_output(['git', 'status', '--porcelain'], text=True)
    return subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()


def load(path):
    return json.loads(Path(path).read_text())


def run(fixture, output, condition, native=None, injection=None):
    if condition == 'native':
        command = [str(native), str(fixture), str(output / 'child')]
        if injection:
            command.append(injection)
    else:
        command = [sys.executable, '-B', str(OLD / 'reference.py'), str(fixture),
                   str(output / 'child'), condition]
    result = supervise(command, output, one_thread_environment())
    write(output / 'identity.json', dict(input_sha256=sha(fixture),
          input=str(fixture), condition=condition,
          configuration_sha256=sha(HERE / 'config.json'),
          runtime_sha256=sha(native if condition == 'native' else OLD / 'reference.py')))
    return result


def inspect_run(folder):
    """Derive trajectory coverage and raw numerical validity from every event."""
    status = load(folder / 'status.json')
    events = traces(folder) if (folder / 'trace.jsonl').exists() else []
    raw = [dict(number=e['number'], **check_lp(e)) for e in events if e['event'] == 'solve']
    topology = []
    for e in events:
        if e['event'] not in ['iteration', 'pruned', 'graph_stop']:
            continue
        n = len(e['degrees'])
        edges = np.asarray(e['edges'], dtype=int).reshape(-1, 2)
        degree = np.bincount(edges.ravel(), minlength=n)
        assert degree.tolist() == e['degrees']
        assert np.flatnonzero(degree == 0).tolist() == e['isolates']
        assert len(set(map(tuple, edges))) == len(edges)
        assert e['edges'] == sorted(e['edges']) and np.all(edges[:, 0] < edges[:, 1])
        adj = sparse.coo_matrix((np.ones(2 * len(edges)),
              (np.r_[edges[:, 0], edges[:, 1]], np.r_[edges[:, 1], edges[:, 0]])), shape=(n, n))
        count, labels = connected_components(adj, directed=False)
        assert labels.tolist() == e['components']
        topology.append(dict(event=e['event'], iteration=e['iteration'],
                             edges=len(edges), components=int(count), isolates=e['isolates']))
    per_iteration = Counter(e['iteration'] for e in events
                            if e['event'] == 'solve' and e['phase'] == 'post_prune')
    solves = [e for e in events if e['event'] == 'solve']
    retunes = [e for e in events if e['event'] == 'retune_stop']
    multipliers = [e['C'] for e in solves if e['phase'] == 'post_prune']
    additions = sum(max(0, n - 1) for n in per_iteration.values())
    pruning = sum(e['event'] == 'pruned' for e in events)
    kernels = kernel_checks(events)
    valid = all(x['accepted'] and x['dual_valid'] for x in raw)
    return dict(status=status, events=len(events), raw_checks=raw, kernels=kernels,
                eligible=bool(status['complete'] and valid and all(x['valid'] for x in kernels)),
                solves=len(raw), pruning_iterations=pruning,
                removed_edges=sum(len(e['removed']) for e in events if e['event'] == 'pruned'),
                additional_pruning_retune_solves=additions,
                pruning_retune_groups=dict(per_iteration),
                pruning_C_changes=sum(a != b for a, b in zip(multipliers, multipliers[1:])),
                pruning_bisection_updates=sum(e['bisection_updates'] for e in retunes
                                               if e['phase'] == 'post_prune'),
                initial_solves=sum(e['phase'] == 'initial' for e in solves),
                final_retuning_solves=sum(e['phase'] == 'final_affinity_retuning' for e in solves),
                boundary_stops=sum(e['boundary_stop'] for e in retunes),
                topology=topology,
                topology_changes=[b for a, b in zip(topology, topology[1:])
                                  if (a['components'], a['isolates']) != (b['components'], b['isolates'])],
                target_reached=bool(pruning >= 10 and additions >= 1))


def checked_comparison(left, right, output):
    result = compare(left, right, output)
    valid = result['passed'] and all(x['accepted'] and x['dual_valid']
                 for x in result['raw_checks_a'] + result['raw_checks_b'])
    valid = valid and all(x['valid'] for x in result['kernel_checks_a'] + result['kernel_checks_b'])
    maxima = {}
    for event in result['checks']:
        for name, value in event.get('numeric', {}).items():
            maxima[name] = max(maxima.get(name, 0), value.get('max_absolute', 0))
    return dict(passed=bool(valid), events_a=result['events_a'], events_b=result['events_b'],
                first_divergence=result['first_divergence'], maxima=maxima)


def graph_units(folder):
    """Interpret upper bounds using only checkpoint metadata and original input."""
    graph = load(folder / 'graph.json')
    assert graph['upper_units'] == 'internal_distance = input_distance * scl'
    assert graph['scl'] > 0 and graph['upper_to_input_distance'] == 1 / graph['scl']
    identity = load(folder.parent / 'identity.json')
    original = load(identity['input'])
    assert graph['input_sha256'] == sha(identity['input'])
    representatives = graph['mapping']['representatives']
    distance = np.asarray(original['distances'])[np.ix_(representatives, representatives)]
    minimum = distance[np.triu_indices(len(distance), 1)].min()
    assert graph['scl'] == 1 / minimum
    upper = np.zeros(len(distance))
    edges = np.asarray(graph['edges']).reshape(-1, 2)
    np.maximum.at(upper, edges[:, 0], distance[edges[:, 0], edges[:, 1]])
    np.maximum.at(upper, edges[:, 1], distance[edges[:, 0], edges[:, 1]])
    restored = np.asarray(graph['upper']) * graph['upper_to_input_distance']
    assert np.allclose(upper, restored, rtol=2e-14, atol=1e-12)
    return dict(scl=graph['scl'], upper_units=graph['upper_units'],
                max_original_unit_error=float(abs(upper - restored).max()), passed=True)
