/*!
  Functions for pruning long edges of a graph, where by a 'long' edge I mean an
  edge for which there is an alternative path between the vertices of the edge.

  An intersection kNN graph G(X|k) associated with a data matrix X is a graph
  whose vertices are integers corresponding to the row indices of X and two
  vertices i,j are connected by an edge if the intersection N(i) \cap N(j) of k
  nearest neighbors of i and j, respectively, is non-empty. The number of elements
  in N(i) \cap N(j) is the isize (intersection size) of the corresponding edge.

  The following prune_long_edges function prunes long edges of the intersection
  kNN graph, where a 'long' edge is defined as an edge for which there exists an
  alternate path between its endpoint vertices all edges of which have
  intersection size (isize) greater than the isize of the current edge. The
  intuition behind the isize based pruning is that the an edge is in some
  sense redundant if the corresponding vertices are connected by a path whose each
  edge is shorter (has higher isize) than the given edge.

  A limitation of the isize pruning as implemented above is that it allows
  alternative paths to be arbitrarily long, whereas intuitively the alternative
  path should be of comparable Rf_length(if we had access to edge lenghts) to the
  length of the edge we are removing. This lack of constrain on the length of the
  alternative path may result in the pruned graph having different topology than
  the original graph. For example, let X be a noisy circle (points in a tubular
  neighborhood of a circle) and G(X|k) is an intersection kNN graph associated
  with X whose embedding recovers the shape of the circle. The graph may have a
  long edge whose alternative path goes around the circle (and so is very long).
  The removal of that edge may result with the pruned graph being approximately a
  chain graph and so the topology of the graph got altered. I want to modify the
  pruning process by impsing the limit on how long the alternative path can be.
  For this I want to replace the function is_edge_redundant by
  alternative_path_length that returns the length of the alternative path if such
  path exists and returns 0 otherwise. I want to use this function to first look
  at the distribution of alternative path lengths in synthetic data and then
  figure out a threshold for that length of the path in the isize pruning.
 */

#include "pruning_long_edges_r.h"
#include "SEXP_cpp_conversion_utils.hpp"
#include "iknn_graphs.hpp"

#include <vector>
#include <queue>
#include <functional> // For std::hash
#include <memory>
#include <limits>
#include <algorithm>
#include <unordered_set>
#include <set>

#include <ANN/ANN.h>  // ANN library header

#include <R.h>
#include <Rinternals.h>

std::vector<std::vector<std::pair<int, int>>> convert_to_int_weighted_adj_list(const std::vector<std::vector<int>>& adj_vect,
                                                                               const std::vector<std::vector<int>>& isize_vect);

struct pair_hash {
    template<typename T1, typename T2>
    std::size_t operator()(const std::pair<T1, T2>& pair) const {
        return std::hash<T1>()(pair.first) ^ std::hash<T2>()(pair.second);
    }
};

// Breadth-First Search to check for alternate paths
// to be used on-line during graph construction
bool has_alternate_path(const std::vector<std::vector<int>>& graph, int source, int target) {
    int n_vertices = graph.size();
    std::vector<bool> visited(n_vertices, false); // Keep track of visited vertices

    std::queue<int> q;
    q.push(source);
    visited[source] = true;

    while (!q.empty()) {
        int current = q.front();
        q.pop();

        // Check neighbors of the current vertex
        for (int neighbor : graph[current]) {
            if (neighbor == target) {
                // Found an alternate path to the target
                return true;
            }

            if (!visited[neighbor]) {
                visited[neighbor] = true;
                q.push(neighbor);
            }
        }
    }

    // Target is not reachable from the source with the direct edge removed
    return false;
}

/*!
  Tests for Alternate Paths Between Edge Vertices

  This function determines if there exists an alternate path between the two
  vertices of an edge in the given graph. It utilizes a Breadth-First Search
  (BFS) algorithm to perform the check.

  \param graph The graph to test, represented as an adjacency list.
  \param source The source vertex of the edge.
  \param target The target vertex of the edge.

  \return A logical value: `TRUE` if an alternate path exists between
  the source and target vertices, `FALSE` otherwise.
*/
bool is_edge_redundant(const std::vector<std::vector<int>>& graph, int source, int target) {

    int n_vertices = graph.size();
    std::vector<bool> visited(n_vertices, false); // Keep track of visited vertices

    std::queue<int> q;
    q.push(source);
    visited[source] = true;

    int depth = 0; // The depth at the start is 0
    while (!q.empty()) {
        int level_size = q.size(); // Tracks the number of nodes at the current level

        // Process all neighbors at the current depth level
        while (level_size-- > 0) {
            int current = q.front();
            q.pop();

            for (int neighbor : graph[current]) {
                if (depth > 1 && neighbor == target) {
                    return true; // Found an alternate path
                }

                if (!visited[neighbor]) {
                    visited[neighbor] = true;
                    q.push(neighbor);
                }
            }
        }

        depth++; // Increment depth after processing the current level
    }

    return false;
}

/*!
  Prunes Long Edges of a Graph

  This function removes 'long' edges from the given graph. A 'long' edge is
  defined as an edge for which there exists an alternate path between its
  endpoint vertices. The function utilizes a Breadth-First Search (BFS) algorithm
  to identify such edges.

  \param graph The input graph represented as an adjacency list.

  \return A pointer to a new adjacency list representing the graph with long edges removed.
 */
std::unique_ptr<std::vector<std::vector<int>>> prune_long_edges(const std::vector<std::vector<int>>& graph) {

    int n_vertices = graph.size();

    std::unordered_set<std::pair<int, int>, pair_hash> edges; // using unordered_set to make sure there are no Rf_duplicate edges in 'edges'
    for (int i = 0; i < n_vertices; i++) {
        for (auto neighbor : graph.at(i)) {
            if ( i < neighbor ) {
                edges.emplace(i, neighbor);
            } else {
                edges.emplace(neighbor, i);
            }
        }
    }

    std::unordered_set<std::pair<int, int>, pair_hash> edges_to_prune;
    int start;
    int end;
    for (auto edge: edges) {
        start = edge.first;
        end = edge.second;
        if ( is_edge_redundant(graph, start, end) ) {
            edges_to_prune.emplace(start, end);
        }
    }

    auto res = std::make_unique<std::vector<std::vector<int>>>(n_vertices); // pruned graph

    for (const auto& edge : edges) {
        if (edges_to_prune.count(edge) == 0) { // Check if the edge is NOT in edges_to_prune
            start = edge.first;
            end = edge.second;
            (*res)[start].push_back(end);
            (*res)[end].push_back(start);
        }
    }

    return res;
}

// --------------------------------------------------------------------------------------------
//
// Intersection kNN graph prune edge functions
//
// --------------------------------------------------------------------------------------------

typedef struct
{
    int start; // start vertex
    int end;   // end vertex;
    int isize; // intersection size
} iedge_t; // intersection kNN graph edge

struct iedge_t_cmp {
    bool operator()(const iedge_t& lhs, const iedge_t& rhs) const {
        if (lhs.isize < rhs.isize) return true;
        if (lhs.isize > rhs.isize) return false;
        // Break ties based on consistent vertex ordering
        if (lhs.start < rhs.start) return true;
        if (lhs.start > rhs.start) return false;
        return lhs.end < rhs.end;
    }
};

/*!
  \brief Removes an edge between two specified vertices in an undirected graph.

  \details This function modifies the graph in-place to remove the connection
  between the vertices specified by `start` and `end`. It assumes that the
  graph is undirected, meaning removing the edge from `start` to `end` also
  removes the corresponding edge from `end` to `start`.

  \param graph A reference to  a vector of vectors of (int, int) pairs, representing the graph's adjacency structure. The graph is modified by this function.
  \param start The index of the starting vertex of the edge to remove.
  \param end The index of the ending vertex of the edge to remove.
 */
void remove_edge(std::vector<std::vector<std::pair<int, int>>>& graph, int start, int end) {

    auto& start_neighbors = graph[start];
    auto it_start = std::find_if(start_neighbors.begin(), start_neighbors.end(),
                                 [end](const std::pair<int, int>& p) { return p.first == end; });
    if (it_start != start_neighbors.end()) { // Check if the edge was found
        start_neighbors.erase(it_start);
    }

    auto& end_neighbors = graph[end];
    auto it_end = std::find_if(end_neighbors.begin(), end_neighbors.end(),
                               [start](const std::pair<int, int>& p) { return p.first == start; });
    if (it_end != end_neighbors.end()) {
        end_neighbors.erase(it_end);
    }
}

/*!
  \brief Tests for the existence of an isize-alternate path between edge vertices in an intersection kNN graph.

  This function determines if there exists an isize-alternate path between the two vertices of an edge in an intersection kNN graph. An isize-alternate path is a path that satisfies the following conditions:
  - It has at least one intermediate vertex.
  - All edges along the path have an intersection size greater than the intersection size of the given edge.

  \param graph The intersection kNN graph, represented as an adjacency list where each element is a pair of (neighbor_index, intersection_size).
  \param source The source vertex of the edge.
  \param target The target vertex of the edge.
  \param edge_isize The intersection size of the given edge.

  \return `true` if an isize-alternate path exists between the source and target vertices, `false` otherwise.
*/
bool is_edge_redundant(std::vector<std::vector<std::pair<int, int>>>& graph,
                       int source, int target, int edge_isize) {
    int n_vertices = graph.size();
    std::vector<int> visited(n_vertices, false);
    std::deque<int> q;

    q.push_back(source);
    visited[source] = true;

    while (!q.empty()) {
        int current = q.front();
        q.pop_front();

        for (const auto& neighbor_pair : graph[current]) {
            int neighbor = neighbor_pair.first;
            int neighbor_isize = neighbor_pair.second;

            if (neighbor == target && neighbor_isize > edge_isize) {
                return true;
            }

            if (!visited[neighbor] && neighbor_isize > edge_isize) {
                visited[neighbor] = true;
                q.push_back(neighbor);
            }
        }
    }

    return false;
}


/**
 * @brief Tests for the existence of an isize-alternate path between edge vertices in an intersection kNN graph.
 *
 * This function determines if there exists an isize-alternate path between the two vertices of an edge
 * in an intersection kNN graph. An isize-alternate path is a path that satisfies the following conditions:
 * - It has at least one intermediate vertex.
 * - All edges along the path have an intersection size greater than the intersection size of the given edge.
 *
 * The function returns a pair containing a boolean value indicating whether an isize-alternate path exists
 * and the actual alternate path as a vector of vertex indices.
 *
 * @param graph The intersection kNN graph, represented as an adjacency list where each element is a pair of (neighbor_index, intersection_size).
 * @param source The source vertex of the edge.
 * @param target The target vertex of the edge.
 * @param edge_isize The intersection size of the given edge.
 * @return A pair containing a boolean value indicating whether an isize-alternate path exists and the alternate path as a vector of vertex indices.
 *         If an isize-alternate path exists, the boolean value is true and the vector contains the vertex indices of the path.
 *         If an isize-alternate path does not exist, the boolean value is false and the vector is empty.
 */
std::pair<bool, std::vector<int>> is_edge_redundant_with_alt_path(const std::unique_ptr<std::vector<std::vector<std::pair<int, int>>>>& graph,
                                                    int source, int target, int edge_isize) {
    int n_vertices = graph->size();
    std::vector<int> parent(n_vertices, -1);
    std::vector<int> visited(n_vertices, false);
    std::deque<int> q;

    q.push_back(source);
    visited[source] = true;

    while (!q.empty()) {
        int current = q.front();
        q.pop_front();

        for (const auto& neighbor_pair : (*graph)[current]) {
            int neighbor = neighbor_pair.first;
            int neighbor_isize = neighbor_pair.second;

            if (neighbor == target && neighbor_isize > edge_isize) {
                // Reconstruct the alternative path
                std::vector<int> path;
                int v = target;
                while (v != -1) {
                    path.push_back(v);
                    v = parent[v];
                }
                std::reverse(path.begin(), path.end());
                return {true, path};
            }

            if (!visited[neighbor] && neighbor_isize > edge_isize) {
                visited[neighbor] = true;
                parent[neighbor] = current;
                q.push_back(neighbor);
            }
        }
    }

    return {false, {}};
}

/**
 * @brief Finds the shortest isize-alternate path between edge vertices in an intersection kNN graph.
 *
 * This function finds the shortest isize-alternate path between the two vertices of an edge
 * in an intersection kNN graph. An isize-alternate path is a path that satisfies the following conditions:
 * - It has at least one intermediate vertex.
 * - All edges along the path have an intersection size greater than the intersection size of the given edge.
 *
 * The function uses a breadth-first search (BFS) algorithm to ensure that the returned path has the minimum
 * number of edges among all possible isize-alternate paths.
 *
 * @param graph The intersection kNN graph, represented as an adjacency list where each element is a pair of (neighbor_index, intersection_size).
 * @param source The source vertex of the edge.
 * @param target The target vertex of the edge.
 * @param edge_isize The intersection size of the given edge.
 * @return A vector of vertex indices representing the shortest alternate path.
 *         If no valid alternate path exists, returns an empty vector.
 */
std::vector<int> find_shortest_alt_path(const std::vector<std::vector<std::pair<int, int>>>& graph,
                                        int source, int target, int edge_isize) {
    int n_vertices = graph.size();
    std::vector<int> parent(n_vertices, -1);
    std::vector<bool> visited(n_vertices, false);
    std::queue<int> q;

    q.push(source);
    visited[source] = true;

    while (!q.empty()) {
        int current = q.front();
        q.pop();

        for (const auto& neighbor_pair : graph[current]) {
            int neighbor = neighbor_pair.first;
            int neighbor_isize = neighbor_pair.second;

            if (neighbor_isize <= edge_isize) {
                continue;
            }

            if (!visited[neighbor]) {
                visited[neighbor] = true;
                parent[neighbor] = current;
                q.push(neighbor);

                if (neighbor == target) {
                    std::vector<int> path;
                    for (int v = target; v != -1; v = parent[v]) {
                        path.push_back(v);
                    }
                    std::reverse(path.begin(), path.end());

                    if (path.size() > 2) {
                        return path;
                    }
                }
            }
        }
    }

    return {};  // Return empty vector if no valid path exists
}

/*!
  \brief Finds the length of the shortest isize-alternate path between edge vertices in an intersection kNN graph.

  This function determines if there exists an isize-alternate path between the two vertices of an edge in
  an intersection kNN graph and returns its length. An isize-alternate path is a path that satisfies:
  - All edges along the path have intersection sizes greater than edge_isize
  - The path must go through at least one intermediate vertex because:
    1. We are looking for an alternative path for an edge (source, target) with a given edge_isize
    2. This means an edge between source and target with intersection size = edge_isize already exists
    3. Since the graph representation doesn't allow multiple edges between the same vertices,
       any alternative path must go through at least one intermediate vertex

  The function uses Breadth-First Search (BFS) which guarantees finding the path with the minimum number
  of edges among all valid alternative paths. This means if there are multiple valid paths between the
  vertices (all having edges with intersection sizes > edge_isize), the function will return the length
  of the path that uses the fewest edges.

  The requirement for paths to include at least one intermediate vertex (length ≥ 2) is explicitly
  enforced in the implementation.

  \param graph The intersection kNN graph, represented as an adjacency list where each element is a pair
         of (neighbor_index, intersection_size). For each edge, intersection size is stored in both
         directions as the graph is undirected.
  \param source The source vertex of the edge.
  \param target The target vertex of the edge.
  \param edge_isize The intersection size of the given edge that we're trying to find an alternative for.
  \return The number of edges in the shortest isize-alternate path if one exists, 0 otherwise.
          A return value of:
          - 0 means no alternative path exists
          - n ≥ 2 means the shortest alternative path uses n edges going through n-1 intermediate vertices
*/
int shortest_alt_path_length(const std::vector<std::vector<std::pair<int, int>>>& graph,
                             int source, int target, int edge_isize) {
    int n_vertices = graph.size();
    if (n_vertices == 2) {
        return 0;
    }

    std::vector<int> distance(n_vertices, -1);  // Track distances instead of just visited
    std::queue<int> q;

    // Initialize BFS from source
    q.push(source);
    distance[source] = 0;

    while (!q.empty()) {
        int current = q.front();
        q.pop();

        // Check all neighbors of current vertex
        for (const auto& neighbor_pair : graph[current]) {
            int neighbor = neighbor_pair.first;
            int neighbor_isize = neighbor_pair.second;

            // Skip if intersection size requirement is not met
            if (neighbor_isize <= edge_isize) {
                continue;
            }

            // If we haven't visited this neighbor yet
            if (distance[neighbor] == -1) {
                distance[neighbor] = distance[current] + 1;
                q.push(neighbor);

                // If we've reached the target, check if path length is valid
                if (neighbor == target && distance[neighbor] >= 2) {
                    return distance[neighbor];  // Return number of edges in path
                }
            }
        }
    }

    return 0;  // Return 0 if no valid path exists
}

/*!
  \brief Finds both the length and total intersection size of the shortest isize-alternate path.

  This function determines if there exists an isize-alternate path between two vertices in
  an intersection kNN graph and returns both the number of edges and the sum of intersection
  sizes along this path. An isize-alternate path is a path that satisfies:
  - All edges along the path have intersection sizes greater than edge_isize
  - The path must go through at least one intermediate vertex because:
    1. We are looking for an alternative path for an edge (source, target) with a given edge_isize
    2. This means an edge between source and target with intersection size = edge_isize already exists
    3. Since the graph representation doesn't allow multiple edges between the same vertices,
       any alternative path must go through at least one intermediate vertex

  The function uses Breadth-First Search (BFS) which guarantees finding the path with the minimum
  number of edges among all valid alternative paths. This means if there are multiple valid paths
  between the vertices (all having edges with intersection sizes > edge_isize), the function will
  return the metrics for the path that uses the fewest edges.

  \param graph The intersection kNN graph, represented as an adjacency list where each element is a pair
         of (neighbor_index, intersection_size). For each edge, intersection size is stored in both
         directions as the graph is undirected.
  \param source The source vertex of the edge.
  \param target The target vertex of the edge.
  \param edge_isize The intersection size of the given edge that we're trying to find an alternative for.
  \return A pair containing (number of edges, total intersection size) for the shortest alternative path.
          Returns (0,0) if no valid path exists. Otherwise returns (n,m) where:
          - n ≥ 2 is the number of edges in the shortest alternative path
          - m is the sum of intersection sizes along this path
*/
std::pair<int,int> find_alt_path_metrics(const std::vector<std::vector<std::pair<int, int>>>& graph,
                                        int source, int target, int edge_isize) {
    int n_vertices = graph.size();
    std::vector<int> total_isize(n_vertices, -1);  // Track total isize
    std::vector<int> num_edges(n_vertices, 0);     // Track number of edges in path
    std::queue<int> q;

    // Initialize BFS from source
    q.push(source);
    total_isize[source] = 0;
    num_edges[source] = 0;

    while (!q.empty()) {
        int current = q.front();
        q.pop();

        // Check all neighbors of current vertex
        for (const auto& neighbor_pair : graph[current]) {
            int neighbor = neighbor_pair.first;
            int neighbor_isize = neighbor_pair.second;

            // Skip if intersection size requirement is not met
            if (neighbor_isize <= edge_isize) {
                continue;
            }

            // If we haven't visited this neighbor yet
            if (total_isize[neighbor] == -1) {
                total_isize[neighbor] = total_isize[current] + neighbor_isize;
                num_edges[neighbor] = num_edges[current] + 1;
                q.push(neighbor);

                // If we've reached the target, check if path length is valid
                if (neighbor == target && num_edges[neighbor] >= 2) {
                    return {num_edges[neighbor], total_isize[neighbor]};
                }
            }
        }
    }
    return {0, 0};  // Return (0,0) if no valid path exists
}

/*!
  \brief Finds the total intersection size of the shortest isize-alternate path between edge vertices.

  This function determines if there exists an isize-alternate path between two vertices in
  an intersection kNN graph and returns the sum of intersection sizes along this path.
  An isize-alternate path is a path that satisfies:
  - All edges along the path have intersection sizes greater than edge_isize
  - The path must go through at least one intermediate vertex because:
    1. We are looking for an alternative path for an edge (source, target) with a given edge_isize
    2. This means an edge between source and target with intersection size = edge_isize already exists
    3. Since the graph representation doesn't allow multiple edges between the same vertices,
       any alternative path must go through at least one intermediate vertex

  The function uses Breadth-First Search (BFS) which guarantees finding the path with the minimum
  number of edges among all valid alternative paths. This means if there are multiple valid paths
  between the vertices (all having edges with intersection sizes > edge_isize), the function will
  return the total intersection size of the path that uses the fewest edges (not necessarily the
  path with minimum total intersection size).

  \param graph The intersection kNN graph, represented as an adjacency list where each element is a pair
         of (neighbor_index, intersection_size). For each edge, intersection size is stored in both
         directions as the graph is undirected.
  \param source The source vertex of the edge.
  \param target The target vertex of the edge.
  \param edge_isize The intersection size of the given edge that we're trying to find an alternative for.
  \return The total intersection size of the shortest isize-alternate path if one exists, 0 otherwise.
          A return value of:
          - 0 means no alternative path exists
          - Otherwise returns the sum of intersection sizes along the shortest alternative path
            (which must contain at least 2 edges)
*/
int shortest_alt_path_total_isize(const std::vector<std::vector<std::pair<int, int>>>& graph,
                                 int source, int target, int edge_isize) {
    int n_vertices = graph.size();
    std::vector<int> total_isize(n_vertices, -1);  // Track total isize
    std::vector<int> num_edges(n_vertices, 0);     // Track number of edges in path
    std::queue<int> q;

    // Initialize BFS from source
    q.push(source);
    total_isize[source] = 0;
    num_edges[source] = 0;

    while (!q.empty()) {
        int current = q.front();
        q.pop();

        // Check all neighbors of current vertex
        for (const auto& neighbor_pair : graph[current]) {
            int neighbor = neighbor_pair.first;
            int neighbor_isize = neighbor_pair.second;

            // Skip if intersection size requirement is not met
            if (neighbor_isize <= edge_isize) {
                continue;
            }

            // If we haven't visited this neighbor yet
            if (total_isize[neighbor] == -1) {
                total_isize[neighbor] = total_isize[current] + neighbor_isize;
                num_edges[neighbor] = num_edges[current] + 1;
                q.push(neighbor);

                // If we've reached the target, check if path length is valid
                if (neighbor == target && num_edges[neighbor] >= 2) {
                    return total_isize[neighbor];
                }
            }
        }
    }
    return 0;  // Return 0 if no valid path exists
}

/*!
  \brief Prunes edges from a graph that have alternative paths with higher intersection sizes,
         subject to optional path length constraints.

  This function examines each edge in the graph to determine if it can be pruned (i.e., if there
  exists an alternative path between its vertices where all edges have higher intersection sizes).
  The pruning decision can be optionally constrained by the maximum allowed length of alternative paths.

  For each candidate edge (whether pruned or not), it records:
  - The intersection size of the edge
  - The number of edges in the alternative path
  - The total intersection size of the alternative path

  The edges are processed in a deterministic order defined by the iedge_t_cmp comparator.

  \param graph The input intersection kNN graph, represented as an adjacency list where each element
         is a pair of (neighbor_index, intersection_size).
  \param long_edge_isize Output vector that will store the intersection sizes of edges with valid
         alternative paths, in the order they are processed.
  \param alt_path_lengths Output vector that will store the number of edges in each alternative path
         found. Each entry corresponds to an edge in the same order as long_edge_isize.
  \param alt_path_total_isize Output vector that will store the sum of intersection sizes along
         each alternative path found. Each entry corresponds to an edge in the same order.
  \param max_alt_path_length Optional parameter to control pruning based on alternative path length:
         - If 0 (default): prunes all edges with valid alternative paths
         - If > 0: only prunes edges whose alternative paths have length ≤ max_alt_path_length
  \return A new graph with redundant edges removed according to the pruning criteria.

  \note The three output vectors (long_edge_isize, alt_path_lengths, and alt_path_total_isize) will
  have the same length. They record metrics for all edges that have valid alternative paths,
  regardless of whether the edge was actually pruned based on the max_alt_path_length constraint.
*/
std::vector<std::vector<std::pair<int, int>>>
prune_edges_with_alt_paths(const std::vector<std::vector<std::pair<int, int>>>& graph,
                           std::vector<int>& long_edge_isize,
                           std::vector<int>& alt_path_lengths,
                           std::vector<int>& alt_path_total_isize,
                           int max_alt_path_length) {
    // Create a copy of the input graph
    std::vector<std::vector<std::pair<int, int>>> pruned_graph = graph;

    // Collect all edges with their intersection sizes
    std::set<iedge_t, iedge_t_cmp> iedges;
    iedge_t iedge;
    for (int i = 0; i < (int)pruned_graph.size(); i++) {
        for (const auto& neighbor_pair : pruned_graph[i]) {
            if (i < neighbor_pair.first) {
                iedge.start = i;
                iedge.end = neighbor_pair.first;
            } else {
                iedge.start = neighbor_pair.first;
                iedge.end = i;
            }
            iedge.isize = neighbor_pair.second;
            iedges.insert(iedge);
        }
    }

    // Clear and reserve space for output vectors
    long_edge_isize.clear();
    alt_path_lengths.clear();
    alt_path_total_isize.clear();
    long_edge_isize.reserve(iedges.size());
    alt_path_lengths.reserve(iedges.size());
    alt_path_total_isize.reserve(iedges.size());

    // Process each edge
    for (const auto& iedge : iedges) {
        auto alt_path_len__path_isize__pair = find_alt_path_metrics(pruned_graph, iedge.start, iedge.end, iedge.isize);
        // If alternative path exists, remove the edge and record metrics
        if (alt_path_len__path_isize__pair.first > 0) { // alt_path_len__path_isize__pair.first = alt_path_len = number of edges in the alternative path
            long_edge_isize.push_back(iedge.isize);
            alt_path_lengths.push_back(alt_path_len__path_isize__pair.first);
            alt_path_total_isize.push_back(alt_path_len__path_isize__pair.second);
            if (max_alt_path_length == 0 || (max_alt_path_length > 0 && alt_path_len__path_isize__pair.first <= max_alt_path_length)) {
                remove_edge(pruned_graph, iedge.start, iedge.end);
            }
        }
    }

    return pruned_graph;
}



/**
 * @brief R interface to find the shortest alternative path in an intersection kNN graph.
 *
 * Takes an adjacency list and corresponding intersection sizes from R, finds the shortest
 * alternative path between two vertices where all edges have intersection sizes greater
 * than the specified edge intersection size.
 *
 * @param s_adj_list R list of integer vectors representing the graph's adjacency list
 * @param s_isize_list R list of integer vectors containing intersection sizes corresponding to adjacencies
 * @param s_source R integer scalar specifying the source vertex
 * @param s_target R integer scalar specifying the target vertex
 * @param s_edge_isize R integer scalar specifying the intersection size threshold
 * @return R integer vector containing the vertices in the shortest alternative path,
 *         or empty vector if no such path exists
 */
SEXP S_find_shortest_alt_path(SEXP s_adj_list,
                              SEXP s_isize_list,
                              SEXP s_source,
                              SEXP s_target,
                              SEXP s_edge_isize) {
    std::vector<std::vector<int>> adj_vect   = convert_adj_list_from_R(s_adj_list);
    std::vector<std::vector<int>> isize_vect = convert_adj_list_from_R(s_isize_list);

    // Extract scalar parameters using defensive coercion
    int source = Rf_asInteger(s_source);
    int target = Rf_asInteger(s_target);
    int edge_isize = Rf_asInteger(s_edge_isize);

    std::vector<std::vector<std::pair<int, int>>> iigraph = convert_to_int_weighted_adj_list(adj_vect, isize_vect);

    std::vector<int> path = find_shortest_alt_path(iigraph, source, target, edge_isize);

    SEXP s_path = convert_vector_int_to_R(path);

    return s_path;
}

/**
 * @brief R interface to find the length of shortest alternative path in an intersection kNN graph.
 *
 * Takes an adjacency list and corresponding intersection sizes from R, computes the length
 * of the shortest alternative path between two vertices where all edges have intersection sizes
 * greater than the specified edge intersection size.
 *
 * @param s_adj_list R list of integer vectors representing the graph's adjacency list
 * @param s_isize_list R list of integer vectors containing intersection sizes corresponding to adjacencies
 * @param s_source R integer scalar specifying the source vertex
 * @param s_target R integer scalar specifying the target vertex
 * @param s_edge_isize R integer scalar specifying the intersection size threshold
 * @return R integer scalar containing the length of the shortest alternative path,
 *         or 0 if no such path exists
 */
SEXP S_shortest_alt_path_length(SEXP s_adj_list,
                                SEXP s_isize_list,
                                SEXP s_source,
                                SEXP s_target,
                                SEXP s_edge_isize) {
    std::vector<std::vector<int>> adj_vect   = convert_adj_list_from_R(s_adj_list);
    std::vector<std::vector<int>> isize_vect = convert_adj_list_from_R(s_isize_list);

    int source     = Rf_asInteger(s_source);
    int target     = Rf_asInteger(s_target);
    int edge_isize = Rf_asInteger(s_edge_isize);

    std::vector<std::vector<std::pair<int, int>>> iigraph = convert_to_int_weighted_adj_list(adj_vect, isize_vect);

    int path_length = shortest_alt_path_length(iigraph, source, target, edge_isize);
    SEXP s_path_length = Rf_ScalarInteger(path_length);
    return s_path_length;
}

/**
 * @brief Tests for the existence of an isize-alternate path between edge vertices in an intersection kNN graph using an alternative algorithm.
 *
 * This function determines if there exists an isize-alternate path between the two vertices of an edge
 * in an intersection kNN graph using an alternative algorithm. The alternative algorithm works as follows:
 * 1. Given an edge with edge_isize, remove all edges from the graph that have an intersection size less than or equal to edge_isize.
 * 2. Perform a BFS traversal starting from the source vertex of the given edge.
 * 3. If the target vertex is reached during the BFS traversal, it means there exists an isize-alternate path between the source and target vertices.
 * 4. If the target vertex is not reached, it means there is no isize-alternate path between the source and target vertices.
 *
 * @param graph The intersection kNN graph, represented as an adjacency list where each element is a pair of (neighbor_index, intersection_size).
 * @param source The source vertex of the edge.
 * @param target The target vertex of the edge.
 * @param edge_isize The intersection size of the given edge.
 * @return True if an isize-alternate path exists between the source and target vertices, false otherwise.
 */
bool is_edge_redundant_alt(std::vector<std::vector<std::pair<int, int>>>& graph,
                           int source, int target, int edge_isize) {
    int n_vertices = graph.size();
    std::vector<std::vector<int>> filtered_graph(n_vertices);
    std::vector<bool> visited(n_vertices, false);
    std::queue<int> q;

    // Create a filtered graph by removing edges with isize <= edge_isize
    for (int i = 0; i < n_vertices; ++i) {
        for (const auto& neighbor_pair : graph[i]) {
            int neighbor = neighbor_pair.first;
            int neighbor_isize = neighbor_pair.second;
            if (neighbor_isize > edge_isize) {
                filtered_graph[i].push_back(neighbor);
            }
        }
    }

    // Perform BFS on the filtered graph
    q.push(source);
    visited[source] = true;

    while (!q.empty()) {
        int current = q.front();
        q.pop();

        if (current == target) {
            return true;
        }

        for (int neighbor : filtered_graph[current]) {
            if (!visited[neighbor]) {
                visited[neighbor] = true;
                q.push(neighbor);
            }
        }
    }

    return false;
}


/*!
  Prunes Long Edges of an Intersection kNN Graph

  This function removes 'long' edges from the given intersection kNN
  graph. A 'long' edge is defined as an edge for which there exists an alternate
  path between its endpoint vertices all edges of which have intersection size
  (isize) greater than the isize of the current edge. The function first sorts
  the edges in ascending order of the intersection size and then utilizes a
  Breadth-First Search (BFS) algorithm to identify such edges.

  The pruning process involves:

  1.*Sorting Edges:** Edges are sorted in ascending order based on their
  intersection size (`isize`).
  2.*Redundancy Check:** For each edge, a Breadth-First Search (BFS) based
  algorithm (`is_edge_redundant`) determines if an alternate path exists
  where all edges have a larger intersection size.
  3.*Removal:** Redundant edges are removed from the graph.

  \param graph A reference to the input intersection kNN graph,
  represented as an adjacency list where each element is a pair
  of (neighbor_index, intersection_size).

  \param version An integer specifying which version of is_edge_redundant function to use. Version 1 uses is_edge_redundant, version 2: is_edge_redundant_alt.

  \return A unique pointer to a new adjacency list representing the pruned graph.
*/
std::unique_ptr<std::vector<std::vector<std::pair<int, int>>>> prune_long_edges(const std::unique_ptr<std::vector<std::vector<std::pair<int, int>>>>& graph,
                                                                                int version) {

    if (version < 1 || version > 2) {
            Rf_error("prune_long_edges(): Invalid 'version' value. Must be 1 or 2");
    }

    auto pruned_graph = std::make_unique<std::vector<std::vector<std::pair<int, int>>>>(*graph);

    std::set<iedge_t, iedge_t_cmp> iedges;
    iedge_t iedge;
    for (int i = 0; i < (int)pruned_graph->size(); i++) {
        for (const auto& neighbor_pair : (*pruned_graph)[i]) {
            if (i < neighbor_pair.first) {
                iedge.start = i;
                iedge.end   = neighbor_pair.first;
            } else {
                iedge.start = neighbor_pair.first;
                iedge.end   = i;
            }
            iedge.isize = neighbor_pair.second;
            iedges.insert(iedge);
        }
    }

    for (auto iedge : iedges) {

        if ((version == 1 && is_edge_redundant(*pruned_graph, iedge.start, iedge.end, iedge.isize)) ||
            (version == 2 && is_edge_redundant_alt(*pruned_graph, iedge.start, iedge.end, iedge.isize))) {

            remove_edge(*pruned_graph, iedge.start, iedge.end);
        }
    }

    return pruned_graph;
}

// -------------------------------------------------------------------------------------------------------------------------------------
//
// edge length based pruning
//
// -------------------------------------------------------------------------------------------------------------------------------------


/**
 * @brief Finds the length of the shortest alternative path between two vertices in a weighted graph.
 *
 * This function searches for an alternative path between the source and target vertices
 * that is shorter than the direct edge between them. It uses a modified breadth-first
 * search algorithm to explore paths, considering edge weights.
 *
 * @param adj_vect A vector of vectors representing the adjacency list of the graph.
 *                 adj_vect[i] contains the indices of vertices adjacent to vertex i.
 * @param edge_length_vect A vector of vectors containing the lengths of edges.
 *                         edge_length_vect[i][j] is the length of the edge from vertex i
 *                         to its j-th neighbor in adj_vect[i].
 * @param source The index of the starting vertex.
 * @param target The index of the ending vertex.
 * @param edge_length The length of the direct edge between source and target.
 *
 * @return The length of the shortest alternative path if one exists and is shorter
 *         than the direct edge; 0 if no such path is found.
 *
 * @note The function assumes that the graph is undirected and the adjacency list
 *       and edge length vector are consistent with each other.
 */
double graph_alternative_path_length_total_path_len_constrained(const std::vector<std::vector<int>>& adj_vect,
                                                                 const std::vector<std::vector<double>>& edge_length_vect,
                                                                 int source,
                                                                 int target,
                                                                 double edge_length) {
    int n_vertices = adj_vect.size();
    std::vector<double> distance(n_vertices, std::numeric_limits<double>::max());
    std::queue<int> q;

    q.push(source);
    distance[source] = 0;

    while (!q.empty()) {
        int current = q.front();
        q.pop();

        for (size_t i = 0; i < adj_vect[current].size(); ++i) {
            int neighbor = adj_vect[current][i];
            double neighbor_edge_length = edge_length_vect[current][i];

            if (neighbor == target && distance[current] + neighbor_edge_length < edge_length) {
                return distance[current] + neighbor_edge_length;
            }

            if (distance[current] + neighbor_edge_length < distance[neighbor] && distance[current] + neighbor_edge_length < edge_length) {
                distance[neighbor] = distance[current] + neighbor_edge_length;
                q.push(neighbor);
            }
        }
    }

    return 0;  // No valid path found
}

/**
 * @brief Finds the length of an alternative path between two vertices in a weighted graph.
 *
 * This function searches for an alternative path between the source and target vertices
 * that satisfies certain length constraints. It uses a modified breadth-first search
 * algorithm to explore paths, considering edge weights.
 *
 * @param adj_vect A vector of vectors representing the adjacency list of the graph.
 *                 adj_vect[i] contains the indices of vertices adjacent to vertex i.
 * @param edge_length_vect A vector of vectors containing the lengths of edges.
 *                         edge_length_vect[i][j] is the length of the edge from vertex i
 *                         to its j-th neighbor in adj_vect[i].
 * @param source The index of the starting vertex.
 * @param target The index of the ending vertex.
 * @param edge_length The length of the direct edge between source and target.
 * @param use_total_length_constraint A boolean flag to choose the length constraint:
 *                                    - If true (default), the total length of the alternative path
 *                                      must be less than edge_length.
 *                                    - If false, each edge in the alternative path must be
 *                                      shorter than edge_length.
 *
 * @return The length of the shortest alternative path that satisfies the chosen constraint.
 *         Returns 0 if no such path is found.
 *
 * @note The function assumes that the graph is undirected and the adjacency list
 *       and edge length vector are consistent with each other.
 *
 * @Rf_warning This function may have different behavior and performance characteristics
 *          depending on the chosen length constraint. The total length constraint
 *          (use_total_length_constraint = true) may find longer paths with more edges,
 *          while the individual edge constraint (use_total_length_constraint = false)
 *          may find shorter paths with fewer edges.
 *
 * @see graph_prune_long_edges
 */
double graph_alternative_path_length(const std::vector<std::vector<int>>& adj_vect,
                                      const std::vector<std::vector<double>>& edge_length_vect,
                                      int source,
                                      int target,
                                      double edge_length,
                                      bool use_total_length_constraint) {
    int n_vertices = adj_vect.size();
    std::vector<double> distance(n_vertices, std::numeric_limits<double>::max());
    std::queue<int> q;
    q.push(source);
    distance[source] = 0;

    while (!q.empty()) {
        int current = q.front();
        q.pop();
        for (size_t i = 0; i < adj_vect[current].size(); ++i) {
            int neighbor = adj_vect[current][i];
            double neighbor_edge_length = edge_length_vect[current][i];

            bool length_condition;
            if (use_total_length_constraint) {
                length_condition = (distance[current] + neighbor_edge_length < edge_length);
            } else {
                length_condition = (neighbor_edge_length < edge_length);
            }

            if (neighbor == target && length_condition) {
                return distance[current] + neighbor_edge_length;
            }

            if (distance[current] + neighbor_edge_length < distance[neighbor] && length_condition) {
                distance[neighbor] = distance[current] + neighbor_edge_length;
                q.push(neighbor);
            }
        }
    }
    return 0;  // No valid path found
}

/**
 * @brief Removes an edge between two specified vertices in an undirected weighted graph.
 *
 * This function modifies the graph in-place to remove the connection between the
 * vertices specified by 'start' and 'end'. It removes the edge from both the
 * adjacency list and the corresponding edge length list.
 *
 * @param adj_vect A vector of vectors representing the adjacency list of the graph.
 *                 This parameter is modified by the function.
 * @param edge_length_vect A vector of vectors containing the lengths of edges.
 *                         This parameter is modified by the function.
 * @param start The index of one endpoint of the edge to be removed.
 * @param end The index of the other endpoint of the edge to be removed.
 *
 * @note This function assumes that the graph is undirected, so it removes the edge
 *       from both start to end and end to start. If the edge doesn't exist, the
 *       function will not modify the graph.
 *
 * @Rf_warning The function does not check if the vertices or edge exist. Ensure that
 *          the provided indices are valid before calling this function.
 */
void graph_remove_edge(std::vector<std::vector<int>>& adj_vect,
                        std::vector<std::vector<double>>& edge_length_vect,
                        int start,
                        int end) {
    // Remove end from start's adjacency list
    auto it_start = std::find(adj_vect[start].begin(), adj_vect[start].end(), end);
    if (it_start != adj_vect[start].end()) {
        size_t index = std::distance(adj_vect[start].begin(), it_start);
        adj_vect[start].erase(it_start);
        edge_length_vect[start].erase(edge_length_vect[start].begin() + index);
    }

    // Remove start from end's adjacency list
    auto it_end = std::find(adj_vect[end].begin(), adj_vect[end].end(), start);
    if (it_end != adj_vect[end].end()) {
        size_t index = std::distance(adj_vect[end].begin(), it_end);
        adj_vect[end].erase(it_end);
        edge_length_vect[end].erase(edge_length_vect[end].begin() + index);
    }
}

struct dedge_t {
    int start;
    int end;
    double length;
};

struct dedge_t_cmp {
    bool operator()(const dedge_t& lhs, const dedge_t& rhs) const {
        if (lhs.length > rhs.length) return true;
        if (lhs.length < rhs.length) return false;
        if (lhs.start < rhs.start) return true;
        if (lhs.start > rhs.start) return false;
        return lhs.end < rhs.end;
    }
};

/**
 * @brief Prunes long edges in a weighted graph based on the existence of shorter alternative paths.
 *
 * This function iterates through the edges of the graph, starting from the longest,
 * and removes edges for which there exists an alternative path that is significantly
 * shorter. The significance is determined by the alt_path_len_ratio_thld parameter.
 *
 * @param adj_vect A vector of vectors representing the adjacency list of the input graph.
 * @param edge_length_vect A vector of vectors containing the lengths of edges in the input graph.
 * @param path_lengths An output vector that will be filled with the lengths of alternative
 *                     paths found during the pruning process.
 * @param edge_lengths An output vector that will be filled with the lengths of edges
 *                     for which alternative paths were found.
 * @param alt_path_len_ratio_thld The threshold ratio for pruning. If the ratio of the
 *                                alternative path length to the direct edge length is
 *                                less than this threshold, the edge is pruned.
 * @param use_total_length_constraint A boolean flag to choose the length constraint:
 *                                    - If true, the total length of the alternative path
 *                                      must be less than the original edge length.
 *                                    - If false, each edge in the alternative path must be
 *                                      shorter than the original edge length.
 * @param verbose A boolean flag to enable or disable progress reporting. Default is false.
 *
 * @return A pair containing:
 *         - First: A vector of vectors representing the adjacency list of the pruned graph.
 *         - Second: A vector of vectors containing the edge lengths of the pruned graph.
 *
 * @note The function assumes that the input graph is undirected and that adj_vect
 *       and edge_length_vect are consistent with each other.
 *
 * @Rf_warning This function modifies the path_lengths and edge_lengths vectors, appending to them
 *          the lengths of alternative paths and corresponding edge lengths found during
 *          the pruning process.
 *
 * @see graph_alternative_path_length
 */
std::pair<std::vector<std::vector<int>>, std::vector<std::vector<double>>>
graph_prune_long_edges(const std::vector<std::vector<int>>& adj_vect,
                        const std::vector<std::vector<double>>& edge_length_vect,
                        std::vector<double>& path_lengths,
                        std::vector<double>& edge_lengths,
                        double alt_path_len_ratio_thld,
                        bool use_total_length_constraint,
                        bool verbose = false) {
    std::set<dedge_t, dedge_t_cmp> dedges;
    for (int i = 0; i < (int)adj_vect.size(); i++) {
        for (size_t j = 0; j < adj_vect[i].size(); j++) {
            int neighbor = adj_vect[i][j];
            if (i < neighbor) {
                dedges.insert({i, neighbor, edge_length_vect[i][j]});
            }
        }
    }

    auto pruned_adj_vect = adj_vect;
    auto pruned_edge_length_vect = edge_length_vect;

    int edge_counter = 1;
    int n_edges = dedges.size();
    for (const auto& edge : dedges)  {
        if (verbose) {
            Rprintf("\r%d / %d", edge_counter, n_edges);
        }
        edge_counter++;

        double path_length = graph_alternative_path_length(pruned_adj_vect,
                                                            pruned_edge_length_vect,
                                                            edge.start,
                                                            edge.end,
                                                            edge.length,
                                                            use_total_length_constraint);
        if (path_length > 0) {
            path_lengths.push_back(path_length);
            edge_lengths.push_back(edge.length);
            if (path_length / edge.length < alt_path_len_ratio_thld) {
                graph_remove_edge(pruned_adj_vect, pruned_edge_length_vect, edge.start, edge.end);
            }
        }
    }

    return std::make_pair(std::move(pruned_adj_vect), std::move(pruned_edge_length_vect));
}

/**
 * @brief R interface for pruning long edges in a weighted graph based on shorter alternative paths.
 *
 * This function serves as an interface between R and the C++ implementation of the
 * graph pruning algorithm. It takes R objects as input, processes them using the C++
 * function graph_prune_long_edges, and returns the results in a format suitable for R.
 *
 * @param s_adj_list An R list representing the adjacency list of the input graph.
 * @param s_edge_length_list An R list of edge lengths corresponding to the adjacency list.
 * @param s_alt_path_len_ratio_thld An R numeric value for the alternative path length ratio threshold.
 * @param s_use_total_length_constraint A boolean flag to choose the length constraint:
 *                                    - If true, the total length of the alternative path
 *                                      must be less than the original edge length.
 *                                    - If false, each edge in the alternative path must be
 *                                      shorter than the original edge length.
 * @param s_verbose A boolean flag to enable or disable progress reporting. Default is false.
 *
 * @return An R list containing four elements:
 *         - adj_list: The adjacency list of the pruned graph.
 *         - edge_lengths_list: The edge lengths of the pruned graph.
 *         - path_lengths: A vector of alternative path lengths found during pruning.
 *         - edge_lengths: A vector of original edge lengths corresponding to path_lengths.
 *
 * @note This function assumes that the input graph is 0-based indexed. The output
 *       graph will be converted back to 1-based indexing for R.
 *
 * @Rf_warning This function may throw R errors if there are inconsistencies in the input data.
 */
SEXP S_wgraph_prune_long_edges(SEXP s_adj_list,
                               SEXP s_edge_length_list,
                               SEXP s_alt_path_len_ratio_thld,
                               SEXP s_use_total_length_constraint,
                               SEXP s_verbose) {

    std::vector<std::vector<int>> adj_vect            = convert_adj_list_from_R(s_adj_list);
    std::vector<std::vector<double>> edge_length_vect = convert_weight_list_from_R(s_edge_length_list);

    double alt_path_len_ratio_thld   = Rf_asReal(s_alt_path_len_ratio_thld);
    bool use_total_length_constraint = (Rf_asLogical(s_use_total_length_constraint) == TRUE);
    bool verbose                     = (Rf_asLogical(s_verbose) == TRUE);

    std::vector<double> path_lengths;
    std::vector<double> edge_lengths;

    auto pruning_res = graph_prune_long_edges(adj_vect,
                                               edge_length_vect,
                                               path_lengths,
                                               edge_lengths,
                                               alt_path_len_ratio_thld,
                                               use_total_length_constraint,
                                               verbose);

    auto pruned_adj_vect          = pruning_res.first;
    auto pruned_edge_lengths_vect = pruning_res.second;

    // Build result (container-first pattern)
    SEXP res = PROTECT(Rf_allocVector(VECSXP, 4));
    {
        // Set names
        SEXP names = PROTECT(Rf_allocVector(STRSXP, 4));
        SET_STRING_ELT(names, 0, Rf_mkChar("adj_list"));
        SET_STRING_ELT(names, 1, Rf_mkChar("edge_lengths_list"));
        SET_STRING_ELT(names, 2, Rf_mkChar("path_lengths"));
        SET_STRING_ELT(names, 3, Rf_mkChar("edge_lengths"));
        Rf_setAttrib(res, R_NamesSymbol, names);
        UNPROTECT(1); // names
    }
    int n_vertices = static_cast<int>(pruned_adj_vect.size());

    // 0: pruned_adj_list
    {
        SEXP pruned_adj_list = PROTECT(Rf_allocVector(VECSXP, n_vertices));
        for (int i = 0; i < n_vertices; i++) {
            SEXP RA = PROTECT(Rf_allocVector(INTSXP, pruned_adj_vect[i].size()));
            int* A = INTEGER(RA);
            for (size_t j = 0; j < pruned_adj_vect[i].size(); j++) {
                A[j] = pruned_adj_vect[i][j] + 1; // Convert to 1-based
            }
            SET_VECTOR_ELT(pruned_adj_list, i, RA);
            UNPROTECT(1); // RA
        }
        SET_VECTOR_ELT(res, 0, pruned_adj_list);
        UNPROTECT(1); // pruned_adj_list
    }

    // 1: pruned_edge_lengths_list
    {
        SEXP pruned_edge_lengths_list = PROTECT(Rf_allocVector(VECSXP, n_vertices));
        for (int i = 0; i < n_vertices; i++) {
            SEXP RD = PROTECT(Rf_allocVector(REALSXP, pruned_edge_lengths_vect[i].size()));
            double* D = REAL(RD);
            for (size_t j = 0; j < pruned_edge_lengths_vect[i].size(); j++) {
                D[j] = pruned_edge_lengths_vect[i][j];
            }
            SET_VECTOR_ELT(pruned_edge_lengths_list, i, RD);
            UNPROTECT(1); // RD
        }
        SET_VECTOR_ELT(res, 1, pruned_edge_lengths_list);
        UNPROTECT(1); // pruned_edge_lengths_list
    }

    // 2: path_lengths
    {
        int n_path_lengths = static_cast<int>(path_lengths.size());
        SEXP R_path_lengths = PROTECT(Rf_allocVector(REALSXP, n_path_lengths));
        double* path_lengths_array = REAL(R_path_lengths);
        for (int i = 0; i < n_path_lengths; i++) {
            path_lengths_array[i] = path_lengths[i];
        }
        SET_VECTOR_ELT(res, 2, R_path_lengths);
        UNPROTECT(1); // R_path_lengths
    }

    // 3: edge_lengths
    {
        int n_edge_lengths = static_cast<int>(edge_lengths.size());
        int n_path_lengths = static_cast<int>(path_lengths.size());
        if (n_path_lengths != n_edge_lengths) {
            UNPROTECT(1); // res
            Rf_error("n_edge_lengths is not equal to n_path_lengths.");
        }
        SEXP R_edge_lengths = PROTECT(Rf_allocVector(REALSXP, n_edge_lengths));
        double* edge_lengths_array = REAL(R_edge_lengths);
        for (int i = 0; i < n_edge_lengths; i++) {
            edge_lengths_array[i] = edge_lengths[i];
        }
        SET_VECTOR_ELT(res, 3, R_edge_lengths);
        UNPROTECT(1); // R_edge_lengths
    }

    UNPROTECT(1); // res
    return res;
}

// -------------------------------------------------------------------------------------------------------------------------------------
//
// a version of isize pruning that constrains the length of the alternative path of a long redundant edge
//
// -------------------------------------------------------------------------------------------------------------------------------------


/*!
  \brief Finds the length of an isize-alternate path between two vertices in an intersection kNN graph.

  \details This function searches for an isize-alternate path between two vertices in an intersection kNN graph. The path must satisfy these conditions:
    - It contains at least one intermediate vertex.
    - All edges along the path have an intersection size greater than the given edge's intersection size.

  If such a path is found, the function returns its Rf_length(number of edges). Otherwise, it returns 0.

  \param graph The intersection kNN graph, represented as an adjacency list where each element is a pair of (neighbor_index, intersection_size).
  \param source The index of the starting vertex.
  \param target The index of the ending vertex.
  \param edge_isize The intersection size of the edge between source and target.

  \return The length of the alternate path if found, or 0 if no such path exists.
*/
int alternative_path_length(const std::unique_ptr<std::vector<std::vector<std::pair<int, int>>>>& graph,
                            int source, int target, int edge_isize) {
    int n_vertices = graph->size();
    std::vector<int> distance(n_vertices, -1);
    std::queue<int> q;

    q.push(source);
    distance[source] = 0;

    while (!q.empty()) {
        int current = q.front();
        q.pop();

        for (const auto& neighbor_pair : (*graph)[current]) {
            int neighbor = neighbor_pair.first;
            int neighbor_isize = neighbor_pair.second;

            if (neighbor == target && neighbor_isize > edge_isize) {
                return distance[current] + 1;
            }

            if (distance[neighbor] == -1 && neighbor_isize > edge_isize) {
                distance[neighbor] = distance[current] + 1;
                q.push(neighbor);
            }
        }
    }

    return 0;  // No valid path found
}


/*!
  Prunes Long Edges of an Intersection kNN Graph constraining the length of the alternative path

  This is a path length constrained (plc) version of a function that removes
  'long' edges from the given intersection kNN graph. A 'long' edge is
  defined as an edge for which there exists an alternate path between its
  endpoint vertices all edges of which have intersection size (isize) greater
  than the isize of the current edge. The function first sorts the edges in
  ascending order of the intersection size and then utilizes a Breadth-First
  Search (BFS) algorithm to identify such edges.

  The pruning process involves:

  1.*Sorting Edges:** Edges are sorted in ascending order based on their
  intersection size (`isize`).
  2.*Redundancy Check:** For each edge, a Breadth-First Search (BFS) based
  algorithm (`is_edge_redundant`) determines if an alternate path exists
  where all edges have a larger intersection size.
  3.*Removal:** Redundant edges are removed from the graph.

  \param graph A reference to the input intersection kNN graph,
  represented as an adjacency list where each element is a pair
  of (neighbor_index, intersection_size).

  \param version An integer specifying which version of is_edge_redundant function to use. Version 1 uses is_edge_redundant, version 2: is_edge_redundant_alt.

  \return A pair consisting of 1) a new adjacency list representing the pruned graph 2) a vector of alternative path lengths (number of edges).
*/
std::pair<std::vector<std::vector<std::pair<int, int>>>, std::vector<int>> plc_prune_long_edges (const std::unique_ptr<std::vector<std::vector<std::pair<int, int>>>>& graph) {

    auto pruned_graph = std::make_unique<std::vector<std::vector<std::pair<int, int>>>>(*graph);

    std::set<iedge_t, iedge_t_cmp> iedges;
    iedge_t iedge;
    for (int i = 0; i < (int)pruned_graph->size(); i++) {
        for (const auto& neighbor_pair : (*pruned_graph)[i]) {
            if (i < neighbor_pair.first) {
                iedge.start = i;
                iedge.end   = neighbor_pair.first;
            } else {
                iedge.start = neighbor_pair.first;
                iedge.end   = i;
            }
            iedge.isize = neighbor_pair.second;
            iedges.insert(iedge);
        }
    }

    int path_length = 0;
    std::vector<int> path_lengths;
    for (auto iedge : iedges) {

        if ( (path_length = alternative_path_length(pruned_graph, iedge.start, iedge.end, iedge.isize)) > 0 ) {
            path_lengths.push_back(path_length);
            remove_edge(*pruned_graph, iedge.start, iedge.end);
        }
    }

    return std::make_pair(std::move(*pruned_graph), std::move(path_lengths));
}


// -------------------------------------------------------------------------------------------------------------------------------------
//
// density based isize pruning
//
// -------------------------------------------------------------------------------------------------------------------------------------

/*!
 * \brief Calculates the local density of a vertex in a graph.
 *
 * This function computes the local density of a given vertex by counting the number of
 * vertices within a specified radius in the graph. The density is measured as the raw
 * count of vertices (including the starting vertex) that can be reached within the
 * given number of edge traversals.
 *
 * \param graph A unique pointer to the graph, represented as an adjacency list where
 *              each element is a vector of pairs. Each pair contains a neighbor index
 *              and an intersection size.
 * \param vertex The index of the vertex for which to calculate the local density.
 * \param radius The maximum number of edge traversals to consider when counting
 *               neighboring vertices.
 *
 * \return An integer representing the number of vertices (including the starting vertex)
 *         that can be reached within the specified radius.
 *
 * \note This function uses a breadth-first search approach to explore the neighborhood
 *       of the given vertex up to the specified radius.
 *
 * \Rf_warning The function assumes that the graph is undirected. For directed graphs,
 *          modifications may be necessary to ensure correct density calculation.
 */
int calculate_local_density(const std::unique_ptr<std::vector<std::vector<std::pair<int, int>>>>& graph,
                            int vertex, int radius) {
    std::set<int> neighborhood;
    std::queue<std::pair<int, int>> q;
    q.push({vertex, 0});
    neighborhood.insert(vertex);

    while (!q.empty()) {
        auto [current, distance] = q.front();
        q.pop();

        if (distance >= radius) continue;

        for (const auto& [neighbor, _] : (*graph)[current]) {
            if (neighborhood.insert(neighbor).second) {
                q.push({neighbor, distance + 1});
            }
        }
    }

    return neighborhood.size();
}

/*!
 * \brief Prunes long edges in a graph based on local density and alternative path length.
 *
 * This function implements a density-aware edge pruning algorithm for intersection k-NN graphs.
 * It removes edges that have alternative paths of acceptable length, where the acceptable
 * length is determined by the local density of the graph around the edge's endpoints.
 *
 * \param graph A unique pointer to the input graph, represented as an adjacency list where
 *              each element is a vector of pairs. Each pair contains a neighbor index
 *              and an intersection size.
 * \param density_radius The radius used for calculating local density around each vertex.
 *                       Default value is 2.
 *
 * \return A pair containing:
 *         - First: A vector of vectors representing the pruned graph's adjacency list.
 *           Each inner vector contains pairs of (neighbor index, intersection size).
 *         - Second: A vector of integers representing the lengths of alternative paths
 *           for the edges that were pruned.
 *
 * \details The function performs the following steps:
 *          1. Calculates local density for all vertices using the specified density_radius.
 *          2. Computes the density distribution across the graph.
 *          3. For each edge:
 *             a. Calculates the average density of its endpoints.
 *             b. Determines the density quantile of this average.
 *             c. Uses the quantile to set a maximum allowed alternative path length.
 *             d. If an alternative path of acceptable length exists, prunes the edge.
 *
 * \note The pruning criteria adapt to the global density distribution of the graph,
 *       making the algorithm robust to varying local dimensionality and density patterns.
 *
 * \Rf_warning This function modifies the input graph. If you need to preserve the original
 *          graph, make a copy before calling this function.
 */
std::pair<std::vector<std::vector<std::pair<int, int>>>, std::vector<int>>
density_prune_long_edges(const std::unique_ptr<std::vector<std::vector<std::pair<int, int>>>>& graph, int density_radius = 2) {
    auto pruned_graph = std::make_unique<std::vector<std::vector<std::pair<int, int>>>>(*graph);
    std::vector<int> path_lengths;

    // Calculate densities for all vertices
    std::vector<int> all_densities;
    for (int i = 0; i < (int)pruned_graph->size(); i++) {
        all_densities.push_back(calculate_local_density(pruned_graph, i, density_radius));
    }

    // Sort densities to compute quantiles
    std::vector<int> sorted_densities = all_densities;
    std::sort(sorted_densities.begin(), sorted_densities.end());

    std::set<iedge_t, iedge_t_cmp> iedges;
    iedge_t iedge;
    for (int i = 0; i < (int)pruned_graph->size(); i++) {
        for (const auto& neighbor_pair : (*pruned_graph)[i]) {
            if (i < neighbor_pair.first) {
                iedge.start = i;
                iedge.end   = neighbor_pair.first;
            } else {
                iedge.start = neighbor_pair.first;
                iedge.end   = i;
            }
            iedge.isize = neighbor_pair.second;
            iedges.insert(iedge);
        }
    }

    for (auto iedge : iedges) {
        int start_density = all_densities[iedge.start];
        int end_density = all_densities[iedge.end];
        int avg_density = (start_density + end_density) / 2;

        // Find the quantile of the average density
        auto it = std::lower_bound(sorted_densities.begin(), sorted_densities.end(), avg_density);
        double quantile = static_cast<double>(it - sorted_densities.begin()) / sorted_densities.size();

        // Adjust max_path_length based on the density quantile
        int max_path_length = std::max(3, static_cast<int>(10 * (1 - quantile)));

        int path_length = alternative_path_length(pruned_graph, iedge.start, iedge.end, iedge.isize);

        if (path_length > 0 && path_length <= max_path_length) {
            path_lengths.push_back(path_length);
            remove_edge(*pruned_graph, iedge.start, iedge.end);
        }
    }

    return std::make_pair(std::move(*pruned_graph), std::move(path_lengths));
}


// -------------------------------------------------------------------------------------------------------------------------------------
//
// prune_long_edges and is_edge_redundant functions for intersection-weighted-distance graphs generated by create_iknn_graph
//
// -------------------------------------------------------------------------------------------------------------------------------------

// something is not right with the following implementation of pruning for IWD graphs
// I am going to use the coversion of IWD kNN graph to an IW kNN graph and use pruning on that resulting graph
#if 0
typedef struct
{
    int start; // start vertex
    int end;   // end vertex
    int isize; // intersection size
    double dist; // distance
} idistance_edge_t; // intersection weighted distance kNN graph edge

struct idistance_edge_t_cmp {
    bool operator()(const idistance_edge_t& lhs, const idistance_edge_t& rhs) const {
        if (lhs.isize < rhs.isize) return true;
        if (lhs.isize > rhs.isize) return false;
        // Break ties based on distance, then consistent vertex ordering
        if (lhs.dist < rhs.dist) return true;
        if (lhs.dist > rhs.dist) return false;
        if (lhs.start < rhs.start) return true;
        if (lhs.start > rhs.start) return false;
        return lhs.end < rhs.end;
    }
};

bool is_edge_redundant(const std::unique_ptr<std::vector<std::vector<iknn_vertex_t>>>& graph,
                       int source, int target, int edge_isize, double edge_dist);
void remove_edge(std::unique_ptr<std::vector<std::vector<iknn_vertex_t>>>& graph, int v1, int v2);


/*!
  \brief Prunes long edges from the intersection-weighted-distance kNN graph.

  This function removes redundant edges from the given intersection-weighted-distance kNN graph. An edge is considered redundant if there exists an alternative path between its vertices that has a greater intersection size.

  \param graph The intersection-weighted-distance kNN graph, represented as a unique pointer to a vector of vectors of iknn_vertex_t structures. Each element represents a neighbor with its index, intersection size, and distance.

  \return A pruned version of the intersection-weighted-distance kNN graph as a unique pointer to a vector of vectors of iknn_vertex_t structures.
*/
std::unique_ptr<std::vector<std::vector<iknn_vertex_t>>> prune_long_edges(const std::unique_ptr<std::vector<std::vector<iknn_vertex_t>>>& graph) {

    auto pruned_graph = std::make_unique<std::vector<std::vector<iknn_vertex_t>>>(*graph);

    std::set<idistance_edge_t, idistance_edge_t_cmp> idistance_edges;
    idistance_edge_t idistance_edge;
    for (int i = 0; i < (int)pruned_graph->size(); i++) {
        for (const auto& neighbor : (*pruned_graph)[i]) {
            if (i < neighbor.index) {
                idistance_edge.start = i;
                idistance_edge.end = neighbor.index;
            } else {
                idistance_edge.start = neighbor.index;
                idistance_edge.end = i;
            }
            idistance_edge.isize = neighbor.isize;
            idistance_edge.dist = neighbor.dist;
            idistance_edges.insert(idistance_edge);
        }
    }

    for (auto idistance_edge : idistance_edges) {
        if (is_edge_redundant(pruned_graph, idistance_edge.start, idistance_edge.end, idistance_edge.isize, idistance_edge.dist)) {
            remove_edge(pruned_graph, idistance_edge.start, idistance_edge.end);
        }
    }

    return pruned_graph;
}

/*!
  \brief Tests for the existence of an isize-alternate path between edge vertices in an intersection-weighted-distance kNN graph.

  This function determines if there exists an isize-alternate path between the two vertices of an edge in an intersection-weighted-distance kNN graph. An isize-alternate path is a path that satisfies the following conditions:
  - It has at least one intermediate vertex.
  - All edges along the path have an intersection size greater than the intersection size of the given edge.

  \param graph The intersection-weighted-distance kNN graph, represented as an adjacency list where each element is a structure (neighbor_index, intersection_size, distance).
  \param source The source vertex of the edge.
  \param target The target vertex of the edge.
  \param edge_isize The intersection size of the given edge.

  \return `true` if an isize-alternate path exists between the source and target vertices, `false` otherwise.
*/
bool is_edge_redundant(const std::unique_ptr<std::vector<std::vector<iknn_vertex_t>>>& graph,
                       int source, int target, int edge_isize, double edge_dist) {
    int n_vertices = graph->size();
    std::vector<int> visited(n_vertices, false);
    std::deque<int> q;

    q.push_back(source);
    visited[source] = true;

    while (!q.empty()) {
        int current = q.front();
        q.pop_front();

        for (const auto& neighbor : (*graph)[current]) {
            int neighbor_index = neighbor.index;
            int neighbor_isize = neighbor.isize;
            double neighbor_dist = neighbor.dist;

            if (neighbor_index == target && neighbor_isize > edge_isize && neighbor_dist < edge_dist) {
                return true;
            }

            if (!visited[neighbor_index] && neighbor_isize > edge_isize && neighbor_dist < edge_dist) {
                visited[neighbor_index] = true;
                q.push_back(neighbor_index);
            }
        }
    }

    return false;
}


/*!
  \brief Removes an edge from the intersection-weighted-distance kNN graph.

  This function removes an edge between two vertices in the intersection-weighted-distance kNN graph.

  \param graph an intersection-weighted-distance kNN graph, represented as an adjacency list where each element is a structure (neighbor_index, intersection_size, distance).
  \param v1 The first vertex of the edge.
  \param v2 The second vertex of the edge.
*/
void remove_edge(std::unique_ptr<std::vector<std::vector<iknn_vertex_t>>>& graph, int v1, int v2) {
    auto& neighbors1 = (*graph)[v1];
    auto it1 = std::find_if(neighbors1.begin(), neighbors1.end(),
                            [v2](const iknn_vertex_t& neighbor) {
                                return neighbor.index == v2;
                            });
    if (it1 != neighbors1.end()) { // Check if the edge was found
        neighbors1.erase(it1);
    }

    auto& neighbors2 = (*graph)[v2];
    auto it2 = std::find_if(neighbors2.begin(), neighbors2.end(),
                            [v1](const iknn_vertex_t& neighbor) {
                                return neighbor.index == v1;
                            });
    if (it2 != neighbors2.end()) {
        neighbors2.erase(it2);
    }
}

#endif
