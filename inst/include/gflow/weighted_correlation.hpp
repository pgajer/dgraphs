#ifndef WEIGHTED_CORRELATION_H_
#define WEIGHTED_CORRELATION_H_

#include <vector>

double calculate_weighted_correlation(
    const std::vector<double>& x,
    const std::vector<double>& y,
    const std::vector<double>& weights);

#endif // WEIGHTED_CORRELATION_H_
