#ifndef MSR2_CPP_UTILS_H_
#define MSR2_CPP_UTILS_H_

#include "progress_utils.hpp" // for elapsed.time

#include <vector>
#include <string>
#include <fstream>
#include <sstream>
#include <iomanip>
#include <type_traits>
#include <unordered_set>
#include <set>
#include <map>
#include <unordered_map>
#include <chrono>    // For std::chrono
#include <utility>   // for std::pair
#include <ctime>
#include <cstdlib>   // For getenv
#include <algorithm>
#include <numeric>
#include <cmath>
#include <cstddef>

#include <R.h>  // For Rprintf

using std::size_t;

struct conn_comps_of_loc_extr_t {
    std::unordered_map<int, std::vector<int>> lmin_cc_map;
    std::unordered_map<int, std::vector<int>> lmax_cc_map;
};

// Convert from map to vector representation
std::vector<double> map_to_vector(
    const std::unordered_map<size_t, double>& map,
    double default_value = INFINITY);

// Convert from vector to map representation (skipping default values)
std::unordered_map<size_t, double> vector_to_map(
    const std::vector<double>& vec,
    double default_value = INFINITY);


// --------------------------------------------------------------------------------------------------------

/**
 * @brief Calculate quantiles of a numeric vector
 *
 * @tparam T Numeric type (int, size_t, double, etc.)
 * @param data Input vector for which to calculate quantiles
 * @param props Vector of probabilities/quantiles to calculate (0 to 1)
 * @return std::vector<double> Vector of calculated quantiles
 */
template <typename T>
std::vector<double> vector_quantiles(const std::vector<T>& data, const std::vector<double>& props) {
    if (data.empty()) {
        return std::vector<double>(props.size(), NAN);
    }

    // Create a copy of the data for sorting
    std::vector<T> sorted_data = data;
    std::sort(sorted_data.begin(), sorted_data.end());

    const size_t n = sorted_data.size();
    std::vector<double> result;
    result.reserve(props.size());

    for (double p : props) {
        // Clamp proportion to [0,1]
        p = std::max(0.0, std::min(1.0, p));

        if (p == 0.0) {
            result.push_back(static_cast<double>(sorted_data.front()));
        } else if (p == 1.0) {
            result.push_back(static_cast<double>(sorted_data.back()));
        } else {
            // Calculate position using R's quantile type 7 method (default)
            double h = (n - 1) * p;
            size_t i = static_cast<size_t>(h);
            double fraction = h - i;

            if (i + 1 < n) {
                result.push_back(static_cast<double>(sorted_data[i]) * (1 - fraction) +
                                 static_cast<double>(sorted_data[i + 1]) * fraction);
            } else {
                result.push_back(static_cast<double>(sorted_data[i]));
            }
        }
    }

    return result;
}

/**
 * @brief Print summary statistics including quantiles for a numeric vector
 *
 * @tparam T Numeric type (int, size_t, double, etc.)
 * @param data Input vector to summarize
 * @param name Name to display in header
 * @param props Vector of probabilities/quantiles to calculate (default: 0, 0.25, 0.5, 0.75, 1)
 * @param with_mean Include mean in statistics (default: true)
 */
template <typename T>
void print_vector_quantiles(
    const std::vector<T>& data,
    const std::string& name,
    const std::vector<double>& props = {0, 0.25, 0.5, 0.75, 1},
    bool with_mean = true) {

    if (data.empty()) {
        Rprintf("%s: Empty vector\n", name.c_str());
        return;
    }

    // Calculate quantiles
    std::vector<double> quantiles = vector_quantiles(data, props);

    // Calculate mean if requested
    double mean = 0.0;
    if (with_mean) {
        mean = std::accumulate(data.begin(), data.end(), 0.0) / data.size();
    }

    // Print header
    Rprintf("\n%s summary (n=%zu):\n", name.c_str(), data.size());

    // Print quantiles with labels
    for (size_t i = 0; i < props.size(); ++i) {
        Rprintf("  %.0f%%: %.2f", props[i] * 100, quantiles[i]);

        // Print labels for common quantiles
        if (props[i] == 0) Rprintf(" (Min)");
        else if (props[i] == 0.25) Rprintf(" (Q1)");
        else if (props[i] == 0.5) Rprintf(" (Median)");
        else if (props[i] == 0.75) Rprintf(" (Q3)");
        else if (props[i] == 1) Rprintf(" (Max)");

        Rprintf("\n");
    }

    // Print mean if requested
    if (with_mean) {
        Rprintf("  Mean: %.2f\n", mean);
    }
}


/**
 * Prints a vector of pairs to stdout.
 *
 * @param vect The vector of pairs to print
 * @param name Optional name to print before the vector
 * @param one_column If true, prints each pair on a new line
 */
template <typename T1, typename T2>
void print_vect_pair(const std::vector<std::pair<T1, T2>>& vect,
                      const std::string& name = "",
                      bool one_column = false) {
    // Print the name if provided
    if (!name.empty()) {
        Rprintf("%s: ", name.c_str());
    }

    // Print the opening bracket
    Rprintf("[");

    // Add a newline after opening bracket when in column mode
    if (one_column && !vect.empty()) {
        Rprintf("\n");
    }

    // Iterate through the vector
    for (size_t i = 0; i < vect.size(); ++i) {
        // Add indentation in column mode
        if (one_column) {
            Rprintf("  ");
        }

        // Print the pair
        Rprintf("(");
        Rprintf("%s", std::to_string(vect[i].first).c_str());
        Rprintf(", ");
        Rprintf("%s", std::to_string(vect[i].second).c_str());
        Rprintf(")");

        // Print a separator after all pairs except the last one
        if (i < vect.size() - 1) {
            if (one_column) {
                Rprintf(",\n");
            } else {
                Rprintf(", ");
            }
        }
    }

    // Add a newline before closing bracket when in column mode
    if (one_column && !vect.empty()) {
        Rprintf("\n");
    }

    // Print the closing bracket and newline
    Rprintf("]\n");
}

inline void print_ivect(const std::vector<int>& vec,
                const std::string& name = "",
                int offset = 0,
                size_t n = 0,
                const std::string& delimiter = ", ") {
    if (n == 0) {
        n = vec.size();
    }
    if (!name.empty()) {
        Rprintf("%s: ", name.c_str());
    }
    for (size_t i = 0; i < n && i < vec.size(); ++i) {
        Rprintf("%d", vec[i] + offset);  // You may need to use a different format specifier based on T
        if (i < n - 1 && i < vec.size() - 1) {
            Rprintf("%s", delimiter.c_str());
        }
    }
    Rprintf("\n");
}

inline void print_zvect(const std::vector<size_t>& vec,
                const std::string& name = "",
                int offset = 0,
                size_t n = 0,
                const std::string& delimiter = ", ") {
    if (n == 0) {
        n = vec.size();
    }
    if (!name.empty()) {
        Rprintf("%s: ", name.c_str());
    }
    for (size_t i = 0; i < n && i < vec.size(); ++i) {
        Rprintf("%zu", vec[i] + offset);  // You may need to use a different format specifier based on T
        if (i < n - 1 && i < vec.size() - 1) {
            Rprintf("%s", delimiter.c_str());
        }
    }
    Rprintf("\n");
}


template <typename T>
std::string write_vect(const std::vector<T>& vec,
                      const std::string& name = "",
                      int offset = 0,
                      size_t n = 0,
                      const std::string& delimiter = ",",
                      const std::string& file_path = "") {
    // Determine how many elements to write
    if (n == 0) {
        n = vec.size();
    }

    // Generate a temporary file path if none is provided
    std::string actual_file_path = file_path;
    if (actual_file_path.empty()) {
        // Create a timestamp for the filename to make it unique
        auto t = std::time(nullptr);
        auto tm = *std::localtime(&t);
        std::ostringstream timestamp;
        timestamp << std::put_time(&tm, "%Y%m%d_%H%M%S");

        // Get the temporary directory in a cross-platform way
        std::string temp_dir;

        // Try multiple environmental variables to find a temp directory
        const char* temp_env[] = {"TMPDIR", "TMP", "TEMP", "TEMPDIR"};
        for (const char* env_var : temp_env) {
            const char* dir = std::getenv(env_var);
            if (dir != nullptr) {
                temp_dir = dir;
                // Make sure the path ends with a separator
                if (!temp_dir.empty() && temp_dir.back() != '/' && temp_dir.back() != '\\') {
                    temp_dir += '/';
                }
                break;
            }
        }

        // If no environment variable worked, use a reasonable default
        if (temp_dir.empty()) {
            #ifdef _WIN32
                temp_dir = "C:/Temp/";
            #else
                temp_dir = "/tmp/";
            #endif
        }

        std::string vec_name = name.empty() ? "vector" : name;
        // Remove any spaces or special characters from the name for the filename
        std::replace(vec_name.begin(), vec_name.end(), ' ', '_');
        std::replace(vec_name.begin(), vec_name.end(), ':', '_');

        actual_file_path = temp_dir + vec_name + "_" + timestamp.str() + ".csv";
    }

    // Open the file for writing
    std::ofstream outfile(actual_file_path);
    if (!outfile.is_open()) {
        Rprintf("Error: Could not open file %s for writing\n", actual_file_path.c_str());
        return "";
    }

    // Write the vector elements
    for (size_t i = 0; i < n && i < vec.size(); ++i) {
        outfile << (vec[i] + offset);
        if (i < n - 1 && i < vec.size() - 1) {
            outfile << delimiter;
        }
    }
    outfile << std::endl;
    outfile.close();

    // Inform the user about where the file was written
    Rprintf("Vector data written to: %s\n", actual_file_path.c_str());

    // Return the file path so the function can be used programmatically
    return actual_file_path;
}

/**
 * @brief Prints the elements of a vector.
 *
 * @tparam T The type of the vector elements.
 * @param vec The vector to be printed.
 * @param name Optional name to be printed before the vector elements. Default is an empty string.
 * @param n Optional number of elements to be printed. Default is 0, which means all elements will be printed.
 * @param delimiter Optional string to be used as a separator between elements. Default is ", ".
 *
 * @details This function prints the elements of a vector up to a specified number of elements.
 *          If a name is provided, it will be printed before the vector elements.
 *          If the number of elements to be printed is not specified or is 0, all elements will be printed.
 *          The delimiter parameter allows customization of the separator between elements.
 *
 * @note The vector type must support the << operator for printing.
 *
 * Example usage:
 * @code
 * std::vector<int> numbers = {1, 2, 3, 4, 5};
 * print_vect(numbers);  // Prints: 1, 2, 3, 4, 5
 * print_vect(numbers, "Numbers");  // Prints: Numbers: 1, 2, 3, 4, 5
 * print_vect(numbers, "First 3 numbers", 3);  // Prints: First 3 numbers: 1, 2, 3
 * print_vect(numbers, "Custom delimiter", 0, " | ");  // Prints: Custom delimiter: 1 | 2 | 3 | 4 | 5
 * @endcode
 */
template <typename T>
inline void print_vect(const std::vector<T>& vec,
                const std::string& name = "",
                int offset = 0,
                size_t n = 0,
                const std::string& delimiter = ", ") {
    if (n == 0) {
        n = vec.size();
    }

    // Build the output string using a stringstream
    std::ostringstream oss;
    if (!name.empty()) {
        oss << name << ": ";
    }

    for (size_t i = 0; i < n && i < vec.size(); ++i) {
        oss << (vec[i] + offset);
        if (i < n - 1 && i < vec.size() - 1) {
            oss << delimiter;
        }
    }

    // Convert the entire stream to a string and print it using Rprintf
    std::string output = oss.str();
    Rprintf("%s\n", output.c_str());
}

#if 0
template <typename T>
void print_vect(const std::vector<T>& vec,
                const std::string& name = "",
                int offset = 0,
                size_t n = 0,
                const std::string& delimiter = ", ") {
    if (n == 0) {
        n = vec.size();
    }
    if (!name.empty()) {
        Rprintf("%s: ", name.c_str());
    }
    for (size_t i = 0; i < n && i < vec.size(); ++i) {
        Rprintf("%d", vec[i] + offset);
        if (i < n - 1 && i < vec.size() - 1) {
            Rprintf("%s", delimiter.c_str());
        }
    }
    Rprintf("\n");
}
#endif


/**
 * @brief Prints the elements of a set.
 *
 * @tparam T The type of the set elements.
 * @param s The set to be printed.
 * @param name Optional name to be printed before the set elements. Default is an empty string.
 * @param n Optional number of elements to be printed. Default is 0, which means all elements will be printed.
 *
 * @details This function prints the elements of a set up to a specified number of elements.
 *     If a name is provided, it will be printed before the set elements.
 *     If the number of elements to be printed is not specified or is 0, all elements will be printed.
 *
 * @note The set type must support the << operator for printing.
 *
 * Example usage:
 * @code
 * std::set<int> numbers = {5, 2, 1, 4, 3};
 * print_set(numbers); // Prints: 1 2 3 4 5
 * print_set(numbers, "Numbers"); // Prints: Numbers: 1 2 3 4 5
 * print_set(numbers, "First 3 numbers", 3); // Prints: First 3 numbers: 1 2 3
 * @endcode
 */
template <typename T>
void print_set(const std::set<T>& s, const std::string& name = "", size_t n = 0) {
    if (n == 0) {
        n = s.size();
    }

    if (!name.empty()) {
        Rprintf("%s: ", name.c_str());
    }

    size_t count = 0;
    for (const auto& elem : s) {
        Rprintf("%d ", elem);
        if (++count == n) {
            break;
        }
    }

    Rprintf("\n");
}


/**
 * @brief Prints the elements of a unordered set.
 *
 * @tparam T The type of the set elements.
 * @param s The unordered set to be printed.
 * @param name Optional name to be printed before the set elements. Default is an empty string.
 * @param n Optional number of elements to be printed. Default is 0, which means all elements will be printed.
 *
 * @details This function prints the elements of an unordered set up to a specified number of elements.
 *     If a name is provided, it will be printed before the set elements.
 *     If the number of elements to be printed is not specified or is 0, all elements will be printed.
 *
 * @note The set type must support the << operator for printing.
 *
 * Example usage:
 * @code
 * std::unordered_set<int> numbers = {5, 2, 1, 4, 3};
 * print_set(numbers); // Prints: 1 2 3 4 5
 * print_set(numbers, "Numbers"); // Prints: Numbers: 1 2 3 4 5
 * print_set(numbers, "First 3 numbers", 3); // Prints: First 3 numbers: 1 2 3
 * @endcode
 */
template <typename T>
void print_uset(const std::unordered_set<T>& s,
                const std::string& name = "",
                size_t n = 0,
                const std::string& delimiter = ", ") {
    if (n == 0) {
        n = s.size();
    }

    if (!name.empty()) {
        Rprintf("%s: ", name.c_str());
    }

    size_t count = 0;
    for (const auto& elem : s) {
        Rprintf("%s", delimiter.c_str());Rprintf("%d", elem);
        if (++count == n) {
            break;
        }
    }

    Rprintf("\n");
}


/**
 * @brief Prints the elements of a 2D vector (vector of vectors).
 *
 * @tparam T The type of the vector elements.
 * @param vec The 2D vector to be printed.
 * @param name Optional name to be printed in a separate row before the vector elements. Default is an empty string.
 * @param n Optional number of rows to be printed. Default is 0, which means all rows will be printed.
 * @param with_row_index A boolean parameter. If true, index values are printed at the beginning of each row.
 *
 * @details This function prints the elements of a 2D vector (vector of vectors) up to a specified number of rows.
 *          Each row of the vector is printed on a separate line.
 *          If a name is provided, it will be printed in a separate row before the vector elements.
 *          If the number of rows to be printed is not specified or is 0, all rows will be printed.
 *
 * @note The vector type must support the << operator for printing.
 *
 * Example usage:
 * @code
 * std::vector<std::vector<int>> matrix = {
 *     {1, 2, 3},
 *     {4, 5, 6},
 *     {7, 8, 9}
 * };
 *
 * print_vectvect(matrix);
 * // Output:
 * // 1 2 3
 * // 4 5 6
 * // 7 8 9
 *
 * print_vectvect(matrix, "Matrix");
 * // Output:
 * // Matrix:
 * // 1 2 3
 * // 4 5 6
 * // 7 8 9
 *
 * print_vectvect(matrix, "First 2 rows", 2);
 * // Output:
 * // First 2 rows:
 * // 1 2 3
 * // 4 5 6
 * @endcode
 */
template <typename T>
void print_vect_vect(const std::vector<std::vector<T>>& vectvect,
                     const std::string& name = "",
                     size_t n = 0,
                     bool with_row_index = true,
                     bool shift = 0) {
    if (n == 0) {
        n = vectvect.size();
    }

    if (!name.empty()) {
        Rprintf("%s:\n", name.c_str());
    }

    for (size_t i = 0; i < n && i < vectvect.size(); ++i) {
        if (with_row_index)
            Rprintf("%zu: ", i + shift);

        for (const auto& val : vectvect[i]) {
            if constexpr (std::is_same_v<T, std::pair<int, int>>) {
                Rprintf("(%d, %d) ", val.first, val.second);
            } else {
                Rprintf("%d ", val + shift);
            }
        }
        Rprintf("\n");
    }
}

/**
 * @brief Prints a 2D array stored in row-major order with R-style formatting.
 *
 * This function prints the contents of a 2D array stored in row-major order,
 * using a formatting style similar to R's matrix output. It supports various
 * data types, including numeric types and std::pair<int, int>.
 *
 * @tparam T The data type of the array elements.
 *
 * @param matrix Pointer to the first element of the row-major 2D array.
 * @param n_rows The number of rows in the 2D array.
 * @param n_cols The number of columns in the 2D array.
 * @param name Optional name label for the array (default is empty string).
 * @param n Number of rows to print. If 0, prints all rows (default is 0).
 * @param with_row_index If true, prints row indices (default is true).
 * @param base Base for integer indexing. If 1, prints integers in 1-based format (default is 0).
 *
 * @note The output format resembles R's matrix print style, with row numbers
 *       in brackets and aligned columns. For floating-point types, values are
 *       formatted to 7 decimal places.
 * @note For std::pair<int, int> type, the output format is (first,second).
 * @note For integer types, when base is 1, the output will be incremented by 1.
 *
 * @example
 *     int matrix[] = {6, 9, 3, 10, 2, 10, 3, 9, 4, 1};
 *     print_row_major_2D_array(matrix, 2, 5, "nn$nn.index");
 *     // Output:
 *     // nn$nn.index
 *     //      [,1] [,2] [,3] [,4] [,5]
 *     // [1,]    6    9    3   10    2
 *     // [2,]   10    3    9    4    1
 */
template <typename T>
void print_row_major_2D_array(const T* matrix,
                              int n_rows,
                              int n_cols,
                              const std::string& name = "",
                              int n = 0,
                              bool with_row_index = true,
                              int base = 0) {
    if (n == 0) {
        n = n_rows;
    }
    if (!name.empty()) {
        Rprintf("%s\n", name.c_str());
    }

    // Determine the maximum width for each column
    std::vector<int> col_widths(static_cast<size_t>(n_cols), 0);
    for (size_t i = 0; i < static_cast<size_t>(n) && i < static_cast<size_t>(n_rows); ++i) {
        for (int j = 0; j < n_cols; ++j) {
            std::ostringstream ss;
            if constexpr (std::is_integral_v<T>) {
                ss << (matrix[i * n_cols + j] + base);
            } else if constexpr (std::is_floating_point_v<T>) {
                ss << std::setprecision(7) << std::fixed << matrix[i * n_cols + j];
            } else {
                ss << matrix[i * n_cols + j];
            }
            size_t idx = static_cast<size_t>(j);
            col_widths[idx] = std::max(col_widths[idx], static_cast<int>(ss.str().length()));
        }
    }

    // Adjust column widths to accommodate headers
    for (int j = 0; j < n_cols; ++j) {
        std::ostringstream ss;
        ss << "[," << (j + base) << "]";
        size_t idx = static_cast<size_t>(j);
        col_widths[idx] = std::max(col_widths[idx], static_cast<int>(ss.str().length())) - 1;
    }

    // Calculate row index width
    int row_index_width = std::to_string(n).length() + 1;

    // Print column headers
    for(int sp=0; sp<row_index_width+1; sp++) Rprintf(" ");
    for (int j = 0; j < n_cols; ++j) {
        size_t idx = static_cast<size_t>(j);
        Rprintf("[,%*d]", col_widths[idx], j + base);
        if (j < n_cols - 1) Rprintf(" ");
    }
    Rprintf("\n");

    // Print each row
    for (size_t i = 0; i < n && i < static_cast<size_t>(n_rows); ++i) {
        if (with_row_index) {
            Rprintf("[%*zu,]", row_index_width - 1, i + base);
        }
        for (int j = 0; j < n_cols; ++j) {
            if (j == 0) {
                // Spacing handled in the value output
            } else {
                // Spacing handled in the value output
            }

            if constexpr (std::is_same_v<T, std::pair<int, int>>) {
                const auto& val = matrix[i * n_cols + j];
                Rprintf("(%d,%d)", val.first, val.second);
            } else if constexpr (std::is_integral_v<T>) {
                Rprintf("%d", matrix[i * n_cols + j] + base);
            } else if constexpr (std::is_floating_point_v<T>) {
                Rprintf("%.7f", matrix[i * n_cols + j]);
            } else {
                Rprintf("%d", matrix[i * n_cols + j]);
            }
            if (j < n_cols - 1) Rprintf(" ");
        }
        Rprintf("\n");
    }
}


/**
 * @brief Prints a 2D array stored in column-major order with R-style formatting.
 *
 * This function prints the contents of a 2D array stored in column-major order,
 * using a formatting style similar to R's matrix output. It supports various
 * data types, including numeric types and std::pair<int, int>.
 *
 * @tparam T The data type of the array elements.
 *
 * @param matrix Pointer to the first element of the column-major 2D array.
 * @param n_rows The number of rows in the 2D array.
 * @param n_cols The number of columns in the 2D array.
 * @param name Optional name label for the array (default is empty string).
 * @param n Number of rows to print. If 0, prints all rows (default is 0).
 * @param with_row_index If true, prints row indices (default is true).
 * @param base Base for integer indexing. If 1, prints integers in 1-based format (default is 0).
 *
 * @note The output format resembles R's matrix print style, with row numbers
 *       in brackets and aligned columns. For floating-point types, values are
 *       formatted to 7 decimal places.
 * @note For std::pair<int, int> type, the output format is (first,second).
 * @note For integer types, when base is 1, the output will be incremented by 1.
 *
 * @example
 *     double matrix[] = {0.5433466, 0.6529210, 0.5868650, 1.0156044, 1.0783535};
 *     print_column_major_2D_array(matrix, 5, 1, "nn$nn.dist");
 *     // Output:
 *     // nn$nn.dist
 *     //           [,1]
 *     // [1,] 0.5433466
 *     // [2,] 0.6529210
 *     // [3,] 0.5868650
 *     // [4,] 1.0156044
 *     // [5,] 1.0783535
 */
template <typename T>
void print_column_major_2D_array(const T* matrix,
                                 int n_rows,
                                 int n_cols,
                                 const std::string& name = "",
                                 size_t n = 0,
                                 bool with_row_index = true,
                                 int base = 0) {
    if (n == 0) {
        n = n_rows;
    }
    if (!name.empty()) {
        Rprintf("%s\n", name.c_str());
    }

    // Determine the maximum width for each column
    std::vector<int> col_widths(n_cols, 0);
    for (size_t i = 0; i < n && i < static_cast<size_t>(n_rows); ++i) {
        for (int j = 0; j < n_cols; ++j) {
            std::ostringstream ss;
            if constexpr (std::is_integral_v<T>) {
                ss << (matrix[j * n_rows + i] + base);
            } else if constexpr (std::is_floating_point_v<T>) {
                ss << std::setprecision(7) << std::fixed << matrix[j * n_rows + i];
            } else {
                ss << matrix[j * n_rows + i];
            }
            col_widths[j] = std::max(col_widths[j], static_cast<int>(ss.str().length()));
        }
    }

    // Print column headers
    Rprintf("     ");
    for (int j = 0; j < n_cols; ++j) {
        Rprintf("[,%*d]", col_widths[j], j + 1);
        if (j < n_cols - 1) Rprintf(" ");
    }
    Rprintf("\n");

    // Print each row
    for (size_t i = 0; i < n && i < static_cast<size_t>(n_rows); ++i) {
        if (with_row_index) {
            Rprintf("[%2zu,] ", i + 1);
        }
        for (int j = 0; j < n_cols; ++j) {
            if constexpr (std::is_same_v<T, std::pair<int, int>>) {
                const auto& val = matrix[j * n_rows + i];
                Rprintf("(%d,%d)", val.first, val.second);
            } else if constexpr (std::is_integral_v<T>) {
                Rprintf("%*d", col_widths[j], matrix[j * n_rows + i] + base);
            } else if constexpr (std::is_floating_point_v<T>) {
                Rprintf("%*.7f", col_widths[j], matrix[j * n_rows + i]);
            } else {
                Rprintf("%*d", col_widths[j], matrix[j * n_rows + i]);
            }
            if (j < n_cols - 1) Rprintf(" ");
        }
        Rprintf("\n");
    }
}

#if 0
template <typename T>
void print_column_major_2D_array(const T* matrix,
                                 int n_rows,
                                 int n_cols,
                                 const std::string& name = "",
                                 size_t n = 0,
                                 bool with_row_index = true) {
    if (n == 0) {
        n = n_rows;
    }
    if (!name.empty()) {
        Rprintf("%s:\n", name.c_str());
    }
    for (size_t i = 0; i < n && i < static_cast<size_t>(n_rows); ++i) {
        if (with_row_index)
            Rprintf("%zu: ", i);
        for (int j = 0; j < n_cols; ++j) {
            if constexpr (std::is_same_v<T, std::pair<int, int>>) {
                const auto& val = matrix[j * n_rows + i];
                Rprintf("(%d, %d) ", val.first, val.second);
            } else {
                Rprintf("%8.4f ", matrix[j * n_rows + i]);
            }
        }
        Rprintf("\n");
    }
}
#endif


/**
 * Prints the contents of a vector of unordered sets in a formatted way.
 *
 * This function takes a vector of unordered sets of type T and prints its contents
 * in a formatted way. It can print a specified number of rows and optionally include
 * row indices. If the elements of the unordered sets are of type std::pair<int, int>,
 * they are printed in the format (first, second). Otherwise, the elements are printed
 * directly.
 *
 * @tparam T The type of elements stored in the unordered sets.
 * @param vectuset The vector of unordered sets to be printed.
 * @param name (Optional) A string to be printed as a label for the output. Default is an empty string.
 * @param n (Optional) The number of rows to be printed. Default is 0, which means all rows will be printed.
 * @param with_row_index (Optional) A boolean indicating whether to print the row index. Default is true.
 *
 * @note If n is greater than the size of vectuset, only the available rows will be printed.
 *
 * Example usage:
 * @code
 * std::vector<std::unordered_set<int>> vec_uset = {{1, 2, 3}, {4, 5}, {6, 7, 8, 9}};
 * print_vect_uset(vec_uset, "Vector of Unordered Sets", 2);
 * @endcode
 *
 * Output:
 * Vector of Unordered Sets:
 * 0: 3 2 1
 * 1: 5 4
 */
template <typename T>
void print_vect_uset(const std::vector<std::unordered_set<T>>& vectuset,
                    const std::string& name = "",
                    size_t n = 0,
                    bool with_row_index = true) {
    if (n == 0) {
        n = vectuset.size();
    }

    if (!name.empty()) {
        Rprintf("%s:\n", name.c_str());
    }

    for (size_t i = 0; i < n && i < vectuset.size(); ++i) {
        if (with_row_index)
            Rprintf("%zu: ", i);

        for (const auto& val : vectuset[i]) {
            if constexpr (std::is_same_v<T, std::pair<int, int>>) {
                Rprintf("(%d, %d) ", val.first, val.second);
            } else {
                Rprintf("%d ", val);
            }
        }
        Rprintf("\n");
    }
}


/**
 * Prints the contents of a vector of sets in a formatted way.
 *
 * This function takes a vector of sets of type T and prints its contents in a
 * formatted way. It can print a specified number of rows and optionally include
 * row indices. If the elements of the unordered sets are of type std::pair<int,
 * int>, they are printed in the format (first, second). Otherwise, the elements
 * are printed directly.
 *
 * @tparam T The type of elements stored in the unordered sets.
 * @param vectset The vector of sets to be printed.
 * @param name (Optional) A string to be printed as a label for the output. Default is an empty string.
 * @param n (Optional) The number of rows to be printed. Default is 0, which means all rows will be printed.
 * @param with_row_index (Optional) A boolean indicating whether to print the row index. Default is true.
 *
 * @note If n is greater than the size of vectset, only the available rows will be printed.
 *
 * Example usage:
 * @code
 * std::vector<std::set<int>> vec_set = {{1, 2, 3}, {4, 5}, {6, 7, 8, 9}};
 * print_vect_set(vec_set, "Vector of Sets", 2);
 * @endcode
 *
 * Output:
 * Vector of Sets:
 * 0: 3 2 1
 * 1: 5 4
 */
template <typename T>
void print_vect_set(const std::vector<std::set<T>>& vectset,
                    const std::string& name = "",
                    size_t n = 0,
                    bool with_row_index = true) {
    if (n == 0) {
        n = vectset.size();
    }

    if (!name.empty()) {
        Rprintf("%s:\n", name.c_str());
    }

    for (size_t i = 0; i < n && i < vectset.size(); ++i) {
        if (with_row_index)
            Rprintf("%zu: ", i);

        for (const auto& val : vectset[i]) {
            if constexpr (std::is_same_v<T, std::pair<int, int>>) {
                Rprintf("(%d, %d) ", val.first, val.second);
            } else {
                Rprintf("%d ", val);
            }
        }
        Rprintf("\n");
    }
}


/**
 * Prints the contents of a std::map in a formatted way.
 *
 * This function takes a std::map with key type T1 and value type T2 and prints
 * its contents in a human-readable format. Each key-value pair is printed on a
 * separate line, with the key and value separated by a colon and a space. If a
 * name is provided, it is printed as a heading before the map contents.
 *
 * @tparam T1 The type of the keys in the map.
 * @tparam T2 The type of the values in the map.
 * @param map The std::map to be printed.
 * @param name Optional name or heading to be printed before the map contents.
 *             Default is an empty string.
 *
 * @note The function assumes that the types T1 and T2 have properly overloaded
 *       stream insertion operators (<<) for printing.
 *
 * Example usage:
 * @code
 * std::map<std::string, int> my_map = {{"a", 1}, {"b", 2}, {"c", 3}};
 * print_map(my_map, "My Map");
 * @endcode
 *
 * Output:
 * My Map:
 * a: 1
 * b: 2
 * c: 3
 */
template <typename T1, typename T2>
void print_map(const std::map<T1, T2>& map,
               const std::string& name = "") {
    if (!name.empty()) {
        Rprintf("%s:\n", name.c_str());
    }
    for (const auto& [key, value] : map) {
        Rprintf("%s: %s\n", std::to_string(key).c_str(), std::to_string(value).c_str());
    }
    Rprintf("\n");
}

template <typename T1, typename T2>
void print_umap(const std::unordered_map<T1, T2>& map,
               const std::string& name = "") {
    if (!name.empty()) {
        Rprintf("%s:\n", name.c_str());
    }
    for (const auto& [key, value] : map) {
        Rprintf("%s: %s\n", std::to_string(key).c_str(), std::to_string(value).c_str());
    }
    Rprintf("\n");
}

/**
 * Prints the contents of an std::unordered_map with values of type std::set in a readable format.
 *
 * This function takes an std::unordered_map where the keys are of type T1 and the values are of type std::set<T2>.
 * It prints the contents of the map in a human-readable format, with each key-value pair on a separate line.
 * The keys and values are separated by a colon and a space, and the elements within each set are separated by spaces.
 *
 * @tparam T1 The type of the keys in the map.
 * @tparam T2 The type of the elements in the sets stored as values in the map.
 * @param map The std::unordered_map to be printed.
 * @param name Optional name or heading to be printed before the map contents. Default is an empty string.
 *
 * @note The function assumes that the types T1 and T2 have the appropriate operator<< overloaded for printing
 *       to output.
 *
 * Example usage:
 * @code
 * std::unordered_map<std::string, std::set<int>> my_map = {
 *     {"key1", {1, 2, 3}},
 *     {"key2", {4, 5}},
 *     {"key3", {6, 7, 8, 9}}
 * };
 * print_umap_to_set(my_map, "My Map");
 * @endcode
 *
 * Output:
 * My Map:
 * key1: 1 2 3
 * key2: 4 5
 * key3: 6 7 8 9
 */
template <typename T1, typename T2>
void print_umap_to_set(const std::unordered_map<T1, std::set<T2>>& map,
                       const std::string& name = "") {
    if (!name.empty()) {
        Rprintf("%s:\n", name.c_str());
    }
    for (const auto& [key, value] : map) {
        Rprintf("%s: ", std::to_string(key).c_str());

        for (const auto& val : value)
            Rprintf("%d ", val);
        Rprintf("\n");
    }
    Rprintf("\n");
}

template <typename T1, typename T2>
void print_map_to_set(const std::map<T1, std::set<T2>>& map,
                      const std::string& name = "") {
    if (!name.empty()) {
        Rprintf("%s:\n", name.c_str());
    }
    for (const auto& [key, value] : map) {
        Rprintf("%s: ", std::to_string(key).c_str());

        for (const auto& val : value)
            Rprintf("%d ", val);
        Rprintf("\n");
    }
    Rprintf("\n");
}

/**
 * Prints the contents of an std::unordered_map with values of type std::vector in a readable format.
 *
 * This function takes an std::unordered_map where the keys are of type T1 and the values are of type std::vector<T2>.
 * It prints the contents of the map in a human-readable format, with each key-value pair on a separate line.
 * The keys and values are separated by a colon and a space, and the elements within each set are separated by spaces.
 *
 * @tparam T1 The type of the keys in the map.
 * @tparam T2 The type of the elements in the sets stored as values in the map.
 * @param map The std::unordered_map to be printed.
 * @param name Optional name or heading to be printed before the map contents. Default is an empty string.
 *
 * @note The function assumes that the types T1 and T2 have the appropriate operator<< overloaded for printing
 *       to output.
 *
 * Example usage:
 * @code
 * std::unordered_map<std::string, std::vector<int>> my_map = {
 *     {"key1", {1, 2, 3}},
 *     {"key2", {4, 5}},
 *     {"key3", {6, 7, 8, 9}}
 * };
 * print_umap_to_vect(my_map, "My Map");
 * @endcode
 *
 * Output:
 * My Map:
 * key1: 1 2 3
 * key2: 4 5
 * key3: 6 7 8 9
 */
template <typename T1, typename T2>
void print_umap_to_vect(const std::unordered_map<T1, std::vector<T2>>& map,
                       const std::string& name = "") {
    if (!name.empty()) {
        Rprintf("%s:\n", name.c_str());
    }
    for (const auto& [key, value] : map) {
        Rprintf("%s: ", std::to_string(key).c_str());

        for (const auto& val : value)
            Rprintf("%d ", val);
        Rprintf("\n");
    }
    Rprintf("\n");
}

#endif // MSR2_CPP_UTILS_H_
