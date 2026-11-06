#include <R_ext/Print.h>  // For Rprintf
#include <chrono>         // For std::chrono
#include <cstdio>         // For snprintf
#include <cstdarg>        // For va_list, va_start, va_end
#include <cmath>          // For std::fmod
#include <ctime>          // For std::tm, std::time_t

namespace {

void format_timestamp(char* timestamp_buf, size_t timestamp_buf_size) {
    const auto now = std::chrono::system_clock::now();
    const std::time_t now_time_t = std::chrono::system_clock::to_time_t(now);

    std::tm now_tm{};
#if defined(_WIN32)
    localtime_s(&now_tm, &now_time_t);
#else
    localtime_r(&now_time_t, &now_tm);
#endif
    std::strftime(timestamp_buf, timestamp_buf_size, "%Y-%m-%d %H:%M:%S", &now_tm);
}

void progress_vlog_impl(const bool with_newline, const char* fmt, va_list args) {
    char message_buf[4096];
    std::vsnprintf(message_buf, sizeof(message_buf), fmt, args);

    char timestamp_buf[24];
    format_timestamp(timestamp_buf, sizeof(timestamp_buf));

    if (with_newline) {
        Rprintf("[%s] %s\n", timestamp_buf, message_buf);
    } else {
        Rprintf("[%s] %s", timestamp_buf, message_buf);
    }
}

}  // namespace

void progress_log(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    progress_vlog_impl(true, fmt, args);
    va_end(args);
}

void progress_log_inline(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    progress_vlog_impl(false, fmt, args);
    va_end(args);
}

void elapsed_time(std::chrono::time_point<std::chrono::steady_clock> start_time,
                  const char* message,
                  bool with_brackets,
                  bool with_timestamp);

void elapsed_time(std::chrono::time_point<std::chrono::steady_clock> start_time,
                 const char* message,
                 bool with_brackets) {
    elapsed_time(start_time, message, with_brackets, false);
}

/**
 * @brief Prints elapsed time with optional message and formatting for parallel processing
 *
 * @param start_time Starting time point from std::chrono::steady_clock
 * @param message Message to display alongside the elapsed time
 * @param with_brackets If true, elapsed time is shown in parentheses (defaults to false)
 *
 * @details Calculates and prints wall-clock elapsed time since start_time.
 *          Designed for accurate timing of parallel operations.
 *          Time format:
 *          - For durations ≥ 1 minute: "mm:ss.xxx" (minutes:seconds.milliseconds)
 *          - For durations < 1 minute: "ss.xxx" (seconds.milliseconds)
 *          Output format is either "message (time)" or "message time" based on with_brackets
 *
 * @pre start_time should be a valid time point obtained from std::chrono::steady_clock::now()
 *
 * @note Uses Rprintf for R package compatibility
 * @note Uses std::chrono::steady_clock for accurate wall-clock timing of parallel operations
 *
 * @example
 * auto ptm = std::chrono::steady_clock::now();
 * // ... code execution ...
 * elapsed_time(ptm, "Processing complete", true);  // Prints "Processing complete (1:23.456)"
 * elapsed_time(ptm, "Processing complete");        // Prints "Processing complete 1:23.456"
 *
 * @see std::chrono::steady_clock
 * @see std::chrono::duration_cast
 */
void elapsed_time(std::chrono::time_point<std::chrono::steady_clock> start_time,
                 const char* message,
                 bool with_brackets,
                 bool with_timestamp) {
    auto end_time = std::chrono::steady_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time);

    double elapsed = duration.count() / 1000.0; // Convert to seconds
    int minutes = static_cast<int>(elapsed / 60);
    int seconds = static_cast<int>(fmod(elapsed, 60));
    int ms = static_cast<int>(fmod(elapsed * 1000, 1000));

    char time_str[20];
    if (minutes > 0) {
        snprintf(time_str, sizeof(time_str), "%d:%02d.%03d", minutes, seconds, ms);
    } else {
        snprintf(time_str, sizeof(time_str), "%d.%03d", seconds, ms);
    }

    if (with_timestamp) {
        char timestamp_buf[24];
        format_timestamp(timestamp_buf, sizeof(timestamp_buf));

        if (with_brackets) {
            Rprintf("[%s] %s (%s)\n", timestamp_buf, message, time_str);
        } else {
            Rprintf("[%s] %s %s\n", timestamp_buf, message, time_str);
        }
        return;
    }

    if (with_brackets) {
        Rprintf("%s (%s)\n", message, time_str);
        return;
    }

    Rprintf("%s %s\n", message, time_str);
}
