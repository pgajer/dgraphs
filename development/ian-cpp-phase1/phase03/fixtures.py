"""Write deterministic coordinates/compositions, distances and stage inputs; no solve."""
import argparse,json,hashlib,subprocess
from pathlib import Path
import numpy as np
from scipy.spatial.distance import pdist,squareform

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def dump(p,d):Path(p).write_text(json.dumps(d,indent=2,allow_nan=False)+'\n')
p=argparse.ArgumentParser();p.add_argument('output',type=Path);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
ordinary=[]
def save(name,X,D=None,ids=None,extra=None):
    if D is None:D=squareform(pdist(X))
    d=dict(kind='full',name=name,features=X.tolist(),distances=D.tolist(),ids=ids or [f'{name}-{i:03d}' for i in range(len(X))])
    if extra:d['provenance']=extra
    dump(a.output/(name+'.json'),d);ordinary.append(name)
t=-1.5+3*np.linspace(0,1,64)**1.8
save('nonuniform_curve',np.column_stack((t,.35*np.sin(2*t),.15*t*t)))
rng=np.random.default_rng(20260917);u,v=np.meshgrid(np.linspace(0,1,10),np.linspace(0,1,8));X=np.column_stack((u.ravel()**1.7,v.ravel()))+.009*rng.normal(size=(80,2))
save('variable_density_patch',X)
t=np.linspace(.12,2.8,48);save('nearby_curved_arms',np.vstack([np.column_stack((np.cos(t),np.sin(t))),np.column_stack((1.18*np.cos(t),1.18*np.sin(t)))]))
source=Path('/Users/pgajer/current_projects/ZB/experiments/038-ian-community-graph-geometry/build/pilot-20260916-v1/pressmat_500_input.npz')
with np.load(source) as f:
    ii=np.floor(np.linspace(0,499,64)).astype(int);X=f['composition'][ii];D=f['hellinger'][np.ix_(ii,ii)]
    assert np.allclose(D,squareform(pdist(np.sqrt(X)))/np.sqrt(2),rtol=1e-12,atol=1e-14)
    save('pressmat_hellinger_subset',X,D,f['representative_ids'][ii].tolist(),dict(source=str(source),sha256=sha(source),selected_profile_indices=ii.tolist(),selection='floor(linspace(0,499,64)), no outcomes or CSTs'))
# A five-point valid input is used only for operational failure tests.
X=np.array([[0.,0.],[1.,0.],[.1,.7],[1.2,.8],[.6,1.4]])
dump(a.output/'failure_input.json',dict(kind='full',name='failure_input',features=X.tolist(),distances=squareform(pdist(X)).tolist(),ids=[f'failure-{i}' for i in range(5)]))
eps=np.finfo(np.float32).eps;center=np.float32(2-10*eps);boundary=[]
for label,d in [('below',np.nextafter(center,np.float32(-np.inf))),('at',center),('above',np.nextafter(center,np.float32(np.inf)))]:
    boundary.append(dict(name=label,D2=[[0,float(d),1],[float(d),0,1],[1,1,0]],edge01_expected=label=='below'))
Xdup=np.array([[0.,0],[1,0],[-0.,0],[1,1],[1,0],[0,1]])
stages=dict(kind='stages',name='targeted',duplicate=dict(features=Xdup.tolist(),distances=squareform(pdist(Xdup)).tolist(),ids=[f'dup-{i}' for i in range(len(Xdup))],expected_map=[0,1,0,2,1,3]),
 gabriel=boundary,decisions=[dict(name='floor',stats=[1.,1.,1.],median=1.),dict(name='conditional_cap',stats=[1.,2.,4.,8.,16.],median=1.),dict(name='cap_not_unconditional',stats=[1.]*30+[5.],median=1.),dict(name='ordinary_ties',stats=[1.]*28+[5.]*4,median=1.),dict(name='override_ties',stats=[1.]*8+[2.]*16+[3.]*8,median=2.)],
 pruning=dict(edges=[[0,1],[0,2],[1,3],[2,3]],distances=[[0,1,1,2],[1,0,2,1],[1,2,0,1],[2,1,1,0]],candidates=[0,2,1,3],expected_removed=[[0,2],[1,3]]),
 disconnected=dict(distances=[[0,1,3,4,7],[1,0,2,3,6],[3,2,0,1,4],[4,3,1,0,3],[7,6,4,3,0]],edges=[[0,1],[2,3]],C=.65,ids=[f'component-{i}' for i in range(5)]),
 affinity_cutoffs=dict(D2=[[0,1e-12,18.4206806,18.4206809,36.,1000.],[1e-12,0,1,2,3,4],[18.4206806,1,0,1,2,3],[18.4206809,2,1,0,1,2],[36.,3,2,1,0,1],[1000.,4,3,2,1,0]],scales=[1.]*6,degrees=[1]*6))
dump(a.output/'stages.json',stages)
# Nonfinite malformed inputs are textual invalid JSON-number cases, not JSON artifacts with NaN.
refusals=[dict(name='single',features=[[1.,2]],distances=[[0.]],ids=['one']),dict(name='all_duplicate',features=[[1.],[1.]],distances=[[0.,0.],[0.,0.]],ids=['a','b']),dict(name='near_duplicate',features=[[0.],[1e-10]],distances=[[0.,1e-10],[1e-10,0.]],ids=['a','b']),dict(name='asymmetric',features=[[0.],[1.]],distances=[[0.,1.],[2.,0.]],ids=['a','b']),dict(name='negative',features=[[0.],[1.]],distances=[[0.,-1.],[-1.,0.]],ids=['a','b'])]
for d in refusals:dump(a.output/('refusal-'+d['name']+'.json'),dict(kind='full',**d))
(a.output/'refusal-nonfinite.json').write_text('{"kind":"full","name":"nonfinite","features":[[0],[1]],"distances":[[0,NaN],[NaN,0]],"ids":["a","b"]}\n')
dump(a.output/'manifest.json',dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),ordinary=ordinary,expected_ordinary='valid reference result or preserved explicit reference failure; no replacement',files={f.name:sha(f) for f in sorted(a.output.glob('*.json'))},solver=dict(core='0.11.1',backend='qdldl',threads=1,fresh=True,tolerance=1e-9,presolve=False,chordal=False,dropzeros=False)))
print('Frozen four ordinary inputs, targeted stages, operational input and six refusal inputs; no solves.')
