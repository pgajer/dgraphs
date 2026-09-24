// C++ persistent sequence client; Clarabel's supported C ABI, binary64.
extern "C" {
#include <clarabel.h>
}
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>
using Clock=std::chrono::steady_clock;
using Time=Clock::time_point;
double seconds(Time a,Time b){return std::chrono::duration<double>(b-a).count();}
template<typename T> std::vector<T> read_array(std::ifstream& f,size_t n){
    std::vector<T> v(n);f.read(reinterpret_cast<char*>(v.data()),n*sizeof(T));
    if(!f) throw std::runtime_error("truncated input");return v;
}
struct Problem{
    size_t m,n,nz;
    std::vector<double> val,b,c,upper,values;
    std::vector<uint64_t> col,rowptr;
    std::vector<uint8_t> active;
    std::vector<uintptr_t> ptr,rows,pzero;
    ClarabelCscMatrix A,P;
    explicit Problem(const std::string& path){
        std::ifstream f(path,std::ios::binary);char magic[8];f.read(magic,8);
        if(!f||std::string(magic,8)!="IANLP001")throw std::runtime_error("invalid magic");
        auto dim=read_array<uint64_t>(f,3);m=dim[0];n=dim[1];nz=dim[2];
        val=read_array<double>(f,nz);col=read_array<uint64_t>(f,nz);rowptr=read_array<uint64_t>(f,m+1);
        b=read_array<double>(f,m);c=read_array<double>(f,n);upper=read_array<double>(f,n);active=read_array<uint8_t>(f,n);
        char extra;if(f.read(&extra,1))throw std::runtime_error("trailing input");
        if(!m||!n||rowptr[0]!=0||rowptr[m]!=nz)throw std::runtime_error("invalid dimensions");
        for(size_t i=0;i<m;i++)if(rowptr[i]>rowptr[i+1])throw std::runtime_error("invalid row pointer");
        for(size_t k=0;k<nz;k++)if(col[k]>=n||!std::isfinite(val[k]))throw std::runtime_error("invalid coefficient");
        for(double v:b)if(!std::isfinite(v))throw std::runtime_error("invalid b");
        for(size_t j=0;j<n;j++)if(!std::isfinite(c[j])||!std::isfinite(upper[j])||upper[j]<0||active[j]>1||bool(active[j])!=(upper[j]>0))throw std::runtime_error("invalid metadata");
    }
    void convert(){
        ptr.assign(n+1,0);rows.resize(nz);values.resize(nz);pzero.assign(n+1,0);
        for(auto j:col)++ptr[j+1];for(size_t j=0;j<n;j++)ptr[j+1]+=ptr[j];auto next=ptr;
        for(size_t i=0;i<m;i++)for(size_t k=rowptr[i];k<rowptr[i+1];k++){auto q=next[col[k]]++;rows[q]=i;values[q]=val[k];}
        clarabel_CscMatrix_init(&A,m,n,ptr.data(),rows.data(),values.data());
        clarabel_CscMatrix_init(&P,n,n,pzero.data(),nullptr,nullptr);
    }
};
void save_vector(const std::string& name,const double* data,size_t n){
    std::ofstream out(name,std::ios::binary);out.write(reinterpret_cast<const char*>(data),n*sizeof(double));
    if(!out)throw std::runtime_error("vector write failed");
}
using Solver=std::unique_ptr<ClarabelDefaultSolver,decltype(&clarabel_DefaultSolver_free)>;
int main(int argc,char** argv){try{
    const auto began=Clock::now();uint16_t endian=1;
    if(*reinterpret_cast<uint8_t*>(&endian)!=1||sizeof(double)!=8||sizeof(uintptr_t)!=8)throw std::runtime_error("requires little-endian 64-bit");
    if(argc!=4)throw std::runtime_error("Usage: ian_sequence sequence.txt output fresh|update");
    std::string mode=argv[3];if(mode!="fresh"&&mode!="update")throw std::runtime_error("invalid mode");
    std::filesystem::path folder=argv[2];if(!std::filesystem::create_directory(folder))throw std::runtime_error("output exists");
    std::ifstream input(argv[1]);if(!input)throw std::runtime_error("sequence missing");
    std::vector<std::string> paths;std::string line;while(std::getline(input,line)){if(!line.empty())paths.push_back(line);}
    if(paths.empty())throw std::runtime_error("empty sequence");
    auto settings=clarabel_DefaultSettings_default();settings.verbose=false;settings.max_iter=300;
    settings.tol_gap_abs=settings.tol_gap_rel=settings.tol_feas=1e-9;settings.max_threads=1;settings.direct_solve_method=QDLDL;
    settings.presolve_enable=false; // no SDP support, no chordal processing; dropzeros defaults false.
    Solver solver(nullptr,&clarabel_DefaultSolver_free);std::vector<uintptr_t> prevptr,prevrows;size_t prevm=0,prevn=0;
    size_t updates=0;double total_input=0,total_assembly=0,total_setup=0,total_solve=0,total_output=0,total_steps=0;
    const auto seq_start=Clock::now();
    for(size_t step=0;step<paths.size();step++){
        const auto start=Clock::now();Problem p(paths[step]);const auto loaded=Clock::now();p.convert();const auto assembled=Clock::now();
        bool reuse=mode=="update"&&bool(solver);
        if(reuse){
            if(prevm!=p.m||prevn!=p.n||prevptr!=p.ptr||prevrows!=p.rows)throw std::runtime_error("unsupported update: changed dimensions/sparsity; no fallback");
            clarabel_DefaultSolver_update_A(solver.get(),p.values.data(),p.nz);
            clarabel_DefaultSolver_update_b(solver.get(),p.b.data(),p.m);
            clarabel_DefaultSolver_update_q(solver.get(),p.c.data(),p.n);updates++;
        }else{
            auto cone=ClarabelNonnegativeConeT(p.m);
            solver.reset(clarabel_DefaultSolver_new(&p.P,p.c.data(),&p.A,p.b.data(),1,&cone,&settings));
            if(!solver)throw std::runtime_error("solver construction failed");
            if(mode=="update"){prevptr=p.ptr;prevrows=p.rows;prevm=p.m;prevn=p.n;}
        }
        const auto setup=Clock::now();clarabel_DefaultSolver_solve(solver.get());const auto solved=Clock::now();
        auto sol=clarabel_DefaultSolver_solution(solver.get());auto info=clarabel_DefaultSolver_info(solver.get());
        std::string id=(step<10?"0":"")+std::to_string(step);std::string prefix=(folder/id).string();
        save_vector(prefix+".x.bin",sol.x,sol.x_length);save_vector(prefix+".z.bin",sol.z,sol.z_length);
        const auto output=Clock::now();double ti=seconds(start,loaded),ta=seconds(loaded,assembled),ts=seconds(assembled,setup),tv=seconds(setup,solved),to=seconds(solved,output),tt=seconds(start,output);
        std::ofstream out(prefix+".json");out<<std::setprecision(17);
        out<<"{\"step\":"<<step<<",\"mode\":\""<<mode<<"\",\"reused_solver\":"<<(reuse?"true":"false")<<",\"operation\":\""<<(reuse?"update":"construct")<<"\",\"status\":\""<<(sol.status==ClarabelSolved?"optimal":"not_optimal")
           <<"\",\"native_status\":"<<sol.status<<",\"objective\":"<<sol.obj_val<<",\"dual_objective\":"<<sol.obj_val_dual<<",\"iterations\":"<<sol.iterations<<",\"solver_seconds\":"<<sol.solve_time
           <<",\"solver_primal_residual\":"<<sol.r_prim<<",\"solver_dual_residual\":"<<sol.r_dual<<",\"backend_gap_abs\":"<<info.gap_abs<<",\"backend_gap_rel\":"<<info.gap_rel
           <<",\"linear_solver\":\"qdldl\",\"linear_solver_threads\":"<<info.linsolver.threads<<",\"factor_nnz\":"<<info.linsolver.nnzL
           <<",\"input_seconds\":"<<ti<<",\"assembly_seconds\":"<<ta<<",\"setup_update_seconds\":"<<ts<<",\"solve_seconds\":"<<tv<<",\"output_seconds\":"<<to<<",\"step_seconds\":"<<tt<<"}\n";
        if(!out)throw std::runtime_error("JSON write failed");
        total_input+=ti;total_assembly+=ta;total_setup+=ts;total_solve+=tv;total_output+=to;total_steps+=tt;
        std::cout<<"step="<<step<<" operation="<<(reuse?"update":"construct")<<" iterations="<<sol.iterations<<" solver="<<sol.solve_time<<std::endl;
        if(mode=="fresh")solver.reset();
    }
    std::ofstream out(folder/"summary.json");out<<std::setprecision(17)
       <<"{\"path\":\"native\",\"mode\":\""<<mode<<"\",\"steps\":"<<paths.size()<<",\"startup_seconds\":"<<seconds(began,seq_start)<<",\"sequence_seconds\":"<<seconds(seq_start,Clock::now())
       <<",\"total_internal_seconds\":"<<seconds(began,Clock::now())<<",\"update_count\":"<<updates<<",\"sums\":{\"input_seconds\":"<<total_input<<",\"assembly_seconds\":"<<total_assembly<<",\"setup_update_seconds\":"<<total_setup<<",\"solve_seconds\":"<<total_solve<<",\"output_seconds\":"<<total_output<<",\"step_seconds\":"<<total_steps<<"}}\n";
    if(!out)throw std::runtime_error("summary write failed");return 0;
}catch(const std::exception& e){std::cerr<<e.what()<<std::endl;return 1;}}
