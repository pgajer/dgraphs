#include "json_adapter.hpp"
#include "events_json.hpp"
#include <fstream>
#include <filesystem>
using namespace ian::io;
struct Summary : ian::Observer {
 std::ofstream stream;int solves=0;
 explicit Summary(const std::filesystem::path& p):stream(p){}
 void on_event(const ian::Event& e) override {
  if(e.name!="solve")return;
  Json j=event_json(e);
  for(const auto* key:{"A_data","A_indices","A_indptr","A_shape","b","c","upper","active","scales","dual","backend_rhs","backend_primal","backend_dual","backend_slack"})j.erase(key);
  stream<<j.dump()<<'\n';stream.flush();
  if(++solves>=1500)throw std::runtime_error("adapter_solve_budget");
 }
};
ian::Matrix binary_matrix(const std::string& path,std::size_t n,std::size_t p){
 std::ifstream f(path,std::ios::binary);std::vector<double> values(n*p);f.read(reinterpret_cast<char*>(values.data()),values.size()*sizeof(double));if(!f || f.peek()!=EOF)throw std::runtime_error("binary_matrix_size");
 ian::Matrix x(n,ian::Vector(p));for(std::size_t i=0;i<n;++i)for(std::size_t j=0;j<p;++j)x[i][j]=values[j*n+i];return x;
}
int main(int argc,char** argv){
 if(argc!=3)return 2;
 std::filesystem::path out=argv[2];if(!std::filesystem::create_directories(out))return 2;
 std::ifstream meta(argv[1]);Json j;meta>>j;int n=j.at("n"),p=j.at("p");
 ian::Input in;in.features=binary_matrix(j.at("features"),n,p);in.distances=binary_matrix(j.at("distances"),n,n);in.specimen_ids=j.at("ids").get<std::vector<std::string>>();in.policy=j.at("numerical_policy");in.preserve_connectivity=true;
 Summary observer(out/"trace.jsonl");auto result=ian::run(in,&observer);
 if(result.affinity_valid){std::ofstream affinity(out/"affinity.bin",std::ios::binary);for(const auto& row:result.affinity)affinity.write(reinterpret_cast<const char*>(row.data()),row.size()*sizeof(double));if(!affinity)throw std::runtime_error("affinity_write");}
 result.affinity.clear();Json r=result_json(result);r["affinity"]=nullptr;r["affinity_binary"]=result.affinity_valid?Json("affinity.bin"):Json(nullptr);r["affinity_storage"]="row-major little-endian binary64; tested on Mac arm64";
 std::ofstream(out/"result.json")<<r.dump()<<'\n';std::ofstream(out/"status.json")<<Json{{"complete",result.complete},{"solves",result.solves},{"error",result.error.code}}.dump()<<'\n';return result.complete?0:1;
}
