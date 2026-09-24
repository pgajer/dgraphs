"""One fixed-problem diagnostic solve; never invokes the outer IAN iteration."""
import sys
import time
from pathlib import Path
import clarabel
import numpy as np
from scipy import sparse
from common import load,write,matrix,pack,product,norm,scalar_check

source,case,condition,output=sys.argv[1:5];source=Path(source);out=Path(output);out.mkdir(parents=True,exist_ok=False)
manifest=load(source/'manifest.json');item=manifest['cases'][case];data=load(item['path'])
saved=load(item['saved']) if case=='historical_first' else data
A=matrix(data);b=np.array(data['b']);q=np.array(data['c']);row_factor=np.ones(len(b))
settings=clarabel.DefaultSettings()
baseline=dict(tol_gap_abs=1e-9,tol_gap_rel=1e-9,tol_feas=1e-9,max_iter=300,direct_solve_method='qdldl',max_threads=1,
    presolve_enable=False,chordal_decomposition_enable=False,input_sparse_dropzeros=False,verbose=False)
changes={
    'baseline':{},'feas11':dict(tol_feas=1e-11),'gap11':dict(tol_gap_abs=1e-11,tol_gap_rel=1e-11),
    'all11':dict(tol_feas=1e-11,tol_gap_abs=1e-11,tol_gap_rel=1e-11),
    'all12':dict(tol_feas=1e-12,tol_gap_abs=1e-12,tol_gap_rel=1e-12),
    'no_equilibration':dict(equilibrate_enable=False),'row_normalized':{}}
for k,v in dict(baseline,**changes[condition]).items():setattr(settings,k,v)
if condition=='row_normalized':
    assert case!='historical_first'
    row_factor=1/np.maximum(1.,np.maximum(abs(b),np.asarray(abs(A).max(axis=1).toarray()).ravel()))
    A=sparse.diags(row_factor)@A;b=row_factor*b
if case=='historical_first':cones=[clarabel.NonnegativeConeT(data['cones'][0]['dim']),clarabel.SecondOrderConeT(3)]
else:cones=[clarabel.NonnegativeConeT(len(b))]
write(out/'problem.json',dict(**pack(A),b=b,c=q,row_factor=row_factor,case=case,condition=condition,settings=str(settings)))
solver=clarabel.DefaultSolver(sparse.csc_matrix((len(q),len(q))),q,A.tocsc(),b,cones,settings)
def info_record(info):
    keys=['iterations','mu','sigma','step_length','cost_primal','cost_dual','res_primal','res_dual','res_primal_inf','res_dual_inf',
        'gap_abs','gap_rel','ktratio','solve_time']
    return dict(status=str(info.status),**{k:getattr(info,k) for k in keys})
iterations=[]
def callback(info):iterations.append(info_record(info));return False
solver.set_termination_callback(callback)
before=solver.get_info();write(out/'before-solve.json',dict(linear_solver=before.linsolver.name,threads=before.linsolver.threads,
    settings=str(solver.get_settings()),clarabel_version=clarabel.__version__))
assert before.linsolver.name=='qdldl' and before.linsolver.threads==1
started=time.perf_counter();raw=solver.solve();elapsed=time.perf_counter()-started;info=solver.get_info()
write(out/'raw-solution.json',dict(x=raw.x,z=raw.z,s=raw.s,status=str(raw.status),iterations=raw.iterations,
    objective=raw.obj_val,dual_objective=raw.obj_val_dual,primal_residual=raw.r_prim,dual_residual=raw.r_dual,wall_seconds=elapsed))
x=np.array(raw.x);z=np.array(raw.z);s=np.array(raw.s);n=len(saved['c']);m=len(saved['b'])
original_x=x[:n];original_z=(z*row_factor)[:m]
check=scalar_check(saved,original_x,original_z,raw.obj_val,str(raw.status))
primal_eq=product(A,x)+s-b;dual_eq=product(A.T,z)+q
primal_den=max(1.,float(max(abs(b)))+norm(x)+norm(s))
dual_den=max(1.,float(max(abs(q)))+norm(x)+norm(z))
reconstructed_primal=norm(primal_eq)/primal_den;reconstructed_dual=norm(dual_eq)/dual_den
nonneg_size=m if case=='historical_first' else len(b)
cone_check=dict(nonnegative_slack_violation=float(max(0.,max(-s[:nonneg_size]))))
historical=None
if case=='historical_first':
    cone_check['soc_slack_violation']=max(0.,norm(s[m+1:])-float(s[m]))
    t=float(x[-1]);delta=t-saved['C']**2;column=A[:m,n].toarray().ravel()
    original_A=matrix(saved);original_b=np.asarray(saved['b'])
    canonical_inequality=product(A[:m,:],x)-b[:m]
    projected_inequality=product(original_A,original_x)-original_b
    projection_rounding=original_b-(b[:m]-column*(saved['C']**2))
    predicted=canonical_inequality-column*delta-projection_rounding
    i=check['worst_row']
    historical=dict(auxiliary_value=t,C_squared=saved['C']**2,auxiliary_error=delta,
        worst_row_auxiliary_coefficient=column[i],worst_row_induced_violation=-column[i]*delta,
        worst_row_canonical_inequality=canonical_inequality[i],worst_row_projected_inequality=projected_inequality[i],
        projection_identity_max_error=float(max(abs(predicted-projected_inequality))),
        max_auxiliary_induced_violation=float(max(abs(column*delta))))
baseline_equal=dict(primal=np.array_equal(original_x,np.array(saved['scales'])),dual=np.array_equal(original_z,np.array(saved['dual'])),
    iterations=raw.iterations==saved['iterations'],objective=raw.obj_val==saved['objective'])
result=dict(case=case,condition=condition,status=str(raw.status),iterations=raw.iterations,objective=raw.obj_val,dual_objective=raw.obj_val_dual,
    x=x,z=z,slack=s,original_scales=original_x,original_dual=original_z,external=check,baseline_exact=baseline_equal,
    scale_difference_max=float(max(abs(original_x-np.asarray(saved['scales'])))),objective_difference=float(raw.obj_val-saved['objective']),
    backend=info_record(info),iteration_history=iterations,wall_seconds=elapsed,backend_solve_seconds=raw.solve_time,
    reconstructed_backend=dict(primal=reconstructed_primal,dual=reconstructed_dual,primal_denominator=primal_den,dual_denominator=dual_den,
        primal_equality_l2=norm(primal_eq),dual_equality_l2=norm(dual_eq),norm_b_inf=float(max(abs(b))),norm_x_l2=norm(x),norm_s_l2=norm(s),
        primal_discrepancy=abs(reconstructed_primal-info.res_primal),dual_discrepancy=abs(reconstructed_dual-info.res_dual)),
    cone_slack=cone_check,historical=historical)
write(out/'result.json',result)
print(dict(case=case,condition=condition,status=str(raw.status),iterations=raw.iterations,external=check['accepted'],row_error=check['normalized_primal'],backend_primal=info.res_primal))
# Numerical rejection is a diagnostic outcome. Baseline reproduction is a harness gate.
if condition=='baseline' and not all(baseline_equal.values()):raise SystemExit(4)
