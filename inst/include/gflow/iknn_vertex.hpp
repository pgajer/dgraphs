#ifndef IKNN_VERTEX_H_
#define IKNN_VERTEX_H_

#include <cstddef>
using std::size_t;

struct iknn_vertex_t {
    size_t index;   ///< Index of the neighbor
    size_t isize;   ///< Size of neighborhood intersection
    double dist;    ///< Minimum indirect distance through common neighbors
};

#endif // IKNN_VERTEX_H_
