// Computational core: no R-level callbacks, Python, checkpointing or file I/O.
#include "quadform_geodesics_solver.h"
#include "quadform_geodesics_exact.h"
#include <Rcpp.h>
#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <list>
#include <map>
#include <random>
#include <unordered_map>
#include <vector>

namespace qgn {
using Clock = std::chrono::steady_clock;
const double inf = std::numeric_limits<double>::infinity();
struct Stop { std::string reason; };
double sum(const std::vector<double>& x) {
  ExactLength total;
  for (double v : x) { if (!std::isfinite(v)) return v; total.add(v); }
  return total.rounded();
}
double norm(const Point& x) {
  double m = std::max(std::abs(x[0]), std::abs(x[1]));
  if (m == 0) return 0;
  double a = x[0] / m, b = x[1] / m;
  return m * std::sqrt(static_cast<double>(static_cast<long double>(a*a) + b*b));
}
Point minus(const Point& a, const Point& b) { return {{a[0]-b[0], a[1]-b[1]}}; }
using PointKey = std::array<uint64_t,2>;
using EdgeKey = std::array<PointKey,2>;
using IndexPath = std::vector<int>;
// Unsigned bit order is the old fixed-width hexadecimal order, including -0.
PointKey key(const Point& p) {
  PointKey out;
  static_assert(sizeof(double) == sizeof(uint64_t), "64-bit coordinates required");
  for (size_t j = 0; j < 2; ++j) std::memcpy(&out[j], &p[j], sizeof(double));
  return out;
}
uint64_t mix(uint64_t x) {
  x += UINT64_C(0x9e3779b97f4a7c15);
  x = (x ^ (x >> 30)) * UINT64_C(0xbf58476d1ce4e5b9);
  x = (x ^ (x >> 27)) * UINT64_C(0x94d049bb133111eb);
  return x ^ (x >> 31);
}
struct EdgeHash {
  size_t operator()(const EdgeKey& k) const {
    uint64_t h = 0;
    for (const auto& p : k) for (auto word : p) h = mix(h ^ word);
    return static_cast<size_t>(h);
  }
};
// Local vertices have key-sorted indices. Edges are measured in lexicographic
// endpoint order; an indexed table then serves all path and graph lookups.
struct EdgeTable {
  Path vertices; std::vector<PointKey> keys;
  std::vector<std::array<int,2>> edges;
  std::vector<int> slots;
  EdgeTable(const Path& old, const Path& candidates = {}) {
    std::map<PointKey,Point> unique;
    for (const auto& p : old) unique.emplace(key(p),p);
    for (const auto& p : candidates) unique.emplace(key(p),p);
    for (const auto& p : unique) { keys.push_back(p.first); vertices.push_back(p.second); }
    slots.assign(vertices.size()*vertices.size(),-1);
  }
  IndexPath indices(const Path& path) const {
    IndexPath out; out.reserve(path.size());
    for (const auto& p : path) {
      auto k = key(p); auto it = std::lower_bound(keys.begin(),keys.end(),k);
      if (it == keys.end() || *it != k) Rcpp::stop("Unknown local vertex");
      out.push_back(static_cast<int>(it-keys.begin()));
    }
    return out;
  }
  void add(int a, int b) {
    if (a > b) std::swap(a,b);
    size_t slot = static_cast<size_t>(a)*vertices.size()+b;
    if (slots[slot] < 0) { slots[slot] = 0; edges.push_back({{a,b}}); }
  }
  void addpath(const IndexPath& path) {
    for (size_t j = 1; j < path.size(); ++j) add(path[j-1],path[j]);
  }
  void order() {
    std::sort(edges.begin(),edges.end());
    for (size_t j = 0; j < edges.size(); ++j) {
      int a = edges[j][0], b = edges[j][1];
      slots[static_cast<size_t>(a)*vertices.size()+b] = static_cast<int>(j);
      slots[static_cast<size_t>(b)*vertices.size()+a] = static_cast<int>(j);
    }
  }
  size_t slot(int a, int b) const {
    int index = slots[static_cast<size_t>(a)*vertices.size()+b];
    if (index < 0) Rcpp::stop("Missing local edge");
    return static_cast<size_t>(index);
  }
  Path points(const IndexPath& path) const {
    Path out; out.reserve(path.size());
    for (int j : path) out.push_back(vertices[j]);
    return out;
  }
};
struct Streams {
  std::mt19937_64 candidates, order, orientation;
  explicit Streams(uint64_t seed) : candidates(mix(seed)), order(mix(seed + UINT64_C(4294967296))),
    orientation(mix(seed + UINT64_C(8589934592))) {}
  static double uniform(std::mt19937_64& g) { return (g() >> 11) * (1.0/9007199254740992.0); }
};
bool Domain::inside(const Point& p) const {
  if (!std::isfinite(p[0]) || !std::isfinite(p[1])) return false;
  return disk ? norm(minus(p, center)) <= radius :
    p[0] >= lower[0] && p[0] <= upper[0] && p[1] >= lower[1] && p[1] <= upper[1];
}
struct CacheEntry {
  Measure values[2]; bool present[2] = {false, false}; std::list<EdgeKey>::iterator position;
};
// Average of hypot(c,x) on [q,r], 0 <= q <= r, with scaled arguments.
// Rationalize r*hypot(c,r)-q*hypot(c,q), and use log1p(x)/x for
// the asinh divided difference. Neither term subtracts nearby primitives.
long double positive_mean(long double c, long double q, long double r) {
  if (q == r) return std::hypot(c,q);
  long double s = std::hypot(c,q), t = std::hypot(c,r);
  long double ratio = (q+r)/(s+t);
  long double x = ((r-q)/(q+s))*(1+ratio);
  long double logarithm = x == 0 ? 1 : std::log1p(x)/x;
  return (t + q*ratio + c*(c/(q+s))*(1+ratio)*logarithm)/2;
}

Measure connector_length(const std::array<double,4>& A, const Point& a, const Point& b) {
  Measure out;
  if (a == b) return out;
  using Real = long double;
  const Real eps = std::numeric_limits<Real>::epsilon();
  const Real tiny = std::numeric_limits<Real>::denorm_min();
  std::array<Real,2> h, eh, ah, eah;
  for (int j = 0; j < 2; ++j) {
    h[j] = static_cast<Real>(b[j])-static_cast<Real>(a[j]);
    eh[j] = eps*std::abs(h[j])+tiny;
  }
  Real c = std::hypot(h[0],h[1]);
  Real ec = 4*eps*c+std::hypot(eh[0],eh[1])+tiny;
  for (int i = 0; i < 2; ++i) {
    Real x = static_cast<Real>(A[2*i])*h[0], y = static_cast<Real>(A[2*i+1])*h[1];
    ah[i] = x+y;
    eah[i] = 8*eps*(std::abs(x)+std::abs(y))+
      std::abs(static_cast<Real>(A[2*i]))*eh[0]+
      std::abs(static_cast<Real>(A[2*i+1]))*eh[1]+4*tiny;
  }
  auto slope = [&](const Point& p, Real& error) {
    Real x = static_cast<Real>(p[0])*ah[0], y = static_cast<Real>(p[1])*ah[1];
    error = 16*eps*(std::abs(x)+std::abs(y))+
      2*(std::abs(static_cast<Real>(p[0]))*eah[0]+
         std::abs(static_cast<Real>(p[1]))*eah[1])+8*tiny;
    return 2*(x+y);
  };
  // Evaluate both endpoint slopes directly: alpha+beta can cancel severely.
  Real e0, e1, v0 = slope(a,e0), v1 = slope(b,e1);
  Real scale = std::max(c,std::max(std::abs(v0),std::abs(v1)));
  if (!(scale > 0) || !std::isfinite(scale) || !std::isfinite(ec) ||
      !std::isfinite(e0) || !std::isfinite(e1)) { out.ok = false; return out; }
  Real cn = c/scale, q = std::abs(v0)/scale, r = std::abs(v1)/scale;
  bool crossing = (v0 < 0) != (v1 < 0);
  Real mean, omitted = 0;
  if (cn <= eps) {
    // |hypot(c,x)-|x|| <= c. Avoid extreme ratios and account for
    // the omitted horizontal contribution explicitly in the error estimate.
    mean = crossing ? (q*q+r*r)/(2*(q+r)) : (q+r)/2;
    omitted = c;
  } else if (crossing) {
    Real weight = q/(q+r);
    mean = weight*positive_mean(cn,0,q)+(1-weight)*positive_mean(cn,0,r);
  } else {
    mean = positive_mean(cn,std::min(q,r),std::max(q,r));
  }
  Real length = scale*mean;
  // The norm is 1-Lipschitz in c and in the linearly interpolated slope.
  // This propagates cancellation-sensitive coefficient errors, in addition
  // to a conservative operation/libm allowance and the final double cast.
  Real error = ec+e0/2+e1/2+omitted+64*eps*length+
    2*std::numeric_limits<double>::epsilon()*length+64*tiny;
  out.length = static_cast<double>(length);
  out.error = std::nextafter(static_cast<double>(error),inf);
  out.ok = std::isfinite(out.length) && out.length > 0 &&
    std::isfinite(out.error) && out.error >= 0;
  return out;
}
using Batch = std::vector<Measure>;
class Solver {
public:
  Config c; Domain domain; std::array<double,4> A; Streams rng; Counters counts;
  Path path, initial; std::vector<Measure> segments; std::vector<int> ids;
  std::vector<Event> events; int dropped = 0, epoch = 0, completed_epochs = 0, next_id = 1;
  double rho = 0, initial_length = std::numeric_limits<double>::quiet_NaN(), initial_error = std::numeric_limits<double>::quiet_NaN();
  bool initialized = false, reversed = false;
  std::string termination = "epoch_limit";
  Clock::time_point start;
  std::unordered_map<EdgeKey, CacheEntry, EdgeHash> cache; std::list<EdgeKey> lru;
  Solver(Config config, Domain d, std::array<double,4> a, uint64_t seed) :
    c(config), domain(d), A(a), rng(seed), start(Clock::now()) {}
  double seconds() const { return std::chrono::duration<double>(Clock::now()-start).count(); }
  void poll() {
    if (seconds() >= c.max_seconds) throw Stop{"time_limit"};
    Rcpp::checkUserInterrupt();
  }
  Measure integrate(Point a, Point b, bool /* tighter */) {
    poll(); if (counts.calls >= c.max_edges) throw Stop{"edge_limit"};
    ++counts.calls;
    // Both legacy precision levels use the same analytic calculation. A retry
    // cannot reduce roundoff; an unresolved replacement remains unaccepted.
    Measure out = connector_length(A,a,b);
    poll(); return out;
  }
  Measure edge(Point a, Point b, bool tighter) {
    auto ka = key(a), kb = key(b);
    if (kb < ka) { std::swap(a,b); std::swap(ka,kb); }
    return measured_edge(a,b,{{ka,kb}},tighter);
  }
  Measure measured_edge(Point a, Point b, const EdgeKey& k, bool tighter) {
    poll(); ++counts.requests;
    auto it = cache.find(k); int level = tighter ? 1 : 0;
    if (it != cache.end()) {
      lru.splice(lru.begin(), lru, it->second.position);
      CacheEntry& e = it->second;
      if (!tighter && e.present[1] && e.values[1].ok) { ++counts.hits; return e.values[1]; }
      if (e.present[level]) { ++counts.hits; return e.values[level]; }
    }
    Measure out = integrate(a,b,tighter);
    if (c.cache_edges == 0) return out;
    if (it == cache.end()) {
      if (cache.size() >= static_cast<size_t>(c.cache_edges)) {
        cache.erase(lru.back()); lru.pop_back(); ++counts.evictions;
      }
      lru.push_front(k); CacheEntry entry; entry.position = lru.begin();
      it = cache.emplace(k,entry).first;
    }
    it->second.values[level] = out; it->second.present[level] = true; return out;
  }
  Batch batch(const EdgeTable& table, bool tighter, bool& ok) {
    Batch out; out.reserve(table.edges.size()); ok = true;
    for (const auto& e : table.edges) {
      Measure m = measured_edge(table.vertices[e[0]],table.vertices[e[1]],
        {{table.keys[e[0]],table.keys[e[1]]}},tighter);
      ok = ok && m.ok; out.push_back(m);
    }
    return out;
  }
  static std::vector<Measure> records(const IndexPath& p, const EdgeTable& table, const Batch& b) {
    std::vector<Measure> out;
    out.reserve(p.size() > 0 ? p.size()-1 : 0);
    for (size_t i = 1; i < p.size(); ++i) out.push_back(b[table.slot(p[i-1],p[i])]);
    return out;
  }
  static Measure measure(const std::vector<Measure>& r) {
    std::vector<double> lengths, errors; Measure out;
    for (const auto& m : r) { lengths.push_back(m.length); errors.push_back(m.error); out.ok &= m.ok; }
    out.length = sum(lengths); out.error = sum(errors);
    out.ok = out.ok && std::isfinite(out.length) && std::isfinite(out.error); return out;
  }
  void record(const std::string& kind, double decrease = std::numeric_limits<double>::quiet_NaN(), double required = std::numeric_limits<double>::quiet_NaN(),
              const std::vector<int>& order = {}) {
    if (!c.trace) return;
    if (events.size() >= static_cast<size_t>(c.trace_limit)) { ++dropped; return; }
    Measure m = measure(segments);
    events.push_back(Event{kind,epoch,path,order,ids,m.length,m.error,decrease,required});
  }
  void initialize(Point from, Point to) {
    reversed = c.random_orientation && Streams::uniform(rng.orientation) < .5;
    if (reversed) std::swap(from,to);
    Measure total = edge(from,to,true);
    if (!total.ok) throw Stop{"initialization_numerical_failure"};
    path = {from,to}; segments = {total}; ids = {1,2}; next_id = 3;
    record("direct_path");
    if (from == to) { initialized = true; initial = path;
      initial_length = total.length; initial_error = total.error; return; }
    bool reverse = key(to) < key(from); Point a = reverse ? to : from, b = reverse ? from : to;
    Path proposed = {a};
    double tolerance = std::min(1e-10*c.scale + 1e-8*total.length/c.initial_edges,
                                1e-6*total.length/c.initial_edges);
    double roundoff = 64*std::numeric_limits<double>::epsilon()*total.length;
    for (int j = 1; j < c.initial_edges; ++j) {
      double fraction = static_cast<double>(j)/c.initial_edges, lo = 0, hi = 1;
      bool resolved = false;
      for (int k = 0; k < 64; ++k) {
        double t = lo+(hi-lo)/2;
        if (t == lo || t == hi) break;
        Point p = {{a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1])}};
        if (!domain.inside(p)) throw Stop{"initialization_unrepresentable"};
        Measure m = edge(a,p,true);
        if (!m.ok) throw Stop{"initialization_numerical_failure"};
        if (std::abs(m.length-fraction*total.length)+m.error+fraction*total.error+roundoff <= tolerance) {
          proposed.push_back(p); resolved = true; break;
        }
        if (m.length < fraction*total.length) lo = t; else hi = t;
      }
      if (!resolved) throw Stop{"initialization_unresolved"};
    }
    proposed.push_back(b); if (reverse) std::reverse(proposed.begin(),proposed.end());
    EdgeTable table(proposed); auto proposed_ids = table.indices(proposed);
    table.edges.reserve(proposed.size()-1);
    table.addpath(proposed_ids); table.order(); bool ok;
    Batch values = batch(table,true,ok);
    if (!ok) throw Stop{"initialization_numerical_failure"};
    auto r = records(proposed_ids,table,values); Measure m = measure(r);
    for (int i = 0; i < c.initial_edges; ++i) {
      if (proposed[i] == proposed[i+1] ||
          std::abs(r[i].length-total.length/c.initial_edges)+r[i].error+total.error/c.initial_edges >
            2*tolerance+roundoff) throw Stop{"initialization_spacing_failure"};
    }
    if (!m.ok || std::abs(m.length-total.length) > m.error+total.error+(c.initial_edges+1)*roundoff)
      throw Stop{"initialization_additivity_failure"};
    path = proposed; segments = r; ids.clear(); next_id = 1;
    for (size_t i = 0; i < path.size(); ++i) ids.push_back(next_id++);
    for (size_t i = 1; i < path.size(); ++i) rho = std::max(rho,norm(minus(path[i],path[i-1])));
    initialized = true; initial = path; initial_length = m.length; initial_error = m.error;
    record("initializer");
  }
  bool sample(const Point& anchor, double radius, Path& candidates) {
    if (!std::isfinite(radius) || radius <= 0) { ++counts.shortfalls; return false; }
    std::map<PointKey,Point> unique;
    for (int j = 0; j < c.candidates; ++j) {
      bool accepted = false;
      for (int attempt = 0; attempt < c.rejection_cap; ++attempt) {
        poll(); ++counts.attempts;
        double angle = 2*std::acos(-1.0)*Streams::uniform(rng.candidates);
        double r = radius*std::sqrt(Streams::uniform(rng.candidates)); counts.candidate_draws += 2;
        Point p = {{anchor[0]+r*std::cos(angle),anchor[1]+r*std::sin(angle)}};
        if (domain.inside(p)) { unique.emplace(key(p),p); accepted = true; break; }
      }
      if (!accepted) { ++counts.shortfalls; return false; }
    }
    for (const auto& v : unique) candidates.push_back(v.second); return true;
  }
  IndexPath shortest(const EdgeTable& table, const Batch& values, int from, int to) {
    size_t n = table.vertices.size();
    std::vector<ExactLength> dist(n); std::vector<bool> done(n,false), reached(n,false);
    std::vector<IndexPath> paths(n);
    reached[from] = true; paths[from] = {from};
    for (size_t step = 0; step < n; ++step) {
      poll(); size_t u = n;
      for (size_t v = 0; v < n; ++v) if (!done[v] && reached[v] &&
          (u == n || dist[v].compare(dist[u]) < 0 ||
           (dist[v].compare(dist[u]) == 0 && paths[v] < paths[u]))) u = v;
      if (u == n) break; if (u == static_cast<size_t>(to)) return paths[u]; done[u] = true;
      for (size_t v = 0; v < n; ++v) if (!done[v] && table.vertices[u] != table.vertices[v]) {
        double w = values[table.slot(u,v)].length; if (w == 0) continue;
        ExactLength d = dist[u]; d.add(w);
        IndexPath proposed_path = paths[u]; proposed_path.push_back(static_cast<int>(v));
        if (!reached[v] || d.compare(dist[v]) < 0 || (d.compare(dist[v]) == 0 && proposed_path < paths[v])) {
          dist[v] = d; reached[v] = true; paths[v] = std::move(proposed_path);
        }
      }
    }
    return {};
  }
  void window(int i) {
    ++counts.visits; int lo = i-1, hi = i+1;
    if (c.neighborhood == "fixed_span") {
      lo = hi = i; double left = 0, right = 0;
      while (lo > 0 && left < rho) { left += norm(minus(path[lo],path[lo-1])); --lo; }
      while (hi+1 < static_cast<int>(path.size()) && right < rho) {
        right += norm(minus(path[hi+1],path[hi])); ++hi; }
    }
    double radius = c.neighborhood == "neighbors" ?
      std::max(norm(minus(path[i],path[lo])),norm(minus(path[i],path[hi]))) : rho;
    Path old(path.begin()+lo,path.begin()+hi+1), candidates;
    if (!sample(path[i],radius,candidates)) return;
    EdgeTable table(old,candidates); auto old_indices = table.indices(old);
    table.edges.reserve(c.graph ? table.vertices.size()*(table.vertices.size()-1)/2 :
      old.size()+2*candidates.size());
    table.addpath(old_indices); std::vector<IndexPath> alternatives;
    if (c.graph) {
      for (size_t j = 0; j < table.vertices.size(); ++j) {
        poll(); for (size_t k = j+1; k < table.vertices.size(); ++k)
          if (table.vertices[j] != table.vertices[k]) table.add(j,k);
      }
    } else {
      alternatives.push_back({old_indices.front(),old_indices.back()});
      for (int p : table.indices(candidates))
        if (table.vertices[p] != old.front() && table.vertices[p] != old.back())
          alternatives.push_back({old_indices.front(),p,old_indices.back()});
      for (const auto& p : alternatives) table.addpath(p);
    }
    table.order();
    bool tighter = false, ok; Batch values = batch(table,false,ok);
    if (!ok) { tighter = true; values = batch(table,true,ok); }
    if (!ok) { ++counts.failures; return; }
    IndexPath best; Measure previous, chosen; double delta = 0, required = 0;
    for (;;) {
      previous = measure(records(old_indices,table,values)); best = old_indices; chosen = previous;
      if (c.graph) {
        IndexPath p = shortest(table,values,old_indices.front(),old_indices.back());
        if (!p.empty()) { Measure m = measure(records(p,table,values));
          if (m.length < chosen.length) { best = p; chosen = m; } }
      } else {
        bool incumbent = true;
        for (const auto& p : alternatives) { Measure m = measure(records(p,table,values));
          if (m.length < chosen.length || (!incumbent && m.length == chosen.length && p < best)) {
            best = p; chosen = m; incumbent = false; }
        }
      }
      double margin = 1e-12*c.scale + 1e-10*previous.length;
      delta = previous.length-chosen.length; required = margin+previous.error+chosen.error;
      if (!(previous.ok && chosen.ok)) { ++counts.failures; return; }
      if (delta > margin && delta <= required && !tighter) {
        tighter = true; values = batch(table,true,ok);
        if (!ok) { ++counts.failures; return; } continue;
      }
      break;
    }
    if (!(delta > required)) return;
    if (path.size() - old.size() + best.size() > static_cast<size_t>(c.max_vertices)) {
      ++counts.vertex_rejections; return;
    }
    Path best_points = table.points(best);
    Path proposed(path.begin(),path.begin()+lo); proposed.insert(proposed.end(),best_points.begin(),best_points.end());
    proposed.insert(proposed.end(),path.begin()+hi+1,path.end());
    auto middle = records(best,table,values);
    std::vector<Measure> new_segments(segments.begin(),segments.begin()+lo);
    new_segments.insert(new_segments.end(),middle.begin(),middle.end());
    new_segments.insert(new_segments.end(),segments.begin()+hi,segments.end());
    if (!measure(new_segments).ok) { ++counts.failures; return; }
    std::vector<int> new_ids(ids.begin(),ids.begin()+lo); int new_next_id = next_id;
    std::vector<bool> used(old.size(),false);
    for (size_t k = 0; k < best.size(); ++k) {
      int id = 0;
      // Endpoints are occurrences, not coordinate keys. A collapsed one-point
      // connector keeps the left occurrence; two endpoints keep both IDs.
      if (k == 0) { id = ids[lo]; used.front() = true; }
      else if (k+1 == best.size()) { id = ids[hi]; used.back() = true; }
      else for (int j = lo+1; j < hi; ++j)
        if (!used[j-lo] && old_indices[j-lo] == best[k]) {
          id = ids[j]; used[j-lo] = true; break;
        }
      new_ids.push_back(id == 0 ? new_next_id++ : id);
    }
    new_ids.insert(new_ids.end(),ids.begin()+hi+1,ids.end());
    poll(); path.swap(proposed); segments.swap(new_segments); ids.swap(new_ids); next_id = new_next_id;
    ++counts.accepted; record("replacement",delta,required);
  }
  void solve(Point from, Point to) {
    try {
      initialize(from,to); if (from == to) { termination = "identity"; return; }
      int plateau = 0; bool incomplete_plateau = false;
      for (epoch = 1; epoch <= c.max_epochs; ++epoch) {
        poll(); std::vector<int> order(ids.begin()+1,ids.end()-1);
        for (size_t k = order.size(); k > 1; --k) {
          uint64_t limit = (UINT64_C(4294967296)/k)*k; bool accepted = false;
          for (int attempt = 0; attempt < c.rejection_cap; ++attempt) {
            poll(); ++counts.order_draws;
            uint64_t x = static_cast<uint64_t>(Streams::uniform(rng.order)*4294967296.0);
            if (x < limit) { std::swap(order[k-1],order[x%k]); accepted = true; break; }
          }
          if (!accepted) throw Stop{"order_sampling_failure"};
        }
        int shortfalls_before = counts.shortfalls, failures_before = counts.failures;
        record("epoch_order",std::numeric_limits<double>::quiet_NaN(),std::numeric_limits<double>::quiet_NaN(),order); double start_length = measure(segments).length;
        for (int id : order) {
          poll(); auto it = std::find(ids.begin(),ids.end(),id);
          if (it != ids.end() && it != ids.begin() && it+1 != ids.end()) window(it-ids.begin());
        }
        double decrease = (start_length-measure(segments).length)/std::max(start_length,1e-12*c.scale);
        ++completed_epochs; record("epoch_end"); plateau = decrease < 1e-5 ? plateau+1 : 0;
        if (plateau == 0) incomplete_plateau = false;
        else incomplete_plateau |= counts.shortfalls > shortfalls_before || counts.failures > failures_before;
        if (plateau >= c.plateau_epochs) {
          termination = incomplete_plateau ? "incomplete_exploration" : "local_stagnation"; break;
        }
      }
    } catch (const Stop& s) { termination = s.reason; }
  }
};
Result solve(const Config& config, const Domain& domain, const std::array<double,4>& A,
             std::uint64_t seed, const Point& from, const Point& to) {
  Solver s(config,domain,A,seed);
  s.solve(from,to);
  Result result;
  result.measure = Solver::measure(s.segments);
  result.counts = s.counts;
  result.initialized = s.initialized; result.reversed = s.reversed;
  result.dropped = s.dropped; result.completed_epochs = s.completed_epochs;
  result.initial_length = s.initial_length; result.initial_error = s.initial_error;
  result.rho = s.rho; result.elapsed_seconds = s.seconds();
  result.cache_entries = s.cache.size(); result.termination = s.termination;
  result.path = std::move(s.path); result.initial = std::move(s.initial);
  result.events = std::move(s.events);
  return result;
}

std::array<std::vector<double>,2> reference_uniforms(std::uint64_t seed, int n) {
  Streams streams(seed);
  std::array<std::vector<double>,2> out;
  out[0].resize(n); out[1].resize(n);
  for (int i = 0; i < n; ++i) {
    out[0][i] = Streams::uniform(streams.candidates);
    out[1][i] = Streams::uniform(streams.order);
  }
  return out;
}
} // namespace qgn
