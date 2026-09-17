"""Finish the frozen comparisons after the documented Python representation difference."""
import argparse
from pathlib import Path
from support import revision, load, write, sha, run, inspect_run, checked_comparison, graph_units
from diagnose import diagnose

p = argparse.ArgumentParser()
p.add_argument('root', type=Path)
p.add_argument('output', type=Path)
p.add_argument('--native', type=Path, required=True)
a = p.parse_args()
rev = revision()
selection = load(a.root / 'search-v1/selection.json')
diagnostic = load(a.root / 'representation-diagnosis-v1.json')
assert diagnostic['representation_difference_with_unchanged_decisions']
assert load(a.root / 'regressions-v1/checks.json')['passed']
assert [x['name'] for x in selection['selected']] == ['hellinger_256', 'hellinger_300']
a.output.mkdir(parents=True, exist_ok=False)
write(a.output / 'provenance.json', dict(revision=rev,
    selection_sha256=sha(a.root / 'search-v1/selection.json'),
    diagnosis_sha256=sha(a.root / 'representation-diagnosis-v1.json'), native_sha256=sha(a.native)))
rows = []
for index, item in enumerate(selection['selected']):
    fixture, original = Path(item['input']), Path(item['reference_child'])
    assert sha(fixture) == item['input_sha256'] and sha(original / 'trace.jsonl') == item['trace_sha256']
    folder = a.output / item['name']
    folder.mkdir()
    if index == 0:
        evaluated = a.root / 'selected-v1' / item['name'] / 'evaluated/child'
        original_comparison = a.root / 'selected-v1' / item['name'] / 'representation'
        assert sha(evaluated / 'trace.jsonl') == diagnostic['evaluated_trace_sha256']
    else:
        process = run(fixture, folder / 'evaluated', 'evaluated')
        evaluated = folder / 'evaluated/child'
        assert process['exit_code'] == 0 and inspect_run(evaluated)['eligible']
    representation = checked_comparison(original, evaluated, folder / 'representation')
    diagnosis = None
    if not representation['passed']:
        diagnosis = diagnose(original, evaluated, folder / 'representation', folder / 'representation-diagnosis.json')
        if not diagnosis['representation_difference_with_unchanged_decisions']:
            write(a.output / 'checks.json', dict(completed=rows, stopped=item['name'], passed=False))
            raise SystemExit('New representation discrepancy needs diagnosis; native not started.')
    native = folder / 'native'
    process = run(fixture, native, 'native', a.native)
    evidence = inspect_run(native / 'child')
    implementation = checked_comparison(evaluated, native / 'child', folder / 'implementation')
    result = dict(name=item['name'], original=str(original), evaluated=str(evaluated),
        native=str(native / 'child'), representation=representation, implementation=implementation,
        representation_diagnosis=(str(folder / 'representation-diagnosis.json') if diagnosis else None),
        original_coverage=inspect_run(original), evaluated_coverage=inspect_run(evaluated),
        native_coverage=evidence, native_process=process, graph_units=graph_units(native / 'child'))
    write(folder / 'checks.json', result)
    rows.append(result)
    print(item['name'], 'representation', representation['passed'],
          'implementation', implementation['passed'], flush=True)
    if process['exit_code'] or not evidence['eligible'] or not implementation['passed']:
        write(a.output / 'checks.json', dict(revision=rev, selected=rows, completed=False))
        raise SystemExit('Native difference retained; stop before another candidate.')
write(a.output / 'checks.json', dict(revision=rev, selected=rows, completed=True,
      all_implementation_comparisons_passed=all(r['implementation']['passed'] for r in rows),
      all_representation_comparisons_passed=all(r['representation']['passed'] for r in rows)))
