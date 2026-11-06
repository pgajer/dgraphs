#pragma once

// Preserve compatibility with native clients while using serial execution.
// Some SDKs define macros that conflict with C++ headers.
#ifdef match
#  undef match
#endif
#ifdef check
#  undef check
#endif

  // Native graph construction remains serial even when the compiler enables OpenMP.
  static inline int  dgraphs_get_max_threads(void)    { return 1; }
  static inline int  dgraphs_get_thread_num(void)     { return 0; }
  static inline int  dgraphs_in_parallel(void)        { return 0; }
  static inline int  dgraphs_get_num_procs(void)      { return 1; }
  static inline int  dgraphs_get_thread_limit(void)   { return 1; }
  static inline void dgraphs_set_dynamic(int on)      { (void)on; }
  static inline void dgraphs_set_num_threads(int n)   { (void)n; }
