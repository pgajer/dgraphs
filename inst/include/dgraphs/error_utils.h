#ifndef ERROR_UTILS_H
#define ERROR_UTILS_H

#include <string>
#include <sstream>
#include <cstdarg>
#include <cstdio>
#include <cstring>
#include <cstddef>      // For size_t (though often included by other headers)

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Error.h>

using std::size_t;

// Macro for location info
#define LOC_INFO __FILE__, __LINE__

inline void report_error(const char* file, int line, const char* format, ...) {
    // Separate buffers for location and message
    constexpr size_t loc_size = 1024;    // Reasonable size for file path and line number
    constexpr size_t msg_size = 7168;    // Remaining space for the actual message
    char location[loc_size];
    char message[msg_size];

    // Format the location string
    int loc_len = snprintf(location, loc_size, "In %s (line %d): ", file, line);
    if (loc_len < 0 || static_cast<size_t>(loc_len) >= loc_size) {
        Rf_error("Error location string truncated");
        return;
    }

    // Format the message string
    va_list args;
    va_start(args, format);
    int msg_len = vsnprintf(message, msg_size, format, args);
    va_end(args);
    if (msg_len < 0 || static_cast<size_t>(msg_len) >= msg_size) {
        Rf_error("Error message truncated");
        return;
    }

    // Calculate total required size
    size_t total_len = static_cast<size_t>(loc_len) + static_cast<size_t>(msg_len);

    // Allocate final message buffer with exact required size plus null terminator
    char final_message[8192];  // Keep your original max size
    if (total_len >= sizeof(final_message)) {
        Rf_error("Combined error message too long");
        return;
    }

    // Combine the messages
    memcpy(final_message, location, loc_len);
    memcpy(final_message + loc_len, message, msg_len + 1);  // Include null terminator

    // Report to R
    Rf_error("%s", final_message);
}


// Wrapper macro for easier use
#define REPORT_ERROR(...) report_error(LOC_INFO, __VA_ARGS__)

// Warning reporting function
inline void report_Rf_warning(const char* file, int line, const char* format, ...) {
    // Increase buffer sizes to handle the worst case
    const size_t buffer_size = 8192;
    const size_t final_buffer_size = 2 * buffer_size + 1;  // Room for both strings plus null terminator

    // Buffer for the location prefix
    char location[buffer_size];
    size_t location_len = snprintf(location, buffer_size,
                                 "In %s (line %d): ", file, line);

    // Buffer for the formatted message
    char message[buffer_size];
    va_list args;
    va_start(args, format);
    size_t message_len = vsnprintf(message, buffer_size, format, args);
    va_end(args);

    // Final buffer large enough for both parts
    char final_message[final_buffer_size];

    // Safely combine the strings with length checking
    if (location_len + message_len < final_buffer_size - 1) {
        // We have room for everything
        snprintf(final_message, final_buffer_size, "%s%s", location, message);
    } else {
        // If we would overflow, truncate the message part while preserving the location
        size_t space_for_message = final_buffer_size - location_len - 1;
        snprintf(final_message, location_len + 1, "%s", location);
        strncat(final_message, message, space_for_message);
    }

    Rf_warning("%s", final_message);
}

// Wrapper macro for warnings
#define REPORT_WARNING(...) report_Rf_warning(LOC_INFO, __VA_ARGS__)

// Input validation utilities
inline void check_null(SEXP x, const char* file, int line, const char* var_name) {
    if (x == R_NilValue) {
        report_error(file, line, "Input '%s' is NULL", var_name);
    }
}

#define CHECK_NULL(x) check_null(x, LOC_INFO, #x)

#if 0
inline void check_length(SEXP x, R_xlen_t expected, const char* file, int line, const char* var_name) {
    if (XLENGTH(x) != expected) {
        report_error(file, line, "Length mismatch for '%s': expected %lld, got %lld",
                    var_name, (long long)expected, (long long)XLENGTH(x));
    }
}

#define CHECK_LENGTH(x, n) check_length(x, n, LOC_INFO, #x)
#endif

// Vector bounds checking
template<typename T>
inline void check_index(T idx, T max, const char* file, int line, const char* var_name) {
    if (idx < 0 || idx >= max) {
        report_error(file, line, "Index out of bounds for '%s': %lld (valid range: 0 to %lld)",
                    var_name, (long long)idx, (long long)(max-1));
    }
}

#define CHECK_INDEX(idx, max) check_index(idx, max, LOC_INFO, #idx)

#endif // ERROR_UTILS_H
