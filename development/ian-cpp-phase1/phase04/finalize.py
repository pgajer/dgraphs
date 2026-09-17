"""Freeze the final submission and check immutable sources, selection and artifacts."""
import argparse
import hashlib
import subprocess
from pathlib import Path
from support import revision, load, write, sha, HERE, OLD

p = argparse.ArgumentParser()
p.add_argument('root', type=Path)
p.add_argument('analysis', type=Path)
p.add_argument('label')
a = p.parse_args()
rev = revision()
repo, worker = Path.cwd(), a.root.parent
assert str(repo) == '/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree'
assert subprocess.check_output(['git', 'branch', '--show-current'], text=True).strip() == 'codex/ian-cpp-feasibility-20260917'
for name in ['checks', 'manifest']:
    assert not (a.root / f'final-{name}-{a.label}.json').exists()
prior = []
for root, manifest in [(worker, worker / 'evidence-manifest.json'),
        (worker / 'phase02', worker / 'phase02/evidence-manifest-v1.json'),
        (worker / 'phase03', worker / 'phase03/final-manifest-v1.json'),
        (repo.parent / 'auditor/review-3', repo.parent / 'auditor/review-3/audit-manifest.json')]:
    record = load(manifest)
    for file, item in record['files'].items():
        assert sha(root / file) == item['sha256'], file
    if root.name in ['phase02', 'phase03']:
        for file, item in record['source_files'].items():
            assert sha(repo / file) == item['sha256'], file
    prior.append(dict(root=str(root), manifest_sha256=sha(manifest),
                      generated_files=len(record['files']),
                      source_files_checked=len(record.get('source_files', {})) if root.name in ['phase02', 'phase03'] else 0))
fixture_manifest = load(a.root / 'fixtures-v1/manifest.json')
for name, digest in fixture_manifest['files'].items():
    assert sha(a.root / 'fixtures-v1' / name) == digest
    source = load(a.root / 'fixtures-v1' / name)['provenance']
    if 'source' in source:
        assert sha(source['source']) == source['sha256']
initial_plan = subprocess.check_output(['git', 'show',
    f"{fixture_manifest['revision']}:development/ian-cpp-phase1/phase04/PLAN.md"])
assert hashlib.sha256(initial_plan).hexdigest() == fixture_manifest['plan_sha256']
selection = load(a.root / 'search-v1/selection.json')
assert selection['attempted'] == 6
ranked = sorted((x for x in selection['inventory'] if x['eligible']),
    key=lambda x: (-x['target_reached'], -x['pruning_iterations'],
                   -x['additional_pruning_retune_solves'], x['order']))
assert [x['name'] for x in ranked[:2]] == [x['name'] for x in selection['selected']]
for item in selection['selected']:
    assert sha(item['input']) == item['input_sha256']
    assert sha(Path(item['reference_child']) / 'trace.jsonl') == item['trace_sha256']
analysis = load(a.analysis / 'results.json')
assert analysis['raw_count'] == 1343 and analysis['valid_raw_count'] == 1342
assert analysis['all_implementation_comparisons_passed']
assert not analysis['all_representation_comparisons_passed']
assert load(a.root / 'regressions-v1/checks.json')['passed']
assert load(a.root / 'refactor-check-v2.json')['configuration_unchanged']

# CMake source identity covers every compiled project source, including extracted headers.
native_files = ['engine.cpp', 'engine.hpp', 'checkpoint.hpp', 'input.hpp',
                'stages.hpp', 'numeric.hpp', 'solver.hpp', 'CMakeLists.txt']
source_hash = hashlib.sha256(''.join(sha(HERE / x) for x in native_files).encode()).hexdigest()
for file in native_files + ['config.json']:
    relative = str((HERE / file).relative_to(repo))
    assert (HERE / file).read_bytes() == subprocess.check_output(['git', 'show', f'fc8d943:{relative}'])
reference_provenance = []
for file in a.root.rglob('child/source/provenance.json'):
    reference_provenance.append(load(file))
assert reference_provenance and all(x == reference_provenance[0] for x in reference_provenance)
expected = load(worker / 'phase03/cases-v1/nonuniform_curve/original/child/source/provenance.json')
assert all(x == expected for x in reference_provenance)
for file in a.root.rglob('child/graph.json'):
    graph = load(file)
    assert graph['source_sha256'] == (source_hash if 'upper_units' in graph else sha(OLD / 'reference.py'))
    assert graph['configuration_sha256'] == sha(HERE / 'config.json')
write(a.root / f'final-checks-{a.label}.json', dict(revision=rev, cwd=str(repo),
      branch='codex/ian-cpp-feasibility-20260917', git_status='',
      base='7d030ff669be9e4a090ec75829c6477c25a7091c',
      preserved=prior, native_source_hash=source_hash,
      native_binary_sha256=sha(a.root / 'build-v1/ian_engine'),
      reference_provenance=expected, selection_sha256=sha(a.root / 'search-v1/selection.json'),
      analysis_sha256=sha(a.analysis / 'results.json'),
      note='Evidence checks completed. Strict Python representation comparisons remain failed; native comparisons pass. No new solves.'))
files = {str(f.relative_to(a.root)): dict(sha256=sha(f), bytes=f.stat().st_size)
         for f in sorted(a.root.rglob('*')) if f.is_file() and not f.name.startswith('final-manifest-')}
sources = {f: dict(sha256=sha(repo / f), bytes=(repo / f).stat().st_size) for f in
           subprocess.check_output(['git', 'ls-files', str(HERE.relative_to(repo))], text=True).splitlines()}
write(a.root / f'final-manifest-{a.label}.json', dict(revision=rev, files=files,
      source_files=sources, note='Excludes this manifest and later handoff outside phase04. Preserves failed check and stopped comparison.'))
print(dict(revision=rev, generated_files=len(files), source_files=len(sources), preserved=prior))
