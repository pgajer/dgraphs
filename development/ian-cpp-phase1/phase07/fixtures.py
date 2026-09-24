"""Generate all prospectively specified inputs without invoking IAN."""
import json
import subprocess
from pathlib import Path
import sys
import numpy as np
from scipy.spatial.distance import pdist, squareform
from checks import sha, write

root = Path(sys.argv[1]); root.mkdir(parents=True, exist_ok=False)
assert not subprocess.check_output(['git', 'status', '--porcelain'], text=True)
files = {}
for n in [500, 1000]:
    t = 4*np.pi*np.linspace(0, 1, n)**1.6
    helix = np.column_stack((np.cos(t), np.sin(t), .12*t))
    cloud = np.random.default_rng(2026091707+n).normal(size=(n, 6))*[1,1,1,.1,.1,.1]
    rng = np.random.default_rng(2026091807+n)
    radius = .25*np.sqrt(rng.random(n)); angle = 2*np.pi*rng.random(n)
    lobes = np.column_stack((radius*np.cos(angle), radius*np.sin(angle)))
    lobes[:,0] += np.repeat([-2.,2.], n//2)
    for family, X in [('helix',helix), ('cloud',cloud), ('lobes',lobes)]:
        name = f'{family}_{n}'; f = root/(name+'.json')
        assert len(np.unique(X,axis=0)) == n
        write(f, dict(kind='full', name=name, features=X.tolist(),
            distances=squareform(pdist(X)).tolist(), ids=[f'{name}-{i}' for i in range(n)],
            provenance=dict(plan_sha256=sha(Path(__file__).with_name('PLAN.md')), family=family, n=n)))
        files[name] = dict(path=str(f.resolve()), sha256=sha(f), n=n)
source = Path('/Users/pgajer/current_projects/ZB/experiments/038-ian-community-graph-geometry/build/pilot-20260916-v1/pressmat_500_input.npz')
with np.load(source) as data:
    X=data['composition']; D=data['hellinger']; ids=data['representative_ids'].tolist()
    assert len(X)==500 and len(np.unique(X,axis=0))==500
    assert np.allclose(D,squareform(pdist(np.sqrt(X)))/np.sqrt(2),rtol=1e-12,atol=1e-14)
    f=root/'pressmat_500.json'
    write(f,dict(kind='full',name='pressmat_500',features=X.tolist(),distances=D.tolist(),ids=ids,
        provenance=dict(source=str(source),sha256=sha(source),selection='all 500 existing pilot profiles; no outcomes')))
    files['pressmat_500']=dict(path=str(f.resolve()),sha256=sha(f),n=500)
write(root/'manifest.json',dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
    files=files,plan_sha256=sha(Path(__file__).with_name('PLAN.md'))))
print('Seven fixed inputs saved; zero solver calls.')
