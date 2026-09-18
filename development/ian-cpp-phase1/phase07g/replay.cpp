extern "C" {
#include <clarabel.h>
}
#include <json.hpp>
#include <filesystem>
#include <fstream>
#include <vector>
#include <string>
#include <stdexcept>
#include <cstddef>
#include <cstring>
using J=nlohmann::json;namespace fs=std::filesystem;
template<class T> std::vector<T> read(fs::path p){std::ifstream f(p,std::ios::binary|std::ios::ate);if(!f)throw std::runtime_error("missing input");auto size=f.tellg();if(size%sizeof(T))throw std::runtime_error("invalid size");std::vector<T> v(size/sizeof(T));f.seekg(0);f.read(reinterpret_cast<char*>(v.data()),size);if(!f)throw std::runtime_error("read failure");return v;}
template<class T> void binary(fs::path p,const std::vector<T>&v){std::ofstream f(p,std::ios::binary);f.write(reinterpret_cast<const char*>(v.data()),v.size()*sizeof(T));if(!f)throw std::runtime_error("write failure");}
void write(fs::path p,const J&j){std::ofstream f(p);f<<j.dump()<<'\n';if(!f)throw std::runtime_error("write failure");}
std::string status(ClarabelSolverStatus s){switch(s){
#define S(x) case Clarabel##x:return #x;
S(Unsolved) S(Solved) S(PrimalInfeasible) S(DualInfeasible) S(AlmostSolved) S(AlmostPrimalInfeasible) S(AlmostDualInfeasible) S(MaxIterations) S(MaxTime) S(NumericalError) S(InsufficientProgress) S(CallbackTerminated)
#undef S
}throw std::runtime_error("unknown status");}
J info(const ClarabelDefaultInfo&i){J j; j["status"]=status(i.status);
#define I(k) j[#k]=i.k;
I(iterations) I(mu) I(sigma) I(step_length) I(cost_primal) I(cost_dual) I(res_primal) I(res_dual) I(res_primal_inf) I(res_dual_inf) I(gap_abs) I(gap_rel) I(ktratio) I(solve_time)
#undef I
return j;}
int observe(ClarabelDefaultInfo*i,void*ctx){static_cast<J*>(ctx)->push_back(info(*i));return 0;}
int main(int argc,char**argv){try{if(argc!=3)throw std::runtime_error("arguments");fs::path f=argv[1],out=argv[2];if(fs::exists(out))throw std::runtime_error("existing output");fs::create_directories(out);J meta;std::ifstream(f/"arrays.json")>>meta;size_t m=meta["shape"][0],n=meta["shape"][1];static_assert(sizeof(uintptr_t)==8);static_assert(sizeof(double)==8);
auto values=read<double>(f/"A_data.bin"),b=read<double>(f/"b.bin"),c=read<double>(f/"c.bin");auto rows=read<uintptr_t>(f/"A_rows.bin"),ptr=read<uintptr_t>(f/"A_ptr.bin"),pzero=read<uintptr_t>(f/"P_ptr.bin");
if(b.size()!=m||c.size()!=n||ptr.size()!=n+1||pzero.size()!=n+1||rows.size()!=values.size()||ptr.back()!=values.size())throw std::runtime_error("dimensions");
binary(out/"A_data.bin",values);binary(out/"A_rows.bin",rows);binary(out/"A_ptr.bin",ptr);binary(out/"b.bin",b);binary(out/"c.bin",c);binary(out/"P_ptr.bin",pzero);write(out/"arrays.json",meta);
ClarabelCscMatrix A,P;clarabel_CscMatrix_init(&A,m,n,ptr.data(),rows.data(),values.data());clarabel_CscMatrix_init(&P,n,n,pzero.data(),nullptr,nullptr);auto cone=ClarabelNonnegativeConeT(m);
auto s=clarabel_DefaultSettings_default();s.verbose=false;s.max_iter=300;s.max_threads=1;s.direct_solve_method=QDLDL;s.presolve_enable=false;s.tol_feas=s.tol_gap_abs=s.tol_gap_rel=1e-11;J settings;
#include "settings.inc"
// Read object representation only: Rust's trailing field occupies C tail padding.
// This observes the returned ABI bytes; it does not set or repair the old header.
unsigned char drop=0;std::memcpy(&drop,reinterpret_cast<const unsigned char*>(&s)+offsetof(ClarabelDefaultSettings,presolve_enable)+1,1);
settings["rust_input_sparse_dropzeros_byte"]=drop;settings["struct_bytes"]=sizeof(s);settings["presolve_offset"]=offsetof(ClarabelDefaultSettings,presolve_enable);write(out/"settings.json",settings);
auto solver=clarabel_DefaultSolver_new(&P,c.data(),&A,b.data(),1,&cone,&s);if(!solver)throw std::runtime_error("solver construction");J history=J::array();clarabel_DefaultSolver_set_termination_callback(solver,observe,&history);clarabel_DefaultSolver_solve(solver);auto r=clarabel_DefaultSolver_solution(solver);auto end=clarabel_DefaultSolver_info(solver);
write(out/"raw.json",J{{"status",status(r.status)},{"iterations",r.iterations},{"x",std::vector<double>(r.x,r.x+r.x_length)},{"z",std::vector<double>(r.z,r.z+r.z_length)},{"s",std::vector<double>(r.s,r.s+r.s_length)},{"objective",r.obj_val},{"dual_objective",r.obj_val_dual},{"r_prim",r.r_prim},{"r_dual",r.r_dual},{"seconds",r.solve_time},{"history",history},{"info",info(end)}});write(out/"trace.jsonl",J{{"event","solve"},{"diagnostic_only",true},{"status",status(r.status)}});clarabel_DefaultSolver_free(solver);return 0;
}catch(const std::exception&e){fprintf(stderr,"%s\n",e.what());return 2;}}
