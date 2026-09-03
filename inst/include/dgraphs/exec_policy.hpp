#pragma once

#include <algorithm>
#include <numeric>
#include <type_traits>
#include <iterator>
#include <utility>

namespace dgraphs {
struct seq_t  { explicit constexpr seq_t(int)  {} };
struct fast_t { explicit constexpr fast_t(int) {} };

inline constexpr seq_t  seq{0};
inline constexpr fast_t fast{0};

// Helpers: detect random-access iterators
template<class It>
using is_random_access_it = std::bool_constant<
  std::is_base_of_v<std::random_access_iterator_tag,
    typename std::iterator_traits<It>::iterator_category>
>;

// -------- for_each --------
template<class PolicyTag, class It, class Fn>
inline void for_each(PolicyTag, It first, It last, Fn&& fn) {
  // Both policy tags use serial execution.
  std::for_each(first, last, std::forward<Fn>(fn));
}

// -------- transform --------
template<class PolicyTag, class InIt, class OutIt, class Fn>
inline OutIt transform(PolicyTag, InIt first, InIt last, OutIt out, Fn&& fn) {
  return std::transform(first, last, out, std::forward<Fn>(fn));
}

// -------- reduce --------
template<class PolicyTag, class It, class T>
inline T reduce(PolicyTag, It first, It last, T init) {
  // Generic serial
  for (; first != last; ++first) init = init + *first;
  return init;
}

// -------- transform_reduce --------
template<class PolicyTag, class It1, class It2, class T, class BinOp1, class BinOp2>
inline T transform_reduce(PolicyTag, It1 f1, It1 l1, It2 f2, T init, BinOp1 reduce_op, BinOp2 xform_op) {
  for (; f1 != l1; ++f1, ++f2) init = reduce_op(init, xform_op(*f1, *f2));
  return init;
}

} // namespace dgraphs

// Compatibility policy tags; neither enables worker threads.
#if defined(_WIN32)
#  define DGRAPHS_EXEC_POLICY dgraphs::seq
#else
#  define DGRAPHS_EXEC_POLICY dgraphs::fast
#endif
