#ifndef VERTEX_PATH_H_
#define VERTEX_PATH_H_

#include <vector>
#include <cstddef>
using std::size_t;

struct vertex_path_t {
	std::vector<size_t> vertices;              // Vertices in the path
	std::vector<double> dist_to_ref_vertex;    // Distance of each vertex to reference vertex
};

#endif // VERTEX_PATH_H_
