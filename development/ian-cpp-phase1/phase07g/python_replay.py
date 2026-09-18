import clarabel,time
from support import *
f,out=map(Path,sys.argv[1:]);out.mkdir(parents=True,exist_ok=False);A,b,c=read_arrays(f);dump_arrays(out,A,b,c)
s=clarabel.DefaultSettings()
for k,v in OPTIONS.items():setattr(s,k,v)
solver=clarabel.DefaultSolver(sparse.csc_matrix((len(c),len(c))),c,A,b,[clarabel.NonnegativeConeT(len(b))],s)
settings=solver.get_settings();write(out/'settings.json',{k:getattr(settings,k) for k in dir(settings) if not k.startswith('_') and not callable(getattr(settings,k))})
def info(v):return dict(status=str(v.status),**{k:getattr(v,k) for k in ['iterations','mu','sigma','step_length','cost_primal','cost_dual','res_primal','res_dual','res_primal_inf','res_dual_inf','gap_abs','gap_rel','ktratio','solve_time']})
history=[]
def observe(v):history.append(info(v));return False
solver.set_termination_callback(observe);start=time.perf_counter();r=solver.solve()
write(out/'raw.json',dict(status=str(r.status),iterations=r.iterations,x=r.x,z=r.z,s=r.s,objective=r.obj_val,dual_objective=r.obj_val_dual,r_prim=r.r_prim,r_dual=r.r_dual,seconds=time.perf_counter()-start,history=history,info=info(solver.get_info())))
write(out/'trace.jsonl',dict(event='solve',diagnostic_only=True,status=str(r.status)))
