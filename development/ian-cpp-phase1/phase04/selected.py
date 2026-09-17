"""Run the two remaining conditions for frozen reference-selected trajectories."""
import argparse
from pathlib import Path
from support import revision, load, write, sha, run, inspect_run, checked_comparison, graph_units

p = argparse.ArgumentParser()
p.add_argument('selection', type=Path)
p.add_argument('regression', type=Path)
p.add_argument('output', type=Path)
p.add_argument('--native', type=Path, required=True)
a = p.parse_args()
rev = revision()
assert load(a.regression)['passed']
selection = load(a.selection)
assert len(selection['selected']) <= 2
a.output.mkdir(parents=True, exist_ok=False)
write(a.output / 'provenance.json', dict(revision=rev, selection_sha256=sha(a.selection),
      regression_sha256=sha(a.regression), native_sha256=sha(a.native)))
rows = []
for item in selection['selected']:
    fixture = Path(item['input'])
    original = Path(item['reference_child'])
    assert sha(fixture) == item['input_sha256']
    assert sha(original / 'trace.jsonl') == item['trace_sha256']
    folder = a.output / item['name']
    folder.mkdir()
    result = dict(name=item['name'], original=inspect_run(original), conditions={}, comparisons={})
    left = original
    for condition, label in [('evaluated', 'representation'), ('native', 'implementation')]:
        destination = folder / condition
        process = run(fixture, destination, condition, a.native)
        evidence = inspect_run(destination / 'child')
        comparison = checked_comparison(left, destination / 'child', folder / label)
        result['conditions'][condition] = dict(process=process, coverage=evidence)
        result['comparisons'][label] = comparison
        if condition == 'native' and evidence['status']['graph']:
            result['graph_units'] = graph_units(destination / 'child')
        write(folder / 'checks.json', result)
        print(item['name'], condition, 'exit', process['exit_code'], 'comparison', comparison['passed'], flush=True)
        if process['exit_code'] or not evidence['eligible'] or not comparison['passed']:
            write(a.output / 'checks.json', dict(revision=rev, passed=False, completed=rows, stopped=result))
            raise SystemExit('First difference retained; stop before subsequent condition/candidate.')
        left = destination / 'child'
    rows.append(result)
write(a.output / 'checks.json', dict(revision=rev, passed=True, selected=rows))
print('Frozen selected comparisons completed:', len(rows), flush=True)
