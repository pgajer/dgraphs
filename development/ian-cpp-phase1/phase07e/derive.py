"""Derive isolated Phase07E runtime from accepted Phase07D; no old edits."""
from pathlib import Path
import shutil,json
H=Path(__file__).resolve().parent;out=H/'candidate';base=H.parent/'phase07d/candidate'
out.mkdir(exist_ok=True)
for p in base.rglob('*'):
 if p.is_file() and '__pycache__' not in p.parts:
  q=out/p.relative_to(base);q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,q)
policy='IAN evaluated-LP retry units11 almost 0.1'
for p in out.rglob('*'):
 if p.is_file() and p.suffix in ['.hpp','.cpp','.py','.json']:
  p.write_text(p.read_text().replace('IAN evaluated-LP retry units11 0.1',policy))
def edit(name,old,new,count=1):
 p=out/name;s=p.read_text();assert s.count(old)==count,(name,old,s.count(old));p.write_text(s.replace(old,new))
# Eligibility and acceptance share the same finite/shape precondition, but have
# distinct status rules. In particular AlmostSolved is never accepted directly.
(out/'src/retry.hpp').write_text('''#pragma once
#include <cmath>
#include <utility>
namespace ian::detail {
template<class V> inline bool usable_return(const V &x,const V &z,const V &upper,
                                            double objective,size_t n,size_t m) {
    if(x.size()!=n || z.size()!=m || upper.size()!=n || !std::isfinite(objective)) return false;
    for(size_t i=0;i<n;++i) if(!std::isfinite(upper[i]) || !std::isfinite(x[i]) || (upper[i]>0 && x[i]<=0)) return false;
    for(double v:z) if(!std::isfinite(v)) return false;
    return true;
}
inline bool retry_eligible(bool usable, double objective_error, double primal,
                           double absolute, double stationarity, double negative, double gap,
                           bool almost=false) {
    return usable && std::isfinite(objective_error) && objective_error <= 1e-7 &&
        std::isfinite(primal) && std::isfinite(absolute) && std::isfinite(stationarity) &&
        std::isfinite(negative) && std::isfinite(gap) &&
        (almost || primal > 1e-7 || stationarity > 1e-7 || negative > 1e-7 || gap > 1e-7);
}
inline std::pair<bool,bool> classify_return(bool usable,bool solved,bool almost,
        double objective_error,double primal,double absolute,double stationarity,double negative,double gap) {
    bool finite=std::isfinite(objective_error)&&std::isfinite(primal)&&std::isfinite(absolute)&&
        std::isfinite(stationarity)&&std::isfinite(negative)&&std::isfinite(gap);
    bool accepted=usable&&solved&&finite&&objective_error<=1e-7&&primal<=1e-7&&
        stationarity<=1e-7&&negative<=1e-7&&gap<=1e-7;
    return {accepted,retry_eligible(usable&&(solved||almost),objective_error,primal,absolute,stationarity,negative,gap,almost)};
}
}
''')
edit('src/solver.hpp','    auto cone = ClarabelNonnegativeConeT(m);','''    for(double v:values) require(std::isfinite(v), "invalid_solver_coefficients");
    for(double v:rhs) require(std::isfinite(v), "invalid_solver_coefficients");
    auto cone = ClarabelNonnegativeConeT(m);''')
edit('src/solver.hpp','    bool accepted = sol.status == ClarabelSolved && x.size() == n && z.size() == m &&\n                    std::isfinite(sol.obj_val);','''    require(x.size()==n && z.size()==m, "invalid_solver_dimensions");
    bool accepted = usable_return(x,z,u,sol.obj_val,n,m);''')
edit('src/solver.hpp','''    bool eligible = retry_eligible(accepted, error, maxnormal, maxabsolute, stationarity, negative, gap);
    accepted = accepted && maxnormal <= 1e-7 && error <= 1e-7 && stationarity <= 1e-7 &&
               negative <= 1e-7 && gap <= 1e-7;''','''    auto disposition=classify_return(accepted,sol.status==ClarabelSolved,sol.status==ClarabelAlmostSolved,
        error,maxnormal,maxabsolute,stationarity,negative,gap);
    accepted=disposition.first;
    bool eligible=disposition.second;''')
(out/'retry_policy.py').write_text('''"""Status eligibility is distinct from original-unit acceptance."""
import math

def usable_return(x,z,upper,objective,n,m):
 if len(x)!=n or len(z)!=m or len(upper)!=n or not math.isfinite(objective):return False
 return (all(math.isfinite(v) for v in list(x)+list(z)+list(upper))
         and all(v>0 for v,u in zip(x,upper) if u>0))

def classify_return(usable,status,objective_error,primal,absolute,stationarity,negative,gap):
 finite=all(math.isfinite(v) for v in [objective_error,primal,absolute,stationarity,negative,gap])
 checks=finite and objective_error<=1e-7 and all(v<=1e-7 for v in [primal,stationarity,negative,gap])
 accepted=bool(usable and status=='Solved' and checks)
 eligible=bool(usable and status in ['Solved','AlmostSolved'] and finite and objective_error<=1e-7
               and (status=='AlmostSolved' or not checks))
 return accepted,eligible
''')
edit('reference.py','import clarabel','import clarabel\nfrom retry_policy import usable_return,classify_return')
edit('reference.py',"   solver=clarabel.DefaultSolver(","   if not (np.isfinite(data['A'].data).all() and np.isfinite(rhs).all() and np.isfinite(data['c']).all()):raise audit.InvalidSolve('invalid_solver_coefficients')\n   solver=clarabel.DefaultSolver(")
edit('reference.py','   scales=np.array(raw.x[:len(u)])*alpha;z=np.array(raw.z[:len(b)])','''   if len(raw.x)!=len(u) or len(raw.z)!=len(b):raise audit.InvalidSolve('invalid_solver_dimensions')
   scales=np.array(raw.x)*alpha;z=np.array(raw.z)''')
edit('reference.py',"   report,_,_=validator(status,scales,objective,A,b,c,active,u)","""   usable=usable_return(scales,z,u,objective,len(u),len(b))
   if not (np.isfinite(scales).all() and np.isfinite(z).all() and np.isfinite(objective)):raise audit.InvalidSolve('invalid_solver_result')
   report,_,_=validator(status,scales,objective,A,b,c,active,u)""")
edit('reference.py',"""   accepted=report['accepted'] and all(np.isfinite(v) and v<=1e-7 for v in dual.values())
   eligible=(not accepted and status=='optimal' and np.isfinite(scales).all() and np.isfinite(z).all() and np.isfinite(raw.obj_val)
     and bool(np.all(scales[active]>0)) and report['objective_relative_error']<=1e-7
     and all(np.isfinite(report[k]) for k in ['objective_relative_error','max_normalized_violation','max_absolute_violation'])
     and all(np.isfinite(v) for v in dual.values()))""","""   accepted,eligible=classify_return(usable,str(raw.status),report['objective_relative_error'],
     report['max_normalized_violation'],report['max_absolute_violation'],
     dual['stationarity'],dual['negative'],dual['relative_gap'])""")
c=json.loads((out/'config.json').read_text());c['retry']['eligible_statuses']=['Solved','AlmostSolved'];c['retry']['accept_status']='Solved';(out/'config.json').write_text(json.dumps(c)+'\n')
# JSON-driven classifications exercise the exact helpers used by the runtime.
edit('tests/retry_tests.cpp','    if(argc==3) {','''    if(argc==2) {
        std::ifstream in(argv[1]);Json cases;in>>cases;
        Json rows=Json::array();
        auto number=[](const Json &v)->double {if(v.is_number()) return v.get<double>();return v=="nan"?std::numeric_limits<double>::quiet_NaN():std::numeric_limits<double>::infinity();};
        for(auto c:cases) {
            auto vec=[&](const char *key){std::vector<double> r;for(auto v:c[key])r.push_back(number(v));return r;};
            auto x=vec("x"),z=vec("z"),u=vec("upper"),d=vec("metrics");
            bool usable=ian::detail::usable_return(x,z,u,number(c["objective"]),c["n"].get<size_t>(),c["m"].get<size_t>());
            auto result=ian::detail::classify_return(usable,c["status"]=="Solved",c["status"]=="AlmostSolved",d[0],d[1],d[2],d[3],d[4],d[5]);
            check(result.first==c["expected"][0].get<bool>() && result.second==c["expected"][1].get<bool>());
            rows.push_back(Json{{"name",c["name"]},{"accepted",result.first},{"retry_eligible",result.second}});
        }
        std::cout<<Json{{"passed",true},{"checks",checks},{"cases",rows}}<<'\\n';return 0;
    }
    if(argc==3) {''')
print('Derived Phase07E candidate from read-only Phase07D.')
