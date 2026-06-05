#include <Rcpp.h>

#include <algorithm>
#include <cmath>
#include <limits>
#include <numeric>
#include <queue>
#include <string>
#include <utility>
#include <vector>

#ifdef _OPENMP
#include <omp.h>
#endif

using Rcpp::IntegerMatrix;
using Rcpp::List;
using Rcpp::LogicalMatrix;
using Rcpp::Named;
using Rcpp::NumericMatrix;
using Rcpp::NumericVector;

namespace {

constexpr double kTol = 1e-12;

struct NeighborEntry {
  int vertex;
  double distance;
};

struct MetricResult {
  bool usable = false;
  double s_min = NA_REAL;
  double s_q = NA_REAL;
  double m = NA_REAL;
  double score = NA_REAL;
  int neighborhood_size = 0;
  double distance_scale = NA_REAL;
};

inline bool less_neighbor_entry(const NeighborEntry& lhs, const NeighborEntry& rhs) {
  if (lhs.distance < rhs.distance - kTol) return true;
  if (lhs.distance > rhs.distance + kTol) return false;
  return lhs.vertex < rhs.vertex;
}

std::vector<std::vector<int>> as_adj_list_zero_based(const List& adj_list) {
  const int n = adj_list.size();
  std::vector<std::vector<int>> out(static_cast<size_t>(n));

  for (int i = 0; i < n; ++i) {
    Rcpp::IntegerVector nbrs = adj_list[i];
    out[static_cast<size_t>(i)].reserve(static_cast<size_t>(nbrs.size()));
    for (int v : nbrs) {
      out[static_cast<size_t>(i)].push_back(v - 1);
    }
  }
  return out;
}

std::vector<std::vector<double>> as_weight_list(const List& weight_list) {
  const int n = weight_list.size();
  std::vector<std::vector<double>> out(static_cast<size_t>(n));

  for (int i = 0; i < n; ++i) {
    NumericVector w = weight_list[i];
    out[static_cast<size_t>(i)].assign(w.begin(), w.end());
  }
  return out;
}

void validate_graph_inputs(const std::vector<std::vector<int>>& adj_list,
                           const std::vector<std::vector<double>>& weight_list,
                           int n_vertices) {
  if (static_cast<int>(adj_list.size()) != n_vertices) {
    Rcpp::stop("adj.list length must match nrow(layout.3d).");
  }
  if (weight_list.size() != adj_list.size()) {
    Rcpp::stop("weight.list length must match adj.list length.");
  }

  for (size_t i = 0; i < adj_list.size(); ++i) {
    if (weight_list[i].size() != adj_list[i].size()) {
      Rcpp::stop("weight.list[[%d]] length does not match adj.list[[%d]] length.",
                 static_cast<int>(i + 1), static_cast<int>(i + 1));
    }
    for (size_t j = 0; j < adj_list[i].size(); ++j) {
      const int v = adj_list[i][j];
      if (v < 0 || v >= n_vertices) {
        Rcpp::stop("adj.list contains an invalid neighbor index at vertex %d.",
                   static_cast<int>(i + 1));
      }
      const double w = weight_list[i][j];
      if (!std::isfinite(w) || w <= 0.0) {
        Rcpp::stop("weight.list must contain finite values > 0.");
      }
    }
  }
}

std::vector<NeighborEntry> truncated_dijkstra(const std::vector<std::vector<int>>& adj_list,
                                              const std::vector<std::vector<double>>& weight_list,
                                              int source,
                                              bool use_k_neighborhood,
                                              int k_max,
                                              double radius_max) {
  const int n = static_cast<int>(adj_list.size());
  std::vector<double> dist(static_cast<size_t>(n), std::numeric_limits<double>::infinity());

  using QueueItem = std::pair<double, int>;
  auto cmp = [](const QueueItem& lhs, const QueueItem& rhs) {
    if (lhs.first > rhs.first + kTol) return true;
    if (lhs.first < rhs.first - kTol) return false;
    return lhs.second > rhs.second;
  };
  std::priority_queue<QueueItem, std::vector<QueueItem>, decltype(cmp)> queue(cmp);

  dist[static_cast<size_t>(source)] = 0.0;
  queue.push(std::make_pair(0.0, source));

  std::vector<NeighborEntry> out;
  double distance_cutoff = use_k_neighborhood ? std::numeric_limits<double>::infinity() : radius_max;

  while (!queue.empty()) {
    const QueueItem item = queue.top();
    queue.pop();
    const double current_dist = item.first;
    const int u = item.second;

    if (current_dist > dist[static_cast<size_t>(u)] + kTol) continue;
    if (!use_k_neighborhood && current_dist > radius_max + kTol) break;
    if (use_k_neighborhood && current_dist > distance_cutoff + kTol) break;

    if (u != source) {
      out.push_back(NeighborEntry{u, current_dist});
      if (use_k_neighborhood && static_cast<int>(out.size()) >= k_max &&
          !std::isfinite(distance_cutoff)) {
        distance_cutoff = current_dist;
      }
    }

    const std::vector<int>& nbrs = adj_list[static_cast<size_t>(u)];
    const std::vector<double>& weights = weight_list[static_cast<size_t>(u)];

    for (size_t i = 0; i < nbrs.size(); ++i) {
      const int v = nbrs[i];
      const double w = weights[i];
      const double next_dist = current_dist + w;

      if (!use_k_neighborhood && next_dist > radius_max + kTol) continue;
      if (use_k_neighborhood && std::isfinite(distance_cutoff) &&
          next_dist > distance_cutoff + kTol) continue;

      if (next_dist + kTol < dist[static_cast<size_t>(v)]) {
        dist[static_cast<size_t>(v)] = next_dist;
        queue.push(std::make_pair(next_dist, v));
      }
    }
  }

  std::sort(out.begin(), out.end(), less_neighbor_entry);
  if (use_k_neighborhood && static_cast<int>(out.size()) > k_max) {
    out.resize(static_cast<size_t>(k_max));
  }
  return out;
}

std::vector<double> compute_neighbor_weights(const std::vector<double>& geodesic_distances,
                                             int weighting_mode,
                                             double gaussian_sigma) {
  std::vector<double> weights(geodesic_distances.size(), 1.0);
  if (geodesic_distances.empty()) return weights;

  if (weighting_mode == 1) {
    for (size_t i = 0; i < geodesic_distances.size(); ++i) {
      weights[i] = 1.0 / std::max(geodesic_distances[i], std::sqrt(std::numeric_limits<double>::epsilon()));
    }
  } else if (weighting_mode == 2) {
    double sigma = gaussian_sigma;
    if (!std::isfinite(sigma) || sigma <= 0.0) {
      std::vector<double> positive;
      positive.reserve(geodesic_distances.size());
      for (double d : geodesic_distances) {
        if (d > 0.0 && std::isfinite(d)) positive.push_back(d);
      }
      if (!positive.empty()) {
        const size_t mid = positive.size() / 2;
        std::nth_element(positive.begin(), positive.begin() + mid, positive.end());
        sigma = positive[mid];
      } else {
        sigma = 1.0;
      }
    }
    for (size_t i = 0; i < geodesic_distances.size(); ++i) {
      const double z = geodesic_distances[i] / sigma;
      weights[i] = std::exp(-0.5 * z * z);
    }
  }

  double total = 0.0;
  for (double& w : weights) {
    if (!std::isfinite(w) || w < 0.0) w = 0.0;
    total += w;
  }
  if (!(total > 0.0)) {
    std::fill(weights.begin(), weights.end(), 1.0 / static_cast<double>(weights.size()));
    return weights;
  }
  for (double& w : weights) w /= total;
  return weights;
}

double weighted_quantile_endpoint(std::vector<double> values,
                                  std::vector<double> weights,
                                  double q) {
  std::vector<std::pair<double, double>> pairs;
  pairs.reserve(values.size());

  for (size_t i = 0; i < values.size(); ++i) {
    const double x = values[i];
    const double w = weights[i];
    if (std::isfinite(x) && std::isfinite(w) && w >= 0.0) {
      pairs.push_back(std::make_pair(x, w));
    }
  }

  if (pairs.empty()) return NA_REAL;
  if (pairs.size() == 1) return pairs.front().first;

  double total = 0.0;
  for (const auto& item : pairs) total += item.second;
  if (!(total > 0.0)) {
    for (auto& item : pairs) item.second = 1.0;
    total = static_cast<double>(pairs.size());
  }

  std::sort(
      pairs.begin(),
      pairs.end(),
      [](const std::pair<double, double>& lhs, const std::pair<double, double>& rhs) {
        if (lhs.first < rhs.first - kTol) return true;
        if (lhs.first > rhs.first + kTol) return false;
        return false;
      });

  double cumulative = 0.0;
  for (const auto& item : pairs) {
    cumulative += item.second;
    if (cumulative / total + kTol >= q) return item.first;
  }
  return pairs.back().first;
}

MetricResult compute_metrics_for_prefix(const NumericMatrix& layout,
                                        int center_vertex,
                                        const std::vector<NeighborEntry>& sorted_neighbors,
                                        int prefix_size,
                                        double q,
                                        int weighting_mode,
                                        double gaussian_sigma,
                                        int min_neighborhood_size) {
  std::vector<int> kept_vertices;
  std::vector<double> geodesic_distances;
  kept_vertices.reserve(static_cast<size_t>(prefix_size));
  geodesic_distances.reserve(static_cast<size_t>(prefix_size));

  const double cx = layout(center_vertex, 0);
  const double cy = layout(center_vertex, 1);
  const double cz = layout(center_vertex, 2);

  std::vector<double> ux;
  std::vector<double> uy;
  std::vector<double> uz;
  ux.reserve(static_cast<size_t>(prefix_size));
  uy.reserve(static_cast<size_t>(prefix_size));
  uz.reserve(static_cast<size_t>(prefix_size));

  for (int i = 0; i < prefix_size; ++i) {
    const int v = sorted_neighbors[static_cast<size_t>(i)].vertex;
    const double dx = layout(v, 0) - cx;
    const double dy = layout(v, 1) - cy;
    const double dz = layout(v, 2) - cz;
    const double len = std::sqrt(dx * dx + dy * dy + dz * dz);
    if (!std::isfinite(len) || len <= 0.0) continue;

    ux.push_back(dx / len);
    uy.push_back(dy / len);
    uz.push_back(dz / len);
    kept_vertices.push_back(v);
    geodesic_distances.push_back(sorted_neighbors[static_cast<size_t>(i)].distance);
  }

  MetricResult result;
  result.neighborhood_size = static_cast<int>(kept_vertices.size());
  if (result.neighborhood_size < min_neighborhood_size) {
    return result;
  }

  std::vector<double> weights = compute_neighbor_weights(
      geodesic_distances, weighting_mode, gaussian_sigma);

  std::vector<double> dots;
  std::vector<double> pair_weights;
  dots.reserve(static_cast<size_t>(result.neighborhood_size * (result.neighborhood_size - 1) / 2));
  pair_weights.reserve(dots.capacity());

  double wx = 0.0;
  double wy = 0.0;
  double wz = 0.0;
  double distance_scale = 0.0;

  for (int i = 0; i < result.neighborhood_size; ++i) {
    const double wi = weights[static_cast<size_t>(i)];
    wx += wi * ux[static_cast<size_t>(i)];
    wy += wi * uy[static_cast<size_t>(i)];
    wz += wi * uz[static_cast<size_t>(i)];
    distance_scale += wi * geodesic_distances[static_cast<size_t>(i)];

    for (int j = i + 1; j < result.neighborhood_size; ++j) {
      double dot = ux[static_cast<size_t>(i)] * ux[static_cast<size_t>(j)] +
                   uy[static_cast<size_t>(i)] * uy[static_cast<size_t>(j)] +
                   uz[static_cast<size_t>(i)] * uz[static_cast<size_t>(j)];
      if (dot < -1.0) dot = -1.0;
      if (dot > 1.0) dot = 1.0;
      dots.push_back(dot);
      pair_weights.push_back(wi * weights[static_cast<size_t>(j)]);
    }
  }

  if (dots.empty()) {
    return result;
  }

  result.usable = true;
  result.s_min = *std::min_element(dots.begin(), dots.end());
  result.s_q = weighted_quantile_endpoint(dots, pair_weights, q);
  result.m = std::sqrt(wx * wx + wy * wy + wz * wz);
  result.score = result.m * (1.0 + result.s_q) / 2.0;
  result.distance_scale = distance_scale;
  return result;
}

int radius_prefix_size(const std::vector<NeighborEntry>& neighbors, double radius) {
  int count = 0;
  for (const NeighborEntry& item : neighbors) {
    if (item.distance <= radius + kTol) {
      ++count;
    } else {
      break;
    }
  }
  return count;
}

std::vector<int> multi_source_radius_support(const std::vector<std::vector<int>>& adj_list,
                                             const std::vector<std::vector<double>>& weight_list,
                                             const std::vector<int>& sources,
                                             double radius) {
  const int n = static_cast<int>(adj_list.size());
  std::vector<int> support(static_cast<size_t>(n), 0);
  if (sources.empty()) return support;

  std::vector<double> dist(static_cast<size_t>(n), std::numeric_limits<double>::infinity());

  using QueueItem = std::pair<double, int>;
  auto cmp = [](const QueueItem& lhs, const QueueItem& rhs) {
    if (lhs.first > rhs.first + kTol) return true;
    if (lhs.first < rhs.first - kTol) return false;
    return lhs.second > rhs.second;
  };
  std::priority_queue<QueueItem, std::vector<QueueItem>, decltype(cmp)> queue(cmp);

  for (int source : sources) {
    if (source < 0 || source >= n) continue;
    if (0.0 + kTol < dist[static_cast<size_t>(source)]) {
      dist[static_cast<size_t>(source)] = 0.0;
      queue.push(std::make_pair(0.0, source));
    }
  }

  while (!queue.empty()) {
    const QueueItem item = queue.top();
    queue.pop();
    const double current_dist = item.first;
    const int u = item.second;

    if (current_dist > dist[static_cast<size_t>(u)] + kTol) continue;
    if (current_dist > radius + kTol) break;

    support[static_cast<size_t>(u)] = 1;

    const std::vector<int>& nbrs = adj_list[static_cast<size_t>(u)];
    const std::vector<double>& weights = weight_list[static_cast<size_t>(u)];
    for (size_t i = 0; i < nbrs.size(); ++i) {
      const int v = nbrs[i];
      const double next_dist = current_dist + weights[i];
      if (next_dist > radius + kTol) continue;
      if (next_dist + kTol < dist[static_cast<size_t>(v)]) {
        dist[static_cast<size_t>(v)] = next_dist;
        queue.push(std::make_pair(next_dist, v));
      }
    }
  }

  return support;
}

}  // namespace

Rcpp::List dgraphs_rcpp_compute_graph_endpoint_scores(const List& adj_list,
                                              const List& weight_list,
                                              const NumericMatrix& layout_3d,
                                              const NumericVector& scales,
                                              const std::string& neighborhood,
                                              double q,
                                              const std::string& neighbor_weighting,
                                              Rcpp::Nullable<double> gaussian_sigma,
                                              int min_neighborhood_size) {
  const int n_vertices = layout_3d.nrow();
  const int n_scales = scales.size();

  if (layout_3d.ncol() != 3) {
    Rcpp::stop("layout.3d must have exactly 3 columns.");
  }
  if (n_scales < 1) {
    Rcpp::stop("scales must contain at least one value.");
  }

  const std::vector<std::vector<int>> adj = as_adj_list_zero_based(adj_list);
  const std::vector<std::vector<double>> weight = as_weight_list(weight_list);
  validate_graph_inputs(adj, weight, n_vertices);

  const bool use_k_neighborhood = (neighborhood == "geodesic_k");
  if (!use_k_neighborhood && neighborhood != "geodesic_radius") {
    Rcpp::stop("neighborhood must be 'geodesic_k' or 'geodesic_radius'.");
  }

  int weighting_mode = 0;
  if (neighbor_weighting == "uniform") {
    weighting_mode = 0;
  } else if (neighbor_weighting == "inverse_distance") {
    weighting_mode = 1;
  } else if (neighbor_weighting == "gaussian") {
    weighting_mode = 2;
  } else {
    Rcpp::stop("neighbor.weighting must be 'uniform', 'inverse_distance', or 'gaussian'.");
  }

  double sigma_value = NA_REAL;
  if (gaussian_sigma.isNotNull()) {
    sigma_value = Rcpp::as<double>(gaussian_sigma);
  }

  std::vector<double> scale_values(scales.begin(), scales.end());
  int max_k = 0;
  double max_radius = 0.0;
  if (use_k_neighborhood) {
    for (double s : scale_values) {
      max_k = std::max(max_k, static_cast<int>(std::round(s)));
    }
  } else {
    for (double s : scale_values) {
      max_radius = std::max(max_radius, s);
    }
  }

  std::vector<double> s_min_storage(static_cast<size_t>(n_vertices * n_scales), NA_REAL);
  std::vector<double> s_q_storage(static_cast<size_t>(n_vertices * n_scales), NA_REAL);
  std::vector<double> m_storage(static_cast<size_t>(n_vertices * n_scales), NA_REAL);
  std::vector<double> score_storage(static_cast<size_t>(n_vertices * n_scales), NA_REAL);
  std::vector<double> distance_scale_storage(static_cast<size_t>(n_vertices * n_scales), NA_REAL);
  std::vector<int> neighborhood_size_storage(static_cast<size_t>(n_vertices * n_scales), 0);

#ifdef _OPENMP
#pragma omp parallel for schedule(dynamic)
#endif
  for (int vertex = 0; vertex < n_vertices; ++vertex) {
    std::vector<NeighborEntry> neighbors = truncated_dijkstra(
        adj, weight, vertex, use_k_neighborhood, max_k, max_radius);

    for (int scale_idx = 0; scale_idx < n_scales; ++scale_idx) {
      const int offset = vertex + n_vertices * scale_idx;
      int prefix_size = 0;

      if (use_k_neighborhood) {
        prefix_size = std::min(static_cast<int>(neighbors.size()),
                               static_cast<int>(std::round(scale_values[static_cast<size_t>(scale_idx)])));
      } else {
        prefix_size = radius_prefix_size(neighbors, scale_values[static_cast<size_t>(scale_idx)]);
      }

      if (prefix_size < min_neighborhood_size) continue;

      MetricResult metrics = compute_metrics_for_prefix(
          layout_3d,
          vertex,
          neighbors,
          prefix_size,
          q,
          weighting_mode,
          sigma_value,
          min_neighborhood_size);

      if (!metrics.usable) {
        neighborhood_size_storage[static_cast<size_t>(offset)] = metrics.neighborhood_size;
        continue;
      }

      s_min_storage[static_cast<size_t>(offset)] = metrics.s_min;
      s_q_storage[static_cast<size_t>(offset)] = metrics.s_q;
      m_storage[static_cast<size_t>(offset)] = metrics.m;
      score_storage[static_cast<size_t>(offset)] = metrics.score;
      neighborhood_size_storage[static_cast<size_t>(offset)] = metrics.neighborhood_size;
      distance_scale_storage[static_cast<size_t>(offset)] = metrics.distance_scale;
    }
  }

  NumericMatrix s_min_by_scale(n_vertices, n_scales);
  NumericMatrix s_q_by_scale(n_vertices, n_scales);
  NumericMatrix m_by_scale(n_vertices, n_scales);
  NumericMatrix score_by_scale(n_vertices, n_scales);
  NumericMatrix distance_scale_by_scale(n_vertices, n_scales);
  IntegerMatrix neighborhood_size_by_scale(n_vertices, n_scales);

  std::copy(s_min_storage.begin(), s_min_storage.end(), s_min_by_scale.begin());
  std::copy(s_q_storage.begin(), s_q_storage.end(), s_q_by_scale.begin());
  std::copy(m_storage.begin(), m_storage.end(), m_by_scale.begin());
  std::copy(score_storage.begin(), score_storage.end(), score_by_scale.begin());
  std::copy(distance_scale_storage.begin(), distance_scale_storage.end(), distance_scale_by_scale.begin());
  std::copy(neighborhood_size_storage.begin(), neighborhood_size_storage.end(), neighborhood_size_by_scale.begin());

  return List::create(
      Named("s.min") = s_min_by_scale,
      Named("s.q") = s_q_by_scale,
      Named("m") = m_by_scale,
      Named("score") = score_by_scale,
      Named("neighborhood.size") = neighborhood_size_by_scale,
      Named("distance.scale") = distance_scale_by_scale);
}

LogicalMatrix dgraphs_rcpp_graph_multi_source_support_by_scale(const List& adj_list,
                                                       const List& weight_list,
                                                       const LogicalMatrix& local_max_by_scale,
                                                       double radius) {
  const int n_vertices = local_max_by_scale.nrow();
  const int n_scales = local_max_by_scale.ncol();

  if (n_scales < 1) {
    Rcpp::stop("local.max.by.scale must have at least one column.");
  }
  if (!std::isfinite(radius) || radius < 0.0) {
    Rcpp::stop("radius must be a finite scalar >= 0.");
  }

  const std::vector<std::vector<int>> adj = as_adj_list_zero_based(adj_list);
  const std::vector<std::vector<double>> weight = as_weight_list(weight_list);
  validate_graph_inputs(adj, weight, n_vertices);

  LogicalMatrix support(n_vertices, n_scales);

  for (int scale_idx = 0; scale_idx < n_scales; ++scale_idx) {
    std::vector<int> sources;
    sources.reserve(static_cast<size_t>(n_vertices));
    for (int vertex = 0; vertex < n_vertices; ++vertex) {
      if (local_max_by_scale(vertex, scale_idx) == TRUE) {
        sources.push_back(vertex);
      }
    }

    const std::vector<int> support_col = multi_source_radius_support(
        adj, weight, sources, radius);

    for (int vertex = 0; vertex < n_vertices; ++vertex) {
      support(vertex, scale_idx) = support_col[static_cast<size_t>(vertex)] != 0;
    }
  }

  return support;
}

LogicalMatrix dgraphs_rcpp_graph_greedy_maxima_suppression_by_scale(const List& adj_list,
                                                            const List& weight_list,
                                                            const LogicalMatrix& local_max_by_scale,
                                                            const NumericMatrix& score_by_scale,
                                                            double radius) {
  const int n_vertices = local_max_by_scale.nrow();
  const int n_scales = local_max_by_scale.ncol();

  if (score_by_scale.nrow() != n_vertices || score_by_scale.ncol() != n_scales) {
    Rcpp::stop("score.by.scale must match local.max.by.scale dimensions.");
  }
  if (!std::isfinite(radius) || radius < 0.0) {
    Rcpp::stop("radius must be a finite scalar >= 0.");
  }

  const std::vector<std::vector<int>> adj = as_adj_list_zero_based(adj_list);
  const std::vector<std::vector<double>> weight = as_weight_list(weight_list);
  validate_graph_inputs(adj, weight, n_vertices);

  LogicalMatrix keep(n_vertices, n_scales);

  for (int scale_idx = 0; scale_idx < n_scales; ++scale_idx) {
    std::vector<int> candidates;
    candidates.reserve(static_cast<size_t>(n_vertices));
    for (int vertex = 0; vertex < n_vertices; ++vertex) {
      if (local_max_by_scale(vertex, scale_idx) == TRUE &&
          std::isfinite(score_by_scale(vertex, scale_idx))) {
        candidates.push_back(vertex);
      }
    }
    if (candidates.empty()) continue;

    std::sort(candidates.begin(), candidates.end(), [&](int lhs, int rhs) {
      const double y_lhs = score_by_scale(lhs, scale_idx);
      const double y_rhs = score_by_scale(rhs, scale_idx);
      if (y_lhs > y_rhs + kTol) return true;
      if (y_lhs < y_rhs - kTol) return false;
      return lhs < rhs;
    });

    std::vector<unsigned char> suppressed(static_cast<size_t>(n_vertices), 0);

    for (int vertex : candidates) {
      if (suppressed[static_cast<size_t>(vertex)] != 0) continue;
      keep(vertex, scale_idx) = true;
      if (radius <= 0.0) continue;

      const std::vector<NeighborEntry> hood = truncated_dijkstra(
          adj, weight, vertex, false, 0, radius);
      suppressed[static_cast<size_t>(vertex)] = 1;
      for (const NeighborEntry& item : hood) {
        suppressed[static_cast<size_t>(item.vertex)] = 1;
      }
    }
  }

  return keep;
}
