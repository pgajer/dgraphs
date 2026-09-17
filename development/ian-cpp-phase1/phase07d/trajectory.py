"""Qualified helix trajectory, then conditional frozen regression panel."""
import shutil,subprocess,sys,hashlib
from pathlib import Path
from support import *
H=HERE;w=Path(sys.argv[1]);root=Path(sys.argv[2]);root.mkdir(parents=True,exist_ok=False);build=w/'phase07d/build-v1';candidate=H/'candidate'
prior=load(w/'phase07d/diagnostic-v1/ledger.json');assert prior['complete'] and prior['qualified']==['units11']
# Independent reconstruction of the configured compiled identity.
names=sorted(str(p.relative_to(candidate)) for d in ['include','src','tests'] for p in (candidate/d).rglob('*') if p.suffix in ['.hpp','.cpp','.inc'])
identity=hashlib.sha256((''.join(sha(candidate/n) for n in names)+sha(candidate/'CMakeLists.txt')).encode()).hexdigest()
flags=(build/'CMakeFiles/ian_core.dir/flags.make').read_text();assert identity in flags and sha(candidate/'config.json') in flags
ledger=dict(complete=False,runs={},comparisons={},processes=[],prior_processes=prior['processes'],gated=[],revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),source_identity=identity,configuration_identity=sha(candidate/'config.json'),engine_sha256=sha(build/'ian_engine'),policy=POLICIES['units11'])
def save():write(root/'ledger.json',ledger)
def execute(cmd,folder):
 used=ledger['prior_processes']+ledger['processes'];wall=3600-sum(x['wall_seconds'] for x in used);solves=8000-sum(x['observed_solves'] for x in used)
 assert wall>0 and solves>0 and tree_bytes(root.parent)<16*2**30 and shutil.disk_usage(root).free>20*2**30
 p=run(cmd,folder,root.parent,wall,solves);ledger['processes'].append(p);save();assert p['reason'] is None;return p
cases=load(w/'phase07d/engine-fixtures-v1/manifest.json')['cases'];cases.sort(key=lambda x:x['name']!='helix_500')
save();gate=True
try:
 for case in cases:
  n=case['name'];kind=case['kind'];fixture=Path(case['input']);paths={};ok=True;both=True
  if not gate:ledger['gated'].append(dict(name=n,reason='helix_or_previous_validation_not_passed'));save();continue
  for condition in ['native','evaluated']:
   folder=root/n/condition;child=folder/'child';paths[condition]=child;probe=kind in ['probe','stage']
   cmd=([build/('ian_probe' if probe else 'ian_engine'),fixture,child]+([] if probe else ['--interval','100']) if condition=='native' else [sys.executable,'-B',candidate/('reference_probe.py' if probe else 'reference.py'),fixture,child,'evaluated'])
   proc=execute(cmd,folder);complete=(child/'stages.json').exists() if kind=='stage' else (load(child/'status.json').get('complete',False) if (child/'status.json').exists() else False)
   item=dict(child=str(child),input=str(fixture),process=proc,complete=complete);both &= complete and proc['exit_code']==0
   if kind!='stage':
    args=['probe',child,folder/'checks'] if kind=='probe' else ['inspect',child,fixture,folder/'checks']
    p=execute([sys.executable,'-B',H/'validate.py',*args],folder/'diagnostic');item['checks']=load(folder/'checks/summary.json') if p['exit_code']==0 else dict(valid=False);ok &= item['checks']['valid']
    p=execute([sys.executable,'-B',H/'validate.py','exact',Path(case['baseline'][condition])/'trace.jsonl',child/'trace.jsonl',folder/'same-path.json']+(['prefix'] if n=='helix_500' else []),folder/'same-path-process')
    item['same_path']=load(folder/'same-path.json') if p['exit_code']==0 else dict(passed=False);ok &= item['same_path']['passed']
   else:item['same_path']=dict(passed=load(Path(case['baseline'][condition])/'stages.json')==load(child/'stages.json'));ok &= item['same_path']['passed']
   item['passed']=bool(complete and proc['exit_code']==0);ledger['runs'][n+'/'+condition]=item;save();print(n,condition,'complete' if complete else 'REFUSED',proc['observed_solves'],'attempts',round(proc['wall_seconds'],2),'seconds',flush=True)
  if kind!='stage':
   folder=root/n/'comparison';p=execute([sys.executable,'-B',H/'validate.py','compare',paths['native']/'trace.jsonl',paths['evaluated']/'trace.jsonl',folder/'checks'],folder)
   comparison=load(folder/'checks/summary.json') if p['exit_code']==0 else dict(passed=False)
  else:comparison=dict(passed=load(paths['native']/'stages.json')==load(paths['evaluated']/'stages.json'))
  ledger['comparisons'][n]=comparison;gate=bool(ok and both and comparison['passed']);save()
 ledger['complete']=True;ledger['validation_gate']=gate;save()
except Exception as e:ledger['error']=repr(e);save();raise
print('Conditional trajectory schedule accounted for.',flush=True)
