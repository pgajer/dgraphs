#include <Rcpp.h>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <map>
#include <unordered_map>
#include <vector>
using namespace Rcpp;

static std::string key(const std::vector<double>& u) {
  if (u.empty()) stop("Invalid key coordinates");
  const char* hex = "0123456789abcdef";
  std::string out;
  auto byte = [&](unsigned x) { out += hex[(x >> 4) & 15]; out += hex[x & 15]; };
  uint32_t n = u.size();
  for (int s = 24; s >= 0; s -= 8) byte((n >> s) & 255);
  for (double x : u) {
    if (!std::isfinite(x)) stop("Invalid key coordinates");
    uint64_t bits; std::memcpy(&bits, &x, sizeof(bits));
    for (int s = 56; s >= 0; s -= 8) byte((bits >> s) & 255);
  }
  return out;
}
static std::vector<double> row(NumericMatrix U, int i) {
  std::vector<double> x(U.ncol());
  for (int j = 0; j < U.ncol(); ++j) x[j] = U(i,j);
  return x;
}
static std::string edgekey(const std::vector<double>& a, const std::vector<double>& b) {
  auto ka = key(a), kb = key(b);
  return ka <= kb ? ka + ":" + kb : kb + ":" + ka;
}
static double compensated(const std::vector<double>& x) {
  double s = 0, c = 0;
  for (double v : x) {
    double t = s + v;
    c += std::abs(s) >= std::abs(v) ? (s-t)+v : (v-t)+s;
    s = t;
  }
  return s+c;
}
// [[Rcpp::export]]
std::string qgc_key(NumericVector u) { return key(as<std::vector<double>>(u)); }
// [[Rcpp::export]]
CharacterVector qgc_keys(NumericMatrix U) {
  CharacterVector keys(U.nrow());
  for (int i=0; i<U.nrow(); ++i) keys[i]=key(row(U,i));
  return keys;
}
// [[Rcpp::export]]
double qgc_sum(NumericVector x) { return compensated(as<std::vector<double>>(x)); }
// [[Rcpp::export]]
List qgc_edge_key(NumericVector a, NumericVector b) {
  std::string ka=qgc_key(a), kb=qgc_key(b);
  return List::create(_["key"]=ka<=kb ? ka+":"+kb : kb+":"+ka,
    _["from"]=ka<=kb ? a : b, _["to"]=ka<=kb ? b : a);
}
// [[Rcpp::export]]
List qgc_edge_order(List edges) {
  std::map<std::string, std::pair<int,bool>> order;
  for (int i=0; i<edges.size(); ++i) {
    NumericMatrix e=edges[i];
    if (e.nrow()!=2) stop("Expected a two-point edge");
    auto a=key(row(e,0)), b=key(row(e,1)); bool reverse=b<a;
    auto k=reverse ? b+":"+a : a+":"+b;
    order.emplace(k,std::make_pair(i+1,reverse));
  }
  CharacterVector keys(order.size()); IntegerVector indices(order.size()); LogicalVector reverse(order.size());
  int i=0;
  for (const auto& x:order) {keys[i]=x.first; indices[i]=x.second.first; reverse[i]=x.second.second; ++i;}
  return List::create(_["keys"]=keys,_["indices"]=indices,_["reverse"]=reverse);
}
// [[Rcpp::export]]
List qgc_complete_edges(NumericMatrix U) {
  std::vector<NumericMatrix> edges;
  for (int i=0;i<U.nrow();++i) for(int j=i+1;j<U.nrow();++j) {
    bool equal=true;
    for(int d=0;d<U.ncol();++d) if(U(i,d)!=U(j,d)) equal=false;
    if(equal) continue;
    NumericMatrix edge(2,U.ncol());
    for(int d=0;d<U.ncol();++d) {edge(0,d)=U(i,d);edge(1,d)=U(j,d);}
    edges.push_back(edge);
  }
  return wrap(edges);
}
// [[Rcpp::export]]
IntegerVector qgc_dijkstra(NumericMatrix U, List edges, List records, int from, int to, Function poll) {
  int n=U.nrow(); --from; --to;
  if(from<0||to<0||from>=n||to>=n) stop("Invalid graph endpoints");
  std::vector<std::string> keys(n),pathkeys(n);
  std::unordered_map<std::string,int> indices;
  for(int i=0;i<n;++i) {keys[i]=key(row(U,i));indices.emplace(keys[i],i);}
  CharacterVector rn=records.names(); std::unordered_map<std::string,int> record_index;
  for(int i=0;i<records.size();++i) record_index.emplace(as<std::string>(rn[i]),i);
  std::vector<std::vector<std::pair<int,double>>> adjacency(n);
  for(int k=0;k<edges.size();++k) {
    NumericMatrix edge=edges[k];auto a=row(edge,0),b=row(edge,1);
    auto ai=indices.find(key(a)),bi=indices.find(key(b)),ri=record_index.find(edgekey(a,b));
    if(ai==indices.end()||bi==indices.end()||ri==record_index.end()) stop("Incomplete graph records");
    List record=records[ri->second]; double w=as<double>(record["length"]);
    if(!std::isfinite(w)||w<0) stop("Invalid graph weight");
    int u=ai->second,v=bi->second;
    if(u==v||w==0) continue;
    adjacency[u].emplace_back(v,w);adjacency[v].emplace_back(u,w);
  }
  std::vector<double> dist(n,R_PosInf);std::vector<bool> done(n,false);
  std::vector<std::vector<int>> paths(n);std::vector<std::vector<double>> weights(n);
  dist[from]=0;paths[from]={from};pathkeys[from]=keys[from];
  while(true) {
    poll();int u=-1;
    for(int i=0;i<n;++i) if(!done[i]&&std::isfinite(dist[i]))
      if(u<0||dist[i]<dist[u]||(dist[i]==dist[u]&&pathkeys[i]<pathkeys[u])) u=i;
    if(u<0) return IntegerVector(0);
    if(u==to) {IntegerVector path(paths[u].size());for(size_t j=0;j<paths[u].size();++j)path[j]=paths[u][j]+1;return path;}
    done[u]=true;
    for(const auto& edge:adjacency[u]) {
      int v=edge.first;if(done[v])continue;
      auto pw=weights[u];pw.push_back(edge.second);double d=compensated(pw);
      auto p=paths[u];p.push_back(v);auto pk=pathkeys[u]+"/"+keys[v];
      if(d<dist[v]||(d==dist[v]&&pk<pathkeys[v])) {dist[v]=d;paths[v]=p;weights[v]=pw;pathkeys[v]=pk;}
    }
  }
}
// The R integration driver and error estimates remain unchanged.
// [[Rcpp::export]]
NumericVector qgc_speeds(NumericVector t, NumericVector h, NumericVector alpha, NumericVector beta) {
  if(alpha.size()!=beta.size()) stop("Inconsistent tangent dimensions");
  NumericVector out(t.size());std::vector<double> x(h.size()+alpha.size());
  for(int k=0;k<t.size();++k) {
    double m=0;
    bool finite=true;
    for(int i=0;i<h.size();++i) {x[i]=h[i];finite=finite&&std::isfinite(x[i]);m=std::max(m,std::abs(x[i]));}
    for(int j=0;j<alpha.size();++j) {x[h.size()+j]=alpha[j]+beta[j]*t[k];finite=finite&&std::isfinite(x[h.size()+j]);m=std::max(m,std::abs(x[h.size()+j]));}
    if(!finite) {out[k]=R_PosInf;continue;}
    if(!std::isfinite(m)) {out[k]=R_PosInf;continue;}
    if(m==0) {out[k]=0;continue;}
    long double total=0;
    for(double v:x) {double z=v/m;double square=z*z;total+=square;}
    out[k]=m*std::sqrt(static_cast<double>(total));
  }
  return out;
}
