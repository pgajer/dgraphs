"""Read-only reconstruction of the declared random streams and artifact identities."""
import json,sys,hashlib
from pathlib import Path
import numpy as np
P=Path(sys.argv[1]);out=Path(sys.argv[2]);assert not out.exists();m=json.loads((P/'manifest.json').read_text());checks=[]
for c in m['cases']:
 raw=json.loads(Path(c['path']).read_text());t=np.load(c['truth']);r=np.random.default_rng(np.random.SeedSequence([c['geometry_index'],c['seed']]));n=c['n']
 if c['geometry']=='square':latent=r.uniform(-1,1,(n,2));X=latent
 elif c['geometry']=='helix':a=r.uniform(0,4*np.pi,n);latent=a[:,None];X=np.column_stack([np.cos(a),np.sin(a),.15*a])
 else:
  z=r.uniform(-1,1,n);a=r.uniform(0,2*np.pi,n);latent=np.column_stack([z,a]);X=np.column_stack([np.sqrt(1-z*z)*np.cos(a),np.sqrt(1-z*z)*np.sin(a),z])
 assert np.array_equal(latent,t['latent']) and np.array_equal(X,raw['features'])
 for rep in range(10):
  rr=np.random.default_rng(np.random.SeedSequence([7200,c['geometry_index'],c['seed'],rep]));assert np.array_equal(rr.permutation(n),t['order'][rep]);assert np.array_equal(rr.normal(0,.2,n),t['noise'][rep])
 checks.append(dict(dataset=c['name'],coordinates=True,split_and_noise_replicates=10,input_sha256=hashlib.sha256(Path(c['path']).read_bytes()).hexdigest(),truth_sha256=hashlib.sha256(Path(c['truth']).read_bytes()).hexdigest()))
out.write_text(json.dumps(dict(passed=True,checks=checks,engine_calls=0),indent=2)+'\n');print('Nine coordinate streams and 90 split/noise streams reconstruct exactly.')
