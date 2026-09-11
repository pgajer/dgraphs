// Standalone component tests; compile with -I src and -I tests/stubs.
#include "quadform_geodesics_solver.cpp"
#include <cassert>
#include <iostream>
#include <set>
using namespace qgn;
Config config(bool graph) {
  return Config{4,1,3,4,257,0,1000,10000,1,inf,inf,graph,true,false,"fixed_span"};
}
int main() {
  Domain d{false,{{0,0}},{{-10,-10}},{{10,10}},10};
  for (bool graph : {false,true}) {
    Solver s(config(graph),d,{{1,0,0,1}},17);
    s.path = {{{-2,0}},{{0,0}},{{1,0}},{{0,0}},{{2,0}}};
    s.ids = {1,2,3,4,5}; s.next_id = 6; s.rho = 1;
    for (int j = 1; j < 5; ++j) s.segments.push_back(s.edge(s.path[j-1],s.path[j],false));
    s.window(2);
    assert(s.counts.accepted == 1);
    assert(std::set<int>(s.ids.begin(),s.ids.end()).size() == s.ids.size());
    assert(s.ids == (graph ? std::vector<int>{1,2,5} : std::vector<int>{1,2,4,5}));
    // Each surviving occurrence, including equal-coordinate endpoints, has
    // exactly one lookup in the following epoch's schedule.
    for (auto it = s.ids.begin()+1; it != s.ids.end()-1; ++it)
      assert(std::find(s.ids.begin(),s.ids.end(),*it) == it);
  }
  Path p{{{1,0}},{{2,0}},{{3,0}},{{4,0}}}; EdgeTable t(p);
  for (int i = 0; i < 4; ++i) for (int j = i+1; j < 4; ++j) t.add(i,j);
  t.order(); Batch values(t.edges.size(),{2,0,true});
  values[t.slot(0,1)].length = 1;
  values[t.slot(0,2)].length = .5-std::ldexp(1.,-54);
  values[t.slot(2,1)].length = .5;
  values[t.slot(1,3)].length = 3*std::ldexp(1.,-54);
  Solver s(config(true),d,{{0,0,0,0}},1);
  auto path = s.shortest(t,values,0,3);
  assert((path == IndexPath{0,2,1,3}));
  assert(Solver::measure(Solver::records(path,t,values)).length == 1);
  ExactLength a,b; a.add(1); b.add(.5); b.add(.5-std::ldexp(1.,-54));
  assert(a.rounded() == b.rounded() && a.compare(b) > 0);
  a.add(3*std::ldexp(1.,-54)); b.add(3*std::ldexp(1.,-54));
  assert(a.rounded() > b.rounded() && a.compare(b) > 0);
  assert(surface_height({{1,1,1,1+std::ldexp(1.,-52)}},{{1e16,-1e16}}) == 22204460492503132.);
  assert(surface_height({{1,1,1,1}},{{1e200,-1e200}}) == 0);
  assert(surface_height({{std::numeric_limits<double>::max(),0,0,0}},{{2,0}}) == inf);
  assert(surface_height({{std::ldexp(1.,-1074),0,0,0}},{{1,0}}) == std::ldexp(1.,-1074));
  assert(surface_height({{std::ldexp(1.,-1074),0,0,0}},{{.5,0}}) == 0);
  std::cout << "Occurrence IDs, rounded-prefix graph counterexample, exact heights and boundaries passed.\n";
}
