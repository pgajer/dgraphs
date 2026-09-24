"""Fixed LP replay with explicit original-unit recovery and solver telemetry."""
import sys,time
from pathlib import Path
import clarabel
import numpy as np
from scipy import sparse
from support import *
folder,case,condition,output=sys.argv[1:];out=Path(output);out.mkdir(parents=True,exist_ok=False)
item=load(Path(folder)/'manifest.json')['cases'][case];original=load(item['path']);A=matrix(original);b=np.array(original['b']);c=np.array(original['c'])
settings=clarabel.DefaultSettings()
options=dict(tol_feas=1e-9,tol_gap_abs=1e-9,tol_gap_rel=1e-9,max_iter=300,max_threads=1,direct_solve_method='qdldl',presolve_enable=False,chordal_decomposition_enable=False,input_sparse_dropzeros=False,verbose=False)
if condition!='ordinary':options.update(tol_feas=1e-12 if condition=='tight12' else 1e-11,tol_gap_abs=1e-12 if condition=='tight12' else 1e-11,tol_gap_rel=1e-12 if condition=='tight12' else 1e-11)
if condition=='refined11':options.update(iterative_refinement_abstol=1e-14,iterative_refinement_reltol=1e-14,iterative_refinement_max_iter=30)
for k,v in options.items():setattr(settings,k,v)
alpha=float(max(original['upper'])) if condition=='units11' else 1.;assert np.isfinite(alpha) and alpha>0
rhs=b/alpha
write(out/'problem.json',dict(**pack(A),b=rhs,c=c,alpha=alpha,original=str(item['path']),original_sha256=sha(item['path']),condition=condition,options=options,settings=str(settings)))
solver=clarabel.DefaultSolver(sparse.csc_matrix((len(c),len(c))),c,A.tocsc(),rhs,[clarabel.NonnegativeConeT(len(b))],settings)
def info(v):return dict(status=str(v.status),**{k:getattr(v,k) for k in ['iterations','mu','sigma','step_length','cost_primal','cost_dual','res_primal','res_dual','gap_abs','gap_rel','ktratio','solve_time']})
history=[]
def observe(v):history.append(info(v));return False
solver.set_termination_callback(observe)
start=time.perf_counter();raw=solver.solve();elapsed=time.perf_counter()-start;end=solver.get_info()
y=np.array(raw.x);z=np.array(raw.z);s=np.array(raw.s);x=alpha*y;objective=alpha*raw.obj_val
write(out/'raw.json',dict(x=y,z=z,s=s,objective=raw.obj_val,dual_objective=raw.obj_val_dual,status=str(raw.status),iterations=raw.iterations,r_prim=raw.r_prim,r_dual=raw.r_dual,seconds=elapsed))
external=scalar_check(original,x,z,objective,str(raw.status));dual=product(A.T,z)+c;primal=product(A,y)+s-rhs
nd=max(1.,max(abs(c))+norm(y)+norm(z));np_=max(1.,max(abs(rhs))+norm(y)+norm(s))
reconstruction=dict(dual=norm(dual)/nd,primal=norm(primal)/np_,dual_numerator=norm(dual),dual_denominator=nd,primal_denominator=np_,norm_c_inf=max(abs(c)),norm_x=norm(y),norm_z=norm(z),norm_s=norm(s),maximum_stationarity=max(abs(dual)),dual_discrepancy=abs(norm(dual)/nd-raw.r_dual),primal_discrepancy=abs(norm(primal)/np_-raw.r_prim))
comparison=None
saved=original if condition=='ordinary' else (load(item['saved_strict']) if condition=='retry11' and item['saved_strict'] else None)
if saved is not None:comparison=dict(x=x.tolist()==saved['scales'],z=z.tolist()==saved['dual'],objective=objective==saved['objective'],iterations=raw.iterations==saved['iterations'])
result=dict(case=case,condition=condition,alpha=alpha,x=x,z=z,slack=alpha*s,objective=objective,external=external,backend=info(end),history=history,reconstructed=reconstruction,saved_exact=comparison,options=options,settings=str(solver.get_settings()),seconds=elapsed)
write(out/'result.json',result)
write(out/'trace.jsonl',dict(event='solve',case=case,condition=condition,diagnostic_only=True,accepted=external['accepted']))
print(dict(case=case,condition=condition,accepted=external['accepted'],stationarity=external['dual_stationarity'],primal=external['normalized_primal'],iterations=raw.iterations,denominator=nd))
if comparison is not None and not all(comparison.values()):raise SystemExit(4)
