#include <R.h>
#include <Rinternals.h>
#include <time.h>

SEXP qgs_monotonic(void) {
    struct timespec value;
    if (clock_gettime(CLOCK_MONOTONIC, &value) != 0)
        error("CLOCK_MONOTONIC unavailable");
    return ScalarReal((double)value.tv_sec + (double)value.tv_nsec * 1e-9);
}
