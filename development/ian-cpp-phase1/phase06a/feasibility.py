"""Execute the frozen clean-build C++/R checks; no search or tuning."""
import argparse
import json
import sys
from pathlib import Path

import numpy as np

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'phase04'))
from support import revision,load,write,sha,compare,traces,check_lp,supervise

p=argparse.ArgumentParser()
p.add_argument('worker',type=Path)
p.add_argument('clean',type=Path)
p.add_argument('output',type=Path)
a=p.parse_args()
rev=revision()
a.output.mkdir(parents=True,exist_ok=False)
build=load(a.clean/'build-record.json');assert build['complete']
env=build['environment']
record=dict(revision=rev,clean_build_sha256=sha(a.clean/'build-record.json'),complete=False,clients=[])
def save():write(a.output/'checks.json',record)
def ensure(ok):
    save()
    if not ok:raise SystemExit('Feasibility discrepancy retained; stop before further numerical execution.')

fixture=a.worker/'phase05/fixtures-v1/helix_120.json'
folder=a.output/'cli-helix'
process=supervise([str(a.clean/'build/ian_engine'),str(fixture),str(folder/'child')],folder,env)
ensure(process['exit_code']==0)
old=a.worker/'phase05/full-v1/helix_120/native/child'
comp=compare(old,folder/'child',folder/'comparison')
def normalized(path):return [{k:v for k,v in e.items() if k!='seconds'} for e in traces(path)]
record['cli']=dict(process=process,comparison_passed=comp['passed'],exact_except_seconds=normalized(old)==normalized(folder/'child'),
    raw=[check_lp(e) for e in traces(folder/'child') if e['event']=='solve'])
ensure(comp['passed'] and record['cli']['exact_except_seconds'] and all(c['accepted'] and c['dual_valid'] for c in record['cli']['raw']))

for name,fixture,expected,mode in [
    ('nonuniform_curve',a.worker/'phase03/fixtures-v1/nonuniform_curve.json',
        a.worker/'phase06a/regressions-v1/full/nonuniform_curve/child/result.json','check'),
    ('helix_120',fixture,folder/'child/result.json','single')]:
    inp=load(fixture);ref=load(expected)
    f=a.output/(name+'-input.txt')
    with f.open('w') as stream:
        stream.write(f"{len(inp['features'])} {len(inp['features'][0])}\n")
        for key in ['features','distances']:
            for row in inp[key]:stream.write(' '.join(format(x,'.17g') for x in row)+'\n')
        for ident in inp['ids']:stream.write(json.dumps(ident)+'\n')
    output=a.output/(name+'-result.json')
    proc=supervise([str(a.clean/'consumer-build/ian_consumer'),str(f),str(output),mode],a.output/('consumer-'+name),env)
    ensure(proc['exit_code']==0)
    result=load(output)
    checks={}
    for key in ['edges','edge_lengths','degrees','components','isolates']:
        checks[key]=result[key]==ref['graph'][key]
    checks['upper']=result['upper']==ref['graph']['upper']
    for key in ['representatives','member_to_profile','specimen_ids','profile_ids']:
        checks[key]=result[key]==ref['mapping'][key]
    for key in ['scales','internal_scales','affinity','multiplier','solves']:
        checks[key]=result[key]==ref[key]
    checks['distance_multiplier']=result['distance_multiplier']==ref['graph']['scl']
    checks['participants']=result['participant_ids']==['participant-'+str(i//2) for i in range(len(inp['ids']))]
    item=dict(name=name,process=proc,input_sha256=sha(f),expected_sha256=sha(expected),
        result_sha256=sha(output),checks=checks,total_solves=result['total_solves'],invalid_calls=result['invalid_calls_checked'])
    record['clients'].append(item)
    ensure(result['complete'] and all(checks.values()))
    print(name,'installed public C++ consumer checks passed',flush=True)

inp=load(a.worker/'phase05/fixtures-v1/helix_120.json')
ref=load(a.output/'cli-helix/child/result.json')
data=a.output/'r-input';data.mkdir()
def array(name,value):
    x=np.asarray(value,dtype='<f8');x.tofile(data/(name+'.bin'))
    if x.ndim==2:(data/(name+'.shape')).write_text(' '.join(map(str,x.shape))+'\n')
for key in ['features','distances']:array(key,inp[key])
for key in ['edges','edge_lengths','degrees','components','isolates']:array(key,ref['graph'][key])
for key in ['representatives','member_to_profile']:array(key,ref['mapping'][key])
for key in ['scales','internal_scales','affinity']:array(key,ref[key])
array('distance_multiplier',[ref['graph']['scl']]);array('multiplier',[ref['multiplier']])
(data/'ids.txt').write_text('\n'.join(inp['ids'])+'\n')
proc=supervise(['/usr/local/bin/Rscript','--vanilla',str(HERE/'tests/r_smoke.R'),
    str(a.clean/'consumer-build/ian_bridge.so'),str(data),str(a.output/'r-result')],a.output/'r-process',env)
record['r']=dict(process=proc,solves=ref['solves'],raw_solver_trace_available=False,
    fixture_sha256=sha(a.worker/'phase05/fixtures-v1/helix_120.json'),
    input_files={str(f.name):sha(f) for f in data.iterdir()},script_sha256=sha(HERE/'tests/r_smoke.R'))
ensure(proc['exit_code']==0)
assert (a.output/'r-result/checks.txt').read_text().startswith('passed\n')
record['complete']=True
record['new_optimization_solves']=len(record['cli']['raw'])+sum(c['total_solves'] for c in record['clients'])+record['r']['solves']
save()
print('Clean-build CLI, installed C++ API and minimal R call agree. Solves:',record['new_optimization_solves'],flush=True)
