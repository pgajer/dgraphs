"""Serial bounded study; preserved prior attempts can be reused by exact identity."""
import argparse
import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'phase04'))
from support import (load, write, sha, revision, run, inspect_run, graph_units,
                     supervise, one_thread_environment, compare, check_lp, traces)
from compare import DISCRETE, arrays


def summarize_comparison(left, right, out):
    result = compare(left, right, out)
    A, B = traces(left), traces(right)
    discrete = []
    for i in range(max(len(A), len(B))):
        bad = ['trace_length'] if i >= min(len(A), len(B)) else [
            k for k in DISCRETE if A[i].get(k) != B[i].get(k)]
        if bad:
            discrete.append(dict(index=i, fields=bad))
    endpoint = None
    if A[-1]['event'] == B[-1]['event'] == 'complete':
        endpoint = dict(affinity=arrays(A[-1]['affinity'], B[-1]['affinity'], 1e-7, 1e-7),
                        scales=arrays(A[-1]['scales'], B[-1]['scales'],
                            1e-7/next(e['scl'] for e in A if e['event']=='processed'), 1e-7))
        ga = next(e for e in reversed(A) if 'edges' in e)
        gb = next(e for e in reversed(B) if 'edges' in e)
        endpoint['edge_symmetric_difference'] = sorted(set(map(tuple, ga['edges'])) ^ set(map(tuple, gb['edges'])))
    return dict(passed=result['passed'], first_divergence=result['first_divergence'],
        failing_events=[dict(index=c['index'], fields=c['bad']) for c in result['checks'] if c['bad']],
        discrete_first=discrete[0] if discrete else None,
        discrete_agreement=not discrete, endpoint=endpoint,
        events=[len(A), len(B)],
        raw_valid=all(c['accepted'] and c['dual_valid'] for c in result['raw_checks_a']+result['raw_checks_b']))


def main():
    p = argparse.ArgumentParser()
    p.add_argument('root', type=Path)
    p.add_argument('output', type=Path)
    p.add_argument('--mode', choices=['probes', 'full', 'stages'], required=True)
    p.add_argument('--prior', type=Path, action='append', default=[])
    p.add_argument('--ack', type=Path)
    a = p.parse_args()
    rev = revision()
    a.root, a.output = a.root.resolve(), a.output.resolve()
    a.output.mkdir(parents=True, exist_ok=False)
    old = {}
    for path in a.prior:
        for key, value in load(path)['runs'].items():
            old[key] = value
    ack = load(a.ack) if a.ack else dict(comparisons=[], runs=[])
    ledger = dict(revision=rev, mode=a.mode, runs={}, comparisons={},
        prior=[dict(path=str(p), sha256=sha(p)) for p in a.prior],
        acknowledgement=None if not a.ack else dict(path=str(a.ack), sha256=sha(a.ack)),
        complete=False)
    def save():
        write(a.output / 'ledger.json', ledger)
    if a.mode == 'probes':
        cases = load(a.root / 'calibration-v1/manifest.json')['cases']
    elif a.mode == 'full':
        cases = [dict(name=n, input=str(a.root / 'fixtures-v1' / (n+'.json')))
                 for n in load(a.root / 'fixtures-v1/manifest.json')['complete_inputs']]
    else:
        cases = [dict(name='stage-probes', input=str(a.root / 'fixtures-v1/stage-probes.json'))]
    for case in cases:
        name, fixture = case['name'], Path(case['input'])
        for condition in ['original', 'evaluated', 'native']:
            key = name + '/' + condition
            if key in old:
                item = old[key]
                assert item['input_sha256'] == sha(fixture)
                assert all(sha(Path(item['folder']) / file) == digest for file, digest in item['files'].items())
                ledger['runs'][key] = item
            else:
                folder = a.output / name / condition
                if a.mode == 'full':
                    proc = run(fixture, folder, condition, a.root.parent / 'phase04/build-v1/ian_engine')
                else:
                    cmd = ([str(a.root / 'build-v1/ian_probe'), str(fixture), str(folder/'child')]
                        if condition == 'native' else [sys.executable, '-B', str(HERE/'reference_probe.py'),
                        str(fixture), str(folder/'child'), condition])
                    proc = supervise(cmd, folder, one_thread_environment())
                child = folder / 'child'
                check = dict(eligible=False)
                if proc['exit_code'] == 0:
                    if a.mode == 'full':
                        check = inspect_run(child)
                        if condition == 'native':
                            check['graph_units'] = graph_units(child)
                    elif a.mode == 'stages':
                        check = dict(eligible=True, solves=0)
                    else:
                        raw = [check_lp(e) for e in traces(child) if e['event'] == 'solve']
                        check = dict(eligible=load(child/'status.json')['complete'] and
                            all(c['accepted'] and c['dual_valid'] for c in raw),
                            solves=len(raw), raw_checks=raw)
                write(folder/'checks.json', check)
                item = dict(folder=str(child), input=str(fixture), input_sha256=sha(fixture),
                    process=proc, check=check, revision=rev,
                    files={str(f.relative_to(child)):sha(f) for f in child.rglob('*') if f.is_file()})
                ledger['runs'][key] = item
                print(key, 'exit', proc['exit_code'], 'valid', check['eligible'], flush=True)
            save()
            if not ledger['runs'][key]['check']['eligible'] and key not in ack['runs']:
                ledger['paused_on'] = dict(run=key)
                save()
                return 3
        for pair, left, right in [('historical', 'original', 'evaluated'), ('implementation', 'evaluated', 'native')]:
            key = name + '/' + pair
            L = Path(ledger['runs'][name+'/'+left]['folder'])
            R = Path(ledger['runs'][name+'/'+right]['folder'])
            if a.mode == 'stages':
                x, y = load(L/'stages.json'), load(R/'stages.json')
                # Exact discrete behavior, baseline floating limits for diagnostic statistics.
                checks = []
                for u, v in zip(x, y):
                    fields = [k for k in ['name', 'selected', 'removed', 'edges'] if u[k] != v[k]]
                    if u['decision']['candidates'] != v['decision']['candidates']:
                        fields.append('candidates')
                    from compare import FLOATS
                    numeric = {k:arrays(u['decision'][k], v['decision'][k], *FLOATS[k])
                               for k in FLOATS if k in u['decision']}
                    checks.append(dict(name=u['name'], fields=fields, numeric=numeric))
                summary = dict(passed=len(x)==len(y) and all(not c['fields'] and all(v['pass_limit']
                    for v in c['numeric'].values()) for c in checks), checks=checks)
            else:
                summary = summarize_comparison(L, R, a.output/'comparisons'/name/pair)
            ledger['comparisons'][key] = summary
            print(key, 'passed', summary['passed'], flush=True)
            save()
            known_array_class = (ack.get('continue_historical_array_class', False) and pair == 'historical'
                and summary.get('discrete_agreement', False) and summary.get('raw_valid', False)
                and all(set(c['fields']) <= {'scales', 'ratios', 'stats', 'wstats', 'location',
                    'dispersion', 'threshold', 'raw_threshold', 'floored_threshold', 'cap', 'median',
                    'median_residual', 'threshold_margins', 'median_margin'}
                    for c in summary.get('failing_events', []))
                and (summary.get('endpoint') is None or (
                    summary['endpoint']['affinity']['pass_limit'] and summary['endpoint']['scales']['pass_limit']
                    and not summary['endpoint']['edge_symmetric_difference'])))
            if known_array_class and not summary['passed']:
                summary['continuation_class'] = 'historical_array_only_retained_failure'
                save()
            if not summary['passed'] and key not in ack['comparisons'] and not known_array_class:
                ledger['paused_on'] = dict(comparison=key)
                save()
                return 4
    ledger['complete'] = True
    save()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
