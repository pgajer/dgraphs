"""Raw-vector checks from original saved NPZ coefficients, outside both solvers."""
import math
import numpy as np
from scipy import sparse

def check_solution(source,scales,dual,objective,status):
    with np.load(source,allow_pickle=False) as f:
        shape=tuple(f['A_shape']);A=sparse.csr_matrix((f['A_data'],f['A_indices'],f['A_indptr']),shape=shape)
        b=f['b'].copy();c=f['c'].copy();upper=f['upper'].copy();active=f['active'].copy();old=f['scales'].copy()
    problems=[]
    if status!='optimal':problems.append('solver_status')
    if scales is None or np.shape(scales)!=(shape[1],):return dict(accepted=False,problems=problems+['missing_or_wrong_shape'])
    x=np.asarray(scales)
    if objective is None or not np.isfinite(objective) or not np.isfinite(x).all():return dict(accepted=False,problems=problems+['nonfinite_or_missing'])
    residual=np.maximum(A@x-b,0);normal=residual/np.maximum(1,np.maximum(abs(b),abs(A)@abs(x)))
    recomputed=math.fsum(float(a)*float(s) for a,s in zip(c,x));err=abs(recomputed-objective)/max(1,abs(recomputed),abs(objective))
    if not np.isfinite(residual).all() or not np.isfinite(normal).all() or not math.isfinite(recomputed):problems.append('nonfinite_diagnostics')
    if normal.max(initial=0)>1e-7:problems.append('constraint_violation')
    if err>1e-7:problems.append('objective_mismatch')
    if np.any(x[active]<=0):problems.append('nonpositive_active')
    report=dict(accepted=not problems,problems=problems,objective=recomputed,objective_error=err,
      normalized_primal=float(normal.max(initial=0)),absolute_primal=float(residual.max(initial=0)),
      lower_violation=float(np.maximum(-x,0).max(initial=0)),upper_violation=float(np.maximum(x-upper,0).max(initial=0)),
      historical_scale_max_abs=float(abs(x-old).max()),historical_scale_relative_l2=float(np.linalg.norm(x-old)/max(1,np.linalg.norm(old))))
    if dual is None or np.shape(dual)!=(shape[0],) or not np.isfinite(dual).all():report.update(dual_valid=False,dual_problem='missing/nonfinite/wrong_shape')
    else:
        z=np.asarray(dual);dualobj=-math.fsum(float(a)*float(v) for a,v in zip(b,z))
        station=float(abs(c+A.T@z).max());neg=float(np.maximum(-z,0).max(initial=0));gap=abs(recomputed-dualobj)/max(1,abs(recomputed),abs(dualobj))
        report.update(dual_valid=bool(gap<=1e-7 and station<=1e-7 and neg<=1e-7),dual_objective=dualobj,dual_relative_gap=gap,dual_stationarity=station,dual_negative_violation=neg)
    return report
