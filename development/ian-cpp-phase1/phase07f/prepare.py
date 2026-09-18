"""Freeze original scale fixtures and four R-generated quadforms without solving."""
import os,sys,subprocess,math
from pathlib import Path
import numpy as np
from scipy.spatial.distance import pdist,squareform
from support import *
w=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=False);repo=Path.cwd()
assert not subprocess.check_output(['git','status','--porcelain'],text=True)
revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
source_manifest=load(w/'phase07/fixtures-v1/manifest.json');prior=load(w/'phase07e/trajectory-v1/ledger.json')
assert prior['complete'] and prior['validation_gate']
assert sha(w/'phase07e/build-v1/ian_engine')==prior['engine_sha256']
cases=[]
for family in ['helix','cloud','lobes']:
 name=family+'_1000';old=source_manifest['files'][name];source=Path(old['path']);assert sha(source)==old['sha256']
 d=load(source);d['numerical_policy']=POLICY;p=out/(name+'.json');write(p,d)
 cases.append(dict(name=name,input=str(p),sha256=sha(p),source=str(source),source_sha256=sha(source),family=family,n=1000,preexisting_unexecuted_fixture=True))
env=dict(os.environ)
for k in ['OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS','VECLIB_MAXIMUM_THREADS','NUMEXPR_NUM_THREADS','RAYON_NUM_THREADS']:env[k]='1'
cmd=['/usr/local/bin/Rscript','--vanilla',str(HERE/'quadforms.R'),str(repo),str(out/'quadforms')]
write(out/'generator-command.json',dict(command=cmd,revision=revision,cwd=str(repo),solver_calls=0))
p=subprocess.run(cmd,env=env,capture_output=True,text=True);(out/'generator.stdout').write_text(p.stdout);(out/'generator.stderr').write_text(p.stderr);assert p.returncode==0,p.stderr
for dimension in range(2,6):
 name=f'quadform_d{dimension}_1000';folder=out/'quadforms'/f'quadform_d{dimension}'
 U=np.fromfile(folder/'latent.bin',dtype='<f8').reshape((1000,dimension),order='F');X=np.fromfile(folder/'predictors.bin',dtype='<f8').reshape((1000,dimension+1),order='F');A=np.fromfile(folder/'form.bin',dtype='<f8').reshape((dimension,dimension),order='F')
 expected=np.diag([(-1)**j*.5/math.sqrt(dimension) for j in range(dimension)])
 assert np.array_equal(A,expected) and np.array_equal(X[:,:dimension],U) and np.isfinite(X).all() and np.all(abs(U)<=1)
 q=np.array([math.fsum(float(row[i])*float(A[i,j])*float(row[j]) for i in range(dimension) for j in range(dimension)) for row in U])
 error=float(max(abs(q-X[:,-1])));assert error<=1e-14 and len(np.unique(X,axis=0))==1000
 distances=squareform(pdist(X));assert np.array_equal(distances,distances.T) and not np.any(np.diag(distances)) and distances[np.triu_indices(1000,1)].min()>0
 provenance=dict(family='quadform',intrinsic_dimension=dimension,ambient_dimension=dimension+1,seed=2026091700+dimension,n=1000,form=A.tolist(),latent_sampling='uniform box [-1,1]^d; not uniform surface area',embedding='(u, u^T A u)',noise='none',canonical_frame=True,source_sample=str(folder/'sample.rds'),source_sample_sha256=sha(folder/'sample.rds'),independent_quadratic_max_error=error)
 fixture=dict(kind='full',name=name,features=X.tolist(),distances=distances.tolist(),ids=[f'{name}-{i}' for i in range(1000)],numerical_policy=POLICY,provenance=provenance)
 p=out/(name+'.json');write(p,fixture)
 cases.append(dict(name=name,input=str(p),sha256=sha(p),family='quadform',n=1000,intrinsic_dimension=dimension,ambient_dimension=dimension+1,provenance=provenance))
# Recompute every distance independently using scalar summation, including originals.
checks=[]
for c in cases:
 d=load(c['input']);X=np.array(d['features']);D=np.array(d['distances']);largest=0.
 assert X.shape[0]==1000 and D.shape==(1000,1000) and len(np.unique(X,axis=0))==1000
 assert len(set(d['ids']))==1000 and np.isfinite(X).all() and np.isfinite(D).all() and np.array_equal(D,D.T) and np.all(np.diag(D)==0)
 for i in range(1000):
  for j in range(i):
   expected=math.sqrt(math.fsum((float(a)-float(b))**2 for a,b in zip(X[i],X[j])))
   largest=max(largest,abs(D[i,j]-expected));assert abs(D[i,j]-expected)<=1e-12+2e-14*expected
 checks.append(dict(name=c['name'],valid=True,scalar_distance_max_error=largest))
rfiles=['R/'+n for n in ['synthetic_components.R','synthetic_geometry.R','synthetic_sampling.R','synthetic_realization.R']]
write(out/'manifest.json',dict(revision=revision,cases=cases,fixture_checks=checks,plan_sha256=sha(HERE/'PLAN.md'),r_sources={n:sha(repo/n) for n in rfiles},reused_prerequisite=dict(ledger=str(w/'phase07e/trajectory-v1/ledger.json'),sha256=sha(w/'phase07e/trajectory-v1/ledger.json'),audit=str(repo.parent/'auditor/review-7e/audit.md'),audit_sha256=sha(repo.parent/'auditor/review-7e/audit.md'),fresh_execution=False),runtime={k:prior[k] for k in ['source_identity','configuration_identity','engine_sha256']},policy=POLICY,solver_calls=0))
print('Seven 1,000-profile fixtures frozen and distances reconstructed; zero solver calls.')
