// progress_utils.hpp
#ifndef PROGRESS_UTILS_HPP
#define PROGRESS_UTILS_HPP

#include "error_utils.h" // for REPORT_ERROR()

#include <cstddef>
#include <chrono>

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <R_ext/Print.h>

using std::size_t;

void elapsed_time(std::chrono::time_point<std::chrono::steady_clock> start_time,
                  const char* message,
                  bool with_brackets = false);
void elapsed_time(std::chrono::time_point<std::chrono::steady_clock> start_time,
                  const char* message,
                  bool with_brackets,
                  bool with_timestamp);

void progress_log(const char* fmt, ...);
void progress_log_inline(const char* fmt, ...);

struct progress_tracker_t {
    std::chrono::steady_clock::time_point start_time;
    std::chrono::steady_clock::time_point last_update;
    size_t total_steps;
    size_t current_step;
    size_t update_frequency;  // How often to show progress (in steps)
    const char* task_name;

    progress_tracker_t(size_t total, const char* name, size_t freq = 10)
        : start_time(std::chrono::steady_clock::now()),
          last_update(start_time),
          total_steps(total),
          current_step(0),
          update_frequency(freq),
          task_name(name) {}

    void update(size_t step, bool force = false) {
        current_step = step;
        auto now = std::chrono::steady_clock::now();

        // Update if forced or if enough steps have passed
        if (force || step % update_frequency == 0) {
            double progress = static_cast<double>(step) / total_steps * 100;
            auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(now - start_time).count();
            auto est_total = elapsed * total_steps / step;
            auto remaining = est_total - elapsed;

            Rprintf("\r%s: %.1f%% complete. Est. remaining: %ds",
                   task_name, progress, static_cast<int>(remaining));
            R_FlushConsole();
            last_update = now;
        }
    }

    void finish() {
        auto total_time = std::chrono::steady_clock::now() - start_time;
        auto seconds = std::chrono::duration_cast<std::chrono::seconds>(total_time).count();
        Rprintf("\n%s completed in %ds\n", task_name, static_cast<int>(seconds));
        R_FlushConsole();
    }
};

#endif // PROGRESS_UTILS_HPP
