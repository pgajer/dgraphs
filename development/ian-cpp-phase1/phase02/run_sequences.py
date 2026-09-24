"""Exactly 18 serial sequence jobs / 96 solves; preserve all outcomes."""
import argparse,json,subprocess,sys,os,platform
from pathlib import Path
import numpy as np
from supervise import supervise,one_thread_environment
from validate_outputs import check_solution
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from common import sha,write_json
p=argparse.ArgumentParser();p.add_argument('--fixtures',type=Path,required=True);p.add_argument('--native',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
assert not subprocess.check_output(['git','status','--porcelain'],text=True),'Commit before measurement'
a.output.mkdir(parents=True,exist_ok=False);manifest=json.loads((a.fixtures/'manifest.json').read_text());cases={c['name']:c for c in manifest['cases']}
configs=[('late_pruning','python','fresh'),('late_pruning','native','fresh'),('final_retuning','python','fresh'),('final_retuning','native','fresh'),('final_retuning','python','update'),('final_retuning','native','update')]
schedule=[]
for rep in range(3):
    order=configs[2*rep:]+configs[:2*rep]
    if rep%2:order=list(reversed(order))
    for seq,path,mode in order:schedule.append(dict(repetition=rep+1,sequence=seq,path=path,mode=mode))
write_json(a.output/'schedule.json',schedule)
env=one_thread_environment()
write_json(a.output/'environment.json',dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),cwd=os.getcwd(),platform=platform.platform(),python=sys.version,
 native_sha256=sha(a.native),fixtures_manifest_sha256=sha(a.fixtures/'manifest.json'),pip_freeze=subprocess.check_output([sys.executable,'-m','pip','freeze'],text=True),
 thread_environment={k:v for k,v in env.items() if k.endswith('THREADS')},
 settings=dict(core='0.11.1',method='qdldl',max_threads=1,max_iter=300,tol_feas=1e-9,tol_gap_abs=1e-9,tol_gap_rel=1e-9,presolve_enable=False,chordal_decomposition_enable=False,input_sparse_dropzeros=False)))
for number,cfg in enumerate(schedule):
    folder=a.output/f'{number:02d}-{cfg["sequence"]}-{cfg["path"]}-{cfg["mode"]}-r{cfg["repetition"]}'
    ids=manifest['sequences'][cfg['sequence']]
    for identity in ids:
        assert sha(a.fixtures/identity/'problem.bin')==cases[identity]['binary_sha256']
        assert sha(cases[identity]['source'])==cases[identity]['source_sha256']
    command=([sys.executable,str(Path(__file__).with_name('sequence_python.py'))] if cfg['path']=='python' else [str(a.native)])+[str(a.fixtures/(cfg['sequence']+'.txt')),str(folder/'child'),cfg['mode']]
    process=supervise(command,folder,env);start=__import__('time').perf_counter();checks=[]
    for step,identity in enumerate(ids):
        try:
            raw=json.loads((folder/'child'/f'{step:02d}.json').read_text())
            x=np.fromfile(folder/'child'/f'{step:02d}.x.bin',dtype='<f8');z=np.fromfile(folder/'child'/f'{step:02d}.z.bin',dtype='<f8')
            check=check_solution(cases[identity]['source'],x,z,raw['objective'],raw['status'])
            checks.append(dict(step=step,identity=identity,raw=raw,check=check))
        except Exception as exc:checks.append(dict(step=step,identity=identity,error=repr(exc),check=dict(accepted=False,dual_valid=False)))
    result=dict(**cfg,sequence_number=number,process=process,steps=checks,
      accepted=process['exit_code']==0 and all(s['check']['accepted'] and s['check'].get('dual_valid',False) for s in checks),
      validation_seconds=__import__('time').perf_counter()-start)
    try:result['summary']=json.loads((folder/'child/summary.json').read_text())
    except Exception as exc:result['summary_error']=repr(exc);result['accepted']=False
    write_json(folder/'validated.json',result)
    print(f'{number+1}/18 {cfg} accepted={result["accepted"]} wall={process["end_to_end_seconds"]:.3f}',flush=True)
