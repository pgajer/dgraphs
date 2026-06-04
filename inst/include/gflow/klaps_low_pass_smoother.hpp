#ifndef KLAPS_LOW_PASS_SMOOTHER_H_
#define KLAPS_LOW_PASS_SMOOTHER_H_

#include <vector>
#include <cstddef>

#include <Eigen/Core>

using std::size_t;

/// Result of low‑pass spectral smoothing with multiple k‑selection criteria
struct klaps_low_pass_smoother_t {
	/// All Laplacian eigenvalues λ_1 ≤ … ≤ λ_n
	std::vector<double>  evalues;

	/// Corresponding eigenvectors; each column is one eigenvector
	Eigen::MatrixXd  evectors;

	/// Candidate k’s (number of eigenvectors) evaluated
	std::vector<size_t>  candidate_ks;

	// —— Eigengap criterion ——
	/// λ_{i+1} − λ_i  for each candidate i
	std::vector<double>  eigengaps;
	/// argmax_i eigengaps[i]
	size_t   opt_k_eigengap;

	// —— Generalized Cross‐Validation (GCV) ——
	/// GCV score for each candidate k:
	///GCV(k) = ‖y − ŷ_k‖² / (n_vertices − k)²
	std::vector<double>  gcv_scores;
	/// argmin_k gcv_scores[k]
	size_t   opt_k_gcv;

	// —— Spectral‐energy threshold ——
	/// Cumulative energy fraction e₁ + … + e_k over total ∑ e_i
	std::vector<double>  spectral_energy;
	/// Smallest k with spectral_energy[k] ≥ energy_threshold
	size_t   opt_k_spectral_energy;

	/// Which method was used to produce `.predictions`
	enum class method_t { Eigengap, GCV, EnergyThreshold }
		used_method = method_t::GCV;

	/// Final, chosen smooth
	std::vector<double> predictions;

	/// Optionally: all intermediate smooths
	std::vector<std::vector<double>> k_predictions;
};

#endif // KLAPS_LOW_PASS_SMOOTHER_H_
