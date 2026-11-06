#include "quadform_geodesics_solver.h"
#include "quadform_geodesics_exact.h"
#include <Rcpp.h>
#include <algorithm>
#include <cmath>

namespace qgn {
Point point(Rcpp::NumericVector x, const char* name) {
  if (x.size() != 2 || !std::isfinite(x[0]) || !std::isfinite(x[1]))
    Rcpp::stop("%s must contain two finite coordinates",name);
  return {{x[0],x[1]}};
}
double scalar(Rcpp::List x, const char* name, double lower, double upper, bool integer = false) {
  Rcpp::NumericVector v = Rcpp::as<Rcpp::NumericVector>(x[name]);
  if (v.size() != 1 || std::isnan(v[0]) || v[0] < lower || v[0] > upper ||
      (integer && (!std::isfinite(v[0]) || std::floor(v[0]) != v[0]))) Rcpp::stop("Invalid %s",name);
  return v[0];
}
bool flag(Rcpp::List x, const char* name) {
  Rcpp::LogicalVector v = x[name];
  if (v.size() != 1 || v[0] == NA_LOGICAL) Rcpp::stop("Invalid %s",name);
  return v[0];
}
Rcpp::NumericMatrix matrix(Path p, bool reverse = false) {
  if (reverse) std::reverse(p.begin(),p.end());
  Rcpp::NumericMatrix out(p.size(),2);
  for (size_t i = 0; i < p.size(); ++i) { out(i,0) = p[i][0]; out(i,1) = p[i][1]; } return out;
}
} // namespace qgn

//' @keywords internal
//' @noRd
// [[Rcpp::export(rng = false)]]
Rcpp::List rcpp_quadform_geodesics_solver(Rcpp::NumericMatrix A, Rcpp::NumericVector from, Rcpp::NumericVector to,
                     Rcpp::List domain, Rcpp::List options) {
  using namespace qgn;
  if (A.nrow() != 2 || A.ncol() != 2) Rcpp::stop("A must be a symmetric 2 by 2 matrix");
  for (double v : A) if (!std::isfinite(v)) Rcpp::stop("A must be finite");
  if (A(0,1) != A(1,0)) Rcpp::stop("A must be symmetric");
  std::array<double,4> a = {{A(0,0),A(0,1),A(1,0),A(1,1)}};
  Point u = point(from,"from"), v = point(to,"to");
  Domain d{}; std::string kind = Rcpp::as<std::string>(domain["kind"]);
  if (kind == "ball") { d.disk = true; d.center = point(domain["center"],"center");
    d.radius = scalar(domain,"radius",std::numeric_limits<double>::min(),1e150); }
  else if (kind == "box") { d.disk = false; d.lower = point(domain["lower"],"lower");
    d.upper = point(domain["upper"],"upper");
    for (int j = 0; j < 2; ++j) if (!(d.lower[j] < d.upper[j]) || !std::isfinite(d.upper[j]-d.lower[j]))
      Rcpp::stop("Box bounds must have finite positive width");
  } else Rcpp::stop("domain kind must be ball or box");
  if (!d.inside(u) || !d.inside(v)) Rcpp::stop("Endpoints must be inside the domain");
  Config c;
  c.initial_edges = scalar(options,"initial_edges",2,256,true);
  c.candidates = scalar(options,"candidates",1,256,true);
  c.max_epochs = scalar(options,"max_epochs",0,100000,true);
  c.plateau_epochs = scalar(options,"plateau_epochs",1,100001,true);
  c.max_vertices = scalar(options,"max_vertices",3,257,true);
  if (c.max_vertices < c.initial_edges+1) Rcpp::stop("max_vertices must exceed initial_edges");
  c.cache_edges = scalar(options,"cache_edges",0,65536,true);
  c.rejection_cap = scalar(options,"rejection_cap",1,10000,true);
  c.trace_limit = scalar(options,"trace_limit",0,10000,true);
  c.scale = scalar(options,"length_scale",1e-150,1e150);
  c.max_edges = scalar(options,"max_edge_calls",0,std::numeric_limits<double>::infinity());
  if (std::isfinite(c.max_edges) && std::floor(c.max_edges) != c.max_edges) Rcpp::stop("Invalid max_edge_calls");
  c.max_seconds = scalar(options,"max_seconds",0,std::numeric_limits<double>::infinity());
  c.trace = flag(options,"trace"); c.random_orientation = flag(options,"random_orientation");
  std::string method = Rcpp::as<std::string>(options["method"]);
  if (method != "single_point" && method != "local_network") Rcpp::stop("Unknown method");
  c.graph = method == "local_network";
  c.neighborhood = Rcpp::as<std::string>(options["neighborhood"]);
  if (c.neighborhood != "neighbors" && c.neighborhood != "fixed_disk" && c.neighborhood != "fixed_span")
    Rcpp::stop("Unknown neighborhood");
  double seed = scalar(options,"seed",0,4294967295.0,true);
  Result s = solve(c,d,a,static_cast<uint64_t>(seed),u,v);
  Measure m = s.measure;
  Rcpp::List trace(s.events.size());
  for (size_t i = 0; i < s.events.size(); ++i) {
    const Event& e = s.events[i];
    std::vector<int> path_ids = e.ids;
    if (s.reversed) std::reverse(path_ids.begin(),path_ids.end());
    trace[i] = Rcpp::List::create(Rcpp::_ ["event"] = e.kind,Rcpp::_ ["epoch"] = e.epoch,
      Rcpp::_ ["path"] = matrix(e.path,s.reversed),Rcpp::_ ["length"] = e.length,
      Rcpp::_ ["error_estimate"] = e.error,Rcpp::_ ["visit_ids"] = e.order,
      Rcpp::_ ["path_ids"] = path_ids,
      Rcpp::_ ["decrease"] = e.decrease,Rcpp::_ ["required_decrease"] = e.required);
  }
  Rcpp::NumericMatrix lifted(s.path.size(),3); Path p = s.path;
  if (s.reversed) std::reverse(p.begin(),p.end());
  for (size_t i = 0; i < p.size(); ++i) {
    lifted(i,0) = p[i][0]; lifted(i,1) = p[i][1];
    lifted(i,2) = surface_height(a,p[i]);
    if (!std::isfinite(lifted(i,2))) Rcpp::stop("Surface height overflow at returned point");
  }
  const Counters& n = s.counts;
  return Rcpp::List::create(
    Rcpp::_ ["implementation"] = "self-contained-cpp-analytic-v3",
    Rcpp::_ ["status"] = s.path.empty() ? "no_path" : (s.initialized ? "candidate" : "direct_fallback"),
    Rcpp::_ ["termination"] = s.termination,Rcpp::_ ["path"] = matrix(s.path,s.reversed),
    Rcpp::_ ["surface_path"] = lifted,Rcpp::_ ["length"] = s.path.empty() ? NA_REAL : m.length,
    Rcpp::_ ["error_estimate"] = s.path.empty() ? NA_REAL : m.error,
    Rcpp::_ ["initial_path"] = matrix(s.initial,s.reversed),Rcpp::_ ["initial_length"] = s.initial_length,
    Rcpp::_ ["initial_error_estimate"] = s.initial_error,Rcpp::_ ["reference_radius"] = s.rho,
    Rcpp::_ ["configuration"] = options,Rcpp::_ ["internal_orientation_reversed"] = s.reversed,
    Rcpp::_ ["random_generator"] = "mt19937_64-splitmix64-labelled-v1",
    Rcpp::_ ["counters"] = Rcpp::List::create(Rcpp::_ ["edge_requests"] = n.requests,
      Rcpp::_ ["edge_calls"] = n.calls,Rcpp::_ ["cache_hits"] = n.hits,
      Rcpp::_ ["cache_entries"] = s.cache_entries,Rcpp::_ ["cache_evictions"] = n.evictions,
      Rcpp::_ ["integrand_evaluations"] = n.evaluations,Rcpp::_ ["candidate_uniforms"] = n.candidate_draws,
      Rcpp::_ ["order_uniforms"] = n.order_draws,Rcpp::_ ["sampling_attempts"] = n.attempts,
      Rcpp::_ ["accepted_replacements"] = n.accepted,Rcpp::_ ["visited_points"] = n.visits,
      Rcpp::_ ["completed_epochs"] = s.completed_epochs,Rcpp::_ ["failed_windows"] = n.failures,
      Rcpp::_ ["sampling_shortfalls"] = n.shortfalls,Rcpp::_ ["vertex_limit_rejections"] = n.vertex_rejections,
      Rcpp::_ ["elapsed_seconds"] = s.elapsed_seconds),
    Rcpp::_ ["trace"] = trace,Rcpp::_ ["trace_truncated"] = s.dropped > 0,
    Rcpp::_ ["trace_events_omitted"] = s.dropped,Rcpp::_ ["state_saving"] = false);
}

// Internal test helper: supplies identical random streams to the R reference.
//' @keywords internal
//' @noRd
// [[Rcpp::export(rng = false)]]
Rcpp::List rcpp_quadform_geodesics_reference_uniforms(double seed, int n) {
  if (!std::isfinite(seed) || seed < 0 || seed > 4294967295.0 || std::floor(seed) != seed || n < 0 || n > 1000000)
    Rcpp::stop("Invalid test stream request");
  auto draws = qgn::reference_uniforms(static_cast<std::uint64_t>(seed),n);
  return Rcpp::List::create(Rcpp::_["candidates"] = draws[0],Rcpp::_["order"] = draws[1]);
}
