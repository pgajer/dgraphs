#include <Rcpp.h>
#include <vector>
#include <algorithm>
#include <cmath>
using namespace Rcpp;
#include "dgraphs/linf_simplex_distance.hpp"
using dgraphs_simplex::Row;
using dgraphs_simplex::Answer;
using dgraphs_simplex::solve;
extern "C" SEXP _dgraphs_linf_simplex(SEXP sx,SEXP ss,SEXP st,SEXP sp,SEXP paths_) {
 BEGIN_RCPP
 NumericMatrix x(sx);IntegerVector sources(ss),targets(st);IntegerMatrix pairs(sp);bool paths=as<bool>(paths_);
 const int n=x.nrow(),d=x.ncol();std::vector<Row> rows(n);
 for(int i=0;i<n;++i){double maximum=0;for(int j=0;j<d;++j)maximum=std::max(maximum,x(i,j));
  for(int j=0;j<d;++j)if(x(i,j)>0){rows[i].id.push_back(j);rows[i].value.push_back(x(i,j)/maximum);}}
 const bool paired=pairs.nrow()>0;
 const R_xlen_t total=paired?pairs.nrow():static_cast<R_xlen_t>(sources.size())*targets.size();
 NumericVector out(total);List pathout(paths?total:0);
 bool symmetric=!paired&&sources.size()==targets.size()&&std::equal(sources.begin(),sources.end(),targets.begin());
 for(R_xlen_t k=0;k<total;++k){if(k%4096==0)checkUserInterrupt();
  int ii=paired?pairs(k,0)-1:sources[k%sources.size()]-1;
  int jj=paired?pairs(k,1)-1:targets[k/sources.size()]-1;
  if(symmetric&&!paths&&(k%sources.size())<(k/sources.size())){out[k]=out[(k%sources.size())*sources.size()+k/sources.size()];continue;}
  Answer answer=solve(rows[ii],rows[jj]);out[k]=answer.distance;
  if(paths){const auto& fs=answer.faces;std::vector<double> a(d),b(d);
   std::fill(a.begin(),a.end(),1);std::fill(b.begin(),b.end(),1);
   for(size_t j=0;j<rows[ii].id.size();++j)a[rows[ii].id[j]]=1-rows[ii].value[j];
   for(size_t j=0;j<rows[jj].id.size();++j)b[rows[jj].id[j]]=1-rows[jj].value[j];
   std::vector<double> times{0};for(size_t r=1;r<fs.size();++r)times.push_back(a[fs[r]]/(a[fs[r]]+b[fs[r-1]]));times.push_back(1);
   NumericMatrix path(times.size(),d);
   for(size_t r=0;r<times.size();++r){double t=times[r];
    for(int j=0;j<d;++j)path(r,j)=1-((1-t)*a[j]+t*b[j]);
    for(size_t j=0;j<fs.size();++j){double z=0;
     if(j>0)z=std::max(z,a[fs[j]]-(a[fs[j]]+b[fs[j-1]])*t);
     if(j+1<fs.size())z=std::max(z,(a[fs[j+1]]+b[fs[j]])*t-a[fs[j+1]]);
     path(r,fs[j])=1-z;}}
   IntegerVector faces(fs.size());for(size_t j=0;j<fs.size();++j)faces[j]=fs[j]+1;
   pathout[k]=List::create(_["points"]=path,_["faces"]=faces,_["times"]=times);
  }
 }
 if(!paired)out.attr("dim")=IntegerVector::create(sources.size(),targets.size());
 if(paths)return List::create(_["distances"]=out,_["paths"]=pathout);
 return out;
 END_RCPP
}
