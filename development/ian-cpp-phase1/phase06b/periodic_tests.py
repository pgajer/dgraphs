"""Nondefault checkpoint cadence, forced cancellation save, and resumed cadence."""
import argparse
import sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'phase04'))
from support import revision,load,write,sha,supervise,one_thread_environment,traces,check_lp
p=argparse.ArgumentParser();p.add_argument('root',type=Path);p.add_argument('output',type=Path);a=p.parse_args()
rev=revision();a.output.mkdir(parents=True,exist_ok=False)
engine=a.root/'build-v3/ian_engine';fixture=a.root.parent/'phase03/fixtures-v1/pressmat_hellinger_subset.json'
reference=a.root/'regressions-v2/full/pressmat_hellinger_subset/child'
record=dict(revision=rev,engine_sha256=sha(engine),complete=False,runs=[])
def normalized(v):return [{k:x for k,x in e.items() if k!='seconds'} for e in v]
def run(name,args,code):
    folder=a.output/name;child=folder/'child'
    proc=supervise([str(engine),str(fixture),str(child),*map(str,args)],folder,one_thread_environment())
    ev=traces(child);raw=[check_lp(e) for e in ev if e['event']=='solve']
    record['runs'].append(dict(name=name,process=proc,solves=len(raw),raw_checks=raw))
    write(a.output/'checks.json',record)
    assert proc['exit_code']==code and all(c['accepted'] and c['dual_valid'] for c in raw)
    return child,ev
child,ev=run('interval-three',['--interval',3],0)
checkpoints=sorted((child/'checkpoints').glob('*.json'))
assert [(load(f)['payload']['iteration'],load(f)['payload']['boundary']) for f in checkpoints]==[(2,'pruning'),(4,'graph')]
assert normalized(ev)==normalized(traces(reference)) and load(child/'result.json')==load(reference/'result.json')
cancel,pre=run('force-save',['--interval',100,'--cancel-after',0],3)
checkpoints=sorted((cancel/'checkpoints').glob('*.json'));assert len(checkpoints)==1
assert load(checkpoints[0])['payload']['iteration']==0
child,post=run('resume-interval-three',['--resume',checkpoints[0],'--interval',3],0)
assert normalized(pre+post)==normalized(traces(reference))
assert load(child/'result.json')==load(reference/'result.json')
assert [(load(f)['payload']['iteration'],load(f)['payload']['boundary']) for f in sorted((child/'checkpoints').glob('*.json'))]==[(2,'pruning'),(4,'graph')]
record['total_solver_calls']=sum(x['solves'] for x in record['runs']);assert record['total_solver_calls']==18
record['complete']=True;write(a.output/'checks.json',record);print('Nondefault cadence and forced save passed; 18 solves.')
