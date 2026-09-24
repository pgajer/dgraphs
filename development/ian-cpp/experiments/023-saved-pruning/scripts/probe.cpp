// Diagnostic consumer of the unchanged native arithmetic; no solver linked.
#include <fstream>
#include <iostream>
#include "numeric.hpp"
using namespace ian::detail;
int main(int argc,char**argv){
 try {
  require(argc==3,"usage: probe input output");std::ifstream stream(argv[1]);Json inp;stream>>inp;
  Mat D=inp.at("D1").get<Mat>(),D2=inp.at("D2").get<Mat>();Ids deg=inp.at("degrees").get<Ids>();
  Json outputs=Json::array();
  for(auto& c:inp.at("cases")){
   Vec stats;double mu;
   if(c.contains("stats")){stats=c.at("stats").get<Vec>();mu=c.at("median");}
   else{stats=volumes(D2,c.at("scales").get<Vec>(),deg);Vec pos;for(double v:stats)if(v>0)pos.push_back(v);mu=median(pos);}
   Json d=decision(stats,mu);Ids candidates=d.at("candidates").get<Ids>(),selected=candidates;
   selected.resize(std::min(selected.size(),size_t(std::max(1,int(.1*selected.size())))));
   Edges edges=c.contains("edges")?c.at("edges").get<Edges>():inp.at("edges").get<Edges>();
   Mat cd=c.contains("D1")?c.at("D1").get<Mat>():D;
   Edges removed=prune(edges,cd,selected);
   double C=c.at("C"),lo=c.at("minC"),hi=c.at("maxC");
   bool stop=std::abs(mu-1)<=.1||(mu-1>.1&&close(C,lo))||(mu-1<-.1&&close(C,hi));
   outputs.push_back(Json{{"name",c.at("name")},{"ratios",stats},{"median",mu},{"retune_stop",stop},{"decision",d},{"selected",selected},{"removed",removed},{"remaining_edges",edges}});
  }
  std::ofstream(argv[2])<<Json{{"optimizer_calls",0},{"cases",outputs}}.dump()<<"\n";
 }catch(const std::exception&e){std::cerr<<e.what()<<"\n";return 1;}
}
