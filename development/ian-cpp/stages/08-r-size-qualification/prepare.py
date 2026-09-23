"""Freeze exact existing inputs and prescribed larger engineering samples; no solves."""
import sys,json,hashlib,subprocess,math
from pathlib import Path
import numpy as np
from scipy.spatial.distance import pdist,squareform
P=Path(sys.argv[1]);F=P/'fixtures';F.mkdir(exist_ok=False);base=P.parent;load=lambda p:json.loads(Path(p).read_text());write=lambda p,j:p.write_text(json.dumps(j)+'\n');sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert not subprocess.check_output(['git','status','--porcelain'],text=True)
cases=[]
old=base/'stage02-scale/fixtures-v1';helix=base/'connected-pruning/fixtures/helix_1000-reference.json'
inputs=[('helix_1000',helix,str(base/'connected-pruning/runs/helix_1000/reference/child'))]
inputs += [(c['name'],Path(c['path']),str(base/'stage02-scale/panel-v1/runs'/c['name']/'native/child')) for c in load(old/'manifest.json')['fixtures']]
for name,source,baseline in inputs:
 j=load(source);cases.append(dict(name=name,n=1000,input=j,baseline=baseline,source=str(source),source_sha256=sha(source),stage='main'))
for name,n,seed in [('helix_2000',2000,8201),('quadform_d4_2000',2000,8202),('helix_5000',5000,8203)]:
 if name.startswith('helix'):
  t=np.random.default_rng(np.random.SeedSequence([1,seed])).uniform(0,4*np.pi,n);X=np.column_stack([np.cos(t),np.sin(t),.15*t]);rule='PCG64 SeedSequence([1, seed]); uniform parameter [0,4*pi]'
 else:
  U=np.random.default_rng(seed).uniform(-1,1,(n,4));q=np.sum(U*U*np.array([.25,-.25,.25,-.25]),axis=1);X=np.column_stack([U,q]);rule='PCG64(seed); latent uniform [-1,1]^4; diag(+.25,-.25,+.25,-.25)'
 D=squareform(pdist(X));largest=0.
 # Independent scalar distances on a prespecified grid, plus complete shape/symmetry checks.
 for i in range(0,n,max(1,n//40)):
  for k in range(0,n,max(1,n//40)):
   z=math.sqrt(math.fsum((float(a)-float(b))**2 for a,b in zip(X[i],X[k])));largest=max(largest,abs(z-D[i,k]));assert abs(z-D[i,k])<1e-12
 assert len(np.unique(X,axis=0))==n and np.array_equal(D,D.T) and np.all(np.diag(D)==0) and np.isfinite(D).all()
 cases.append(dict(name=name,n=n,stage='larger' if n==2000 else 'conditional',baseline=None,provenance=dict(seed=seed,rule=rule,scalar_grid_max_error=largest),input=dict(schema_version=1,features=X.tolist(),distances=D.tolist(),ids=[name+'-'+str(i) for i in range(n)],numerical_policy='IAN evaluated-LP retry-power 0.1')))
for c in cases:
 j=c.pop('input');X=np.array(j['features']);D=np.array(j['distances']);folder=F/c['name'];folder.mkdir();X.astype('<f8').ravel(order='F').tofile(folder/'features.bin');D.astype('<f8').ravel(order='F').tofile(folder/'distances.bin')
 meta=dict(n=len(X),p=X.shape[1],ids=j['ids'],numerical_policy=j['numerical_policy'],features=str(folder/'features.bin'),distances=str(folder/'distances.bin'))
 write(folder/'metadata.json',meta);c['metadata']=str(folder/'metadata.json');c['binary_sha256']={f:sha(folder/f) for f in ['features.bin','distances.bin','metadata.json']}
 for mode in (['reference','connected'] if c['stage']=='main' else ['connected']):
  jj=dict(j);jj['preserve_connectivity']=mode=='connected'
  if not jj['preserve_connectivity']:jj.pop('preserve_connectivity')
  if c['stage']!='conditional':path=folder/(mode+'.json');write(path,jj);c[mode]=dict(path=str(path),sha256=sha(path))
write(P/'fixtures.json',dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),cases=cases,solver_calls=0));print('Frozen',len(cases),'cases; no solves',flush=True)
