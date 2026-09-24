#pragma once
#include <cmath>
namespace ian::detail {
// usable means Solved, finite primal/dual/objective and positive active scales.
inline bool retry_eligible(bool usable, double objective_error, double primal,
                           double absolute, double stationarity, double negative, double gap) {
    return usable && std::isfinite(objective_error) && objective_error <= 1e-7 &&
        std::isfinite(primal) && std::isfinite(absolute) && std::isfinite(stationarity) &&
        std::isfinite(negative) && std::isfinite(gap) &&
        (primal > 1e-7 || stationarity > 1e-7 || negative > 1e-7 || gap > 1e-7);
}
}
