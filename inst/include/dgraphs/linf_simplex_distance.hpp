#ifndef DGRAPHS_LINF_SIMPLEX_DISTANCE_HPP
#define DGRAPHS_LINF_SIMPLEX_DISTANCE_HPP
#include <vector>
#include <cmath>
#include <algorithm>
// Shared exact intrinsic solver: intermediate faces are admissible.
namespace dgraphs_simplex {
struct Row { std::vector<int> id; std::vector<double> value; };
struct Answer { double distance; std::vector<int> faces; };
inline Answer solve(const Row& u,const Row& v) {
 std::vector<int> ids; std::vector<double> a,b;
 size_t i=0,j=0; double chord=0; int start=-1,end=-1,shared=-1;
 while(i<u.id.size()||j<v.id.size()) {
  int id; double x=0,y=0;
  if(j==v.id.size()||(i<u.id.size()&&u.id[i]<v.id[j])){id=u.id[i];x=u.value[i++];}
  else if(i==u.id.size()||v.id[j]<u.id[i]){id=v.id[j];y=v.value[j++];}
  else {id=u.id[i];x=u.value[i++];y=v.value[j++];}
  chord+=(x-y)*(x-y); ids.push_back(id);a.push_back(1-x);b.push_back(1-y);
  int k=ids.size()-1;
  if(x==1 && (start<0 || b[k]<b[start]))start=k;
  if(y==1 && (end<0 || a[k]<a[end]))end=k;
  if(x==1&&y==1)shared=k;
 }
 if(shared>=0)return {std::sqrt(chord),{ids[shared]}};
 double best=b[start]*a[end]; int last=start;
 const int m=ids.size(); std::vector<double> cost(m);std::vector<int> pred(m,start);std::vector<bool> done(m,false);
 for(int k=0;k<m;++k){cost[k]=a[k]*(b[start]+b[k]);done[k]=(a[k]==0||b[k]==0||a[k]*b[k]>=best);}
 for(;;){
  int k=-1;double smallest=best;
  for(int l=0;l<m;++l)if(!done[l]&&cost[l]<smallest){k=l;smallest=cost[l];}
  if(k<0)break;
  done[k]=true;
  double candidate=cost[k]+a[end]*b[k];
  if(candidate<best){best=candidate;last=k;}
  for(int l=0;l<m;++l)if(!done[l]){
   double candidate=cost[k]+a[l]*(b[k]+b[l]);
   if(candidate<cost[l]){cost[l]=candidate;pred[l]=k;}
  }
 }
 std::vector<int> path{ids[end]};
 for(int k=last;k!=start;k=pred[k])path.push_back(ids[k]);
 path.push_back(ids[start]);std::reverse(path.begin(),path.end());
 return {std::sqrt(chord+2*best),path};
}
}
#endif
