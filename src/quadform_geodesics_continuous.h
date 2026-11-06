#ifndef DGRAPHS_QUADFORM_GEODESICS_CONTINUOUS_H
#define DGRAPHS_QUADFORM_GEODESICS_CONTINUOUS_H

#include "quadform_geodesics_methods.h"

namespace qgc {
struct Options {
  double ode_tolerance = 1e-6, integration_tolerance = 1e-10, endpoint_tolerance = 1e-8;
  double path_tolerance = 1e-7, max_seconds = std::numeric_limits<double>::infinity();
  int iterations = 30, continuation_steps = 8, continuation_attempts = 128;
  int initial_nodes = 17, max_nodes = 1025, max_path_vertices = 4097;
  int max_evaluations = 500000, domain_depth = 20;
  std::vector<double> bends{0,-1,1};
};
qgm::Result solve(const std::array<double,4>& A, const qgn::Domain& domain,
                  qgn::Point from, qgn::Point to, const Options& options, bool collocation);
}
#endif
