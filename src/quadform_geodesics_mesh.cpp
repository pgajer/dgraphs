#include "quadform_geodesics_reference.h"
#include "vendor/geodesic/geodesic_algorithm_exact.h"
#include <algorithm>

namespace qgr {
MeshResult mesh_path(const std::vector<double>& vertices,const std::vector<unsigned>& faces,
  unsigned source,unsigned target,size_t max_propagations,size_t max_intervals,const std::function<void()>& poll){
  geodesic::Mesh mesh;poll();mesh.initialize_mesh_data(vertices,faces);
  geodesic::GeodesicAlgorithmExact algorithm(&mesh);
  algorithm.poll=poll;algorithm.max_propagations=max_propagations;algorithm.max_intervals=max_intervals;
  std::vector<geodesic::SurfacePoint> sources{geodesic::SurfacePoint(&mesh.vertices()[source])};
  geodesic::SurfacePoint end(&mesh.vertices()[target]);
  std::vector<geodesic::SurfacePoint> targets{end},path;
  algorithm.propagate(sources,geodesic::GEODESIC_INF,&targets);poll();
  MeshResult out;algorithm.best_source(end,out.distance);
  algorithm.trace_back(end,path);poll();
  if(path.empty()||out.distance>=geodesic::GEODESIC_INF/10)throw geodesic::Invariant("Empty mesh route");
  for(auto p:path)out.path.push_back({{p.x(),p.y(),p.z()}});
  std::reverse(out.path.begin(),out.path.end());
  out.propagations=algorithm.propagations();out.peak_intervals=algorithm.peak_intervals;
  return out;
}
}
