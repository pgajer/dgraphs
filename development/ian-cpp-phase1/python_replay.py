"""One fresh CVXPY solve; canonicalization separated from backend setup/solve."""
import time
started=time.perf_counter()
import sys
import numpy as np
import cvxpy as cp
from common import load_lp, write_json, OPTIONS
imported=time.perf_counter()
d=load_lp(sys.argv[1]); loaded=time.perf_counter()
x=cp.Variable(len(d['c']))
constraint=d['A']@x<=d['b']
problem=cp.Problem(cp.Minimize(d['c']@x),[constraint])
data,chain,inverse=problem.get_problem_data(cp.CLARABEL)
# Verify canonicalization preserves exactly the recorded LP, not merely its size.
assert (data['A']!=d['A']).nnz==0
assert np.array_equal(data['b'],d['b']) and np.array_equal(data['c'],d['c'])
assert data['dims'].nonneg==len(d['b']) and data['dims'].zero==0
setup=time.perf_counter()
raw=chain.solve_via_data(problem,data,warm_start=False,verbose=False,solver_opts=OPTIONS)
solved=time.perf_counter()
problem.unpack_results(raw,chain,inverse)
status=problem.status
np.asarray(raw.x,dtype='<f8').tofile(sys.argv[2]+'.x.bin')
np.asarray(raw.z,dtype='<f8').tofile(sys.argv[2]+'.z.bin')
ended=time.perf_counter()
write_json(sys.argv[2]+'.json',dict(path='python',status=status,
    objective=float(raw.obj_val),dual_objective=float(raw.obj_val_dual),
    iterations=raw.iterations,solver_time=raw.solve_time,
    solver_primal_residual=raw.r_prim,solver_dual_residual=raw.r_dual,
    startup_import_seconds=imported-started,input_seconds=loaded-imported,
    setup_seconds=setup-loaded,solve_call_seconds=solved-setup,
    validation_output_seconds=ended-solved,internal_seconds=ended-started,
    backend_setup_seconds=None,linear_solver_threads=1,
    linear_solver_threads_source='explicit QDLDL settings; backend thread telemetry unavailable through CVXPY result',
    options=OPTIONS))
