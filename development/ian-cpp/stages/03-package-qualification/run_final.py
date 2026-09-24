"""Serial installed R qualification, with all entries and attempts accounted."""
import sys,json,os,subprocess,shutil,itertools,hashlib
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[3]
sys.path.insert(0,str(HERE.parent/'01-numerical-policy'));from guard import run,reserve,write
sys.path.insert(0,str(ROOT/'development/ian-cpp-phase1/phase07e'));import validate as v
v.POLICY='IAN evaluated-LP retry-power 0.1'
root=Path(sys.argv[1]);out=root/'numerical-v2';out.mkdir(exist_ok=False)
load=lambda p:json.loads(Path(p).read_text())
envmanifest=load(root/'environment.json');stage1=root.parent/'stage01-policy';fixtures=stage1/'build-v1/fixtures';small=['nonuniform_curve','variable_density_patch','nearby_curved_arms','pressmat_hellinger_subset']
prior=load(root/'numerical-v1/ledger.json');assert prior['complete']
ledger=dict(prior_processes=prior['processes'],revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),schedule=[],processes=[],checks={},complete=False)
for runtime in ['rdevel-v2','r45-v2']:
 cfg=envmanifest['runtimes'][runtime]
 lib=Path(cfg['library']);rs=cfg['rscript'];base=out/runtime
 assert load(root/runtime/'backend-v2/build-record.json')['complete']
 relocated=root/runtime/'relocated';relocated.mkdir();shutil.copy2(lib/'dgraphs/ian/native/dgraphs_ian.so',relocated/'dgraphs_ian.so')
 for policy,names in [('strict',['pressmat_hellinger_subset']),('candidate',['helix_500'])]:
  for name in names:
   f=fixtures/(name+('-strict' if policy=='strict' else '')+'.json');baseline=root/'numerical-v1'/runtime.removesuffix('-v2')/(policy+'-'+name)/'child/result.rds';native=stage1/'supplement-v1'/('strict-'+name)/'child' if policy=='strict' else stage1/'qualification-v2/runs'/name/'native/child'
   folder=base/(policy+'-'+name)
   ledger['schedule'].append(dict(name=runtime+'-'+policy+'-'+name,runtime=runtime,entries=1,kind=policy,fixture=str(f),baseline=str(baseline),native=str(native),command=[rs,'--vanilla',str(HERE/'full_case.R'),str(lib),str(f),'installed',str(folder/'child'),str(baseline)],folder=str(folder)))
 for kind,entries,mode in [('candidate-controls',3,'candidate'),('relocation',1,str(relocated/'dgraphs_ian.so'))]:
  folder=base/kind;ledger['schedule'].append(dict(name=runtime+'-'+kind,runtime=runtime,entries=entries,kind=kind,command=[rs,'--vanilla',str(HERE/'controls.R'),str(lib),mode,str(folder/'child')],folder=str(folder)))
assert sum(c['entries'] for c in ledger['schedule'])==12
write(out/'ledger.json',ledger)
def save():write(out/'ledger.json',ledger)
def check(name,condition):ledger['checks'][name]=bool(condition);save();assert condition,name
try:
 for item in ledger['schedule']:
  cfg=envmanifest['runtimes'][item['runtime']];os.environ.pop('R_HOME',None);os.environ.update(cfg['env'])
  census=ledger['prior_processes']+ledger['processes'];used=sum(p['optimizer_calls'] for p in census);wall=sum(p['wall_seconds'] for p in census);entries=sum(p['engine_entries'] for p in census)
  assert used<2000 and wall<3600 and entries+item['entries']<=64 and shutil.disk_usage(root).free>20*2**30
  reserve(out/'reservations.json',64,dict(name=item['name'],engine_entries=item['entries'],command=item['command']))
  r=run(item['command'],item['folder'],root,wall_limit=min(900,3600-wall),max_attempts=min(250,2000-used))
  child=Path(item['folder'])/'child';observed=0
  if (child/'ledger.json').exists():
   interim=load(child/'ledger.json');observed=len(interim['calls'] if item['kind']=='interface' else interim)
  elif (child/'reservation.txt').exists():observed=1
  r.update(name=item['name'],engine_entries=observed,reserved_engine_entries=item['entries'],entry_count_scope='observed R adapter-call reservations; failures may leave an incomplete call')
  ledger['processes'].append(r);save()
  check(item['name']+' completion/accounting',r['state']=='reaped' and r['reason'] is None and r['exit_code']==0)
  child=Path(item['folder'])/'child';kind=item['kind']
  if kind in ['strict','candidate']:
   compare=v.compare(Path(item['native'])/'trace.jsonl',child/'trace.jsonl',Path(item['folder'])/'comparison');check(item['name']+' native comparison',compare['passed'])
   if kind=='candidate':v.retry_checks(child,Path(item['folder'])/'certificates')
   else:
    for e in v.events(child/'trace.jsonl'):
     if e['event']=='solve':
      c=v.inspect.__globals__['check_lp'](e);check(item['name']+' certificate '+str(e['number']),c['accepted'] and c['dual_valid'])
   check(item['name']+' solve census',load(child/'status.json')['solves']==r['optimizer_calls'])
  else:
   data=load(child/'ledger.json');calls=data['calls'] if kind=='interface' else data
   check(item['name']+' entry census',len(calls)==item['entries'] and all(c['status']=='returned' for c in calls.values()))
   check(item['name']+' solve census',sum(c['solves'] for c in calls.values())==r['optimizer_calls'])
  print(item['name'],item['entries'],'entries',r['optimizer_calls'],'attempts',flush=True)
 ledger['complete']=True;save()
except Exception as exc:ledger['error']=repr(exc);save();raise
