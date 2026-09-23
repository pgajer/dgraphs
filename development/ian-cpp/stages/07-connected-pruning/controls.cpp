#include "connected.hpp"
#include "events_json.hpp"
#include <iostream>
using namespace ian;using namespace ian::detail;
int main() {
 int checks=0;
 // Exhaustively compare endpoint reachability against component-count change.
 for(int n=2;n<=5;++n) {
  Edges possible;for(int i=0;i<n;++i)for(int j=i+1;j<n;++j)possible.push_back({i,j});
  for(unsigned mask=1;mask<(1u<<possible.size());++mask) {
   Edges e;for(size_t k=0;k<possible.size();++k)if(mask&(1u<<k))e.push_back(possible[k]);
   auto labels=components(n,e);int before=*std::max_element(labels.begin(),labels.end());
   for(auto edge:e) {auto after=e;after.erase(std::find(after.begin(),after.end(),edge));auto l=components(n,after);require(bridge(n,e,edge)==(*std::max_element(l.begin(),l.end())>before),"bridge_exhaustive");++checks;}
  }
 }
 Mat D(20,Vec(20,1));for(int i=0;i<20;++i)D[i][i]=0;
 // A cycle whose two disjoint longest proposed edges form a joint cut.
 Edges cycle{{0,19}};for(int i=0;i<19;++i)cycle.push_back({i,i+1});std::sort(cycle.begin(),cycle.end());D[0][1]=D[1][0]=3;D[2][3]=D[3][2]=3;
 Decision d{};d.stats=Vec(20,4);d.threshold=2.75;d.median_residual=0;
 PruningDiagnostics diag;Ids selected;std::vector<PruningAttempt> attempts;
 auto removed=prune_connected(cycle,D,d,0,diag,selected,[&](const auto& a){attempts.push_back(a);});
 require(removed==Edges{{0,1}} && components(20,cycle)==Ids(20,0),"sequential_joint_cut");
 require(diag.history[0].allowance==2 && diag.history[0].removed==1,"actual_deletion_budget");
 require(std::any_of(attempts.begin(),attempts.end(),[](auto& a){return a.edge==std::array<int,2>{2,3} && a.action=="new_bridge" && !a.conditions_tested;}),"sequential_bridge_before_condition");
 auto before=diag.protected_bridges;attempts.clear();selected.clear();removed=prune_connected(cycle,D,d,1,diag,selected,[&](const auto& a){attempts.push_back(a);});
 require(removed.empty() && diag.history.back().cached_skips>0,"all_protected_cache_termination");
 // High-score bridge at vertex 0 must not exhaust the budget before a lower
 // score vertex on a triangle can remove an edge. Edges not eligible remain.
 Edges lollipop{{0,1},{1,2},{1,3},{2,3}};Mat L(4,Vec(4,1));for(int i=0;i<4;++i)L[i][i]=0;
 L[0][1]=L[1][0]=5;L[2][3]=L[3][2]=2;
 d.stats={10,1,4,1};PruningDiagnostics other;selected.clear();attempts.clear();
 removed=prune_connected(lollipop,L,d,0,other,selected,[&](const auto& a){attempts.push_back(a);});
 require(removed==Edges{{2,3}} && other.history[0].bridge_skips==1 && selected==Ids{2},"skip_continue_budget");
 require(attempts[0].action=="new_bridge" && !attempts[0].conditions_tested,"bridge_first");
 Edges low{{0,1},{0,2},{1,2}};d.stats={1,1,1};PruningDiagnostics none;selected.clear();
 require(prune_connected(low,Mat(3,Vec(3,1)),d,0,none,selected).empty() && none.history[0].condition_rejections==3,"no_conditions_termination");
 auto disconnected=components(4,Edges{{0,1},{2,3}});require(*std::max_element(disconnected.begin(),disconnected.end())==1,"disconnected_detection");
 std::cout << ian::io::Json{{"exhaustive_bridge_checks",checks},{"sequential_cycle",true},{"cached_bridge",true},{"skipped_bridge_budget",true},{"lower_rank_candidate",true},{"no_removal",true},{"disconnected_detection",true}}.dump(2)<<'\n';
}
