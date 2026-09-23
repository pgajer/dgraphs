"""Freeze independent geometry and response truth before any IAN entry."""
import sys,json,hashlib,subprocess,platform
from pathlib import Path
import numpy as np
from scipy.spatial.distance import pdist,squareform
H=Path(__file__).resolve().parent;P=Path(sys.argv[1]);P.mkdir(parents=True,exist_ok=False)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();write=lambda p,v:Path(p).write_text(json.dumps(v,indent=2,allow_nan=False)+'\n')
S=P.parent/'stage01-policy';B=S/'build-v1';ref=S/'reference-v2'
m=dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),plan_sha256=sha(H/'PLAN.md'),engine=str(B/'engine'),engine_sha256=sha(B/'engine'),reference=str(ref),reference_hashes={p.name:sha(p) for p in ref.glob('*.py')},numpy=np.__version__,platform=platform.platform(),cases=[],coordinate_seed_rule='PCG64 SeedSequence([geometry_index, seed])',replicate_seed_rule='PCG64 SeedSequence([7200, geometry_index, seed, replicate])')
for gi,geometry in enumerate(['square','helix','sphere']):
 for seed in [6101,6102,6103]:
  rng=np.random.default_rng(np.random.SeedSequence([gi,seed]));n=200;name=f'{geometry}-{seed}'
  if geometry=='square':
   latent=rng.uniform(-1,1,(n,2));X=latent.copy();mean=np.sin(np.pi*X[:,0])*np.cos(np.pi*X[:,1]/2);oracle=squareform(pdist(X))
  elif geometry=='helix':
   t=rng.uniform(0,4*np.pi,n);latent=t[:,None];X=np.column_stack([np.cos(t),np.sin(t),.15*t]);oracle=np.sqrt(1+.15**2)*np.abs(t[:,None]-t);mean=np.sin(t/2)+.3*t/(4*np.pi)
  else:
   z=rng.uniform(-1,1,n);angle=rng.uniform(0,2*np.pi,n);latent=np.column_stack([z,angle]);X=np.column_stack([np.sqrt(1-z*z)*np.cos(angle),np.sqrt(1-z*z)*np.sin(angle),z]);oracle=np.arccos(np.clip(X@X.T,-1,1));np.fill_diagonal(oracle,0);mean=z+.5*X[:,0]*X[:,1]
  D=squareform(pdist(X));assert np.array_equal(D,D.T) and np.array_equal(oracle,oracle.T) and np.isfinite(oracle).all();assert np.all(D[np.triu_indices(n,1)]>1e-8)
  folder=P/'fixtures'/name;folder.mkdir(parents=True);inp=folder/'input.json';truth=folder/'truth.npz'
  write(inp,dict(schema_version=1,numerical_policy='IAN evaluated-LP retry-power 0.1',features=X.tolist(),distances=D.tolist(),ids=[f'{name}-{i:03}' for i in range(n)]))
  orders=[];noise=[]
  for rep in range(10):
   rr=np.random.default_rng(np.random.SeedSequence([7200,gi,seed,rep]));orders.append(rr.permutation(n));noise.append(rr.normal(0,.2,n))
  noise=np.array(noise);orders=np.array(orders);np.savez_compressed(truth,latent=latent,oracle=oracle,mean=mean,order=orders,noise=noise,response=mean+noise)
  m['cases'].append(dict(name=name,geometry=geometry,geometry_index=gi,seed=seed,n=n,path=str(inp),input_sha256=sha(inp),truth=str(truth),truth_sha256=sha(truth)))
write(P/'manifest.json',m);print('Frozen nine coordinate datasets and 90 independent response/split replicates; zero solves.')
