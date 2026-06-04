#ifndef GRAPH_SPECTRAL_LOWESS_HPP
#define GRAPH_SPECTRAL_LOWESS_HPP

#include <vector>

struct graph_spectral_lowess_t {
	std::vector<double> predictions;      ///< predictions[i] is an estimate of E(Y|G) at the i-th vertex
    std::vector<double> errors;           ///< errors[i] is an estimate of the prediction error at the i-th vertex
    std::vector<double> scale;            ///< scale[i] is a local scale (radius/bandwidth) at the i-th vertex
};

#endif // GRAPH_SPECTRAL_LOWESS_HPP
