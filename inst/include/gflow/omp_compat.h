#pragma once

// Some SDKs leak macros that break OpenMP pragmas; sanitize.
#ifdef match
#  undef match
#endif
#ifdef check
#  undef check
#endif

#ifdef _OPENMP
  #include <omp.h>
  static inline int  gflow_get_max_threads(void)    { return omp_get_max_threads(); }
  static inline int  gflow_get_thread_num(void)     { return omp_get_thread_num(); }
  static inline int  gflow_in_parallel(void)        { return omp_in_parallel(); }
  static inline int  gflow_get_num_procs(void)      { return omp_get_num_procs(); }
  static inline int  gflow_get_thread_limit(void)   { return omp_get_thread_limit(); }
  static inline void gflow_set_dynamic(int on)      { omp_set_dynamic(on ? 1 : 0); }
  static inline void gflow_set_num_threads(int n)   { if (n > 0) omp_set_num_threads(n); }
#else
  // Stubs for builds without OpenMP
  static inline int  gflow_get_max_threads(void)    { return 1; }
  static inline int  gflow_get_thread_num(void)     { return 0; }
  static inline int  gflow_in_parallel(void)        { return 0; }
  static inline int  gflow_get_num_procs(void)      { return 1; }
  static inline int  gflow_get_thread_limit(void)   { return 1; }
  static inline void gflow_set_dynamic(int on)      { (void)on; }
  static inline void gflow_set_num_threads(int n)   { (void)n; }
#endif
