import sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'phase07b'))
from common import *
WORKER=Path.cwd().parent/'worker'
def dump_arrays(out,A,b,c):
    out=Path(out);A=A.tocsc();n=A.shape[1]
    arrays={'A_data':(A.data,'<f8'),'A_rows':(A.indices,'<u8'),'A_ptr':(A.indptr,'<u8'),'b':(b,'<f8'),'c':(c,'<f8'),'P_ptr':(np.zeros(n+1),'<u8')}
    for name,(v,dtype) in arrays.items():np.asarray(v,dtype=dtype).tofile(out/(name+'.bin'))
    write(out/'arrays.json',dict(shape=A.shape,nnz=A.nnz,explicit_zeros=int(np.sum(A.data==0)),P_shape=[n,n],P_nnz=0,cones=[dict(type='NonnegativeConeT',dimension=A.shape[0])],arrays={k:sha(out/(k+'.bin')) for k in arrays}))
def read_arrays(folder):
    f=Path(folder);d=load(f/'arrays.json');m,n=d['shape'];read=lambda name,dt:np.fromfile(f/(name+'.bin'),dtype=dt)
    A=sparse.csc_matrix((read('A_data','<f8'),read('A_rows','<u8'),read('A_ptr','<u8')),shape=(m,n))
    return A,read('b','<f8'),read('c','<f8')

OPTIONS=dict(presolve=False,disp=True,maxiter=100000,time_limit=60.,primal_feasibility_tolerance=1e-10,dual_feasibility_tolerance=1e-10,simplex_dual_edge_weight_strategy="steepest-devex",simplex_scale_strategy=0,threads=1,parallel=False,random_seed=0,small_matrix_value=1e-12)
