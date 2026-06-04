#pragma once

#include <algorithm>
#include <numeric>
#include <type_traits>
#include <iterator>
#include <utility>

namespace gflow {
struct seq_t  { explicit constexpr seq_t(int)  {} };
struct fast_t { explicit constexpr fast_t(int) {} };

inline constexpr seq_t  seq{0};
inline constexpr fast_t fast{0};

// Small threshold to avoid threading tiny loops
#ifndef GFLOW_OMP_MIN_N
#  define GFLOW_OMP_MIN_N  16384
#endif

// Helpers: detect random-access iterators
template<class It>
using is_random_access_it = std::bool_constant<
  std::is_base_of_v<std::random_access_iterator_tag,
    typename std::iterator_traits<It>::iterator_category>
>;

// -------- for_each --------
template<class PolicyTag, class It, class Fn>
inline void for_each(PolicyTag, It first, It last, Fn&& fn) {
#if defined(_OPENMP)
  if constexpr (!std::is_same_v<PolicyTag, seq_t> && is_random_access_it<It>::value) {
    const auto n_total = std::distance(first, last);
    if (n_total >= static_cast<decltype(n_total)>(GFLOW_OMP_MIN_N)) {
      const auto n = static_cast<std::ptrdiff_t>(n_total);
      #pragma omp parallel for schedule(static)
      for (std::ptrdiff_t i = 0; i < n; ++i) {
        fn(*(first + i));
      }
      return;
    }
  }
#endif
  // Serial fallback
  std::for_each(first, last, std::forward<Fn>(fn));
}

// -------- transform --------
template<class PolicyTag, class InIt, class OutIt, class Fn>
inline OutIt transform(PolicyTag, InIt first, InIt last, OutIt out, Fn&& fn) {
  const auto n = std::distance(first, last);
#if defined(_OPENMP)
  if constexpr (!std::is_same_v<PolicyTag, seq_t> &&
                is_random_access_it<InIt>::value && is_random_access_it<OutIt>::value) {
    if (n >= static_cast<decltype(n)>(GFLOW_OMP_MIN_N)) {
      #pragma omp parallel for schedule(static)
      for (std::ptrdiff_t i = 0; i < static_cast<std::ptrdiff_t>(n); ++i) {
        *(out + i) = fn(*(first + i));
      }
      return out + n;
    }
  }
#endif
  return std::transform(first, last, out, std::forward<Fn>(fn));
}

// -------- reduce --------
template<class PolicyTag, class It, class T>
inline T reduce(PolicyTag, It first, It last, T init) {
  const auto n = std::distance(first, last);
#if defined(_OPENMP)
  if constexpr (!std::is_same_v<PolicyTag, seq_t> && is_random_access_it<It>::value &&
                std::is_arithmetic_v<T>) {
    if (n >= static_cast<decltype(n)>(GFLOW_OMP_MIN_N)) {
      T sum = init;
      #pragma omp parallel for reduction(+:sum) schedule(static)
      for (std::ptrdiff_t i = 0; i < static_cast<std::ptrdiff_t>(n); ++i) {
        sum += *(first + i);
      }
      return sum;
    }
  }
#endif
  // Generic serial
  for (; first != last; ++first) init = init + *first;
  return init;
}

// -------- transform_reduce --------
template<class PolicyTag, class It1, class It2, class T, class BinOp1, class BinOp2>
inline T transform_reduce(PolicyTag, It1 f1, It1 l1, It2 f2, T init, BinOp1 reduce_op, BinOp2 xform_op) {
  const auto n = std::distance(f1, l1);
#if defined(_OPENMP)
  if constexpr (!std::is_same_v<PolicyTag, seq_t> &&
                is_random_access_it<It1>::value && is_random_access_it<It2>::value) {
    if (n >= static_cast<decltype(n)>(GFLOW_OMP_MIN_N)) {
      T res = init;
      #pragma omp parallel
      {
        T local = T{};
        #pragma omp for nowait schedule(static)
        for (std::ptrdiff_t i = 0; i < static_cast<std::ptrdiff_t>(n); ++i) {
          local = reduce_op(local, xform_op(*(f1 + i), *(f2 + i)));
        }
        #pragma omp critical
        { res = reduce_op(res, local); }
      }
      return res;
    }
  }
#endif
  for (; f1 != l1; ++f1, ++f2) init = reduce_op(init, xform_op(*f1, *f2));
  return init;
}

} // namespace gflow

// Project-wide default, override per-call with gflow::seq / gflow::fast
#if defined(_WIN32)
#  define GFLOW_EXEC_POLICY gflow::seq
#else
#  define GFLOW_EXEC_POLICY gflow::fast
#endif
