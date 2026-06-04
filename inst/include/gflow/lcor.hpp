#ifndef LCOR_HPP
#define LCOR_HPP

#include <vector>
#include <limits>

/**
 * @enum edge_diff_type_t
 * @brief Types of edge difference computation for local correlation
 *
 * Defines how to compute directional differences Δ_e f = f(u) - f(v) along
 * edges. The choice depends on the nature of the data:
 * - DIFFERENCE: Standard for continuous data in Euclidean space
 * - LOGRATIO: Appropriate for compositional data (relative abundances, proportions)
 */
enum class edge_diff_type_t {
    /**
     * Standard difference: Δ_e f = f(u) - f(v)
     *
     * Appropriate for:
     * - Continuous functions in Euclidean space
     * - Data where additive changes are meaningful
     * - Standard regression responses
     */
    DIFFERENCE,

    /**
     * Log-ratio: Δ_e f = log((f(u) + ε) / (f(v) + ε))
     *
     * Appropriate for:
     * - Compositional data (relative abundances, proportions)
     * - Data constrained to positive values
     * - Situations where multiplicative changes are more meaningful
     *
     * The log transformation maps ratios to a symmetric additive scale:
     * - 2-fold increase: log(2) ≈ 0.693
     * - 2-fold decrease: log(0.5) ≈ -0.693
     *
     * The pseudocount ε handles zeros. If ε = 0 (default), it is computed
     * adaptively as 1e-6 times the minimum non-zero value in the data.
     *
     * GEOMETRIC INTERPRETATION:
     * Log-ratios correspond to the Aitchison distance on the simplex,
     * making this the natural choice for compositional data analysis.
     * The correlation of log-ratio gradients measures directional alignment
     * in the appropriate geometry for relative abundance data.
     */
    LOGRATIO
};

/**
 * @enum lcor_type_t
 * @brief Types of local correlation coefficients
 *
 * Defines the different weighting schemes for computing local correlation
 * between two functions y and z defined on graph vertices. Each type represents
 * a different way of aggregating the edge-wise co-variation.
 */
enum class lcor_type_t {
    /**
     * Unit weights (w_e = 1 for all edges)
     *
     * The local correlation at vertex v is:
     *   comono(y,z)(v) = Σ(Δ_e y · Δ_e z) / Σ|Δ_e y · Δ_e z|
     * where the sum is over all edges incident to v, and Δ_e y = y(u) - y(v)
     * for edge e = [v,u].
     */
    UNIT,

    /**
     * Derivative-like weights (w_e = 1/(Δ_e)²)
     *
     * The local correlation at vertex v is:
     *   comono_∂(y,z)(v) = Σ(w_e · Δ_e y · Δ_e z) / Σ(w_e · |Δ_e y · Δ_e z|)
     * where w_e = 1/(Δ_e)² and Δ_e is the edge length. This weighting normalizes
     * by edge length squared, making it analogous to comparing derivatives rather
     * than absolute changes.
     */
    DERIVATIVE,

    /**
     * Sign-based local correlation (using only direction of change)
     *
     * The local correlation at vertex v is:
     *   comono_±(y,z)(v) = Σ sign(Δ_e y · Δ_e z) / |N(v)|
     * where sign(x) = +1 if x > 0, -1 if x < 0, and 0 if x = 0.
     * This measure only captures whether the functions change in the same
     * direction, ignoring the magnitude of change.
     */
    SIGN
};

/**
 * @struct lcor_result_t
 * @brief Result structure for local correlation computation
 *
 * Contains the vertex-wise local correlation coefficients along with edge
 * differences and weights for each vertex information.
 */
struct lcor_result_t {
    std::vector<double> vertex_coefficients; ///< local correlation coefficient at each vertex

    // Store edge differences and weights for each vertex
    // Using vectors-of-vectors to maintain vertex-neighborhood structure
    std::vector<std::vector<double>> vertex_delta_y;
    std::vector<std::vector<double>> vertex_delta_z;
    std::vector<std::vector<double>> vertex_weights;

    std::vector<double> all_delta_y;
    std::vector<double> all_delta_z;

    // winsorization bounds across all edges
    double y_lower = -std::numeric_limits<double>::max();
    double y_upper = std::numeric_limits<double>::max();
    double z_lower = -std::numeric_limits<double>::max();
    double z_upper = std::numeric_limits<double>::max();
};

/**
 * @struct lcor_vector_matrix_result_t
 * @brief Result structure for vector-matrix local correlation computation
 *
 * Contains vertex-wise local correlation coefficients for each column of Z,
 * stored as a matrix, along with winsorization bounds when applicable.
 */
struct lcor_vector_matrix_result_t {
    /// Coefficient matrix: coefficients(v, j) = lcor(y, z_j)(v)
    /// Stored in column-major order for R compatibility
    Eigen::MatrixXd coefficients;

    /// Winsorization bounds for y edge differences (scalars)
    double y_lower = -std::numeric_limits<double>::max();
    double y_upper = std::numeric_limits<double>::max();

    /// Winsorization bounds for z edge differences (per-column vectors)
    std::vector<double> z_lower;
    std::vector<double> z_upper;
};

#endif // LCOR_HPP
