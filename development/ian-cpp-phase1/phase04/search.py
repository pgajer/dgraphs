"""Run the six frozen original-expression controls, then select by coverage only."""
import argparse
from pathlib import Path
from support import revision, load, write, sha, run, inspect_run, OLD

p = argparse.ArgumentParser()
p.add_argument('fixtures', type=Path)
p.add_argument('output', type=Path)
a = p.parse_args()
rev = revision()
a.output.mkdir(parents=True, exist_ok=False)
manifest = load(a.fixtures / 'manifest.json')
write(a.output / 'provenance.json', dict(revision=rev, condition='original',
      fixtures_manifest_sha256=sha(a.fixtures / 'manifest.json'),
      reference_sha256=sha(OLD / 'reference.py')))
rows = []
for index, name in enumerate(manifest['order']):
    fixture = a.fixtures / (name + '.json')
    assert sha(fixture) == manifest['files'][fixture.name]
    folder = a.output / name
    process = run(fixture, folder, 'original')
    result = inspect_run(folder / 'child')
    result['eligible'] = result['eligible'] and process['exit_code'] == 0
    result.update(name=name, order=index, input=str(fixture), input_sha256=sha(fixture),
                  process=process, reference_child=str(folder / 'child'))
    rows.append(result)
    write(folder / 'coverage.json', result)
    print(name, 'exit', process['exit_code'], 'pruning', result['pruning_iterations'],
          'extra pruning-retune solves', result['additional_pruning_retune_solves'],
          'target', result['target_reached'], flush=True)
eligible = sorted((r for r in rows if r['eligible']),
                  key=lambda r: (-r['target_reached'], -r['pruning_iterations'],
                                 -r['additional_pruning_retune_solves'], r['order']))
selected = [dict(name=r['name'], input=r['input'], input_sha256=r['input_sha256'],
                 reference_child=r['reference_child'],
                 trace_sha256=sha(Path(r['reference_child']) / 'trace.jsonl'))
            for r in eligible[:2]]
write(a.output / 'selection.json', dict(revision=rev, condition='original',
      ranking='target reached, descending pruning, descending extra pruning retunes, frozen order',
      target_reached=any(r['target_reached'] for r in eligible),
      attempted=len(rows), eligible=len(eligible), selected=selected, inventory=rows))
print('Selection frozen:', [x['name'] for x in selected], flush=True)
