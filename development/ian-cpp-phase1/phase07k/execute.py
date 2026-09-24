"""Fixed fourteen-run schedule; corrected reap-first guard with bounded counts."""
import importlib.util,shutil
from common import *
root=Path(sys.argv[1]).resolve();assert (root/'derivation.json').exists()
# Version the audited guard by a deterministic, recorded source transformation.
original=HERE.parent/'phase07h/oneshot_guard.py';source=original.read_text()
for a,b in [('expected_events=1','expected_events=500'),('events>1','events>500'),("if events!=1:reason=reason or 'single_solve_contract_count'","if events>500:reason=reason or 'solve_contract_count'")]:
 assert source.count(a)==1;source=source.replace(a,b)
guard=root/'trajectory_guard.py';guard.write_text(source)
spec=importlib.util.spec_from_file_location('trajectory_guard',guard);g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
fixture=W/'phase07f/fixtures-v1/helix_1000.json'
schedule=[dict(mode=mode,interface=interface,name='helix_1000',fixture=str(fixture)) for mode in ['historical','multiply','power'] for interface in ['native','evaluated']]
for name in ['nonuniform_curve','variable_density_patch','nearby_curved_arms','pressmat_hellinger_subset']:
 for interface in ['native','evaluated']:schedule.append(dict(mode='power',interface=interface,name=name,fixture=str(W/f'phase07e/engine-fixtures-v1/{name}.json')))
ledger=dict(revision=revision(),schedule=schedule,processes=[],complete=False,optimizer_calls=0,guard_parent_sha256=sha(original),guard_sha256=sha(guard))
write(root/'ledger.json',ledger)
for i,cell in enumerate(schedule):
 used=sum(p['wall_seconds'] for p in ledger['processes'])
 assert used<900 and ledger['optimizer_calls']<=1500 and shutil.disk_usage(root).free>20*2**30 and g.tree_bytes(root)<16*2**30
 g.reserve(root/'reservations.json',14,cell)
 mode=cell['mode'];interface=cell['interface'];base=E/'candidate' if mode=='historical' else root/mode/'candidate'
 engine=W/'phase07e/build-v1/ian_engine' if mode=='historical' else root/mode/'build/ian_engine'
 folder=root/'runs'/str(i);out=folder/'child'
 cmd=[engine,cell['fixture'],out,'--interval','100'] if interface=='native' else [sys.executable,'-B',base/'reference.py',cell['fixture'],out,'evaluated']
 result=g.run(cmd,folder,root,wall_limit=min(180,900-used));result.update(cell=cell,index=i)
 ledger['processes'].append(result);ledger['optimizer_calls']+=result['optimizer_calls'];write(root/'ledger.json',ledger)
 assert result['reason'] is None and result['state']=='reaped',result
 status=load(out/'status.json');print(i,mode,interface,cell['name'],status['complete'],result['optimizer_calls'],status.get('error'),flush=True)
ledger['complete']=True;write(root/'ledger.json',ledger)
