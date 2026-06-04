#ifndef EDGE_INFO_H_
#define EDGE_INFO_H_

#include <cstddef>
#include <functional>   // for std::hash

#include <R.h>
#include <Rinternals.h>

using std::size_t;

/**
 * @struct edge_info_t
 * @brief Represents an edge in the graph with its target vertex and weight
 *
 * This structure is used within the adjacency lists to store edge information.
 * The comparison operator enables its use in ordered containers like std::set.
 */
struct edge_info_t {
	size_t vertex;   ///< Target vertex of the edge
	double weight;   ///< Weight (length) of the edge


	/// Default constructor
	edge_info_t() : vertex(0), weight(0.0) {}

	/// Parameterized constructor
	edge_info_t(size_t v, double w) : vertex(v), weight(w) {}

	// Equality operator for unordered_set
	bool operator==(const edge_info_t& other) const {
		return vertex == other.vertex;
	}

	// Less than operator for ordered set (if needed)
	bool operator<(const edge_info_t& other) const {
		return vertex < other.vertex;
	}
};

// Hash function for edge_info_t (needed for unordered_set)
namespace std {
	template<>
	struct hash<edge_info_t> {
		size_t operator()(const edge_info_t& e) const {
			return hash<size_t>()(e.vertex);
		}
	};
}

#endif // EDGE_INFO_H_
