#ifndef GEOSMOOTH_QUADFORM_GEODESICS_METHODS_H
#define GEOSMOOTH_QUADFORM_GEODESICS_METHODS_H

#include "quadform_geodesics_solver.h"
#include <map>

namespace qgm {
struct Options {
  int nx = 33, ny = 33, directions = 2, attachments = 8;
  int iterations = 80, samples = 257, domain_depth = 16;
  double max_edges = 1000000, max_seconds = std::numeric_limits<double>::infinity();
  double angle_tolerance = 1e-12;
  bool direct = true, keep_graph = false;
};
struct Result {
  std::string status = "failed", termination, representation;
  double length = std::numeric_limits<double>::quiet_NaN();
  double error = std::numeric_limits<double>::quiet_NaN();
  qgn::Path path, vertices;
  std::vector<std::array<int,2>> edges;
  std::vector<double> weights;
  std::map<std::string,double> numbers, curve;
  std::map<std::string,std::string> labels;
};
Result grid(const std::array<double,4>& A, const qgn::Domain& domain,
            qgn::Point from, qgn::Point to, const Options& options);
Result clairaut(const std::array<double,4>& A, const qgn::Domain& domain,
                qgn::Point from, qgn::Point to, const Options& options);
} // namespace qgm
#endif
