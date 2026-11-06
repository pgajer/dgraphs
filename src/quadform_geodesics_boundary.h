#ifndef DGRAPHS_QUADFORM_GEODESICS_BOUNDARY_H
#define DGRAPHS_QUADFORM_GEODESICS_BOUNDARY_H
#include "quadform_geodesics_methods.h"
namespace qgb {
struct Options {
  int initial_edges=8, levels=2, evaluations_per_start=2000, max_evaluations=20000;
  double position_tolerance=1e-6, initial_step=.05;
  double max_seconds=std::numeric_limits<double>::infinity();
  std::vector<double> bends{0,-.5,.5};
  qgn::Path initial_path;
};
qgm::Result solve(const std::array<double,4>&,const qgn::Domain&,
                  qgn::Point,qgn::Point,const Options&);
}
#endif
