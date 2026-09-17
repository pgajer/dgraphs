"""Copy only frozen inputs; add an explicit experimental policy declaration."""
import json,hashlib,sys
from pathlib import Path
POLICY='IAN evaluated-LP retry 0.1'
def load(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
w=Path(sys.argv[1]);root=w/'phase07c/fixtures-v1';root.mkdir(parents=True,exist_ok=False)
cases=[]
def add(name,source,kind,baseline):
 d=load(source);d['numerical_policy']=POLICY;p=root/(name+'.json');p.write_text(json.dumps(d,allow_nan=False)+'\n')
 cases.append(dict(name=name,input=str(p),sha256=sha(p),source=str(source),source_sha256=sha(source),kind=kind,baseline={k:str(v) for k,v in baseline.items()}))
for n in load(w/'phase03/fixtures-v1/manifest.json')['ordinary']:
 add(n,w/'phase03/fixtures-v1'/(n+'.json'),'full',dict(native=w/'phase04/regressions-v1'/n/'child',evaluated=w/'phase03/cases-v1'/n/'evaluated/child'))
for n in load(w/'phase05/fixtures-v1/manifest.json')['complete_inputs']:
 add(n,w/'phase05/fixtures-v1'/(n+'.json'),'full',{c:w/'phase05/full-v1'/n/c/'child' for c in ['native','evaluated']})
ledger=load(w/'phase05/probes-v2/ledger.json')
for e in load(w/'phase05/calibration-v1/manifest.json')['cases']:
 n=e['name'];add(n,Path(e['input']),'probe',{c:ledger['runs'][n+'/'+c]['folder'] for c in ['native','evaluated']})
add('stage-probes',w/'phase05/fixtures-v1/stage-probes.json','stage',{c:w/'phase05/stages-v1/stage-probes'/c/'child' for c in ['native','evaluated']})
ledger=load(w/'phase07/ladder-v2/ledger.json')
for n in ['helix_500','cloud_500','lobes_500','pressmat_500']:
 e=ledger['runs'][n+'/native'];baselines={c:next(v for v in ledger['runs'][n+'/'+c]['process']['command'] if str(v).endswith('/child')) for c in ['native','evaluated']}
 add(n,Path(e['fixture']),'scale',baselines)
(root/'manifest.json').write_text(json.dumps(dict(cases=cases),indent=2)+'\n')
print(len(cases),'frozen fixtures copied with explicit policy')
