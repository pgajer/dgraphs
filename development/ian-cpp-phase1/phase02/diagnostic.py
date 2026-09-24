"""One controlled historical/replay diagnostic; never executes the IAN loop."""
import argparse,json,sys,time,hashlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import numpy as np
import cvxpy as cp
from scipy import sparse
from common import load_lp,write_json,validate,dual_diagnostics
from prepare import reconstruct
p=argparse.ArgumentParser();p.add_argument('--fixtures',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
p.add_argument('--expression',choices=['original','saved','evaluated'],required=True);p.add_argument('--backend',choices=['auto','qdldl'],required=True);p.add_argument('--threads',type=int,required=True)
a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
t0=time.perf_counter();saved=load_lp(a.fixtures/'001872/problem.bin')
if a.expression=='saved':
    x=cp.Variable(len(saved['c']));prob=cp.Problem(cp.Minimize(saved['c']@x),[saved['A']@x<=saved['b']]);reconstruction=None
else:prob,reconstruction,x=reconstruct()
constructed=time.perf_counter()
data,chain,inverse=prob.get_problem_data(cp.CLARABEL,ignore_dpp=(a.expression=='evaluated'))
canonical=time.perf_counter();A=data['A'].tocsc();n=len(saved['c']);m=len(saved['b']);nc=len(data['c'])
metadata=dict(expression=a.expression,backend_requested=a.backend,threads_requested=a.threads,ignore_dpp=a.expression=='evaluated',
    canonical_shape=list(A.shape),nonzeros=A.nnz,cone_dimensions=str(data['dims']),reconstruction=reconstruction)
assert data['dims'].nonneg==m and data['dims'].zero==0
assert np.array_equal(data['c'][:n],saved['c']) and not np.any(data['c'][n:])
assert nc in (n,n+1)
if nc==n+1:
    assert data['dims'].soc==[3] and a.expression=='original'
    C=reconstruction['final_C'];reduced_A=A[:m,:n].tocsr();reduced_b=data['b'][:m]-np.asarray(A[:m,n].toarray()).ravel()*(C*C)
    metadata['auxiliary_cone_rows']=A[m:].toarray().tolist()
    # Store compact cone coefficients separately, not a 3-by-n JSON array.
    metadata['auxiliary_cone_rows']=[dict(indices=A.getrow(i).indices.tolist(),values=A.getrow(i).data.tolist(),b=float(data['b'][i])) for i in range(m,A.shape[0])]
else:
    assert not data['dims'].soc;reduced_A=A.tocsr();reduced_b=data['b']
diff=reduced_A-saved['A'];metadata.update(projected_A_differences=diff.nnz,projected_A_max_abs=float(abs(diff.data).max(initial=0)),
 projected_b_max_abs=float(abs(reduced_b-saved['b']).max()),projected_b_differences=int(np.count_nonzero(reduced_b!=saved['b'])),
 canonical_data_sha256=hashlib.sha256(A.data.tobytes()+A.indices.tobytes()+A.indptr.tobytes()+data['b'].tobytes()+data['c'].tobytes()).hexdigest())
opts=dict(tol_gap_abs=1e-9,tol_gap_rel=1e-9,tol_feas=1e-9,max_iter=300,direct_solve_method=a.backend,max_threads=a.threads)
# Inspect and save the backend before solve; CVXPY's pinned reduction builds it
# through the supported Clarabel constructor and provides equivalent settings.
import clarabel
from cvxpy.reductions.solvers.conic_solvers.clarabel_conif import dims_to_solver_cones,CLARABEL
settings=CLARABEL.parse_solver_opts(False,dict(opts))
solver=clarabel.DefaultSolver(sparse.csc_matrix((nc,nc)),data['c'],A,data['b'],dims_to_solver_cones(data['dims']),settings)
info=solver.get_info();metadata.update(actual_linear_solver=info.linsolver.name,actual_linear_threads=info.linsolver.threads,
 factor_nnz=info.linsolver.nnzL,settings=str(solver.get_settings()),options=opts,
 source_reconstruction_seconds=constructed-t0,canonicalization_seconds=canonical-constructed,
 native_construction_seconds=time.perf_counter()-canonical)
write_json(a.output/'before-solve.json',metadata)
started=time.perf_counter();raw=solver.solve();elapsed=time.perf_counter()-started
prob.unpack_results(raw,chain,inverse);s=np.asarray(x.value)
np.asarray(raw.x,dtype='<f8').tofile(a.output/'canonical-x.bin');np.asarray(raw.z,dtype='<f8').tofile(a.output/'canonical-z.bin');s.astype('<f8').tofile(a.output/'scales.bin')
check=validate(saved,s,float(prob.value),prob.status)
# First m duals correspond to the original inequalities. Additional cone duals
# belong to the lifted parameter expression; diagnose original LP stationarity too.
z=np.asarray(raw.z)[:m];dual=dual_diagnostics(saved,s,z)
old=np.load(a.fixtures/'001872/historical.npz')['scales'];backend=solver.get_info()
report=dict(**metadata,status=prob.status,objective=float(prob.value),solver_seconds=raw.solve_time,solve_wall_seconds=elapsed,
 iterations=raw.iterations,validation=check,lp_dual_diagnostics=dual,
 original_scale_max_abs=float(abs(s-old).max()),canonical_auxiliary_value=float(raw.x[-1]) if nc>n else None,
 solver_primal_residual=raw.r_prim,solver_dual_residual=raw.r_dual,backend_gap_abs=backend.gap_abs,
 backend_gap_rel=backend.gap_rel,total_internal_seconds=time.perf_counter()-t0)
write_json(a.output/'result.json',report)
print(json.dumps({k:report[k] for k in ['expression','backend_requested','threads_requested','actual_linear_solver','actual_linear_threads','solver_seconds','iterations','validation']},indent=2))
raise SystemExit(0 if check['accepted'] else 2)
