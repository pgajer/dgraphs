"""Freeze an engineering qualification panel before engine calls."""
import json,sys,hashlib,subprocess
from pathlib import Path
import numpy as np
from scipy.spatial.distance import pdist,squareform
P=Path(sys.argv[1]);F=P/'fixtures';F.mkdir(exist_ok=False);S=P.parent/'stage05-science';B=P.parent/'stage01-policy';load=lambda p:json.loads(p.read_text());write=lambda p,x:p.write_text(json.dumps(x,indent=2)+'\n');sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
cases=[]
for c in load(S/'manifest.json')['cases']:
 inp=load(Path(c['path']));cases.append(dict(name=c['name'],input=inp,baseline=str(S/'runs'/c['name']/'native/child'),variant=True))
for c in load(B/'build-v1/manifest.json')['fixtures']:
 if c['name'] in ['nonuniform_curve','variable_density_patch','nearby_curved_arms','pressmat_hellinger_subset','helix_1000']:
  cases.append(dict(name=c['name'],input=load(Path(c['path'])),baseline=str(B/'qualification-v2/runs'/c['name']/'native/child'),variant=False))
for seed in [6201,6202,6203]:
 rng=np.random.default_rng(np.random.SeedSequence([1,seed]));t=rng.uniform(0,4*np.pi,200);X=np.column_stack([np.cos(t),np.sin(t),.15*t]);name=f'helix-{seed}'
 cases.append(dict(name=name,input=dict(schema_version=1,numerical_policy='IAN evaluated-LP retry-power 0.1',features=X.tolist(),distances=squareform(pdist(X)).tolist(),ids=[f'{name}-{i:03}' for i in range(200)]),baseline=None,variant=True))
for c in cases:
 for mode in ['reference','connected']:
  inp=dict(c['input']);
  if mode=='connected':inp['preserve_connectivity']=True
  file=F/(c['name']+'-'+mode+'.json');write(file,inp);c[mode]=dict(path=str(file),sha256=sha(file))
 c.pop('input')
 if c['baseline'] and not (Path(c['baseline'])/'trace.jsonl').exists():
  alt=Path(c['baseline'].replace('qualification-v2','qualification-v1'));assert (alt/'trace.jsonl').exists();c['baseline']=str(alt)
write(P/'fixtures.json',dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),cases=cases,seed_rule='Stage 5 PCG64 SeedSequence([1, seed]), uniform [0, 4*pi]'))
print('Frozen',len(cases),'cases; zero engine calls.')
