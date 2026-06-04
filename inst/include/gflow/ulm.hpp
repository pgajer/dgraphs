#ifndef ULM_HPP
#define ULM_HPP

#include <vector>
#include <cstddef>
using std::size_t;


struct ulm_t {
    std::vector<double> predictions;   ///< predicted values
    std::vector<double> errors;        ///< Leave-One-Out Cross-Validation squared errors

    // Additional members to support generalized prediction
    double slope = 0.0;                ///< Fitted slope coefficient
    double x_wmean = 0.0;              ///< Weighted mean of predictor
    double y_wmean = 0.0;              ///< Weighted mean of response

    // New prediction method
    std::vector<double> predict(const std::vector<double>& x_new) const {
        std::vector<double> new_predictions;
        new_predictions.reserve(x_new.size());

        for (const auto& x_val : x_new) {
            // Apply linear model prediction formula
            double prediction = y_wmean + slope * (x_val - x_wmean);
            new_predictions.push_back(prediction);
        }

        return new_predictions;
    }
};

struct ext_ulm_t : public ulm_t {
    // Reorder member declarations to match initialization order
    std::vector<size_t> vertices;         ///< vertices of the path along which the model is estimated
    std::vector<size_t> grid_vertices;    ///< grid vertices within the path along which the model is estimated
    std::vector<double> x_path;           ///< distance from the start of the path
    std::vector<double> y_path;           ///< y values over the path
    std::vector<double> w_path;           ///< weights at the vertices of the path
    std::vector<double> grid_predictions; ///< model predictions at the grid vertices
    std::vector<double> grid_w_path;      ///< weights at grid vertices

    double bw;                            ///< bandwidth at which the data of the model was constructed
    double mean_error;                    ///< mean LOOCV error of the model

    // Update constructor to match new declaration order
    explicit ext_ulm_t(const ulm_t& base)
        : ulm_t(base),
          vertices(),
          grid_vertices(),
          w_path(),
          grid_predictions(),
          grid_w_path(),
          bw(0.0),
          mean_error(0.0)
        {}

    // This operator enables automatic sorting in set/multiset in the ascending order from the smallest to largest model's mean_error - models with the smallest mean_error are the most desirable
    bool operator<(const ext_ulm_t& other) const {
        return mean_error < other.mean_error;
    }
};

struct ulm_plus_t {
    // Data components
    std::vector<double> w;       ///< weight values for the x_values
    int x_min_index;             ///< the index of the the samallest x value in the larger dataset
    int x_max_index;             ///< the index of the the largest x value in the larger dataset

    // Model evaluation
    std::vector<double> predictions;   ///< predicted values
    std::vector<double> errors;        ///< Leave-One-Out Cross-Validation squared errors
};


ulm_t ulm(const double* x,
          const double* y,
          const std::vector<double>& w,
          bool y_binary = false,
          double epsilon = 1e-8);

ulm_t cleveland_ulm(
    const double* x,
    const double* y,
    const std::vector<double>& w,
    bool y_binary = false,
    double tolerance = 1e-6,
    int n_iter = 3,
    double robust_scale = 6.0);

#endif // ULM_HPP
