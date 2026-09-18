import sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'phase07c'))
from guard import run
sys.path.insert(0,str(HERE.parent/'phase07b'))
from common import *
WORKER=Path.cwd().parent/'worker'
OPTIONS=dict(tol_feas=1e-11,tol_gap_abs=1e-11,tol_gap_rel=1e-11,max_iter=300,max_threads=1,direct_solve_method='qdldl',presolve_enable=False,chordal_decomposition_enable=False,input_sparse_dropzeros=False,verbose=False)
def dump_arrays(out,A,b,c):
    out=Path(out);A=A.tocsc();n=A.shape[1]
    arrays={'A_data':(A.data,'<f8'),'A_rows':(A.indices,'<u8'),'A_ptr':(A.indptr,'<u8'),'b':(b,'<f8'),'c':(c,'<f8'),'P_ptr':(np.zeros(n+1),'<u8')}
    for name,(v,dtype) in arrays.items():np.asarray(v,dtype=dtype).tofile(out/(name+'.bin'))
    write(out/'arrays.json',dict(shape=A.shape,nnz=A.nnz,explicit_zeros=int(np.sum(A.data==0)),P_shape=[n,n],P_nnz=0,cones=[dict(type='NonnegativeConeT',dimension=A.shape[0])],arrays={k:sha(out/(k+'.bin')) for k in arrays}))
def read_arrays(folder):
    f=Path(folder);d=load(f/'arrays.json');m,n=d['shape'];read=lambda name,dt:np.fromfile(f/(name+'.bin'),dtype=dt)
    A=sparse.csc_matrix((read('A_data','<f8'),read('A_rows','<u8'),read('A_ptr','<u8')),shape=(m,n))
    return A,read('b','<f8'),read('c','<f8')
