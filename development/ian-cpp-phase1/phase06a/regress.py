"""Serial frozen native regressions; stop at the first new discrepancy."""
import argparse
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'phase04'))
from support import revision,load,write,sha,run,inspect_run,graph_units,compare,traces,check_lp,supervise,one_thread_environment

p=argparse.ArgumentParser()
p.add_argument('worker',type=Path)
p.add_argument('output',type=Path)
p.add_argument('--build',type=Path,required=True)
a=p.parse_args()
rev=revision()
a.output.mkdir(parents=True,exist_ok=False)
engine,probe=a.build/'ian_engine',a.build/'ian_probe'
record=dict(revision=rev,engine_sha256=sha(engine),probe_sha256=sha(probe),complete=False,full=[],probes=[],stages=[])
def save():write(a.output/'checks.json',record)
def exact(left,right):
    return [{k:v for k,v in e.items() if k!='seconds'} for e in traces(left)] == [
            {k:v for k,v in e.items() if k!='seconds'} for e in traces(right)]
def comparison(left,right,out):
    c=compare(left,right,out)
    return dict(passed=c['passed'],events=[c['events_a'],c['events_b']],first_divergence=c['first_divergence'])
def ensure(ok):
    save()
    if not ok:raise SystemExit('Stopped at discrepancy; retain evidence and diagnose before continuation.')

cases=[]
for name in load(a.worker/'phase03/fixtures-v1/manifest.json')['ordinary']:
    cases.append((name,a.worker/'phase03/fixtures-v1'/(name+'.json'),
        a.worker/'phase04/regressions-v1'/name/'child',a.worker/'phase03/cases-v1'/name/'evaluated/child'))
for name in load(a.worker/'phase05/fixtures-v1/manifest.json')['complete_inputs']:
    cases.append((name,a.worker/'phase05/fixtures-v1'/(name+'.json'),
        a.worker/'phase05/full-v1'/name/'native/child',a.worker/'phase05/full-v1'/name/'evaluated/child'))
for name,fixture,old,python in cases:
    folder=a.output/'full'/name
    proc=run(fixture,folder,'native',engine)
    child=folder/'child'
    coverage=inspect_run(child)
    item=dict(name=name,input=str(fixture),input_sha256=sha(fixture),process=proc,coverage=coverage,
        native=comparison(old,child,folder/'native-comparison'),
        evaluated=comparison(python,child,folder/'evaluated-comparison'),
        exact_except_seconds=exact(old,child),units=graph_units(child),checkpoints=[])
    for stage in ['graph','scales','affinity']:
        x,y=load(old/(stage+'.json')),load(child/(stage+'.json'))
        x.pop('source_sha256');y.pop('source_sha256')
        item['checkpoints'].append(dict(stage=stage,equal_except_source=x==y))
        status=load(child/'status.json')
        assert status[stage+'_sha256']==sha(child/(stage+'.json'))
    result=load(child/'result.json')
    graph=load(child/'graph.json');scales=load(child/'scales.json');affinity=load(child/'affinity.json')
    assert result['complete'] and all(result[k+'_valid'] for k in ['graph','scales','affinity'])
    assert result['graph']['edges']==graph['edges'] and result['scales']==scales['scales'] and result['affinity']==affinity['affinity']
    fixture_data=load(fixture);reps=result['mapping']['representatives']
    assert result['graph']['edge_lengths']==[fixture_data['distances'][reps[i]][reps[j]] for i,j in graph['edges']]
    record['full'].append(item)
    ensure(proc['exit_code']==0 and coverage['eligible'] and item['native']['passed'] and item['evaluated']['passed']
        and item['exact_except_seconds'] and all(x['equal_except_source'] for x in item['checkpoints']))
    print(name,'full exact/frozen-limit comparisons passed',flush=True)

old_ledger=load(a.worker/'phase05/probes-v2/ledger.json')
for case in load(a.worker/'phase05/calibration-v1/manifest.json')['cases']:
    name=case['name'];folder=a.output/'probes'/name
    proc=supervise([str(probe),case['input'],str(folder/'child')],folder,one_thread_environment())
    child=folder/'child';raw=[check_lp(e) for e in traces(child) if e['event']=='solve']
    native=Path(old_ledger['runs'][name+'/native']['folder'])
    python=Path(old_ledger['runs'][name+'/evaluated']['folder'])
    item=dict(name=name,input=case['input'],input_sha256=sha(case['input']),process=proc,raw=raw,
        native=comparison(native,child,folder/'native-comparison'),
        evaluated=comparison(python,child,folder/'evaluated-comparison'),
        exact_except_seconds=exact(native,child),result_exact=load(native/'result.json')==load(child/'result.json'))
    record['probes'].append(item)
    ensure(proc['exit_code']==0 and all(x['accepted'] and x['dual_valid'] for x in raw)
        and item['native']['passed'] and item['evaluated']['passed'] and item['exact_except_seconds'] and item['result_exact'])
    print(name,'fixed-state exact/frozen-limit comparisons passed',flush=True)

for name,fixture,binary,old in [
    ('legacy',a.worker/'phase03/boundary-supplement-v1/stages.json',engine,a.worker/'phase04/regressions-v1/stages/child'),
    ('phase05',a.worker/'phase05/fixtures-v1/stage-probes.json',probe,a.worker/'phase05/stages-v1/stage-probes/native/child')]:
    folder=a.output/'stages'/name
    proc=supervise([str(binary),str(fixture),str(folder/'child')],folder,one_thread_environment())
    x,y=load(old/'stages.json'),load(folder/'child/stages.json')
    raw=[]
    if name=='legacy':
        raw=[check_lp(y['disconnected']['solve'])]
        x['disconnected']['solve'].pop('seconds');y['disconnected']['solve'].pop('seconds')
    item=dict(name=name,process=proc,exact=x==y,raw=raw)
    record['stages'].append(item)
    ensure(proc['exit_code']==0 and item['exact'] and all(c['accepted'] and c['dual_valid'] for c in raw))

cmd=[sys.executable,'-B',str(HERE.parent/'phase03/failures.py'),str(a.worker/'phase03/fixtures-v1/failure_input.json'),
    str(a.output/'failures'),'--native',str(engine)]
record['failure_driver']=supervise(cmd,a.output/'failure-driver',one_thread_environment())
ensure(record['failure_driver']['exit_code']==0)
record['failures']=load(a.output/'failures/checks.json')
folder=a.output/'pruning-cap'
proc=run(a.worker/'phase03/fixtures-v1/pressmat_hellinger_subset.json',folder,'native',engine,'pruning_cap')
old=a.worker/'phase04/regressions-v1/pruning-cap/child'
record['cap']=dict(process=proc,comparison=comparison(old,folder/'child',folder/'comparison'),
    exact_except_seconds=exact(old,folder/'child'),status=load(folder/'child/status.json'))
ensure(proc['exit_code']!=0 and record['cap']['comparison']['passed'] and record['cap']['exact_except_seconds']
    and not any(record['cap']['status'][k] for k in ['graph','scales','affinity','complete']))
record['complete']=True
save()
print('Frozen regression workload complete.',flush=True)
