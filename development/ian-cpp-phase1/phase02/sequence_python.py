"""Persistent CVXPY canonicalization + Clarabel, fresh construction or data updates."""
import time
began=time.perf_counter()
import argparse,json,sys,gc
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import numpy as np
import cvxpy as cp
import clarabel
from scipy import sparse
from common import load_lp,write_json
from cvxpy.reductions.solvers.conic_solvers.clarabel_conif import dims_to_solver_cones
p=argparse.ArgumentParser();p.add_argument('sequence',type=Path);p.add_argument('output',type=Path);p.add_argument('mode',choices=['fresh','update']);args=p.parse_args();args.output.mkdir(parents=True,exist_ok=False)
paths=args.sequence.read_text().splitlines();imported=time.perf_counter();solver=None;pattern=None;records=[]
settings=clarabel.DefaultSettings();settings.verbose=False;settings.max_iter=300;settings.tol_gap_abs=settings.tol_gap_rel=settings.tol_feas=1e-9
settings.max_threads=1;settings.direct_solve_method='qdldl';settings.presolve_enable=False;settings.chordal_decomposition_enable=False;settings.input_sparse_dropzeros=False
write_json(args.output/'settings.json',dict(settings=str(settings),mode=args.mode,clarabel=clarabel.__version__,cvxpy=cp.__version__))
sequence_start=time.perf_counter()
for step,path in enumerate(paths):
    start=time.perf_counter();d=load_lp(path);loaded=time.perf_counter()
    x=cp.Variable(len(d['c']));prob=cp.Problem(cp.Minimize(d['c']@x),[d['A']@x<=d['b']])
    data,chain,inverse=prob.get_problem_data(cp.CLARABEL)
    A=data['A'].tocsc();assert (A!=d['A']).nnz==0
    assert np.array_equal(data['b'],d['b']) and np.array_equal(data['c'],d['c'])
    assert data['dims'].nonneg==len(d['b']) and not data['dims'].soc and data['dims'].zero==0
    canonical=time.perf_counter();reuse=args.mode=='update' and solver is not None
    if reuse:
        if A.shape!=pattern[0] or not np.array_equal(A.indptr,pattern[1]) or not np.array_equal(A.indices,pattern[2]):
            raise ValueError('Unsupported update: shape/sparsity changed; no fallback')
        assert solver.is_data_update_allowed()
        old_id=id(solver);solver.update(A=A,b=data['b'],q=data['c']);assert id(solver)==old_id
    else:
        solver=clarabel.DefaultSolver(sparse.csc_matrix((len(d['c']),len(d['c']))),data['c'],A,data['b'],dims_to_solver_cones(data['dims']),settings)
        pattern=(A.shape,A.indptr.copy(),A.indices.copy())
    setup=time.perf_counter();raw=solver.solve();solved=time.perf_counter();info=solver.get_info()
    prob.unpack_results(raw,chain,inverse)
    np.asarray(raw.x,dtype='<f8').tofile(args.output/f'{step:02d}.x.bin');np.asarray(raw.z,dtype='<f8').tofile(args.output/f'{step:02d}.z.bin')
    row=dict(step=step,fixture=str(path),mode=args.mode,reused_solver=reuse,operation='update' if reuse else 'construct',
      status=prob.status,objective=float(raw.obj_val),dual_objective=float(raw.obj_val_dual),iterations=raw.iterations,
      solver_seconds=raw.solve_time,solver_primal_residual=raw.r_prim,solver_dual_residual=raw.r_dual,
      backend_gap_abs=info.gap_abs,backend_gap_rel=info.gap_rel,linear_solver=info.linsolver.name,
      linear_solver_threads=info.linsolver.threads,factor_nnz=info.linsolver.nnzL,
      input_seconds=loaded-start,assembly_seconds=canonical-loaded,setup_update_seconds=setup-canonical,
      solve_seconds=solved-setup,output_seconds=time.perf_counter()-solved,step_seconds=time.perf_counter()-start)
    write_json(args.output/f'{step:02d}.json',row);records.append(row)
    del raw,prob,data,chain,inverse,x,A,d
    if args.mode=='fresh':solver=None;pattern=None
    gc.collect()
    print(f'step={step} operation={row["operation"]} iterations={row["iterations"]} solver={row["solver_seconds"]:.4f}',flush=True)
write_json(args.output/'summary.json',dict(path='python',mode=args.mode,steps=len(records),
    startup_seconds=imported-began,sequence_seconds=time.perf_counter()-sequence_start,total_internal_seconds=time.perf_counter()-began,
    sums={k:sum(r[k] for r in records) for k in ['input_seconds','assembly_seconds','setup_update_seconds','solve_seconds','output_seconds','step_seconds']},
    update_count=sum(r['reused_solver'] for r in records)))
