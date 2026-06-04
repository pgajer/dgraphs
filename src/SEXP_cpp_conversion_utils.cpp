 // The helper functions follow these patterns:

 // Sets are converted to R vectors
 // Maps are converted to named R lists
 // Nested structures (vector of sets, etc.) become nested R lists
 // All numeric values are properly converted to R integer or real types

#include "SEXP_cpp_conversion_utils.hpp"

/**
 * @brief Helper function to convert mean shift smoothing results to an R list.
 *
 * This function takes the results of the mean shift smoothing algorithm (trajectory of points
 * and median k-distances) and converts them into an R list structure. It is designed to be used
 * internally by the S_mean_shift_data_smoother function to prepare its return value for R.
 *
 * @param X_traj const std::vector<std::vector<std::vector<double>>>&
 *        A 3D vector representing the trajectory of points across all smoothing steps.
 *        - First dimension: steps
 *        - Second dimension: points
 *        - Third dimension: features of each point
 *
 * @param median_kdistances const std::vector<double>&
 *        A vector of median k-distances, one for each smoothing step.
 *
 * @return SEXP
 *         Returns an R list containing:
 *         - X_traj: A list of matrices, each representing the smoothed dataset at each step.
 *         - median_kdistances: A numeric vector of median k-distances.
 *
 * @note This function uses R's C API to create R objects. It handles the necessary memory
 *       protection (PROTECT/UNPROTECT) to prevent garbage collection issues.
 *
 * @Rf_warning This function assumes that the input vectors are not empty. It does not perform
 *          extensive Rf_error checking on the inputs.
 */
SEXP create_R_list(const std::vector<std::vector<std::vector<double>>>& X_traj,
                   const std::vector<double>& median_kdistances) {
    int n_steps = X_traj.size();
    int n_points = X_traj[0].size();
    int n_features = X_traj[0][0].size();

    // Create result list
    SEXP result = PROTECT(Rf_allocVector(VECSXP, 2));

    // Create and set names
    {
        SEXP names = PROTECT(Rf_allocVector(STRSXP, 2));
        SET_STRING_ELT(names, 0, Rf_mkChar("X_traj"));
        SET_STRING_ELT(names, 1, Rf_mkChar("median_kdistances"));
        Rf_setAttrib(result, R_NamesSymbol, names);
        UNPROTECT(1); // names
    }

    // Create trajectory list
    {
        SEXP X_traj_r = PROTECT(Rf_allocVector(VECSXP, n_steps));

        // Fill trajectory matrices
        for (int step = 0; step < n_steps; step++) {
            SEXP step_matrix = PROTECT(Rf_allocMatrix(REALSXP, n_points, n_features));

            double* matrix_ptr = REAL(step_matrix);
            for (int i = 0; i < n_points; i++) {
                for (int j = 0; j < n_features; j++) {
                    matrix_ptr[i + j * n_points] = X_traj[step][i][j];
                }
            }
            SET_VECTOR_ELT(X_traj_r, step, step_matrix);
            UNPROTECT(1); // release the temporary protection for this element
        }
        SET_VECTOR_ELT(result, 0, X_traj_r);
        UNPROTECT(1);
    }

    // Create median k-distances vector
    {
        SEXP median_kdistances_r = PROTECT(Rf_allocVector(REALSXP, median_kdistances.size()));
        std::copy(median_kdistances.begin(), median_kdistances.end(), REAL(median_kdistances_r));
        SET_VECTOR_ELT(result, 1, median_kdistances_r);
        UNPROTECT(1);
    }


    UNPROTECT(1); // result
    return result;
}

/**
 * @brief Converts an R matrix to a C++ vector of vectors.
 *
 * This function takes an R matrix (SEXP) as input and converts it to a C++
 * std::vector<std::vector<double>>. It handles the column-major storage of R matrices
 * and returns a row-major C++ representation.
 *
 * @param Rmatrix SEXP representing an R matrix. Must be a numeric (double) matrix.
 *
 * @return std::unique_ptr<std::vector<std::vector<double>>> A unique pointer to a vector of vectors
 *         where each inner vector represents a row of the input matrix.
 *
 * @throws Rf_error If the input is not a numeric matrix.
 *
 * @note This function assumes column-major storage for the input R matrix and converts it
 *       to a row-major format in the returned C++ structure.
 *
 * @Rf_warning The function does not perform any data type conversion. It assumes that the input
 *          matrix contains double precision floating point numbers.
 *
 * Example usage:
 * @code
 * SEXP R_matrix = ...; // Assume this is a valid R matrix
 * try {
 *     auto cpp_matrix = Rmatrix_to_cpp(R_matrix);
 *     // Use cpp_matrix...
 * } catch (const std::exception& e) {
 *     REprintf("Error: %s\n", e.what());
 * }
 * @endcode
 *
 * @see R_list_of_dvectors_to_cpp_vector_of_dvectors for converting R list of vectors to C++
 */
std::unique_ptr<std::vector<std::vector<double>>> Rmatrix_to_cpp(SEXP Rmatrix) {
     // Check if the input is a matrix
    if (!Rf_isMatrix(Rmatrix) || !Rf_isReal(Rmatrix)) {
        Rf_error("Rmatrix_to_cpp: Input must be a numeric matrix");
    }

     // Get matrix dimensions
    SEXP Rdim = Rf_getAttrib(Rmatrix, R_DimSymbol);
    if (Rdim == R_NilValue || Rf_length(Rdim) != 2) {
        Rf_error("Rmatrix_to_cpp: Input must be a matrix");
    }
    int nrows = INTEGER(Rdim)[0];
    int ncols = INTEGER(Rdim)[1];

     // Get pointer to matrix data
    double* matrix_data = REAL(Rmatrix);

     // Create and populate the C++ vector of vectors
    auto cpp_matrix = std::make_unique<std::vector<std::vector<double>>>(nrows);

    for (int i = 0; i < nrows; ++i) {
        (*cpp_matrix)[i].reserve(ncols);
        for (int j = 0; j < ncols; ++j) {
             // R matrices are column-major, so we need to calculate the correct index
            (*cpp_matrix)[i].push_back(matrix_data[i + j * nrows]);
        }
    }

    return cpp_matrix;
}

/**
 * Converts an R numeric vector to a C++ vector of doubles.
 *
 * This function takes an R numeric vector (`Ry`) and converts it to a C++ vector
 * (`std::vector<double>`). The function iterates over each element of the R vector,
 * extracts the double value, and assigns it to the corresponding element of the
 * C++ vector.
 *
 * Caller Responsibility: The caller should ensure that `Ry` is protected before
 * passing it to `Rvect_to_CppVect_double`.
 *
 * Function Assumption: The `Rvect_to_CppVect_double` function assumes that the passed
 * `Ry` is protected and does not need to protect it again.
 *
 * Protection Management: The caller should manage the protection lifecycle of `Ry`,
 * ensuring it remains protected for the duration of its use.
 *
 * @param Ry An R numeric vector.
 *
 * @return A unique pointer to a C++ vector of doubles (`std::unique_ptr<std::vector<double>>`)
 *         representing the values in the R numeric vector.
 */
std::unique_ptr<std::vector<double>> Rvect_to_CppVect_double(SEXP Ry) {
    std::vector<double> y(REAL(Ry), REAL(Ry) + LENGTH(Ry));
    return std::make_unique<std::vector<double>>(std::move(y));
}

/**
 * @brief Converts an R list of numeric vectors to a C++ vector of vectors of doubles.
 *
 * This function takes an R object (SEXP) representing a list of double vectors and
 * converts it to a C++ std::vector<std::vector<double>>.
 *
 * @param Rvectvect An R object (SEXP) representing a list of double vectors.
 * @return A unique pointer to a vector of vectors of doubles.
 *
 * @note The function assumes that Rvectvect is a valid R list of double vectors.
 *       It does not perform extensive Rf_error checking on the input.
 */
std::unique_ptr<std::vector<std::vector<double>>> R_list_of_dvectors_to_cpp_vector_of_dvectors(SEXP Rvectvect) {
    int n_vertices = LENGTH(Rvectvect);
    auto cpp_vect_list = std::make_unique<std::vector<std::vector<double>>>(n_vertices);

    for (int i = 0; i < n_vertices; ++i) {
        SEXP R_vector = VECTOR_ELT(Rvectvect, i);
        int vector_length = LENGTH(R_vector);
        double* double_vector = REAL(R_vector);

        (*cpp_vect_list)[i].reserve(vector_length);
        (*cpp_vect_list)[i].assign(double_vector, double_vector + vector_length);
    }

    return cpp_vect_list;
}

/**
 * @brief Converts an R adjacency list to a C++ vector representation
 *
 * @details This function takes an R SEXP object representing an adjacency list
 * and converts it to a C++ nested vector representation. The function expects
 * the input to be a list of integer vectors, where each vector contains the
 * indices of adjacent vertices. The function performs input validation to ensure
 * the proper format.
 *
 * @param s_adj_list An R SEXP object representing an adjacency list
 * @return std::vector<std::vector<int>> A C++ nested vector representation of the adjacency list
 * @throws R Rf_error if the input is not a list or contains non-integer vectors
 *
 * @note The function assumes indices are already adjusted for C++ (0-based indexing)
 */
std::vector<std::vector<int>> convert_adj_list_from_R(SEXP s_adj_list) {
  if (TYPEOF(s_adj_list) != VECSXP) {
    Rf_error("convert_adj_list_from_R: expected a list (VECSXP).");
  }

  const R_xlen_t n_vertices = XLENGTH(s_adj_list);
  std::vector<std::vector<int>> adj(static_cast<size_t>(n_vertices));

  for (R_xlen_t i = 0; i < n_vertices; ++i) {
    SEXP v = VECTOR_ELT(s_adj_list, i);
    if (TYPEOF(v) != INTSXP) {
      Rf_error("convert_adj_list_from_R: adj[[%lld]] must be an integer vector.",
               static_cast<long long>(i + 1));
    }

    const R_xlen_t deg = XLENGTH(v);
    const int* pv = INTEGER(v);
    auto& row = adj[static_cast<size_t>(i)];
    row.resize(static_cast<size_t>(deg));

    for (R_xlen_t j = 0; j < deg; ++j) {
      const int idx = pv[j];
      if (idx == NA_INTEGER) {
        Rf_error("convert_adj_list_from_R: adj[[%lld]][%lld] is NA.",
                 static_cast<long long>(i + 1), static_cast<long long>(j + 1));
      }
      if (idx < 0 || idx >= n_vertices) {
        Rf_error("convert_adj_list_from_R: index %d out of range at adj[[%lld]][%lld]; "
                 "expected 0..%lld.",
                 idx,
                 static_cast<long long>(i + 1),
                 static_cast<long long>(j + 1),
                 static_cast<long long>(n_vertices - 1));
      }
      row[static_cast<size_t>(j)] = idx; // keep 0-based as provided
    }
  }

  return adj;
}

/**
 * \brief Converts an R weight list (list of numeric vectors) to
 *        std::vector<std::vector<double>>.
 *
 * \details
 *   - Input is either \c NULL (meaning “no weights”) or a list (\c VECSXP).
 *   - Each list element is a numeric vector (\c REALSXP); a \c NULL element
 *     becomes an empty \c std::vector<double>.
 *   - The function copies values into C++ containers and does not allocate
 *     any SEXPs (pure read), so no PROTECT/UNPROTECT is needed here.
 *
 * \param s_weight_list R object holding the weight list; may be \c R_NilValue.
 *
 * \return A nested \c std::vector<double> with the same outer length as
 *         \c s_weight_list (or empty when \c s_weight_list is \c NULL).
 *         Inner vectors preserve the element order from R.
 *
 * \pre s_weight_list == \c R_NilValue || TYPEOF(s_weight_list) == \c VECSXP.
 * \pre For every i, \c weight_list[[i]] is \c REALSXP or \c R_NilValue.
 *
 * \post Returned container size equals \c XLENGTH(s_weight_list) (or 0 if \c NULL).
 *
 * \throws Calls \c Rf_error() if \c s_weight_list is not a list or any element
 *         is non-numeric.
 *
 * \note Shape consistency with the adjacency list (same outer length and
 *       per-vertex degree) is validated by the caller.
 */
std::vector<std::vector<double>> convert_weight_list_from_R(SEXP s_weight_list) {
  // Allow NULL to mean “no weights supplied”
  if (s_weight_list == R_NilValue) {
    return {};
  }

  if (TYPEOF(s_weight_list) != VECSXP) {
    Rf_error("convert_weight_list_from_R: expected a list (VECSXP).");
  }

  const R_xlen_t n_vertices = XLENGTH(s_weight_list);
  std::vector<std::vector<double>> weights(static_cast<size_t>(n_vertices));

  for (R_xlen_t i = 0; i < n_vertices; ++i) {
    SEXP v = VECTOR_ELT(s_weight_list, i);

    // Treat NULL element as empty weight vector for that vertex
    if (v == R_NilValue) {
      weights[static_cast<size_t>(i)].clear();
      continue;
    }

    if (TYPEOF(v) != REALSXP) {
      Rf_error("convert_weight_list_from_R: weight_list[[%lld]] must be a numeric (double) vector.",
               static_cast<long long>(i + 1));
    }

    const R_xlen_t nw = XLENGTH(v);
    const double* pv = REAL(v);

    auto& row = weights[static_cast<size_t>(i)];
    row.resize(static_cast<size_t>(nw));
    for (R_xlen_t j = 0; j < nw; ++j) {
      row[static_cast<size_t>(j)] = pv[j];
    }
  }

  return weights;
}

/**
 * Converts a C++ vector of vectors of integers to an R list of integer vectors.
 *
 * This function takes a C++ std::vector<std::vector<int>> and converts it to an R list
 * of integer vectors. Each inner vector of the input is converted to an R integer vector,
 * and these vectors are combined into an R list.
 *
 * @param cpp_vec_vec The input C++ vector of vectors of integers to be converted.
 * @return An R list of integer vectors representing the converted input in the PROTECTed state!
 */
SEXP convert_vector_vector_int_to_R(const std::vector<std::vector<int>>& x) {

  const size_t n = x.size();
  SEXP out = PROTECT(Rf_allocVector(VECSXP, n));

  for (size_t i = 0; i < n; ++i) {
    const auto& vi = x[i];
    const size_t m = vi.size();
    SEXP v = PROTECT(Rf_allocVector(INTSXP, m));
    int* pv = INTEGER(v);
    for (size_t j = 0; j < m; ++j) {
      pv[j] = vi[j];
    }
    SET_VECTOR_ELT(out, i, v);
    UNPROTECT(1);
  }

  UNPROTECT(1); // out
  return out;
}

/**
 * @brief Converts a C++ vector of vectors of doubles to an R list of numeric vectors
 *
 * @param vec Input vector of vectors of doubles to convert
 * @return SEXP A protected R list where each element is a numeric vector
 *             corresponding to the inner vectors of the input
 *
 * @details This function takes a C++ nested vector structure containing double values
 *          and converts it to an R list where each element is a numeric vector.
 *          The function handles all necessary R object protection and unprotection.
 *          The double precision values are preserved in the conversion process.
 *
 * @note The returned SEXP object is the PROTECTed state and should be unprotected by the caller
 *
 * @Rf_warning The function assumes the input vector is valid and non-null. Empty vectors
 *          are handled correctly but not specially treated.
 *
 * @see REAL, PROTECT, UNPROTECT, Rf_allocVector, SET_VECTOR_ELT
 */
SEXP convert_vector_vector_double_to_R(const std::vector<std::vector<double>>& x) {

  const size_t n = x.size();
  SEXP out = PROTECT(Rf_allocVector(VECSXP, n));

  for (size_t i = 0; i < n; ++i) {
    const auto& vi = x[i];
    const size_t m = vi.size();
    SEXP v = PROTECT(Rf_allocVector(REALSXP, m));
    double* pv = REAL(v);
    for (size_t j = 0; j < m; ++j) {
      pv[j] = vi[j];
    }
    SET_VECTOR_ELT(out, i, v);
    UNPROTECT(1);  // release element temporary
  }

  UNPROTECT(1); // out
  return out;
}

/**
 * @brief Converts a C++ vector of vectors of booleans to an R list of logical vectors
 *
 * @param vec Input vector of vectors of booleans to convert
 * @return SEXP A protected R list where each element is a logical vector
 *             corresponding to the inner vectors of the input
 *
 * @details This function takes a C++ nested vector structure containing boolean values
 *          and converts it to an R list where each element is a logical vector.
 *          The function handles all necessary R object protection and unprotection.
 *          Each inner vector becomes a logical vector in R, preserving the boolean values.
 *
 * @note The returned SEXP object is protected once and should be unprotected by the caller
 *       if necessary
 *
 * @Rf_warning The function assumes the input vector is valid and non-null. Empty vectors
 *          are handled correctly but not specially treated.
 */
SEXP convert_vector_vector_bool_to_R(const std::vector<std::vector<bool>>& x) {

  const size_t n = static_cast<size_t>(x.size());
  SEXP out = PROTECT(Rf_allocVector(VECSXP, n));

  for (size_t i = 0; i < n; ++i) {
    const auto& vi = x[i];
    const size_t m = vi.size();
    SEXP v = PROTECT(Rf_allocVector(LGLSXP, m));
    int* pv = LOGICAL(v);
    for (size_t j = 0; j < m; ++j) {
      pv[j] = vi[j] ? 1 : 0;
    }
    SET_VECTOR_ELT(out, i, v);
    UNPROTECT(1);
  }

  UNPROTECT(1); // out
  return out;
}

/**
 * @brief Converts a C++ vector of vectors to an R matrix
 *
 * @details
 * This function handles the conversion from C++ std::vector<std::vector<double>>
 * to an R matrix (SEXP), accounting for:
 * - R's column-major order storage
 * - Memory protection
 * - Empty input handling
 *
 * The function performs the following steps:
 * 1. Checks for empty input
 * 2. Allocates R matrix
 * 3. Copies data with transposition for column-major order
 * 4. Handles memory protection
 *
 * @param data Input vector of vectors where:
 *             - Outer vector represents rows
 *             - Inner vectors represent columns
 *             - All inner vectors must have the same size
 *             - data[i][j] represents element at row i, column j
 *
 * @return SEXP (REALSXP matrix) where:
 *         - Returns R_NilValue if input is empty
 *         - Returns nrow × ncol matrix otherwise
 *         - Matrix is column-major ordered as required by R
 *         - Matrix elements are copied from input with proper transposition
 *
 * @note Memory Management:
 *       - Uses PROTECT/UNPROTECT for R object safety
 *       - Caller does not need to UNPROTECT the result
 *       - Properly handles cleanup on Rf_error
 *
 * @Rf_warning
 *       - Assumes all inner vectors have the same length
 *       - Does not verify inner vector size consistency
 *       - May cause undefined behavior if inner vectors differ in size
 *
 * @see convert_vector_double_to_R For single vector conversion
 * @see convert_vector_int_to_R For integer vector conversion
 *
 * @example
 * ```cpp
 * std::vector<std::vector<double>> data = {{1.0, 2.0}, {3.0, 4.0}};
 * SEXP matrix = convert_vector_vector_double_to_matrix(data);
 * // Results in 2×2 R matrix:
 * // [,1] [,2]
 * // [1,]  1.0  2.0
 * // [2,]  3.0  4.0
 * ```
 */
SEXP convert_vector_vector_double_to_matrix(const std::vector<std::vector<double>>& data) {

  // Empty -> type-stable 0x0 matrix
  if (data.empty()) {
    SEXP out0 = PROTECT(Rf_allocMatrix(REALSXP, 0, 0));
    UNPROTECT(1);
    return out0;
  }

  const size_t nrow = data.size();
  const size_t ncol = data.front().size();

  // Rectangular check
  for (size_t i = 1; i < nrow; ++i) {
    if (data[i].size() != ncol) {
      Rf_error("convert_vector_vector_double_to_matrix: ragged input at row %lld",
               static_cast<long long>(i + 1));
    }
  }

  // Guard against INT overflow in Rf_allocMatrix arguments
  if (nrow > INT_MAX || ncol > INT_MAX) {
    Rf_error("convert_vector_vector_double_to_matrix: dimensions exceed matrix limits");
  }

  SEXP M = PROTECT(Rf_allocMatrix(REALSXP, static_cast<int>(nrow), static_cast<int>(ncol)));
  double* pm = REAL(M);

  // Fill column-major: [i + j*nrow]
  for (size_t j = 0; j < ncol; ++j) {
    for (size_t i = 0; i < nrow; ++i) {
      pm[i + j * nrow]
        = data[i][j];
    }
  }

  UNPROTECT(1); // M
  return M;
}

/**
 * @brief Converts a C++ vector of doubles to an R numeric vector (REALSXP)
 *
 * @details
 * Creates an R numeric vector from a C++ std::vector<double>, copying all elements.
 * The function properly protects the R vector during creation and returns it
 * in a protected state for further use.
 *
 * @param vec The std::vector<double> to convert
 * @return SEXP (UNPROTECTED).
 *
 */
SEXP convert_vector_double_to_R(const std::vector<double>& vec) {

  const size_t n = vec.size();
  SEXP Rvec = Rf_allocVector(REALSXP, n);
  double* p = REAL(Rvec);
  for (size_t i = 0; i < n; ++i) {
    p[i] = vec[i];
  }

  return Rvec;
}


/**
 * @brief Converts a C++ vector of integers to an R integer vector
 *
 * @param vec Input vector of integers to convert
 * @return SEXP An unprotected R integer vector containing the same values as the input
 *
 * @details This function takes a C++ vector of integers and converts it to an R integer
 *          vector, preserving all values. The function handles the necessary R object
 *          protection and unprotection.
 *
 * @note The returned SEXP object is unprotected and should be either immediately returned or protected
 *
 * @Rf_warning The function assumes the input vector is valid. No range checking is performed
 *          on the integer values, so values outside the range of R's integers may cause
 *          undefined behavior
 *
 * @see INTEGER, PROTECT, UNPROTECT, Rf_allocVector
 */
SEXP convert_vector_int_to_R(const std::vector<int>& vec) {

  const size_t n = vec.size();
  SEXP Rvec = Rf_allocVector(INTSXP, n);
  int* p = INTEGER(Rvec);
  for (size_t i = 0; i < n; ++i) {
    p[i] = vec[i];
  }

  return Rvec;
}

/**
 * @brief Converts a C++ vector of booleans to an R logical vector
 *
 * @param vec Input vector of booleans to convert
 * @return SEXP Aa unprotected R logical vector containing the same values as the input
 *
 * @details This function takes a C++ vector of booleans and converts it to an R logical
 *          vector, preserving the boolean values. The function handles the necessary R
 *          object protection and unprotection. Note that R's logical values are stored
 *          as integers internally (0 for FALSE, 1 for TRUE).
 *
 * @note The returned SEXP object is unprotected and should be either immediately returned or protected
 *
 * @Rf_warning Special consideration should be given to std::vector<bool> which is a specialized
 *          template that packs booleans into bits for space efficiency
 *
 * @see LOGICAL, PROTECT, UNPROTECT, Rf_allocVector
 */
SEXP convert_vector_bool_to_R(const std::vector<bool>& vec) {

  const size_t n = vec.size();
  SEXP Rvec = Rf_allocVector(LGLSXP, n);
  int* p = LOGICAL(Rvec);
  for (size_t i = 0; i < n; ++i) {
    p[i] = vec[i] ? 1 : 0;
  }

  return Rvec;
}

/**
 * @brief Converts a C++ unordered map to an R named list of integer vectors
 *
 * @param cpp_map_int_vect_int An unordered_map from integers to vectors of integers
 * @param names Vector of integers to use as component names
 * @return SEXP A protected R list where each element is an integer vector with named components
 *
 * @details The function creates an R list where:
 *          - Each map key determines the position in the list
 *          - Each map value becomes an integer vector
 *          - List length equals (maximum key + 1)
 *          - Missing keys result in NULL elements
 *          - Names vector must match the list length
 *
 * @throws R Rf_error if names vector length doesn't match list length
 *
 * @example
 * Input map: {{1, {1,2}}, {3, {4,5}}}
 * Names: {10, 20, 30, 40}
 * Result: List of length 4:
 *   [[1]] = c(1,2)      name: "10"
 *   [[2]] = NULL        name: "20"
 *   [[3]] = c(4,5)      name: "30"
 *   [[4]] = NULL        name: "40"
 */
SEXP convert_map_int_vector_int_to_R(
    const std::map<int, std::vector<int>>& m,
    const std::vector<std::string>& names
) {
    if (m.empty()) {
        SEXP out = PROTECT(Rf_allocVector(VECSXP, 0));
        if (!names.empty()) {
            SEXP nm = PROTECT(Rf_allocVector(STRSXP, 0));
            Rf_setAttrib(out, R_NamesSymbol, nm);
            UNPROTECT(2); // out, nm
        } else {
            UNPROTECT(1); // out
        }
        return out;
    }

    int max_key = -1;
    for (const auto& kv : m) {
        const int key = kv.first;
        if (key < 0) Rf_error("convert_map_int_vector_int_to_R: negative key %d not allowed", key);
        if (key > max_key) max_key = key;
    }

    const int list_len = max_key + 1;
    if (!names.empty() && (int)names.size() != list_len) {
        Rf_error("convert_map_int_vector_int_to_R: names.size() (%d) != max_key+1 (%d)",
                 (int)names.size(), list_len);
    }

    SEXP out = PROTECT(Rf_allocVector(VECSXP, list_len));

    // init to integer(0)
    for (int i = 0; i < list_len; ++i) {
        SEXP empty = PROTECT(Rf_allocVector(INTSXP, 0));
        SET_VECTOR_ELT(out, i, empty);
        UNPROTECT(1);
    }

    // fill present keys (LENGTH-first)
    for (const auto& kv : m) {
        const int key = kv.first;
        const auto& v  = kv.second;
        if ((size_t)v.size() > (size_t)INT_MAX) Rf_error("vector too large");
        const int n = (int)v.size();

        SEXP Ri = PROTECT(Rf_allocVector(INTSXP, n));
        int* pi = INTEGER(Ri);
        for (int j = 0; j < n; ++j) pi[j] = v[(size_t)j];
        SET_VECTOR_ELT(out, key, Ri);
        UNPROTECT(1);
    }

    if (!names.empty()) {
        SEXP nm = PROTECT(Rf_allocVector(STRSXP, list_len));
        for (int i = 0; i < list_len; ++i) {
            SET_STRING_ELT(nm, i, Rf_mkCharCE(names[(size_t)i].c_str(), CE_UTF8));
        }
        Rf_setAttrib(out, R_NamesSymbol, nm);
        UNPROTECT(1);
    }

    UNPROTECT(1); // out
    return out;
}

/**
 * Converts a C++ unordered map of integers to integer sets into an R list of integer vectors.
 *
 * This function takes a C++ std::unordered_map<int, std::set<int>> and converts
 * it to an R list of integer vectors. Each inner set of the input is converted
 * to an R integer vector, and these vectors are combined into an R list.
 *
 * @param cpp_map_int_set_int The input C++ unordered map from integers to sets of integers to be converted.
 * @return An R list of integer vectors representing the converted input.
 *
 * @note The function assumes that the keys of the input map are non-negative integers.
 * The resulting R list will have a length equal to the maximum key value plus one,
 * and the elements corresponding to missing keys will be NULL.
 *
 * @note The function uses 1-based indexing for the R list, consistent with R's indexing convention.
 * @note The function protects the allocated R objects to prevent memory leaks.
 */
SEXP Cpp_map_int_set_int_to_Rlist(const std::unordered_map<int, std::set<int>>& cpp_map_int_set_int) {
    // ---- First pass: validate and find max key (no PROTECTs yet) ----
    if (cpp_map_int_set_int.empty()) {
        // Return an empty list; no elements to fill.
        SEXP empty = PROTECT(Rf_allocVector(VECSXP, 0));
        UNPROTECT(1);
        return empty;
    }

    int max_key = 0;
    for (const auto& kv : cpp_map_int_set_int) {
        const int key = kv.first;
        if (key < 0) {
            Rf_error("Cpp_map_int_set_int_to_Rlist(): negative key %d is not allowed.", key);
        }
        if (key > max_key) max_key = key;
    }

    SEXP Rlist = PROTECT(Rf_allocVector(VECSXP, max_key + 1)); // [P1]

    // R initializes VECSXP slots to NULL; we fill only those present in the map.
    for (const auto& kv : cpp_map_int_set_int) {
        const int key = kv.first;
        const std::set<int>& s = kv.second;

        // key is guaranteed 0..max_key by the validation pass above.
        const size_t m = s.size();
        SEXP Rvec = PROTECT(Rf_allocVector(INTSXP, m));      // [P2]
        int* ptr = INTEGER(Rvec);
        size_t j = 0;
        for (int e : s) ptr[j++] = e;

        SET_VECTOR_ELT(Rlist, key, Rvec);
        UNPROTECT(1); // [/P2]
    }

    UNPROTECT(1); // [/P1] unprotect the list before returning
    return Rlist;
}

/**
 * @brief Converts a C++ vector of integer pairs to an R matrix (unique pointer version)
 *
 * This function takes a unique pointer to a vector of integer pairs and
 * converts it to an R matrix with two columns. Each pair in the input vector
 * becomes a row in the output matrix.
 *
 * @param cpp_vector A unique pointer to a vector of integer pairs to be converted
 * @return SEXP An R matrix (INTSXP) with two columns, containing the data from the input vector
 *
 * @note The function uses PROTECT/UNPROTECT to manage R's garbage collection.
 *       Caller does not need to UNPROTECT the returned SEXP.
 *
 * @Rf_warning The function assumes that the input vector is not empty. Behavior is
 *          undefined for empty vectors.
 */
SEXP uptr_vector_of_pairs_to_R_matrix(
    const std::unique_ptr<std::vector<std::pair<int,int>>>& v
){
    if (!v) {                        // unique_ptr holds no object
        return Rf_allocMatrix(INTSXP, 0, 2);
    }
    const size_t nsz = v->size();
    if (nsz > (size_t)INT_MAX) Rf_error("Too many rows for INT matrix");
    const int n_rows = (int) nsz;

    SEXP Rmat = Rf_allocMatrix(INTSXP, n_rows, 2);
    int* x = INTEGER(Rmat);
    for (int i = 0; i < n_rows; ++i) {
        x[i]          = (*v)[(size_t)i].first  + 1;
        x[i + n_rows] = (*v)[(size_t)i].second + 1;
    }
    return Rmat; // UNPROTECTED on return - caller protects or inserts immediately
}

/**
 * @brief Converts a C++ vector of integer pairs to an R matrix
 *
 * This function takes a vector of integer pairs and converts it to an R matrix
 * with two columns. Each pair in the input vector becomes a row in the output matrix.
 *
 * @param cpp_vector A const reference to a vector of integer pairs to be converted
 * @return SEXP An R matrix (INTSXP) with two columns, containing the data from the input vector
 *
 * @note Caller needs to UNPROTECT the returned SEXP.
 *
 * @Rf_warning The function assumes that the input vector is not empty. Behavior is
 *          undefined for empty vectors.
 */
SEXP cpp_vector_of_pairs_to_R_matrix(const std::vector<std::pair<int,int>>& v) {
    const size_t nsz = v.size();
    if (nsz > (size_t)INT_MAX) Rf_error("Too many rows for INT matrix");
    const int n_rows = (int)nsz;

    SEXP Rmat = Rf_allocMatrix(INTSXP, n_rows, 2);
    int* x = INTEGER(Rmat);
    for (int i = 0; i < n_rows; ++i) {
        x[i]          = v[(size_t)i].first  + 1;
        x[i + n_rows] = v[(size_t)i].second + 1;
    }
    return Rmat; // leaf
}

/**
 * @brief Converts a flat C++ vector to an R matrix.
 *
 * This function takes a flat C++ vector representing a matrix in column-major order
 * and converts it into an R matrix object (SEXP). The function is particularly
 * useful for interfacing C++ functions that return flat matrices with R, where
 * matrix objects are more commonly used.
 *
 * @param flat_matrix A const reference to a std::vector<double> containing the
 *                    matrix elements in column-major order.
 * @param nrow The number of rows in the matrix.
 * @param ncol The number of columns in the matrix.
 *
 * @return SEXP A PROTECT'd R matrix object (REALSXP) containing the data from
 *              the input flat_matrix. The caller is responsible for calling
 *              UNPROTECT(1) after using the returned object.
 *
 * @note This function allocates memory for a new R matrix and copies the data
 *       from the input vector. The input vector is not modified.
 *
 * @warning The function assumes that the size of flat_matrix is equal to
 *          nrow * ncol. No bounds checking is performed, so ensure the input
 *          parameters are consistent to avoid undefined behavior.
 *
 * @see S_shortest_path for an example of how this function is used in
 *      conjunction with R interface functions.
 *
 * Example usage:
 * @code
 * std::vector<double> flat_mat = {1.0, 2.0, 3.0, 4.0};
 * SEXP r_mat = flat_vector_to_R_matrix(flat_mat, 2, 2); // already PROTECT'ed
 * // Use r_mat...
 * UNPROTECT(1); // r_mat
 * @endcode
 */
SEXP flat_vector_to_R_matrix(const std::vector<double>& flat_matrix, int nrow, int ncol) {
    SEXP r_matrix = Rf_allocMatrix(REALSXP, nrow, ncol);
    double* matrix_ptr = REAL(r_matrix);
    for (int i = 0; i < nrow * ncol; ++i) {
        matrix_ptr[i] = flat_matrix[i];
    }

    return r_matrix; // UNPROTECTED on return
}

/**
 * @brief Converts a C++ set of integers into an R integer vector.
 *
 * This utility allocates a new R integer vector (`INTSXP`) of length equal
 * to the size of the input set and copies each element into it in order.
 *
 * @param set A std::set<int> containing the integer values to be converted.
 *
 * @return SEXP An R integer vector containing all elements from the set.
 *
 * @note The returned SEXP is returned in a PROTECTed state.
 *       Callers must balance this by invoking `UNPROTECT(1)` after the object
 *       has been stored in a container (e.g. via `SET_VECTOR_ELT`) or otherwise
 *       made safe. This pattern follows the rchk-safe "producer returns protected,
 *       caller unprotects" convention.
 *
 * @warning No checks are performed on the contents of the set; ensure the values
 *          are valid integers for your R use case.
 *
 * @see The pragmatic rchk guidelines (container-first, fixed UNPROTECT) for how
 *      to safely integrate this helper into higher-level list/matrix assemblers.
 */
SEXP convert_set_to_R(const std::set<int>& set) {
    const int n = (int)set.size();
    SEXP Rvec = Rf_allocVector(INTSXP, n);
    int* ptr = INTEGER(Rvec);
    int i = 0;
    for (int v : set) ptr[i++] = v;
    return Rvec; // UNPROTECTED on return - caller protects or inserts immediately
}

/**
 * @brief Converts a C++ map from integers to sets of integers to a named R list
 *
 * @param map_set Input map where keys are integers and values are sets of integers
 * @return SEXP Named R list where names are the keys from the map (as strings)
 *              and values are integer vectors (converted from sets)
 *
 * @note List names are created by converting integer keys to strings
 * @note The returned SEXP is returned in a PROTECTed state.
 *       Callers must balance this by invoking `UNPROTECT(1)` after the object
 *       has been stored in a container (e.g. via `SET_VECTOR_ELT`) or otherwise
 *       made safe. This pattern follows the rchk-safe "producer returns protected,
 *       caller unprotects" convention.
 */
SEXP convert_map_set_to_R(const std::map<int, std::set<int>>& map_set) {
    const int n = (int)map_set.size();

    SEXP Rlist = PROTECT(Rf_allocVector(VECSXP, n)); // protect parent immediately

    // Names under protection while we create strings
    {
        SEXP names = PROTECT(Rf_allocVector(STRSXP, n));
        int i = 0;
        for (const auto& kv : map_set) {
            // Use UTF-8 to be explicit about encoding
            SET_STRING_ELT(names, i++, Rf_mkCharCE(std::to_string(kv.first).c_str(), CE_UTF8));
        }
        Rf_setAttrib(Rlist, R_NamesSymbol, names);
        UNPROTECT(1); // names
    }

    // Fill elements: alloc child → SET_VECTOR_ELT right away (no allocations in between)
    {
        int i = 0;
        for (const auto& kv : map_set) {
            SEXP tmp = convert_set_to_R(kv.second); // returns UNPROTECTED, does no post-alloc allocations
            SET_VECTOR_ELT(Rlist, i++, tmp);        // safe: parent is protected
        }
    }

    UNPROTECT(1); // Rlist
    return Rlist; // unprotected to caller; caller may PROTECT if doing more work
}

/**
 * @brief Converts a C++ map from integer pairs to vectors of integer sets to a named R list
 *
 * @param map_vec_set Input map where keys are pairs of integers and values are vectors of integer sets
 * @return SEXP Named R list where:
 *              - Names are created by concatenating the pair of keys with underscore ("key1_key2")
 *              - Each value is a list of integer vectors (converted from vector of sets)
 *
 * @note Creates a nested list structure to represent the vector of sets
 * @note The returned SEXP is PROTECTed state.
 */
SEXP convert_map_vector_set_to_R(
    const std::map<std::pair<int,int>, std::vector<std::set<int>>>& map_vec_set
) {
    const int n = (int)map_vec_set.size();
    SEXP Rlist = PROTECT(Rf_allocVector(VECSXP, n));

    SEXP names = PROTECT(Rf_allocVector(STRSXP, n));
    int i = 0;
    for (const auto& pair : map_vec_set) {
        const size_t inner_n = pair.second.size();
        if (inner_n > (size_t)INT_MAX) Rf_error("inner list too large");

        SEXP inner_list = PROTECT(Rf_allocVector(VECSXP, (int)inner_n));
        for (size_t j = 0; j < inner_n; ++j) {
            // child is a leaf; insert immediately; NO PROTECT needed; NO UNPROTECT here
            SEXP tmp = convert_set_to_R(pair.second[j]);
            SET_VECTOR_ELT(inner_list, (int)j, tmp);
        }

        std::string name = std::to_string(pair.first.first) + "_" + std::to_string(pair.first.second);
        SET_STRING_ELT(names, i, Rf_mkCharCE(name.c_str(), CE_UTF8));

        SET_VECTOR_ELT(Rlist, i, inner_list);
        UNPROTECT(1); // inner_list
        ++i;
    }
    Rf_setAttrib(Rlist, R_NamesSymbol, names);
    UNPROTECT(2); // names, Rlist
    return Rlist;
}

/**
 * @brief Converts a C++ map of cell trajectories to a named R list
 *
 * @param cell_traj Input map where keys are cell_t structures and values are sets of size_t indices
 * @return SEXP Named R list where:
 *              - Names are created by concatenating cell components ("lmax_lmin_cell_index")
 *              - Values are integer vectors containing trajectory indices
 *
 * @note The returned SEXP is the PROTECTed state.
 * @note Converts size_t values to integers for R compatibility
 */
SEXP convert_cell_trajectories_to_R(const std::map<cell_t, std::set<size_t>>& cell_traj) {
    int n = cell_traj.size();
    SEXP Rlist = PROTECT(Rf_allocVector(VECSXP, n));

    {
        SEXP names = PROTECT(Rf_allocVector(STRSXP, n));
        int i = 0;
        for (const auto& pair : cell_traj) {
            // Convert set of size_t to vector of integers
            SEXP Rvec = PROTECT(Rf_allocVector(INTSXP, pair.second.size()));
            int* ptr = INTEGER(Rvec);
            int j = 0;
            for (const auto& val : pair.second) {
                ptr[j++] = static_cast<int>(val);
            }

            // Create name from cell_t components
            std::string name = std::to_string(pair.first.lmax) + "_" +
                std::to_string(pair.first.lmin) + "_" +
                std::to_string(pair.first.cell_index);
            SET_STRING_ELT(names, i, Rf_mkChar(name.c_str()));

            SET_VECTOR_ELT(Rlist, i, Rvec);
            UNPROTECT(1); // Rvec
            i++;
        }
        Rf_setAttrib(Rlist, R_NamesSymbol, names);
        UNPROTECT(1);
    }

    UNPROTECT(1); // Rlist
    return Rlist; // UNPROTECTED on return - caller protects or inserts immediately
}


/**
 * @brief Converts a C++ map from integer pairs to vectors of integers to a named R list
 *
 * @param map_vec Input map where keys are pairs of integers and values are vectors of integers
 * @return SEXP Named R list where:
 *              - Names are created by concatenating the pair of keys with underscore ("key1_key2")
 *              - Values are integer vectors
 *
 * @note The returned SEXP is in the PROTECTed state.
 */
SEXP convert_map_vector_to_R(const std::map<std::pair<int,int>, std::vector<int>>& map_vec) {

    int n = map_vec.size();
    SEXP Rlist = PROTECT(Rf_allocVector(VECSXP, n));

    {
        SEXP names = PROTECT(Rf_allocVector(STRSXP, n));

        int i = 0;
        for (const auto& pair : map_vec) {
            // Convert vector to R vector
            SEXP Rvec = PROTECT(Rf_allocVector(INTSXP, pair.second.size()));
            int* ptr = INTEGER(Rvec);
            for (size_t j = 0; j < pair.second.size(); ++j) {
                ptr[j] = pair.second[j];
            }

            // Set the name as "key1_key2"
            std::string name = std::to_string(pair.first.first) + "_" + std::to_string(pair.first.second);
            SET_STRING_ELT(names, i, Rf_mkChar(name.c_str()));

            SET_VECTOR_ELT(Rlist, i, Rvec);
            UNPROTECT(1); // Rvec
            i++;
        }

        Rf_setAttrib(Rlist, R_NamesSymbol, names);
        UNPROTECT(1);
    }

    UNPROTECT(1); // Rlist
    return Rlist; // UNPROTECTED on return - caller protects or inserts immediately
}

/**
 * @brief Converts a named R list to a C++ map from integer pairs to vectors of integers
 *
 * This is an inverse of convert_map_vector_to_R
 *
 * @param Rlist Input named R list where:
 *              - Names are strings in the format "key1_key2" where key1 and key2 are integers
 *              - Values are integer vectors
 * @return std::map<std::pair<int,int>, std::vector<int>> Map where:
 *              - Keys are pairs of integers extracted from list names
 *              - Values are vectors of integers from the list elements
 *
 * @throws std::runtime_error If list names are not in the expected "key1_key2" format
 *                           or if list elements are not integer vectors
 * @note The function handles R object protection internally
 */
std::map<std::pair<int,int>, std::vector<int>> convert_R_to_map_vector(SEXP Rlist) {
    if (!Rf_isNewList(Rlist)) {
        Rf_error("Input must be an R list");
    }

    std::map<std::pair<int,int>, std::vector<int>> result;
    int n = Rf_length(Rlist);

     // Get names
    SEXP names = PROTECT(Rf_getAttrib(Rlist, R_NamesSymbol));
    if (names == R_NilValue) {
        UNPROTECT(1);
        Rf_error("Input list must have names");
    }

     // Process each element
    for (int i = 0; i < n; i++) {
         // Parse name to get key pair
        std::string name = CHAR(STRING_ELT(names, i));
        size_t underscore_pos = name.find('_');
        if (underscore_pos == std::string::npos) {
            UNPROTECT(1);
            Rf_error("List names must be in format 'key1_key2'");
        }

         // Extract and convert keys
        try {
            int key1 = std::stoi(name.substr(0, underscore_pos));
            int key2 = std::stoi(name.substr(underscore_pos + 1));
            std::pair<int,int> key(key1, key2);

             // Get vector element
            SEXP Rvec = VECTOR_ELT(Rlist, i);
            if (!Rf_isInteger(Rvec)) {
                UNPROTECT(1);
                Rf_error("List elements must be integer vectors");
            }

             // Convert R vector to std::vector
            int* ptr = INTEGER(Rvec);
            int vec_length = Rf_length(Rvec);
            std::vector<int> value(ptr, ptr + vec_length);

             // Insert into map
            result[key] = value;
        }
        catch (const std::invalid_argument& e) {
            UNPROTECT(1);
            Rf_error("Failed to parse integer keys from list names");
        }
    }

    UNPROTECT(1);
    return result;
}


/**
 * @brief Converts a C++ map from integer pairs to sets of integers (procells) to a named R list
 *
 * @param procells Input map where keys are pairs of integers (typically max-min pairs)
 *                 and values are sets of integers representing proto-cells
 * @return SEXP Named R list where:
 *              - Names are created by concatenating the pair of keys with underscore ("max_min")
 *              - Values are integer vectors (converted from sets)
 *
 * @note The returned SEXP is in PROTECTed state.
 * @note List names follow the format "max_min" where max and min are the components of the key pair
 */
SEXP convert_procells_to_R(const std::map<std::pair<int,int>, std::set<int>>& procells) {
    int n = procells.size();
    SEXP Rlist = PROTECT(Rf_allocVector(VECSXP, n));

    {
        SEXP names = PROTECT(Rf_allocVector(STRSXP, n));
        int i = 0;
        for (const auto& pair : procells) {
            // Convert the set to R vector
            SEXP Rvec = PROTECT(Rf_allocVector(INTSXP, pair.second.size()));
            int* ptr = INTEGER(Rvec);
            int j = 0;
            for (const auto& val : pair.second) {
                ptr[j++] = val;
            }

            // Set the name as "max_min"
            std::string name = std::to_string(pair.first.first) + "_" + std::to_string(pair.first.second);
            SET_STRING_ELT(names, i, Rf_mkChar(name.c_str()));

            SET_VECTOR_ELT(Rlist, i, Rvec);
            UNPROTECT(1); // Rvec
            i++;
        }
        Rf_setAttrib(Rlist, R_NamesSymbol, names);
        UNPROTECT(1);
    }

    UNPROTECT(1);
    return Rlist;
}


/**
 * @brief Converts an R list containing shortest paths data into a C++ map structure
 *
 * @details The function takes an R list with three named components:
 *          - 'i': Integer vector of source vertices (1-based indices)
 *          - 'j': Integer vector of target vertices (1-based indices)
 *          - 'paths': List of integer vectors, each containing a path from i to j (1-based indices)
 *          The function converts these R data structures back into a C++ map where keys are
 *          pairs of vertices (i,j) and values are vectors containing the paths between them.
 *          All indices are converted from R's 1-based to C++'s 0-based indexing.
 *
 * @param s_shortest_paths SEXP object containing the R list with shortest paths data
 *
 * @return std::map with pairs of vertices as keys and vectors of path vertices as values
 *
 * @note The input R list should have the exact structure as produced by S_create_path_graph
 *
 * @throw No explicit exceptions, but R Rf_error handling may trigger if input structure is invalid
 */
std::map<std::pair<int,int>, std::vector<int>> shortest_paths_Rlist_to_cpp_map(SEXP s_shortest_paths) {
    std::map<std::pair<int,int>, std::vector<int>> result;

     // Extract the three components from the list
    SEXP i_coords = VECTOR_ELT(s_shortest_paths, 0);  // First element (i coordinates)
    SEXP j_coords = VECTOR_ELT(s_shortest_paths, 1);  // Second element (j coordinates)
    SEXP paths = VECTOR_ELT(s_shortest_paths, 2);     // Third element (paths list)

     // Get pointers to the coordinate arrays
    int* i_ptr = INTEGER(i_coords);
    int* j_ptr = INTEGER(j_coords);

     // Get the length of the arrays (they should all be the same length)
    R_xlen_t n_paths = XLENGTH(i_coords);

     // Iterate through all paths
    for (R_xlen_t idx = 0; idx < n_paths; ++idx) {
         // Get current i,j coordinates (subtract 1 to convert from R's 1-based to C++'s 0-based indexing)
        int i = i_ptr[idx] - 1;
        int j = j_ptr[idx] - 1;

         // Get the current path vector
        SEXP current_path = VECTOR_ELT(paths, idx);
        int* path_ptr = INTEGER(current_path);
        R_xlen_t path_length = XLENGTH(current_path);

         // Create vector for this path
        std::vector<int> path_vec;
        path_vec.reserve(path_length);

         // Copy path values (subtract 1 to convert from R's 1-based to C++'s 0-based indexing)
        for (R_xlen_t k = 0; k < path_length; ++k) {
            path_vec.push_back(path_ptr[k] - 1);
        }

         // Insert into map
        result[std::make_pair(i, j)] = std::move(path_vec);
    }

    return result;
}




/**
 * @brief Converts a 3D vector of doubles to an R list of matrices
 *
 * @param data 3D vector organized as [outer_idx][middle_idx][inner_idx]
 *
 * @return SEXP (List) A list of matrices where:
 *         - Each list element corresponds to outer_idx
 *         - Each matrix has rows corresponding to middle_idx
 *         - Each matrix has columns corresponding to inner_idx
 *
 * @note Memory Management:
 *       - Allocates new R objects
 *       - Caller must handle PROTECT/UNPROTECT
 *       - Returns PROTECTED object
 *
 * @Rf_warning
 *       - Assumes non-empty input vector
 *       - Assumes consistent dimensions for all inner vectors
 *       - Caller must UNPROTECT returned object
 */
SEXP convert_vector_vector_vector_double_to_R(
    const std::vector<std::vector<std::vector<double>>>& data) {

    if (data.empty()) return R_NilValue;

    int n_outer = data.size();
    SEXP result = PROTECT(Rf_allocVector(VECSXP, n_outer));

    for (int i = 0; i < n_outer; i++) {
        if (data[i].empty()) {
            SET_VECTOR_ELT(result, i, R_NilValue);
            continue;
        }

        int n_rows = data[i].size();
        int n_cols = data[i][0].size();

         // Create matrix for this outer index
        SEXP matrix = PROTECT(Rf_allocMatrix(REALSXP, n_rows, n_cols));
        double* ptr = REAL(matrix);

         // Fill matrix
        for (int j = 0; j < n_rows; j++) {
            for (int k = 0; k < n_cols; k++) {
                ptr[j + k * n_rows] = data[i][j][k];  // Column-major order for R
            }
        }

        SET_VECTOR_ELT(result, i, matrix);
        UNPROTECT(1);  // Unprotect matrix after setting it in list
    }

    UNPROTECT(1);
    return result; // UNPROTECTed
}


/**
 * @brief Converts a C++ graph object to an R list representation
 *
 * @details
 * This function converts a set_wgraph_t graph object to an R list containing
 * the adjacency list and weight list, suitable for use in R. The adjacency list
 * is converted from 0-based indexing (C++) to 1-based indexing (R).
 *
 * The returned R list contains two named elements:
 * - `adj_list`: A list where each element contains the indices of vertices adjacent to vertex i
 * - `weight_list`: A list where each element contains the weights of edges connecting vertex i to its adjacent vertices
 *
 * @param graph The C++ graph object to convert
 * @return SEXP A named R list containing the adjacency list and weight list
 *
 * @note The returned SEXP object is properly protected during construction and unprotected before return
 * @note Vertex indices are converted from 0-based (C++) to 1-based (R) indexing
 */
SEXP convert_wgraph_to_R(const set_wgraph_t& graph) {
    const size_t n_vertices_sz = graph.num_vertices();
    if (n_vertices_sz > (size_t)INT_MAX) {
        Rf_error("Too many vertices for this build (>%d).", INT_MAX);
    }
    const int n_vertices = (int)n_vertices_sz;

    SEXP r_list = PROTECT(Rf_allocVector(VECSXP, 2));
    {
        SEXP r_list_names = PROTECT(Rf_allocVector(STRSXP, 2));
        SET_STRING_ELT(r_list_names, 0, Rf_mkChar("adj_list"));
        SET_STRING_ELT(r_list_names, 1, Rf_mkChar("weight_list"));
        Rf_setAttrib(r_list, R_NamesSymbol, r_list_names);
        UNPROTECT(1);
    }

    SEXP adj_list    = PROTECT(Rf_allocVector(VECSXP, n_vertices));
    SEXP weight_list = PROTECT(Rf_allocVector(VECSXP, n_vertices));

    for (int i = 0; i < n_vertices; ++i) {
        const auto& nbrs = graph.adjacency_list[(size_t)i]; // std::set<edge_info_t>
        const size_t deg = nbrs.size();
        if (deg > (size_t)INT_MAX) Rf_error("Degree too large");

        SEXP RA = PROTECT(Rf_allocVector(INTSXP,  (int)deg));
        SEXP RW = PROTECT(Rf_allocVector(REALSXP, (int)deg));
        int*    A = INTEGER(RA);
        double* W = REAL(RW);

        int j = 0;
        for (const auto& e : nbrs) {
            A[j] = (int)e.vertex + 1;
            W[j] = e.weight;
            ++j;
        }
        SET_VECTOR_ELT(adj_list,    i, RA);
        SET_VECTOR_ELT(weight_list, i, RW);
        UNPROTECT(2); // RA, RW
    }

    SET_VECTOR_ELT(r_list, 0, adj_list);
    SET_VECTOR_ELT(r_list, 1, weight_list);
    UNPROTECT(3); // adj_list, weight_list, r_list
    return r_list; // leaf
}
