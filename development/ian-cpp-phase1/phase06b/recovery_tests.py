"""Serial restart equivalence, real process death, and declared corruption tests."""
import argparse
import copy
import json
import os
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'phase04'))
from support import revision,load,write,sha,supervise,one_thread_environment,traces,check_lp
p=argparse.ArgumentParser();p.add_argument('worker',type=Path);p.add_argument('output',type=Path)
p.add_argument('--build',type=Path,required=True);a=p.parse_args()
rev=revision();a.output.mkdir(parents=True,exist_ok=False)
engine=a.build/'ian_engine';tool=a.build/'ian_checkpoint_tool'
record=dict(revision=rev,engine_sha256=sha(engine),complete=False,runs=[],comparisons=[],mutations=[])
def save():write(a.output/'checks.json',record)
def events(path):return traces(path) if (path/'trace.jsonl').exists() else []
def normalized(values):return [{k:v for k,v in e.items() if k!='seconds'} for e in values]
def fixture(name):
    phase='phase05' if name in ['helix_120','hellinger_256_perturbed','hellinger_300_perturbed'] else 'phase03'
    return a.worker/phase/'fixtures-v1'/(name+'.json')
def reference(name):return a.worker/'phase06b/regressions-v1/full'/name/'child'
def snapshots(folder):return sorted((folder/'checkpoints').glob('checkpoint-*.json'))
def prefix(checkpoint,seen=None):
    seen=set() if seen is None else seen
    assert checkpoint not in seen;seen.add(checkpoint)
    j=load(checkpoint);data=Path(j['trace_file']).read_bytes()[:j['trace_prefix_bytes']]
    values=[json.loads(line) for line in data.splitlines()]
    assert len(values)==j['trace_prefix_events']
    parent=j['parent_checkpoint']
    return (prefix(Path(parent),seen) if parent else [])+values
def run(name,source,options=(),expected=0,action=None):
    folder=a.output/name;child=folder/'child';done=threading.Event();actions=[];errors=[]
    def control():
        while not done.wait(.01):
            marker=child/'ready.json'
            if not marker.exists():continue
            try:
                ready=load(marker);pid=ready['pid']
                import psutil
                assert psutil.Process(pid).cmdline()[0]==str(engine)
                while psutil.Process(pid).status()!=psutil.STATUS_STOPPED:
                    time.sleep(.001)
                os.kill(pid,signal.SIGKILL if action=='kill' else signal.SIGINT)
                if action!='kill':os.kill(pid,signal.SIGCONT)
                actions.append(dict(**ready,action=action));return
            except Exception as e: errors.append(repr(e)); return
    thread=threading.Thread(target=control) if action else None
    if thread:thread.start()
    try:proc=supervise([str(engine),str(source),str(child),*map(str,options)],folder,one_thread_environment())
    finally:
        done.set()
        if thread:thread.join()
    ev=events(child);raw=[check_lp(e) for e in ev if e['event']=='solve']
    item=dict(name=name,source=str(source),input_sha256=sha(source),options=list(map(str,options)),
        process=proc,raw_checks=raw,solves=len(raw),actions=actions)
    record['runs'].append(item);save()
    assert proc['exit_code']==expected,(name,proc)
    assert not errors and (not action or len(actions)==1),(errors,actions)
    assert all(c['accepted'] and c['dual_valid'] for c in raw),name
    assert 460+sum(r['solves'] for r in record['runs'])<=1000
    print(name,'exit',expected,'solves',len(raw),flush=True)
    return child
def compare(checkpoint,child,name):
    expected=reference(name);combined=prefix(checkpoint)+events(child)
    check=dict(checkpoint=str(checkpoint),child=str(child),fixture=name,
        trace_exact=normalized(combined)==normalized(events(expected)),
        result_exact=load(child/'result.json')==load(expected/'result.json'),
        local_solves=len([e for e in events(child) if e['event']=='solve']),
        restored_solves=load(checkpoint)['payload']['solves'])
    record['comparisons'].append(check);save()
    assert check['trace_exact'] and check['result_exact'],check
    assert check['local_solves']+check['restored_solves']==load(child/'result.json')['solves']
    for stage in ['graph','scales','affinity']:
        x,y=load(child/(stage+'.json')),load(expected/(stage+'.json'))
        x.pop('input_sha256');y.pop('input_sha256')
        assert x==y,(name,stage)
        assert load(child/'status.json')[stage+'_sha256']==sha(child/(stage+'.json'))
    assert load(child/'progress.json')['state']=='complete'

# The preselected checkpoints come from the uninterrupted regression executions.
for name,wanted in [('helix_120',0),('helix_120',7),('helix_120','graph'),
                    ('hellinger_256_perturbed',90),('hellinger_300_perturbed',88)]:
    choices=snapshots(reference(name))
    cp=next(f for f in choices if (load(f)['payload']['boundary']=='graph' if wanted=='graph'
                                 else load(f)['payload']['iteration']==wanted))
    child=run(name+'-resume-'+str(wanted),fixture(name),['--resume',cp]);compare(cp,child,name)

small='pressmat_hellinger_subset';source=fixture(small)
child=run('cancel',source,['--cancel-after',0],3);cp=snapshots(child)[-1]
assert load(child/'progress.json')['state']=='cancelled' and load(child/'progress.json')['resumable']
second=run('cancel-again',source,['--resume',cp,'--cancel-after',1],3);cp2=snapshots(second)[-1]
assert normalized(prefix(cp2))==normalized(events(reference(small))[:len(prefix(cp2))])
third=run('cancel-twice-resume',source,['--resume',cp2]);compare(cp2,third,small)

child=run('sigint',source,['--fault','signal_after_directory_sync','--fault-at',1],3,'signal')
cp=snapshots(child)[-1];assert load(child/'progress.json')['state']=='cancelled'
resumed=run('sigint-resume',source,['--resume',cp]);compare(cp,resumed,small)

for point in ['partial_write','after_file_sync','after_rename','after_directory_sync']:
    for at in [1,2]:
        name='kill-'+point+'-'+str(at)
        child=run(name,source,['--fault','kill_'+point,'--fault-at',at],-9,'kill')
        available=snapshots(child)
        expected_count=at if point in ['after_rename','after_directory_sync'] else at-1
        assert len(available)==expected_count
        if available:
            resumed=run(name+'-resume',source,['--resume',child/'checkpoints']);compare(available[-1],resumed,small)
        else:
            refused=run(name+'-no-checkpoint',source,['--resume',child/'checkpoints'],1)
            assert load(refused/'status.json')['error']=='no_committed_checkpoint' and not events(refused)

for point,at in [('open',1),('open',2),('partial_write',2),('file_sync',2),('rename',2),('directory_sync',2)]:
    name='storage-'+point+'-'+str(at)
    child=run(name,source,['--fault',point,'--fault-at',at],1)
    progress=load(child/'progress.json');assert progress['state']=='failed'
    assert progress['error']=='injected_storage_'+point
    assert progress['checkpoint_commit_uncertain']==(point=='directory_sync')
    assert progress['resumable']==(at>1)
    available=snapshots(child)
    if available:
        resumed=run(name+'-resume',source,['--resume',child/'checkpoints']);compare(available[-1],resumed,small)

# Temporary files are ignored, and the newest corrupted committed file fails closed.
scratch=a.output/'discovery';scratch.mkdir()
basecp=snapshots(reference(small))[0]
(scratch/'checkpoint-000001.json').write_bytes(basecp.read_bytes())
(scratch/'checkpoint-000002.json.tmp').write_text('{partial')
child=run('ignore-incomplete-temp',source,['--resume',scratch]);compare(basecp,child,small)
(scratch/'checkpoint-000002.json').write_text('{partial')
child=run('reject-newest-corrupt',source,['--resume',scratch],1);assert not events(child)

mutations=[('envelope-fraction',['checkpoint_schema'],1.5),('envelope-narrow',['checkpoint_schema'],4294967297),
    ('envelope-float',['checkpoint_schema'],1.0),('envelope-null',['checkpoint_schema'],None),
    ('state-fraction',['payload','version'],1.5),('state-narrow',['payload','version'],4294967297),
    ('state-float',['payload','version'],1.0),('state-two',['payload','version'],2),
    ('state-string',['payload','version'],'1'),('state-bool',['payload','version'],True),
    ('state-null',['payload','version'],None),('policy',['payload','policy'],'changed'),
    ('source',['payload','source'],'changed'),('configuration',['payload','configuration'],'changed'),
    ('semantic-input',['payload','input_hash'],'changed'),('input-file',['input_file_sha256'],'changed'),
    ('digest',['payload_sha256'],'changed'),('boundary',['payload','boundary'],'mid_solve'),
    ('iteration',['payload','iteration'],1.5),('solves',['payload','solves'],4294967297),
    ('bounds',['payload','upper',0],-1),('degree',['payload','degrees',0],999),
    ('edge-index',['payload','edges',0,0],-1),('cache',['payload','cache'],False),
    ('C',['payload','multiplier'],2),('scale',['payload','distance_multiplier'],0),
    ('stats',['payload','last_stats',0],-1),('mapping',['payload','mapping','representatives',0],1),
    ('trace-count',['trace_prefix_events'],99999),('trace-hash',['trace_prefix_sha256'],'changed'),
    ('parent',['parent_checkpoint_sha256'],'changed')]
for name,keys,value in mutations:
    j=copy.deepcopy(load(basecp));node=j
    for key in keys[:-1]:node=node[key]
    node[keys[-1]]=value
    raw=a.output/('mutation-'+name+'.raw.json');path=a.output/('mutation-'+name+'.json');write(raw,j)
    if keys[0]=='payload':subprocess.run([str(tool),str(raw),str(path)],check=True)
    else:path.write_bytes(raw.read_bytes())
    child=run('reject-'+name,source,['--resume',path],1)
    assert not events(child) and load(child/'status.json')['solves']==0
    if (child/'progress.json').exists():assert not load(child/'progress.json')['resumable']
    record['mutations'].append(dict(name=name,keys=keys,value=value,payload_hash_recomputed=keys[0]=='payload',passed=True));save()
changed=load(source);changed['ids'][0]+='-changed';path=a.output/'different-input.json';write(path,changed)
child=run('reject-different-input',path,['--resume',basecp],1);assert not events(child)

curve=fixture('nonuniform_curve');child=run('optional-diagnostic',curve,['--diagnostic-fail'])
assert load(child/'status.json')['complete'] and load(child/'progress.json')['state']=='complete'
assert not load(child/'diagnostics.json')['complete']
assert normalized(events(child))==normalized(events(reference('nonuniform_curve')))
assert load(child/'result.json')==load(reference('nonuniform_curve')/'result.json')

record['total_solver_calls']=sum(r['solves'] for r in record['runs'])
record['complete']=True;save();print('Recovery workload complete:',record['total_solver_calls'],'solves',flush=True)
