#pragma once
#include "numeric.hpp"
#include <functional>
#include <set>

namespace ian::detail {
// Read-only reachability after omitting one existing edge. No temporary graph
// mutation can leak through an exception or observer cancellation.
inline bool bridge(int n, const Edges& edges, const std::array<int,2>& edge) {
    require(std::find(edges.begin(),edges.end(),edge)!=edges.end(),"missing_edge");
    std::vector<Ids> adjacency(n);
    for (auto e:edges) if(e!=edge) {adjacency[e[0]].push_back(e[1]);adjacency[e[1]].push_back(e[0]);}
    Ids seen(n), todo{edge[0]};seen[edge[0]]=1;
    for(size_t k=0;k<todo.size();++k) for(int j:adjacency[todo[k]]) {
        if(j==edge[1])return false;
        if(!seen[j]) {seen[j]=1;todo.push_back(j);}
    }
    return true;
}
struct PruningContext { Ids order; int needed=0, candidate_count=0; bool expanded=false; };
inline PruningContext pruning_context(const ian::Decision& d) {
    PruningContext c; int positive=0,below=0;
    for(size_t i=0;i<d.stats.size();++i) {
        c.order.push_back(i);
        positive+=d.stats[i]>0;below+=d.stats[i]>0 && d.stats[i]<1.1;
        c.candidate_count+=d.stats[i]>d.threshold;
    }
    c.needed=positive-2*below;
    c.expanded=d.median_residual>.1 && c.needed>c.candidate_count;
    if(c.expanded) {c.order=numpy_argsort(d.stats);std::reverse(c.order.begin(),c.order.end());c.candidate_count=c.needed;}
    else std::stable_sort(c.order.begin(),c.order.end(),[&](int i,int j){return d.stats[i]>d.stats[j];});
    return c;
}
// Global threshold/rank summaries are already available, but the actual point
// eligibility predicate is evaluated only after this proposal's bridge guard.
inline Edges prune_connected(Edges& edges,const Mat& D,const ian::Decision& d,int iteration,
                            ian::PruningDiagnostics& diagnostics,Ids& selected,
                            const std::function<void(const ian::PruningAttempt&)>& observe = {}) {
    const auto c=pruning_context(d);const auto nbrs=neighbors(D,edges);
    diagnostics.history.push_back({});auto& step=diagnostics.history.back();step.iteration=iteration;
    step.statistical_candidates=c.candidate_count;step.allowance=std::max(1,int(.1*c.candidate_count));
    Ids touched(D.size());Edges removed;
    for(size_t rank=0;rank<c.order.size();++rank) {
        int i=c.order[rank];if(nbrs[i].empty() || touched[i])continue;
        int j=nbrs[i][0];std::array<int,2> e{std::min(i,j),std::max(i,j)};
        ian::PruningAttempt attempt{e,i,"",false,d.stats[i],d.threshold,d.stats[i]-d.threshold};++step.examined;
        auto cached=std::find_if(diagnostics.protected_bridges.begin(),diagnostics.protected_bridges.end(),[&](const auto& b){return b.edge==e;});
        bool is_bridge=cached!=diagnostics.protected_bridges.end();
        if(is_bridge) {++step.cached_skips;attempt.action="cached_bridge";}
        else {++step.bridge_checks;is_bridge=bridge(D.size(),edges,e);attempt.action="new_bridge";}
        if(is_bridge) {
            ++step.bridge_skips;
            if(cached==diagnostics.protected_bridges.end())diagnostics.protected_bridges.push_back({e,i,iteration,iteration,1,d.stats[i],d.threshold,d.stats[i]-d.threshold});
            else {++cached->encounters;cached->last_iteration=iteration;}
        } else {
            attempt.conditions_tested=true;
            bool eligible=d.stats[i]>d.threshold || (c.expanded && int(rank)<c.needed);
            if(!eligible) {attempt.action="conditions_failed";++step.condition_rejections;}
            else if(touched[j]) {attempt.action="endpoint_conflict";++step.endpoint_conflicts;}
            else {
                edges.erase(std::find(edges.begin(),edges.end(),e));removed.push_back(e);selected.push_back(i);
                touched[i]=touched[j]=1;++step.removed;attempt.action="removed";
            }
        }
        if(observe)observe(attempt);
        if(step.removed>=step.allowance)break;
    }
    return removed;
}
}
