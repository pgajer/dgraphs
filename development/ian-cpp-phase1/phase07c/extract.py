"""Mechanical candidate derivation. Accepted phase sources remain read-only."""
from pathlib import Path
import shutil,json
H=Path(__file__).resolve().parent
for folder in ['include','src','tests','cmake']:
 shutil.copytree(H.parent/'phase06b'/folder,H/folder,dirs_exist_ok=True)
for name in ['CMakeLists.txt','config.json','IAN-LICENSE.txt','NUMPY-LICENSE.txt']:
 shutil.copyfile(H.parent/'phase06b'/name,H/name)
def edit(name,old,new,count=1):
 p=H/name;s=p.read_text();assert s.count(old)==count,(name,old,s.count(old));p.write_text(s.replace(old,new))
policy='IAN evaluated-LP retry 0.1'
edit('include/ian/core.hpp','IAN evaluated-LP 1.0',policy)
edit('src/json_adapter.hpp','    in.policy = j.value("numerical_policy", std::string(numerical_policy));','    if (!j.contains("numerical_policy") || j.at("numerical_policy") != numerical_policy)\n        throw std::invalid_argument("unsupported_policy");\n    in.policy = numerical_policy;')
edit('src/cli.cpp','        if(input_json.value("kind","")=="stages") {','        require(input_json.contains("numerical_policy") && input_json.at("numerical_policy")==ian::numerical_policy,"unsupported_policy");\n        if(input_json.value("kind","")=="stages") {')
edit('src/core.cpp','    if (input.contains("cases")) {','    require(input.contains("numerical_policy") && input.at("numerical_policy")==numerical_policy,"unsupported_policy");\n    if (input.contains("cases")) {')
edit('src/core.cpp','code == "invalid_solver_result" ||','code == "retry_exhausted" || code == "invalid_solver_result" ||')
edit('src/core.cpp','"none", "invalid_solver",','"none", "retry_exhausted", "invalid_solver",')
edit('src/restart_methods.inc','(s.iteration + 1) * 21','(s.iteration + 1) * 42')
edit('src/state_json.hpp','42000','84000')
edit('src/files.hpp','{"input_sha256",input_hash}', '{"numerical_policy",ian::numerical_policy},{"input_sha256",input_hash}')
edit('src/solver.hpp','#include "numeric.hpp"','#include "numeric.hpp"\n#include "retry.hpp"')
edit('src/solver.hpp','bool parameterized, bool inject = false)', 'bool parameterized, bool inject = false, double tolerance = 1e-9, bool damage = false)')
edit('src/solver.hpp','settings.tol_gap_rel = 1e-9','settings.tol_gap_rel = tolerance')
edit('src/solver.hpp','    if (inject)\n', '    Json original = nullptr;\n    if (damage) {\n        original = Json{{"scales",x},{"objective",sol.obj_val}};\n        for (auto &v : x) v *= .5;\n        sol.obj_val *= .5;\n    }\n    if (inject)\n')
edit('src/solver.hpp','    accepted = accepted && maxnormal <= 1e-7', '    bool eligible = retry_eligible(accepted, error, maxnormal, maxabsolute, stationarity, negative, gap);\n    accepted = accepted && maxnormal <= 1e-7')
edit('src/solver.hpp','    return {x, z, record};','    record["retry_eligible"] = eligible;\n    if (damage) { record["test_fault"]="halved_primal_and_objective"; record["before_test_fault"]=original; }\n    return {x, z, record};')
p=H/'src/engine.hpp';s=p.read_text();start=s.index('    Vec solve(bool parameterized)');end=s.index('\n    ',s.index('    }',start)+5)
s=s[:start]+'''    Vec solve(bool parameterized) {
        const int logical = solves;
        for (int attempt = 0; attempt < 2; ++attempt) {
            double tolerance = attempt == 0 ? 1e-9 : 1e-11;
            auto r = solve_lp(D, edges, upper, C, parameterized,
                inject == "invalid_solver" && solves == 0, tolerance, inject == "retry_exhausted");
            r.record["number"] = solves++;
            r.record["logical_solve"] = logical;
            r.record["attempt"] = attempt;
            r.record["numerical_policy"] = numerical_policy;
            r.record["solver_tolerance"] = tolerance;
            emit(r.record); // Observer failure stops before a retry is constructed.
            if (r.record["accepted"].get<bool>()) return r.x;
            require(attempt == 0, "retry_exhausted");
            require(r.record["retry_eligible"].get<bool>(), "invalid_solver_result");
        }
        throw std::runtime_error("unreachable_retry");
    }
''' +s[end:];p.write_text(s)
config=json.loads((H/'config.json').read_text());config.update(numerical_policy=policy,retry=dict(max_attempts=2,tol_feas=1e-11,tol_gap_abs=1e-11,tol_gap_rel=1e-11,external_tolerance=1e-7));(H/'config.json').write_text(json.dumps(config)+'\n')
shutil.copyfile(H.parent/'phase03/reference.py',H/'reference.py')
edit('reference.py',"OPTIONS=dict(","POLICY='"+policy+"'\nOPTIONS=dict(")
edit('reference.py',"choices=['original','evaluated']","choices=['evaluated']")
edit('reference.py',"d=json.loads(a.input.read_text());D,mapping=preprocess(d)","d=json.loads(a.input.read_text());assert d.get('numerical_policy')==POLICY,'unsupported_policy';D,mapping=preprocess(d)")
edit('reference.py','meta=dict(input_sha256=', 'meta=dict(numerical_policy=POLICY,input_sha256=')
p=H/'reference.py';s=p.read_text();a=s.index('  t=time.perf_counter();data,chain,inverse=');b=s.index('\n def evaluation',a)
s=s[:a]+'''  logical=state.solves
  for attempt,tolerance in enumerate([1e-9,1e-11]):
   t=time.perf_counter();data,chain,inverse=prob.get_problem_data(cp.CLARABEL)
   settings=clarabel.DefaultSettings()
   for k,v in OPTIONS.items():setattr(settings,k,v)
   settings.tol_feas=settings.tol_gap_abs=settings.tol_gap_rel=tolerance
   settings.verbose=False
   solver=clarabel.DefaultSolver(sparse.csc_matrix((len(data['c']),len(data['c']))),data['c'],data['A'],data['b'],dims_to_solver_cones(data['dims']),settings)
   raw=solver.solve();prob.unpack_results(raw,chain,inverse)
   scales=np.array(raw.x[:len(u)]);z=np.array(raw.z[:len(b)])
   report,_,_=validator(prob.status,scales,float(raw.obj_val),A,b,c,active,u)
   dual=dict(stationarity=float(abs(c+A.T@z).max()),negative=float(np.maximum(-z,0).max(initial=0)),relative_gap=float(abs(c@scales+b@z)/max(1,abs(c@scales),abs(b@z))))
   accepted=report['accepted'] and all(np.isfinite(v) and v<=1e-7 for v in dual.values())
   eligible=(not accepted and prob.status=='optimal' and np.isfinite(scales).all() and np.isfinite(z).all() and np.isfinite(raw.obj_val)
     and bool(np.all(scales[active]>0)) and report['objective_relative_error']<=1e-7
     and all(np.isfinite(report[k]) for k in ['objective_relative_error','max_normalized_violation','max_absolute_violation'])
     and all(np.isfinite(v) for v in dual.values()))
   state.C=C;state.emit(dict(event='solve',number=state.solves,logical_solve=logical,attempt=attempt,numerical_policy=POLICY,solver_tolerance=tolerance,retry_eligible=bool(eligible),site=site,C=C,A_data=A.data,A_indices=A.indices,A_indptr=A.indptr,A_shape=A.shape,b=b,c=c,upper=u,active=active.astype(int),scales=scales,dual=z,status=prob.status,objective=raw.obj_val,iterations=raw.iterations,seconds=time.perf_counter()-t,accepted=bool(accepted),validation=report,dual_check=dual,canonical_shape=data['A'].shape,canonical_soc=data['dims'].soc))
   state.solves+=1
   if accepted:
    x.value=scales
    return float(raw.obj_val)
   if attempt:raise audit.InvalidSolve('retry_exhausted')
   if not eligible:raise audit.InvalidSolve('invalid_solver_result')
''' +s[b:];p.write_text(s)
shutil.copyfile(H.parent/'phase05/reference_probe.py',H/'reference_probe.py')
edit('reference_probe.py',"OLD = Path(__file__).resolve().parents[1] / 'phase03'","OLD = Path(__file__).resolve().parent")
edit('reference_probe.py',"choices=['original', 'evaluated']","choices=['evaluated']")
# The probe shares the declared policy check without changing its arithmetic.
edit('reference_probe.py','from reference import ', 'from reference import POLICY, ')
edit('reference_probe.py',"    output.mkdir(parents=True, exist_ok=False)", "    assert inp.get('numerical_policy')==POLICY,'unsupported_policy'\n    output.mkdir(parents=True, exist_ok=False)")
print('Derived candidate; retry.hpp and test clients are separately authored.')
edit('CMakeLists.txt','add_executable(ian_checkpoint_tool tests/checkpoint_tool.cpp)', 'add_executable(ian_checkpoint_tool tests/checkpoint_tool.cpp)\nadd_executable(ian_retry_tests tests/retry_tests.cpp)')
edit('CMakeLists.txt','foreach(TARGET ian_engine ian_probe ian_checkpoint_tool)', 'foreach(TARGET ian_engine ian_probe ian_checkpoint_tool ian_retry_tests)')
