#ifndef DGRAPHS_NEIGHBORHOOD_HPP
#define DGRAPHS_NEIGHBORHOOD_HPP
#include <algorithm>
#include <cmath>
#include <utility>
#include <vector>
// One ordering for coordinate and graph-geodesic neighborhoods. Self is
// excluded by identity and is inserted separately by the cover builders.
inline std::vector<std::pair<double, int>> dgraphs_rank_others(
    std::vector<std::pair<double, int>> ranked, int source, int k) {
    ranked.erase(std::remove_if(ranked.begin(), ranked.end(), [source](const auto& x) {
        return x.second == source || !std::isfinite(x.first);
    }), ranked.end());
    const int keep = std::min(k, static_cast<int>(ranked.size()));
    std::partial_sort(ranked.begin(), ranked.begin() + keep, ranked.end());
    ranked.resize(keep);
    return ranked;
}
inline std::vector<int> dgraphs_nearest_others(const std::vector<double>& distances,
                                              int source, int k) {
    std::vector<std::pair<double, int>> ranked;
    for (int j = 0; j < static_cast<int>(distances.size()); ++j) ranked.emplace_back(distances[j], j);
    const auto selected = dgraphs_rank_others(std::move(ranked), source, k);
    std::vector<int> out;
    for (const auto& entry : selected) out.push_back(entry.second);
    return out;
}
#endif
