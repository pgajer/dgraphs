// Standalone C++ client of Clarabel.cpp's supported C ABI (binary64).
extern "C" {
#include <clarabel.h>
}
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <vector>
using Clock=std::chrono::steady_clock;
double elapsed(Clock::time_point a,Clock::time_point b){return std::chrono::duration<double>(b-a).count();}
template<class T> std::vector<T> read(std::ifstream& f,size_t n){
    std::vector<T> v(n); f.read(reinterpret_cast<char*>(v.data()),n*sizeof(T));
    if(!f) throw std::runtime_error("Truncated input"); return v;
}
template<class T> void write(std::ofstream& f,const std::vector<T>& v){f.write(reinterpret_cast<const char*>(v.data()),v.size()*sizeof(T));}
int main(int argc,char** argv){try{
    const auto start=Clock::now();
    if(argc!=3 && argc!=4) throw std::runtime_error("Usage: ian_lp_replay fixture.bin output_prefix [--echo]");
    uint16_t endian=1;
    if(*reinterpret_cast<uint8_t*>(&endian)!=1 || sizeof(double)!=8 || sizeof(uintptr_t)!=8) throw std::runtime_error("Requires little-endian 64-bit host");
    std::ifstream f(argv[1],std::ios::binary); char magic[8];f.read(magic,8);
    if(std::string(magic,8)!="IANLP001") throw std::runtime_error("Invalid magic");
    auto dim=read<uint64_t>(f,3);size_t m=dim[0],n=dim[1],nz=dim[2];
    auto val=read<double>(f,nz);auto col=read<uint64_t>(f,nz);auto rowptr=read<uint64_t>(f,m+1);
    auto b=read<double>(f,m);auto c=read<double>(f,n);auto upper=read<double>(f,n);auto active=read<uint8_t>(f,n);
    char extra;if(f.read(&extra,1)) throw std::runtime_error("Trailing input");
    if(!m||!n||rowptr[0]!=0||rowptr[m]!=nz) throw std::runtime_error("Invalid CSR dimensions");
    for(size_t i=0;i<m;i++) if(rowptr[i]>rowptr[i+1]) throw std::runtime_error("Invalid CSR pointer");
    for(size_t k=0;k<nz;k++) if(col[k]>=n||!std::isfinite(val[k])) throw std::runtime_error("Invalid CSR coefficient");
    for(double v:b) if(!std::isfinite(v)) throw std::runtime_error("Invalid RHS");
    for(size_t j=0;j<n;j++) if(!std::isfinite(c[j])||!std::isfinite(upper[j])||upper[j]<0||active[j]>1||bool(active[j])!=(upper[j]>0)) throw std::runtime_error("Invalid variable metadata");
    if(argc==4){
        if(std::string(argv[3])!="--echo") throw std::runtime_error("Unknown option");
        std::ofstream out(argv[2],std::ios::binary);out.write(magic,8);write(out,dim);write(out,val);write(out,col);write(out,rowptr);write(out,b);write(out,c);write(out,upper);write(out,active);
        if(!out) throw std::runtime_error("Echo output failed");return 0;
    }
    // Stable CSR to CSC conversion, preserving row order and every coefficient.
    std::vector<uintptr_t> ptr(n+1,0),rows(nz),pzero(n+1,0);
    std::vector<double> values(nz);
    for(auto j:col) ++ptr[j+1];for(size_t j=0;j<n;j++) ptr[j+1]+=ptr[j];auto next=ptr;
    for(size_t i=0;i<m;i++) for(size_t k=rowptr[i];k<rowptr[i+1];k++){auto q=next[col[k]]++;rows[q]=i;values[q]=val[k];}
    const auto loaded=Clock::now();
    ClarabelCscMatrix A,P;clarabel_CscMatrix_init(&A,m,n,ptr.data(),rows.data(),values.data());
    clarabel_CscMatrix_init(&P,n,n,pzero.data(),nullptr,nullptr);
    ClarabelSupportedConeT cone=ClarabelNonnegativeConeT(m);
    auto settings=clarabel_DefaultSettings_default();settings.verbose=false;
    settings.tol_gap_abs=1e-9;settings.tol_gap_rel=1e-9;settings.tol_feas=1e-9;settings.max_iter=300;
    settings.max_threads=1;settings.direct_solve_method=QDLDL;
    auto* solver=clarabel_DefaultSolver_new(&P,c.data(),&A,b.data(),1,&cone,&settings);
    if(!solver) throw std::runtime_error("Solver construction failed");
    const auto setup=Clock::now();clarabel_DefaultSolver_solve(solver);const auto solved=Clock::now();
    auto sol=clarabel_DefaultSolver_solution(solver);
    auto info=clarabel_DefaultSolver_info(solver);
    std::string prefix=argv[2];
    std::ofstream xs(prefix+".x.bin",std::ios::binary);xs.write(reinterpret_cast<char*>(sol.x),sol.x_length*sizeof(double));xs.close();
    std::ofstream zs(prefix+".z.bin",std::ios::binary);zs.write(reinterpret_cast<char*>(sol.z),sol.z_length*sizeof(double));zs.close();
    const auto output=Clock::now();std::ofstream out(prefix+".json");out<<std::setprecision(17);
    out<<"{\"path\":\"native\",\"status\":\""<<(sol.status==ClarabelSolved?"optimal":"not_optimal")<<"\",\"native_status\":"<<sol.status
       <<",\"objective\":"<<sol.obj_val<<",\"dual_objective\":"<<sol.obj_val_dual<<",\"iterations\":"<<sol.iterations<<",\"solver_time\":"<<sol.solve_time
       <<",\"solver_primal_residual\":"<<sol.r_prim<<",\"solver_dual_residual\":"<<sol.r_dual
       <<",\"solver_gap_abs\":"<<info.gap_abs<<",\"solver_gap_rel\":"<<info.gap_rel
       <<",\"linear_solver_threads\":"<<info.linsolver.threads<<",\"linear_solver_nnzL\":"<<info.linsolver.nnzL
       <<",\"startup_import_seconds\":0,\"input_seconds\":"<<elapsed(start,loaded)
       <<",\"setup_seconds\":"<<elapsed(loaded,setup)<<",\"backend_setup_seconds\":"<<elapsed(loaded,setup)
       <<",\"solve_call_seconds\":"<<elapsed(setup,solved)<<",\"validation_output_seconds\":"<<elapsed(solved,output)
       <<",\"internal_seconds\":"<<elapsed(start,output)<<"}\n";
    bool ok=bool(out)&&bool(xs)&&bool(zs);clarabel_DefaultSolver_free(solver);
    if(!ok) throw std::runtime_error("Output failed");return 0;
}catch(const std::exception& e){std::cerr<<e.what()<<'\n';return 1;}}
