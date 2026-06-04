/*!

  Union-Find Algorithm for finding connected components of a graph

    * Initially, each vertex is treated as its own separate component (a set of one element).
    * When an edge exists between two vertices, merge (union) their corresponding sets.
    * After processing all edges, the remaining distinct sets represent the connected components.

    Key Idea:  Vertices belonging to the same set indicate they are connected by some sequence of edges.

 */

#include "graph_conn_components_r.h"

#include <vector>
#include <unordered_set>
#include <memory>
#include <numeric>
#include <algorithm>
#include <map>
#include <unordered_map>

#include <R.h>
#include <Rinternals.h>

/**
 * @brief Computes connected components of a graph using Union-Find (disjoint set) data structure
 *
 * @details Implements weighted quick union with path compression for optimal performance.
 * Each vertex starts in its own component, and components are merged when edges are processed.
 * The function returns a vector where each entry i contains the representative (root) vertex
 * of the component containing vertex i.
 *
 * Time complexity: O(α(V)×E) where α is the inverse Ackermann function, V is number of vertices,
 * and E is number of edges.
 * Space complexity: O(V)
 *
 * @param adj_vect Adjacency list representation of the graph
 * @return Vector where entry i is the component identifier for vertex i
 */
std::vector<int> union_find(const std::vector<std::vector<int>>& adj_vect) {

    int n_vertices = adj_vect.size();

    // Initialization - each vertex is its own parent initially
    std::vector<int> parent(n_vertices);
    std::iota(parent.begin(), parent.end(), 0);
    // for (int i = 0; i < n_vertices; ++i)
    //     parent[i] = i;

    // Find the root of a given vertex (with path compression)
    // 1. **Base Case (Root Found):**
    //     - If `i` is its own parent (meaning `parent[i]` is `i`), it has reached the root of its set. It returns `i` as the root.
    // 2. **Recursive Exploration (Path Compression):**
    //     - If `i` is not its own parent, the function recursively calls `find_root(parent[i])`. This continues the exploration up the tree towards the root.
    //     - Importantly, the line `parent[i] = find_root(parent[i])` performs path compression.
    //     - It assigns the result of `find_root(parent[i])` (which is the actual root) back to `parent[i]`.
    //     - This effectively shortens the path from `i` to the root by making all nodes along the path point directly to the root.
    //
    //     - Subsequent calls to `find_root` for nodes along the compressed path will be much faster because they will directly access the root.
    auto find_root = [&](int i) {
        while (i != parent[i]) {
            parent[i] = parent[parent[i]];
            i = parent[i];
        }
        return i;
    };

    // Union of two sets containing vertices x and y using union-by-rank optimization
    std::vector<int> rank(n_vertices, 0);

    // The union-by-rank optimization maintains a `rank` array (initialized to 0 for all vertices). The `rank` of a vertex roughly corresponds to the depth of its subtree.
    // When merging the sets of `x` and `y` (by making one root the parent of another), the root with the higher `rank` is chosen to be the parent of the other.
    // If the roots have the same `rank`, then after the union, the `rank` of the chosen parent is incremented.
    //
    // The benefit of the union-by-rank optimization is that it keeps trees
    // shallow, prevents trees from becoming overly skewed; the resulting trees
    // are closer to being balanced.
    auto union_sets = [&](int x, int y) {
        int root_x = find_root(x);
        int root_y = find_root(y);
        if (root_x != root_y) {
            if (rank[root_x] < rank[root_y]) {
                parent[root_x] = root_y;
            } else if (rank[root_x] > rank[root_y]) {
                parent[root_y] = root_x;
            } else {
                parent[root_y] = root_x;
                rank[root_x]++;
            }
        }
    };

    // Process edges
    for (int i = 0; i < n_vertices; ++i) {
        for (int adj : adj_vect[i]) {
            union_sets(i, adj);
        }
    }

    // Constructing a component vector with component_vect[i] = the root of i
    std::vector<int> component_vect(n_vertices);
    for (int i = 0; i < n_vertices; ++i) {
        component_vect[i] = find_root(i);
    }

    return component_vect;
}

std::unique_ptr<std::unordered_map<int, int>> count_subgraph_components(const std::vector<std::vector<int>>& graph,
                                                                        const std::vector<int>& V) {
    auto subgraph_adj_list = std::vector<std::vector<int>>(V.size());

    for (size_t i = 0; i < V.size(); ++i) {
        int v = V[i];
        for (int neighbor : graph[v]) {
            auto it = std::find(V.begin(), V.end(), neighbor);
            if (it != V.end()) {
                size_t subgraph_index = (size_t)std::distance(V.begin(), it);
                if (i >= subgraph_adj_list.size() || subgraph_index >= subgraph_adj_list.size()) {
                    Rprintf("Index out of bounds: i = %d, subgraph_index = %zu, subgraph_adj_list.size() = %zu\n",
                            (int)i, subgraph_index, subgraph_adj_list.size());
                    return nullptr;
                }
                subgraph_adj_list[i].push_back(subgraph_index);
            }
        }
    }

    auto components = union_find(subgraph_adj_list);
    auto vertex_component_map = std::make_unique<std::unordered_map<int, int>>();
    for (size_t i = 0; i < V.size(); ++i) {
        (*vertex_component_map)[V[i]] = components[i];
    }

    return vertex_component_map;
}

/**
 * Assign Vertices to Connected Components
 *
 * This function takes an R graph representation and assigns each vertex to a connected component.
 *
 * @param R_graph An R list representing the adjacency list of the graph.
 *        Each element of the list corresponds to a vertex and contains the indices of its neighbors.
 *
 * @return An integer vector where each element represents the connected component
 *         ID for the corresponding vertex.
 *
 * Example usage in R:
 * graph <- list(c(2,3), c(1), c(1), c(5), c(4))
 * components <- .Call("S_graph_connected_components", graph)
 *
 * @note This function is to be called from R using .Call()
 */
SEXP S_graph_connected_components(SEXP R_graph) {

    if (!Rf_isNewList(R_graph)) {
        Rf_error("Input must be a list");
    }

    int n = Rf_length(R_graph);
    auto adj_vect = std::vector<std::vector<int>>(n);

    for (int i = 0; i < n; ++i) {
        SEXP neighbors = VECTOR_ELT(R_graph, i);
        if (!Rf_isInteger(neighbors)) {
            Rf_error("Each element of the input list must be an integer vector");
        }
        int* p_neighbors = INTEGER(neighbors);
        int m = Rf_length(neighbors);
        adj_vect[i].reserve(m);
        for (int j = 0; j < m; ++j) {
            adj_vect[i].push_back(p_neighbors[j]);
        }
    }

    std::vector<int> result = union_find(adj_vect);

    SEXP R_result = PROTECT(Rf_allocVector(INTSXP, n));
    int* p_result = INTEGER(R_result);

    for (int i = 0; i < n; ++i) {
        p_result[i] = result[i] + 1; // Convert 0-based to 1-based indexing
    }

    UNPROTECT(1);

    return R_result;
}
