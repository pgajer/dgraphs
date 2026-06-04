#ifndef IKNN_GRAPHS_HPP_
#define IKNN_GRAPHS_HPP_

#include "vect_wgraph.hpp"
#include "iknn_vertex.hpp"

struct knn_result_t;

struct iknn_graph_t {
    std::vector<std::vector<iknn_vertex_t>> graph; // ToDo: change to 'neighbors' or 'adjacency_list'

    // Constructor that takes initial size
    explicit iknn_graph_t(size_t n_vertices)
        : graph(n_vertices),
          total_isize_cache(n_vertices),
          num_edges_cache(n_vertices)
        {}

    // Constructor takes rvalue reference - meaning it expects a temporary or moved value
    explicit iknn_graph_t(std::vector<std::vector<iknn_vertex_t>>&& input_graph)
        : graph(std::move(input_graph)),
          total_isize_cache(input_graph.size()),
          num_edges_cache(input_graph.size())
        {}

    // Public interface declaration
    vect_wgraph_t prune_graph(int max_alt_path_length) const;

    size_t size() const {
        return graph.size();
    }

    const std::vector<iknn_vertex_t>& get_neighbors(int vertex) const {
        return graph[vertex];
    }

    // Future member functions could include:
    // void add_edge(int from, int to, int common_count, double distance);
    // void remove_edge(int from, int to);

    void print(size_t vertex_index_shift = 0,
               const std::string& name = "") const;

private:
    mutable std::vector<int> total_isize_cache;
    mutable std::vector<int> num_edges_cache;

    // Helper struct for edge processing
    struct weighted_edge_t {
        size_t start;
        size_t end;
        double dist;
        size_t isize;

        bool operator<(const weighted_edge_t& other) const {
            if (isize < other.isize) return true;      // Smaller isizeance first
            if (isize > other.isize) return false;     // Larger isizeance later
            // Break ties in same order as original
            if (start < other.start) return true;
            if (start > other.start) return false;
            return end < other.end;
        }
    };

    // Private helper function declaration
    bool find_alternative_path(int start,
                               int end,
                               int edge_isize,
                               int max_path_length) const;

};

/**
 * Build an ikNN graph from flat kNN buffers (shared backend entry point).
 *
 * @param knn_result Flat kNN result with row-major [n x k_full] buffers.
 * @param k Number of neighbors from each row to use (k <= knn_result.k).
 * @param use_bucket_parallel Enable bucket-level OpenMP parallelism when available.
 * @param num_threads Requested OpenMP thread count.
 */
iknn_graph_t create_iknn_graph_from_knn_result(
    const knn_result_t& knn_result,
    int k,
    bool use_bucket_parallel = true,
    int num_threads = 1
);

#endif // IKNN_GRAPHS_HPP_
