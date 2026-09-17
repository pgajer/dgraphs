"""Run four unchanged native fixtures and targeted operational regression checks."""
import argparse
from pathlib import Path
from support import (revision, load, write, sha, run, inspect_run, checked_comparison,
                     graph_units, traces, check_lp, OLD, supervise, one_thread_environment)

p = argparse.ArgumentParser()
p.add_argument('baseline', type=Path)
p.add_argument('output', type=Path)
p.add_argument('--native', type=Path, required=True)
a = p.parse_args()
rev = revision()
a.output.mkdir(parents=True, exist_ok=False)
write(a.output / 'provenance.json', dict(revision=rev, native_sha256=sha(a.native),
      baseline_manifest_sha256=sha(a.baseline / 'final-manifest-v1.json')))
checks = []
for name in load(a.baseline / 'fixtures-v1/manifest.json')['ordinary']:
    fixture = a.baseline / 'fixtures-v1' / (name + '.json')
    current = a.output / name
    process = run(fixture, current, 'native', a.native)
    before = a.baseline / 'native-verification-v1' / name / 'child'
    after = current / 'child'
    evidence = inspect_run(after)
    comp = checked_comparison(before, after, current / 'comparison')
    old_events, new_events = traces(before), traces(after)
    exact = [{k: v for k, v in e.items() if k != 'seconds'} for e in old_events] == [
             {k: v for k, v in e.items() if k != 'seconds'} for e in new_events]
    checkpoint_checks = []
    for stage in ['graph', 'scales', 'affinity']:
        old, new = load(before / (stage + '.json')), load(after / (stage + '.json'))
        old.pop('source_sha256')
        new.pop('source_sha256')
        if stage == 'graph':
            for key in ['scl', 'upper_units', 'upper_to_input_distance']:
                new.pop(key)
        checkpoint_checks.append(dict(stage=stage, unchanged=old == new))
    result = dict(name=name, process=process, coverage=evidence, comparison=comp,
                  exact_trace_except_seconds=exact, checkpoints=checkpoint_checks,
                  standalone_graph_units=graph_units(after))
    passed = process['exit_code'] == 0 and evidence['eligible'] and comp['passed'] and exact
    passed = passed and all(x['unchanged'] for x in checkpoint_checks)
    result['passed'] = bool(passed)
    checks.append(result)
    write(current / 'checks.json', result)
    print(name, 'exact native regression', passed, flush=True)
    if not passed:
        write(a.output / 'checks.json', dict(revision=rev, ordinary=checks, passed=False))
        raise SystemExit('Regression difference retained; stop before further execution.')

# The same explicit disconnected adjacency and float32/tie/cutoff cases as phase 03.
fixture = a.baseline / 'boundary-supplement-v1/stages.json'
folder = a.output / 'stages'
process = run(fixture, folder, 'native', a.native)
current = load(folder / 'child/stages.json')
old = load(a.baseline / 'stages-supplement-v1/native/child/stages.json')
current['disconnected']['solve'].pop('seconds')
old['disconnected']['solve'].pop('seconds')
stage = dict(process=process, exact_native_stage_values=current == old,
             raw=check_lp(current['disconnected']['solve']))
assert process['exit_code'] == 0 and stage['exact_native_stage_values']
assert stage['raw']['accepted'] and stage['raw']['dual_valid']

# Existing injection checker is reused read-only; it validates all eight raw solves.
failure_output = a.output / 'failures'
command = [__import__('sys').executable, '-B', str(OLD / 'failures.py'),
           str(a.baseline / 'fixtures-v1/failure_input.json'), str(failure_output),
           '--native', str(a.native)]
failure_driver = supervise(command, a.output / 'failure-driver', one_thread_environment())
assert failure_driver['exit_code'] == 0
failures = load(failure_output / 'checks.json')
assert failures['all_passed']
for check in failures['checks']:
    folder = failure_output / check['injection']
    # The reused driver predates identity.json; add observation-only input provenance.
    write(folder / 'identity.json', dict(input=str(a.baseline / 'fixtures-v1/failure_input.json')))
    if check['status']['graph']:
        check['standalone_graph_units'] = graph_units(folder / 'child')

folder = a.output / 'pruning-cap'
process = run(a.baseline / 'fixtures-v1/pressmat_hellinger_subset.json', folder,
              'native', a.native, 'pruning_cap')
cap = inspect_run(folder / 'child')
comparison = checked_comparison(a.baseline / 'native-verification-v1/cap/native/child',
                               folder / 'child', folder / 'comparison')
assert process['exit_code'] != 0 and not any(cap['status'][s] for s in ['graph', 'scales', 'affinity', 'complete'])
assert comparison['passed']
write(a.output / 'checks.json', dict(revision=rev, ordinary=checks, stages=stage,
      failure_driver=failure_driver, failures=failures, cap=cap,
      cap_comparison=comparison, passed=True))
print('Four ordinary, targeted stages, four failures and cap regressions passed.', flush=True)
