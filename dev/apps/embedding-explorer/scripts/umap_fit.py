"""One reproducible UMAP fit, using the app's exact neighbors including self."""
import json
import os
import sys
import warnings

for name in ('NUMBA_NUM_THREADS', 'OMP_NUM_THREADS', 'OPENBLAS_NUM_THREADS', 'MKL_NUM_THREADS'):
    os.environ[name] = '1'
import numpy as np
import umap

with open(sys.argv[1]) as handle:
    job = json.load(handle)
s = job['spec']
x = np.asarray(job['x'], dtype=float)
indices = np.asarray(job['indices'], dtype=np.int32)
distances = np.asarray(job['distances'], dtype=float)
initial = job.get('initial')
init = np.asarray(initial, dtype=np.float32) if initial is not None else s['init']
if isinstance(init, np.ndarray):
    # PCA on a flat surface may have a zero third component; a reproducible tiny
    # perturbation allows optimization to use all three dimensions.
    init = init / max(np.abs(init).max(), 1e-12) * 10
    init += np.random.RandomState(int(s['seed'])).normal(0, 1e-4, init.shape)
with warnings.catch_warnings(record=True) as seen:
    model = umap.UMAP(n_components=3, n_neighbors=int(s['k']) + 1,
        min_dist=float(s['min_dist']), spread=float(s['spread']),
        learning_rate=float(s['learning_rate']), repulsion_strength=float(s['repulsion']),
        negative_sample_rate=int(s['negative_samples']), n_epochs=int(s['epochs']),
        init=init, random_state=int(s['seed']), n_jobs=1,
        precomputed_knn=(indices, distances, None))
    coords = model.fit_transform(x)
if not np.isfinite(coords).all():
    raise ValueError('UMAP returned nonfinite coordinates')
if not np.array_equal(model._knn_indices, indices):
    raise ValueError('UMAP changed the supplied neighbor identities')
with open(sys.argv[2], 'w') as handle:
    json.dump(dict(coords=coords.tolist(), initial=init.tolist() if isinstance(init,np.ndarray) else None,
        warnings=[str(w.message) for w in seen], metadata=dict(umap_version=umap.__version__,
        numpy_version=np.__version__, n_neighbors=int(s['k'])+1, init=s['init'],
        a=float(model._a), b=float(model._b))), handle, allow_nan=False)
