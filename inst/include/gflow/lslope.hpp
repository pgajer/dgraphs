#ifndef LSLOPE_HPP
#define LSLOPE_HPP

#include <Eigen/Dense>
#include <vector>
#include <limits>
#include <cmath>

/**
 * @file lslope.hpp
 * @brief Local slope (asymmetric association) types and structures
 *
 * This file defines the types and structures for computing asymmetric local
 * association measures between a directing function y and a response function z
 * defined on graph vertices. Unlike symmetric local correlation, these measures
 * treat y as the directing variable and z as the response, yielding regression-
 * type coefficients rather than correlation coefficients.
 *
 * The key measures are:
 *
 * 1. Gradient-restricted slope: Uses only the single gradient edge at each vertex
 *    β_∇y(z)(v) = Δ_∇y(v) z / Δ_∇y(v) y
 *
 * 2. Neighborhood local regression coefficient: Uses all edges in neighborhood
 *    β_loc(z; y, w)(v) = Σ w_e Δ_e y · Δ_e z / Σ w_e (Δ_e y)²
 *
 * These measures are asymmetric: β(z; y) ≠ β(y; z) in general.
 */

/**
 * @enum lslope_type_t
 * @brief Types of local slope (asymmetric association) measures
 *
 * Defines the different asymmetric local association measures between a
 * directing function y and response function z. These differ from local
 * correlation in that they are not symmetric in y and z.
 */
enum class lslope_type_t {
    /**
     * Gradient-restricted slope (raw)
     *
     * At vertex v, computes the ratio of edge differences along the gradient edge:
     *   β_∇y(z)(v) = Δ_∇y(v) z / Δ_∇y(v) y
     *
     * where ∇y(v) is the edge from v to the neighbor u that maximizes Δy = y(u) - y(v).
     *
     * Interpretation: "For each unit increase in y along the steepest direction,
     * how much does z change?"
     *
     * Range: (-∞, +∞)
     * At local extrema of y: undefined (set to 0 or NaN depending on context)
     */
    GRADIENT_SLOPE,

    /**
     * Gradient-restricted slope with sigmoid normalization
     *
     * At vertex v, applies sigmoid transformation to bound the slope:
     *   β̃_∇y(z)(v) = σ_α(β_∇y(z)(v))
     *
     * where α is a scale parameter (default: calibrated from median absolute slope).
     *
     * Example: σ_α(β_∇y(z)(v)) = tanh(α · β_∇y(z)(v))
     *
     * Range: (-1, +1)
     * Provides numerical stability near extrema where Δy is small.
     */
    GRADIENT_SLOPE_NORMALIZED,

    /**
     * Gradient-restricted sign
     *
     * At vertex v, computes only the sign of the z-difference along gradient:
     *   s_∇y(z)(v) = sign(Δ_∇y(v) z)
     *
     * Range: {-1, 0, +1}
     * Robust to outliers; answers "does z increase or decrease along ∇y?"
     */
    GRADIENT_SIGN,

    /**
     * Neighborhood local regression coefficient
     *
     * At vertex v, computes the local regression coefficient using all edges:
     *   β_loc(z; y, w)(v) = Σ w_e Δ_e y · Δ_e z / Σ w_e (Δ_e y)²
     *
     * This equals lcor(y, z) × sd_loc(z) / sd_loc(y), the local analog of
     * the regression relationship β = ρ × σ_z / σ_y.
     *
     * Range: (-∞, +∞)
     * Uses all neighborhood information rather than just the gradient edge.
     */
    NEIGHBORHOOD_SLOPE
};


/**
 * @enum sigmoid_type_t
 * @brief Types of sigmoid functions for normalizing slopes
 */
enum class sigmoid_type_t {
    /**
     * Hyperbolic tangent: σ(x) = tanh(α·x)
     * Range: (-1, 1), smooth, symmetric
     */
    TANH,

    /**
     * Scaled arctangent: σ(x) = (2/π)·arctan(α·x)
     * Range: (-1, 1), slightly heavier tails than tanh
     */
    ARCTAN,

    /**
     * Algebraic sigmoid: σ(x) = x / √(α⁻² + x²)
     * Range: (-1, 1), simpler derivative
     */
    ALGEBRAIC
};


/**
 * @struct lslope_result_t
 * @brief Result structure for local slope computation
 *
 * Contains the vertex-wise local slope coefficients along with diagnostic
 * information about gradient edges and extrema.
 */
struct lslope_result_t {
    /// Local slope coefficient at each vertex
    std::vector<double> vertex_coefficients;

    /// Gradient edge neighbor for each vertex (INVALID_VERTEX if local extremum)
    std::vector<size_t> gradient_neighbors;

    /// Delta y along gradient edge for each vertex (0 if local extremum)
    std::vector<double> gradient_delta_y;

    /// Delta z along gradient edge for each vertex
    std::vector<double> gradient_delta_z;

    /// Boolean mask: true if vertex is a local extremum of y
    std::vector<bool> is_local_extremum;

    /// Number of local maxima of y
    size_t n_local_maxima = 0;

    /// Number of local minima of y
    size_t n_local_minima = 0;

    /// Sigmoid scale parameter (for GRADIENT_SLOPE_NORMALIZED)
    double sigmoid_alpha = 1.0;

    /// Summary statistics
    double mean_coefficient = 0.0;
    double median_coefficient = 0.0;
    size_t n_positive = 0;
    size_t n_negative = 0;
    size_t n_zero = 0;
};


/**
 * @struct lslope_nbhd_result_t
 * @brief Result structure for neighborhood local slope computation
 *
 * Contains the vertex-wise neighborhood regression coefficients with
 * diagnostic information.
 */
struct lslope_nbhd_result_t {
    /// Local regression coefficient at each vertex
    std::vector<double> vertex_coefficients;

    /// Local standard deviation of y at each vertex
    std::vector<double> sd_y;

    /// Local standard deviation of z at each vertex
    std::vector<double> sd_z;

    /// Local correlation at each vertex (for reference)
    std::vector<double> lcor;

    /// Summary statistics
    double mean_coefficient = 0.0;
    double median_coefficient = 0.0;
};

/**
 * @struct lslope_vector_matrix_result_t
 * @brief Result structure for vector-matrix local slope computation
 *
 * Contains the coefficient matrix (n_vertices x n_columns) along with
 * shared gradient structure information from the directing function y.
 * Used by lslope_vector_matrix() for efficient batch computation.
 */
struct lslope_vector_matrix_result_t {
    /// Coefficient matrix: coefficients(v, j) = lslope(Z_j; y)(v)
    /// Stored in column-major order for R compatibility
    Eigen::MatrixXd coefficients;

    /// Gradient edge neighbor for each vertex (shared across all columns)
    /// Value is std::numeric_limits<size_t>::max() for local extrema
    std::vector<size_t> gradient_neighbors;

    /// Delta y along gradient edge for each vertex (shared across all columns)
    std::vector<double> gradient_delta_y;

    /// Boolean mask: true if vertex is a local extremum of y
    std::vector<bool> is_local_extremum;

    /// Number of local maxima of y (when ascending = true)
    size_t n_local_maxima = 0;

    /// Number of local minima of y (when ascending = false)
    size_t n_local_minima = 0;

    /// Sigmoid scale parameter used (for GRADIENT_SLOPE_NORMALIZED)
    /// Calibrated from data if input sigmoid_alpha = 0
    double sigmoid_alpha = 1.0;
};

/**
 * @brief Apply sigmoid transformation to a value
 *
 * @param x Input value
 * @param alpha Scale parameter
 * @param type Type of sigmoid function
 * @return Transformed value in (-1, 1)
 */
inline double apply_sigmoid(double x, double alpha, sigmoid_type_t type) {
    switch (type) {
        case sigmoid_type_t::TANH:
            return std::tanh(alpha * x);

        case sigmoid_type_t::ARCTAN:
            return (2.0 / M_PI) * std::atan(alpha * x);

        case sigmoid_type_t::ALGEBRAIC:
            {
                double inv_alpha_sq = 1.0 / (alpha * alpha);
                return x / std::sqrt(inv_alpha_sq + x * x);
            }

        default:
            return std::tanh(alpha * x);
    }
}


/**
 * @brief Compute median of a vector (modifies input by partial sorting)
 *
 * @param values Vector of values (will be partially sorted)
 * @return Median value
 */
inline double compute_median(std::vector<double>& values) {
    if (values.empty()) return 0.0;

    size_t n = values.size();
    size_t mid = n / 2;

    std::nth_element(values.begin(), values.begin() + mid, values.end());

    if (n % 2 == 0) {
        double upper = values[mid];
        std::nth_element(values.begin(), values.begin() + mid - 1, values.end());
        double lower = values[mid - 1];
        return (lower + upper) / 2.0;
    } else {
        return values[mid];
    }
}


/**
 * @brief Compute median absolute value of a vector
 *
 * @param values Vector of values
 * @return Median of absolute values
 */
inline double compute_median_abs(const std::vector<double>& values) {
    if (values.empty()) return 1.0;

    std::vector<double> abs_values;
    abs_values.reserve(values.size());
    for (double v : values) {
        if (std::isfinite(v) && v != 0.0) {
            abs_values.push_back(std::abs(v));
        }
    }

    if (abs_values.empty()) return 1.0;

    return compute_median(abs_values);
}


#endif // LSLOPE_HPP
