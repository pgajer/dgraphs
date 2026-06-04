#ifndef GRAPH_SPECTRAL_FILTER_HPP
#define GRAPH_SPECTRAL_FILTER_HPP

#include <vector>
#include <cstddef>

#include <Eigen/Core>

using std::size_t;

/**
 * @brief Types of graph Laplacians for spectral decomposition
 */
enum class laplacian_type_t {
    STANDARD,            // L = D - A (combinatorial Laplacian)
    NORMALIZED,          // L_norm = D^(-1/2) L D^(-1/2) (normalized Laplacian)
    RANDOM_WALK,         // L_rw = D^(-1) L (random walk Laplacian)
    KERNEL,              // L_kernel = D_kernel - W_kernel (kernel Laplacian)
    NORMALIZED_KERNEL,   // Normalized version of kernel Laplacian
    ADAPTIVE_KERNEL,     // Kernel Laplacian with adaptive bandwidth
    SHIFTED,             // I - L (shifted standard Laplacian)
    SHIFTED_KERNEL,      // I - L_kernel (shifted kernel Laplacian)
    REGULARIZED,         // L + ε*I (regularized standard Laplacian)
    REGULARIZED_KERNEL,  // L_kernel + ε*I (regularized kernel Laplacian)
    MULTI_SCALE,         // Weighted combination of kernel Laplacians at different scales
    PATH                 // path Laplacian
};

/**
 * @brief Types of kernel functions for distance weighting
 */
enum class kernel_type_t {
    S_INVERSE,       // -1/(d*τ)
    S_GAUSSIAN,      // exp(-d²/τ²)
    S_EXPONENTIAL,   // exp(-d/τ)
    S_HEAT,          // exp(-d²/4τ)
    S_TRICUBE,       // (1-(d/τ)³)³ for d < τ, 0 otherwise
    S_EPANECHNIKOV,  // 1-(d/τ)² for d < τ, 0 otherwise
    S_UNIFORM,       // 1 for d < τ, 0 otherwise
    S_TRIANGULAR,    // 1-|d/τ| for d < τ, 0 otherwise
    S_QUARTIC,       // (1-(d/τ)²)² for d < τ, 0 otherwise
    S_TRIWEIGHT      // (1-(d/τ)²)³ for d < τ, 0 otherwise
};

/**
 * @brief Types of spectral filters for signal smoothing
 */
enum class filter_type_t {
    // Basic filters
    HEAT,               // exp(-t*λ) - Heat kernel filter
    GAUSSIAN,           // exp(-t*λ²) - Gaussian filter
    NON_NEGATIVE,       // exp(-t*max(λ,0)) - Non-negative truncated heat kernel
    CUBIC_SPLINE,       // 1/(1+t*λ²) - Cubic spline-like filter

    // Additional filters
    EXPONENTIAL,        // exp(-t*sqrt(λ)) - Exponential filter (less aggressive than heat)
    MEXICAN_HAT,        // λ*exp(-t*λ²) - Mexican hat wavelet (band-pass)
    IDEAL_LOW_PASS,     // 1 for λ < t, 0 otherwise - Ideal low-pass (sharp cutoff)
    BUTTERWORTH,        // 1/(1+(λ/t)^(2*n)) - Butterworth filter (n controls steepness)
    TIKHONOV,           // 1/(1+t*λ) - Tikhonov regularization filter (first-order)

    // Special filters
    POLYNOMIAL,         // (1-λ/λ_max)^p for λ < λ_max - Polynomial filter
    INVERSE_COSINE,     // cos(π*λ/(2*λ_max)) - Inverse cosine filter
    ADAPTIVE            // Data-driven filter that adapts to signal properties
};

/**
 * @brief Parameters for kernel-based Laplacian computations
 */
struct kernel_params_t {
    double tau_factor = 0.01;          // Kernel bandwidth parameter factor: tau = tau_factor * graph_diameter
    double radius_factor = 3.0;        // Search radius multiplier
    kernel_type_t kernel_type = kernel_type_t::S_GAUSSIAN; // Type of kernel function
    bool adaptive = false;             // Whether to use adaptive bandwidth
    double min_radius_factor = 0.05;   // min_radius = min_radius_factor * graph_diameter;
    double max_radius_factor = 0.99;   // max_radius = max_radius_factor * graph_diameter;
    size_t domain_min_size = 4;        // the minimal number of verticex within a disk of the given radius
    double precision = 1e-6;           // Precision for find_minimum_radius_for_domain_min_size()
};

/**
 * @brief Results of a graph heat‐kernel (spectral diffusion) smoothing.
 */
struct graph_spectral_filter_t {
    // Result data
    std::vector<double>   evalues;        ///< Laplacian eigenvalues
    Eigen::MatrixXd       evectors;       ///< Laplacian eigenvectors (columns)
    std::vector<double>   candidate_ts;   ///< Diffusion times tested
    std::vector<double>   gcv_scores;     ///< GCV score for each t
    size_t                opt_t_idx;      ///< Index of optimal t in candidate_ts
    std::vector<double>   predictions;    ///< y_{t*} (optimal smooth)
    std::vector<std::vector<double>> t_predictions;  ///< Optional: full family y_{t_j}, size = candidate_ts.size()

    // Configuration parameters used
    laplacian_type_t      laplacian_type; ///< Type of Laplacian used
    filter_type_t         filter_type;    ///< Type of spectral filter applied
    size_t                laplacian_power;///< Power to which Laplacian was raised
    kernel_params_t       kernel_params;  ///< Kernel parameters used

    // Performance metrics
    double                compute_time_ms = 0.0;  ///< Computation time in milliseconds
    double                gcv_min_score = 0.0;    ///< Minimum GCV score achieved

    // Constructor with default values
    graph_spectral_filter_t() :
        laplacian_type(laplacian_type_t::STANDARD),
        filter_type(filter_type_t::HEAT),
        laplacian_power(1) {}
};

#endif // GRAPH_SPECTRAL_FILTER_HPP
