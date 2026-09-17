"""Freeze the focused parser correction without rewriting original evidence."""
import argparse
import hashlib
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'phase04'))
from support import revision, load, write, sha

p = argparse.ArgumentParser()
p.add_argument('output', type=Path)
a = p.parse_args()
repo = Path.cwd()
rev = revision()
base = '4f4bebaac9f35d7705763fda82b37c7530b609d9'
built = '7fd0b2eb17087b7e6f57b27c5ff5dc4717d65e02'
assert not (a.output / 'manifest-v1.json').exists()
assert subprocess.check_output(['git', 'branch', '--show-current'], text=True).strip() == 'codex/ian-cpp-feasibility-20260917'
subprocess.run([sys.executable, '-B', str(HERE / 'extract.py'), '--check'], check=True)

def gitbytes(commit, name):
    return subprocess.check_output(['git', 'show', commit + ':' + name])

changed = subprocess.check_output(['git', 'diff', '--name-only', base, '--', str(HERE / 'src'),
                                   str(HERE / 'include'), str(HERE / 'config.json'),
                                   str(HERE / 'CMakeLists.txt')], text=True).splitlines()
assert changed == ['development/ian-cpp-phase1/phase06a/src/json_adapter.hpp']
names = subprocess.check_output(['git', 'ls-files', str(HERE)], text=True).splitlines()
for name in names:
    if '/src/' in name or '/include/' in name or name.endswith(('CMakeLists.txt', 'config.json', 'schema_regression.py')):
        assert (repo / name).read_bytes() == gitbytes(built, name), name

worker = a.output.parent
preserved = []
prior = [(worker / 'phase06a', worker / 'phase06a/final-manifest-v1.json', base)]
for item in load(worker / 'phase06a/final-checks-v1.json')['preserved']:
    path = Path(item['manifest'])
    assert sha(path) == item['sha256']
    prior.append((path.parent, path, None))
audit = repo.parent / 'auditor/review-6a'
prior.append((audit, audit / 'audit-manifest.json', None))
for root, path, source_commit in prior:
    data = load(path)
    files = data.get('files', data)
    for name, entry in files.items():
        expected = entry['sha256'] if isinstance(entry, dict) else entry
        assert sha(root / name) == expected, str(root / name)
    source_count = 0
    for name, entry in data.get('source_files', {}).items():
        expected = entry['sha256'] if isinstance(entry, dict) else entry
        content = gitbytes(source_commit or data['revision'], name)
        assert hashlib.sha256(content).hexdigest() == expected, name
        source_count += 1
    preserved.append(dict(manifest=str(path), sha256=sha(path), files=len(files),
                          sources_verified_at_frozen_commit=source_count))
handoff = worker / 'phase06a-implementer-handoff.md'
assert sha(handoff) == '5c14d0583e3ce729d150cf975e547514d723236029b2d3dde3977cfe812e4898'
assert sha(worker / 'phase06a/final-manifest-v1.json') == '774880969ccd85ba6a6c00f1dfde28441ff3d35c08ac69c83c2d1a72bc37e61b'

checks = load(a.output / 'schema-v1/checks.json')
assert checks['revision'] == built and checks['complete'] and checks['total_solver_calls'] == 4
assert len(checks['cases']) == 18 and all(c['passed'] for c in checks['cases'])
assert sha(Path(checks['engine'])) == checks['engine_sha256']
for case in checks['cases']:
    assert sha(a.output / 'schema-v1' / case['name'] / 'input.json') == case['input_sha256']

relative = str(HERE.relative_to(repo)) + '/'
identity_files = sorted(n for n in names if n.startswith(tuple(relative + d for d in ['src/', 'include/', 'tests/']))
                        and n.endswith(('.cpp', '.hpp')))
hashes = ''.join(sha(repo / n) for n in identity_files) + sha(HERE / 'CMakeLists.txt')
source_identity = hashlib.sha256(hashes.encode()).hexdigest()
for name in ['omitted', 'integer_one']:
    graph = load(a.output / 'schema-v1' / name / 'child/graph.json')
    assert graph['source_sha256'] == source_identity
    assert graph['configuration_sha256'] == sha(HERE / 'config.json')
write(a.output / 'preservation-v1.json', dict(revision=rev, base=base, build_revision=built,
    git_status='', source_identity=source_identity, only_runtime_change=changed,
    original_handoff_sha256=sha(handoff), preserved=preserved))
files = {str(f.relative_to(a.output)): dict(sha256=sha(f), bytes=f.stat().st_size)
         for f in sorted(a.output.rglob('*')) if f.is_file() and f.name != 'manifest-v1.json'}
names += ['development/ian-cpp-phase1/coordinator/ROADMAP.md']
sources = {n: dict(sha256=sha(repo / n), bytes=(repo / n).stat().st_size) for n in names}
write(a.output / 'manifest-v1.json', dict(revision=rev, base=base, files=files, source_files=sources,
    note='Focused F1 correction. Original submission and auditor evidence retained; external handoff excluded.'))
print(dict(revision=rev, generated_files=len(files), source_files=len(sources), preserved=preserved))
