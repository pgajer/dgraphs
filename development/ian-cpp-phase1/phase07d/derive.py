"""Derive the qualifying units11 candidate from the accepted Phase07C source."""
from pathlib import Path
import shutil,json
H=Path(__file__).resolve().parent;out=H/'candidate';base=H.parent/'phase07c';out.mkdir(exist_ok=True)
for folder in ['include','src','tests','cmake']:shutil.copytree(base/folder,out/folder,dirs_exist_ok=True)
for name in ['CMakeLists.txt','config.json','IAN-LICENSE.txt','NUMPY-LICENSE.txt','reference.py','reference_probe.py']:
 shutil.copyfile(base/name,out/name)
policy='IAN evaluated-LP retry units11 0.1'
for p in out.rglob('*'):
 if p.is_file() and p.suffix in ['.hpp','.cpp','.py']:
  p.write_text(p.read_text().replace('IAN evaluated-LP retry 0.1',policy))
def edit(name,old,new,count=1):
 p=out/name;s=p.read_text();assert s.count(old)==count,(name,old,s.count(old));p.write_text(s.replace(old,new))
edit('src/solver.hpp','    auto cone = ClarabelNonnegativeConeT(m);','''    const bool normalized_retry = tolerance < 1e-9;
    const double alpha = normalized_retry ? *std::max_element(u.begin(), u.end()) : 1.;
    require(std::isfinite(alpha) && alpha > 0, "invalid_retry_units");
    Vec rhs = b;
    if (normalized_retry) for (auto &v : rhs) v /= alpha;
    auto cone = ClarabelNonnegativeConeT(m);''')
edit('src/solver.hpp','&A, b.data(), 1, &cone','&A, rhs.data(), 1, &cone')
edit('src/solver.hpp','    Json original = nullptr;','''    Json backend = Json::object();
    if (normalized_retry) {
        backend = Json{{"solver_units",alpha},{"backend_rhs",rhs},{"backend_primal",x},
            {"backend_dual",z},{"backend_slack",Vec(sol.s,sol.s+sol.s_length)},
            {"backend_objective",sol.obj_val},{"backend_res_primal",sol.r_prim},
            {"backend_res_dual",sol.r_dual}};
        for (auto &v : x) v *= alpha;
        sol.obj_val *= alpha;
    }
    Json original = nullptr;''')
edit('src/solver.hpp','    record["retry_eligible"] = eligible;','    record.update(backend);\n    record["retry_eligible"] = eligible;')
# Reference status is derived directly from the raw return, so a nonoptimal
# finite return is saved instead of being discarded by CVXPY unpacking.
edit('reference.py',"   solver=clarabel.DefaultSolver(sparse.csc_matrix((len(data['c']),len(data['c']))),data['c'],data['A'],data['b'],dims_to_solver_cones(data['dims']),settings)","""   alpha=float(max(u)) if attempt else 1.
   assert np.isfinite(alpha) and alpha>0,'invalid_retry_units'
   rhs=data['b']/alpha if attempt else data['b']
   solver=clarabel.DefaultSolver(sparse.csc_matrix((len(data['c']),len(data['c']))),data['c'],data['A'],rhs,dims_to_solver_cones(data['dims']),settings)""")
edit('reference.py','   raw=solver.solve();prob.unpack_results(raw,chain,inverse)\n   scales=np.array(raw.x[:len(u)]);z=np.array(raw.z[:len(b)])','''   raw=solver.solve();status='optimal' if str(raw.status)=='Solved' else 'not_optimal'
   scales=np.array(raw.x[:len(u)])*alpha;z=np.array(raw.z[:len(b)])
   objective=float(raw.obj_val)*alpha
   backend=dict(solver_units=alpha,backend_rhs=rhs,backend_primal=raw.x,backend_dual=raw.z,backend_slack=raw.s,backend_objective=raw.obj_val,backend_res_primal=raw.r_prim,backend_res_dual=raw.r_dual) if attempt else {}''')
edit('reference.py',"validator(prob.status,scales,float(raw.obj_val)","validator(status,scales,objective")
edit('reference.py',"prob.status=='optimal'","status=='optimal'")
edit('reference.py','status=prob.status,objective=raw.obj_val,','status=status,objective=objective,')
edit('reference.py',"canonical_soc=data['dims'].soc))","canonical_soc=data['dims'].soc,**backend))")
edit('reference.py','    return float(raw.obj_val)','    return objective')
c=json.loads((out/'config.json').read_text());c['numerical_policy']=policy;c['retry']['variable_units']='alpha=max(upper); min c^T y, A y <= b/alpha; x=alpha*y, z unchanged, objective*=alpha';(out/'config.json').write_text(json.dumps(c)+'\n')
print('Derived units11 candidate; no accepted source modified.')
