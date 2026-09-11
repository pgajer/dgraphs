#ifndef GEOSMOOTH_QUADFORM_GEODESICS_SOLVER_H
#define GEOSMOOTH_QUADFORM_GEODESICS_SOLVER_H

#include <array>
#include <cstdint>
#include <limits>
#include <string>
#include <vector>

namespace qgn {
using Point = std::array<double, 2>;
using Path = std::vector<Point>;
struct Measure { double length = 0, error = 0; bool ok = true; };
struct Domain {
  bool disk; Point center, lower, upper; double radius;
  bool inside(const Point& p) const;
};
struct Config {
  int initial_edges, candidates, max_epochs, plateau_epochs, max_vertices;
  int cache_edges, rejection_cap, trace_limit;
  double scale, max_edges, max_seconds;
  bool graph, trace, random_orientation; std::string neighborhood;
};
struct Counters {
  double requests = 0, hits = 0, calls = 0, evaluations = 0, evictions = 0;
  double candidate_draws = 0, order_draws = 0, attempts = 0;
  int accepted = 0, visits = 0, failures = 0, shortfalls = 0, vertex_rejections = 0;
};
struct Event {
  std::string kind; int epoch; Path path; std::vector<int> order, ids;
  double length, error, decrease, required;
};

struct Result {
  Path path, initial;
  std::vector<Event> events;
  Measure measure;
  Counters counts;
  bool initialized, reversed;
  int dropped, completed_epochs;
  double initial_length, initial_error, rho, elapsed_seconds;
  std::size_t cache_entries;
  std::string termination;
};
Result solve(const Config& config, const Domain& domain, const std::array<double,4>& A,
             std::uint64_t seed, const Point& from, const Point& to);
Measure connector_length(const std::array<double,4>& A, const Point& from, const Point& to);
std::array<std::vector<double>,2> reference_uniforms(std::uint64_t seed, int n);
} // namespace qgn

#endif
