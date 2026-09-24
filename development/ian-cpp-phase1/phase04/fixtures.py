"""Freeze six prespecified trajectory-search inputs, without executing IAN."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

import numpy as np
from scipy.spatial.distance import pdist, squareform


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2, allow_nan=False) + '\n')


parser = argparse.ArgumentParser()
parser.add_argument('output', type=Path)
args = parser.parse_args()
assert not subprocess.check_output(['git', 'status', '--porcelain'], text=True)
args.output.mkdir(parents=True, exist_ok=False)
names = []


def save(name, features, construction, distances=None, ids=None):
    if distances is None:
        distances = squareform(pdist(features))
    if ids is None:
        ids = [f'{name}-{i:03d}' for i in range(len(features))]
    value = dict(kind='full', name=name, features=features.tolist(),
                 distances=distances.tolist(), ids=ids, provenance=construction)
    write(args.output / (name + '.json'), value)
    names.append(name)


u, v = np.meshgrid(np.linspace(0, 1, 20), np.linspace(0, 1, 10))
rng = np.random.default_rng(2026091801)
x = np.column_stack((u.ravel() ** 2.5, v.ravel()))
x += .003 * rng.normal(size=x.shape)
save('density_patch_200', x, dict(grid=[20, 10], power=2.5,
                                 jitter_sd=.003, seed=2026091801))
t = np.linspace(0, 1, 120)
a = .12 + 2.68 * t ** 2
b = .12 + 2.68 * (1 - (1 - t) ** 2)
x = np.vstack((np.column_stack((np.cos(a), np.sin(a))),
               1.08 * np.column_stack((np.cos(b), np.sin(b)))))
save('density_arms_240', x, dict(points_per_arm=120, radii=[1, 1.08],
                                angles=[.12, 2.8], opposite_power=2))
source = Path('/Users/pgajer/current_projects/ZB/experiments/038-ian-community-graph-geometry/build/pilot-20260916-v1/pressmat_500_input.npz')
with np.load(source) as f:
    for n in [128, 192, 256, 300]:
        indices = np.floor(np.linspace(0, 499, n)).astype(int)
        x = f['composition'][indices]
        d = f['hellinger'][np.ix_(indices, indices)]
        assert np.allclose(d, squareform(pdist(np.sqrt(x))) / np.sqrt(2),
                           rtol=1e-12, atol=1e-14)
        save(f'hellinger_{n}', x,
             dict(source=str(source), sha256=sha(source),
                  selected_profile_indices=indices.tolist(),
                  selection='floor(linspace(0,499,n)); no CSTs/outcomes'),
             d, f['representative_ids'][indices].tolist())
write(args.output / 'manifest.json', dict(
    revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
    plan_sha256=sha(Path(__file__).with_name('PLAN.md')),
    condition='original', order=names,
    files={name + '.json': sha(args.output / (name + '.json')) for name in names}))
print('Frozen six candidates; zero optimization runs.')
