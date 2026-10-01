#include <Rcpp.h>
#include <queue>
#include <vector>
#include <limits>
#include <cmath>

// Truncated Dijkstra with reusable, generation-stamped scratch space.
// [[Rcpp::export]]
Rcpp::List fermat_knn_cpp(Rcpp::IntegerMatrix index, Rcpp::NumericMatrix weight) {
    const int n=index.nrow(), k=index.ncol();
    if (k < 1 || k >= n || weight.nrow()!=n || weight.ncol()!=k)
        Rcpp::stop("Invalid neighbor table dimensions");
    for (int i=0;i<n;++i) for(int j=0;j<k;++j)
        if(index(i,j)<1 || index(i,j)>n || index(i,j)==i+1 ||
           !std::isfinite(weight(i,j)) || weight(i,j)<0)
            Rcpp::stop("Invalid neighbor table entry");
    Rcpp::IntegerMatrix outIndex(n,k);
    Rcpp::NumericMatrix outDistance(n,k);
    std::vector<double> distance(n);
    std::vector<int> seen(n,-1), settled(n,-1);
    using Entry=std::pair<double,int>;
    for(int s=0;s<n;++s) {
        Rcpp::checkUserInterrupt();
        std::priority_queue<Entry,std::vector<Entry>,std::greater<Entry>> queue;
        distance[s]=0; seen[s]=s; queue.emplace(0,s);
        int count=0;
        while(!queue.empty() && count<k) {
            const auto entry=queue.top(); queue.pop();
            const double du=entry.first; const int u=entry.second;
            if(settled[u]==s || du!=distance[u]) continue;
            settled[u]=s;
            if(u!=s) {
                outIndex(s,count)=u+1; outDistance(s,count)=du;
                if(++count==k) break;
            }
            for(int j=0;j<k;++j) {
                const int v=index(u,j)-1;
                if(settled[v]==s) continue;
                const double candidate=du+weight(u,j);
                if(!std::isfinite(candidate)) Rcpp::stop("Path costs overflow; rescale points");
                if(seen[v]!=s || candidate<distance[v]) {
                    seen[v]=s; distance[v]=candidate; queue.emplace(candidate,v);
                }
            }
        }
        if(count!=k) Rcpp::stop("Insufficient reachable neighbors");
    }
    return Rcpp::List::create(Rcpp::Named("index")=outIndex,
                              Rcpp::Named("distance")=outDistance);
}
