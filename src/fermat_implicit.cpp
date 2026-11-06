#include <Rcpp.h>
#include <algorithm>
#include <cmath>
#include <limits>
#include <vector>
#include <set>

// Dense Dijkstra on an implicit complete graph: no adjacency or distance cache.
// [[Rcpp::export]]
Rcpp::List fermat_implicit_cpp(Rcpp::NumericMatrix x, double p,
    Rcpp::IntegerVector sources, Rcpp::IntegerVector targets, double budget, bool return_graph) {
    const int n = x.nrow(), dim = x.ncol();
    if (n < 1 || dim < 1 || !std::isfinite(p) || p < 1 ||
        !std::isfinite(budget) || budget <= 0) Rcpp::stop("Invalid implicit Fermat controls");
    for (double v : x) if (!std::isfinite(v)) Rcpp::stop("Nonfinite coordinates");
    for (int v : sources) if (v == NA_INTEGER || v < 1 || v > n) Rcpp::stop("Invalid source");
    for (int v : targets) if (v == NA_INTEGER || v < 1 || v > n) Rcpp::stop("Invalid target");
    // Includes input, output and conservative linear scratch; not process RSS.
    const long double estimate = 8.L * n * dim +
        8.L * sources.size() * targets.size() + 40.L * n + (return_graph ? 80.L * std::min((long double)sources.size() * std::max(0, n-1), (long double)n * std::max(0, n-1) / 2) : 0);
    if (estimate > budget) Rcpp::stop("Implicit Fermat workspace exceeds max.workspace.bytes");
    Rcpp::NumericMatrix out(sources.size(), targets.size());
    std::set<std::pair<int,int>> edges;
    if (!sources.size() || !targets.size()) return Rcpp::List::create(Rcpp::Named("distances")=out, Rcpp::Named("edges")=Rcpp::IntegerMatrix(0,2), Rcpp::Named("weights")=Rcpp::NumericVector(0));
    const double limit = std::numeric_limits<double>::max() / std::max(1, n-1);
    auto weight = [&](int i, int j) {
        double norm = 0;
        for (int k=0; k<dim; ++k) norm = std::hypot(norm, x(i,k)-x(j,k));
        if (!std::isfinite(norm)) Rcpp::stop("Euclidean distances overflow; rescale points");
        double w = std::pow(norm,p);
        if (!std::isfinite(w)) Rcpp::stop("Powered edge lengths overflow; rescale points");
        if (norm > 0 && w == 0) Rcpp::stop("Powered edge lengths underflow to zero; rescale points");
        if (w > limit) Rcpp::stop("Potential path-cost overflow; rescale points");
        return w;
    };
    // Check all edges even if a requested path settles early, matching the
    // explicit reference's numeric-range contract without storing the edges.
    for (int i=0; i<n; ++i) {
        Rcpp::checkUserInterrupt();
        for (int j=i+1; j<n; ++j) weight(i,j);
    }
    std::vector<double> d(n);
    std::vector<int> parent(n,-1);
    std::vector<unsigned char> traced(n);
    std::vector<unsigned char> settled(n), requested(n,0);
    for (int t : targets) requested[t-1] = 1;
    const int total = std::count(requested.begin(), requested.end(), 1);
    for (int s=0; s<sources.size(); ++s) {
        std::fill(d.begin(), d.end(), std::numeric_limits<double>::infinity());
        std::fill(settled.begin(), settled.end(), 0);
        std::fill(parent.begin(), parent.end(), -1);
        d[sources[s]-1] = 0;
        int remaining = total;
        for (int step=0; step<n; ++step) {
            Rcpp::checkUserInterrupt();
            int u=-1;
            for (int i=0; i<n; ++i) if (!settled[i] && (u<0 || d[i]<d[u])) u=i;
            settled[u]=1;
            if (requested[u] && --remaining==0) break;
            for (int v=0; v<n; ++v) if (!settled[v]) {
                const double candidate=d[u]+weight(u,v);
                if (candidate<d[v]) { d[v]=candidate; parent[v]=u; }
            }
        }
        for (int j=0; j<targets.size(); ++j) out(s,j)=d[targets[j]-1];
        if (return_graph) {
            std::fill(traced.begin(), traced.end(), 0);
            for (int target : targets) {
                int v=target-1;
                while (parent[v]>=0 && !traced[v]) {
                    traced[v]=1;
                    int u=parent[v];
                    edges.emplace(std::min(u,v),std::max(u,v));
                    v=u;
                }
            }
        }
    }
    Rcpp::IntegerMatrix edge_out(edges.size(),2);
    Rcpp::NumericVector weights(edges.size());
    int e=0;
    for (const auto& edge : edges) {
        edge_out(e,0)=edge.first+1; edge_out(e,1)=edge.second+1;
        weights[e]=weight(edge.first,edge.second); ++e;
    }
    return Rcpp::List::create(Rcpp::Named("distances")=out,
        Rcpp::Named("edges")=edge_out, Rcpp::Named("weights")=weights);
}
