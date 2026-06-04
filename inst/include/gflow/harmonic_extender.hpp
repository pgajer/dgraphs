#ifndef HARMONIC_EXTENDER_HPP
#define HARMONIC_EXTENDER_HPP

#include <vector>
#include <cstddef>
using std::size_t;

struct harmonic_extender_t {
	std::vector<std::vector<double>> iterations; ///< Function values at each recorded iteration
	size_t num_iterations;                       ///< Total number of iterations performed
	bool converged;                              ///< Whether the algorithm converged
	double max_change_final;                     ///< Maximum change in the final iteration
};

#endif // HARMONIC_EXTENDER_HPP
