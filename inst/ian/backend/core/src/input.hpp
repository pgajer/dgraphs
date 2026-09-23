#pragma once
#include "numeric.hpp"
#include <map>
#include <set>
// Exact feature-row duplicates preserve first-occurrence specimen order.
namespace ian::detail {
struct ProcessedInput {
    Mat D;
    ian::Mapping mapping;
};
inline ProcessedInput preprocess(const ian::Input &in) {
    const Mat& X = in.features; const Mat& D = in.distances;
    const auto& ids = in.specimen_ids;
    size_t n = X.size();
    require(n > 0 && D.size() == n && ids.size() == n, "input_shape_or_identity");
    std::set<std::string> distinct(ids.begin(), ids.end());
    require(distinct.size() == n, "input_shape_or_identity");
    for (size_t i = 0; i < n; i++) {
        require(X[i].size() == X[0].size() && D[i].size() == n, "input_shape_or_identity");
        for (double v : X[i])
            require(std::isfinite(v), "invalid_distances_or_features");
        for (double v : D[i])
            require(std::isfinite(v) && v >= 0, "invalid_distances_or_features");
    }
    for (size_t i = 0; i < n; i++)
        for (size_t j = 0; j < n; j++)
            require(D[i][j] == D[j][i] && (i != j || D[i][j] == 0),
                    "invalid_distances_or_features");
    std::map<Vec, int> lookup;
    Ids reps, mapping;
    for (size_t i = 0; i < n; i++) {
        auto it = lookup.find(X[i]);
        if (it == lookup.end()) {
            int id = reps.size();
            lookup[X[i]] = id;
            reps.push_back(i);
            mapping.push_back(id);
        } else
            mapping.push_back(it->second);
    }
    Mat U(reps.size(), Vec(reps.size()));
    for (size_t i = 0; i < reps.size(); i++)
        for (size_t j = 0; j < reps.size(); j++)
            U[i][j] = D[reps[i]][reps[j]];
    for (size_t i = 0; i < n; i++)
        for (size_t j = 0; j < n; j++)
            require(D[i][j] == U[mapping[i]][mapping[j]], "duplicate_distance_inconsistency");
    require(reps.size() >= 2, "fewer_than_two_unique_profiles");
    double minimum = std::numeric_limits<double>::infinity();
    for (size_t i = 0; i < U.size(); i++)
        for (size_t j = i + 1; j < U.size(); j++)
            minimum = std::min(minimum, U[i][j]);
    require(!close(minimum, 0), "nearly_identical_distinct_profiles");
    std::vector<std::string> profileids;
    for (int i : reps)
        profileids.push_back(ids[i]);
    return {U, ian::Mapping{reps, mapping, ids, profileids, in.participant_ids}};
}

} // namespace ian::detail
