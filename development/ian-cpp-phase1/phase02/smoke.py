"""Small analytic LPs test persistent fresh/update paths and refusal of invalid updates."""
import argparse,json,sys,subprocess
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import numpy as np
from scipy import sparse
from common import save_lp,write_json
from supervise import supervise,one_thread_environment
from validate_outputs import check_solution
p=argparse.ArgumentParser();p.add_argument('--native',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
problems=[]
for i in range(3):
    # Independent boxes: min x+y subject to x>=l, y>=.3, x<=1, y<=1.
    A=sparse.csr_matrix([[-1.,0],[0,-1],[1,0],[0,1]])
    if i==2:A=sparse.vstack([A,[[1.,1.]]],format='csr')
    lower=.2 if i==0 else .4;b=np.array([-lower,-.3,1.,1.]+([1.5] if i==2 else []))
    d=dict(A_data=A.data,A_indices=A.indices,A_indptr=A.indptr,A_shape=A.shape,b=b,c=np.ones(2),upper=np.ones(2),active=np.ones(2,dtype=bool),scales=np.array([lower,.3]))
    save_lp(a.output/f'{i}.bin',d);np.savez(a.output/f'{i}.npz',**d);problems.append(d)
(a.output/'valid.txt').write_text('\n'.join(str(a.output/f'{i}.bin') for i in [0,1])+'\n')
(a.output/'changed.txt').write_text('\n'.join(str(a.output/f'{i}.bin') for i in [0,2])+'\n')
results=[]
for backend in ['python','native']:
    for mode in ['fresh','update']:
        folder=a.output/f'{backend}-{mode}';cmd=([sys.executable,str(Path(__file__).with_name('sequence_python.py'))] if backend=='python' else [str(a.native)])+[str(a.output/'valid.txt'),str(folder/'child'),mode]
        process=supervise(cmd,folder,one_thread_environment());assert process['exit_code']==0
        for step in [0,1]:
            row=json.loads((folder/'child'/f'{step:02d}.json').read_text());x=np.fromfile(folder/'child'/f'{step:02d}.x.bin',dtype='<f8');z=np.fromfile(folder/'child'/f'{step:02d}.z.bin',dtype='<f8')
            check=check_solution(a.output/f'{step}.npz',x,z,row['objective'],row['status']);assert check['accepted'] and check['dual_valid']
            assert np.max(abs(x-problems[step]['scales']))<1e-7
            assert row['reused_solver']==(mode=='update' and step==1)
            results.append(dict(backend=backend,mode=mode,step=step,check=check))
    folder=a.output/f'{backend}-changed-update';cmd=([sys.executable,str(Path(__file__).with_name('sequence_python.py'))] if backend=='python' else [str(a.native)])+[str(a.output/'changed.txt'),str(folder/'child'),'update']
    process=supervise(cmd,folder,one_thread_environment());assert process['exit_code']!=0
    assert not (folder/'child/01.json').exists()
    results.append(dict(backend=backend,changed_shape_refused=True))
# Acceptance adversaries exercise real saved coefficients without additional solves.
for label,x,obj,status in [('missing',None,.5,'optimal'),('nan',[np.nan,.3],.5,'optimal'),('infeasible',[0.,0.],0.,'optimal'),('inaccurate',[.2,.3],.5,'optimal_inaccurate')]:
    check=check_solution(a.output/'0.npz',x,None,obj,status);assert not check['accepted'];results.append(dict(adversary=label,rejected=True))
write_json(a.output/'checks.json',results);print('Eight analytic smoke solutions, two unsupported-update refusals, four adversarial rejections passed.')
