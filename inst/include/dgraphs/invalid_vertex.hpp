#ifndef INVALID_VERTEX_HPP
#define INVALID_VERTEX_HPP

#include <limits>   // for std::numeric_limits
#include <cstddef>  // for size_t

using std::size_t;

constexpr size_t INVALID_VERTEX = std::numeric_limits<size_t>::max();

#endif // INVALID_VERTEX_HPP
