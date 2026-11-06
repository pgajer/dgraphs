#ifndef GEODESIC_STATS_UPDATES_H_
#define GEODESIC_STATS_UPDATES_H_

#include <vector>
#include <unordered_map>
#include <array>
#include <cstddef>
using std::size_t;

// Forward declarations
std::vector<double> calculate_overlap_statistics(const std::vector<double>& overlap_indices);

/**
 * @struct overlap_stats_t
 * @brief Stores detailed statistics about path overlap
 */
struct overlap_stats_t {
    double min;           // Minimum overlap
    double p05;           // 5th percentile
    double p25;           // 25th percentile
    double median;        // Median (50th percentile)
    double p75;           // 75th percentile
    double p95;           // 95th percentile
    double max;           // Maximum overlap

    // Default constructor
    overlap_stats_t() : min(0), p05(0), p25(0), median(0), p75(0), p95(0), max(0) {}

    // Constructor from vector of statistics
    overlap_stats_t(const std::vector<double>& stats) {
        if (stats.size() >= 7) {
            min = stats[0];
            p05 = stats[1];
            p25 = stats[2];
            median = stats[3];
            p75 = stats[4];
            p95 = stats[5];
            max = stats[6];
        } else {
            // Default values if not enough statistics
            min = p05 = p25 = median = p75 = p95 = max = 0.0;
        }
    }
};

/**
 * @struct geodesic_stats_t
 * @brief Stores statistics about geodesics for grid vertices at various radii
 */
struct geodesic_stats_t {
    // For each radius, store statistics for each grid vertex
    std::vector<double> radii;
    std::vector<std::unordered_map<size_t, size_t>> geodesic_rays;       // Number of geodesic rays per grid vertex
    std::vector<std::unordered_map<size_t, size_t>> composite_geodesics; // Number of composite geodesics per grid vertex

    // Detailed overlap statistics
    std::vector<std::unordered_map<size_t, overlap_stats_t>> paths_overlap;  // Overlap statistics for each grid vertex
    std::vector<std::vector<double>> radius_overlaps;                        // All overlap indices for each radius
};

#endif // GEODESIC_STATS_UPDATES_H_
