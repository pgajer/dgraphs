#include <R.h>
#include <R_ext/Lapack.h>
#include <stdlib.h>

#include "gflow_macros.h"

/*!
    \brief Creates a Minimal Spanning Tree (MST) on a matrix X with > 1 column using Prim's algorithm

    This function implements Prim's algorithm to construct a Minimal Spanning Tree (MST)
    from a given set of points. The algorithm works as follows:

    1. Start with an initial point (specified by riinit).
    2. Initialize the tree T with this point.
    3. While T does not include all points:
       a. Find the point not in T that is closest to any point in T.
       b. Add this point to T and the corresponding edge to the MST.
    4. Repeat step 3 until all points are included in T.

    The function uses pre-computed nearest neighbor information (nn_i and nn_d) to
    efficiently find the closest points at each step.

    \param riinit     Pointer to the index of the starting column in X for tree construction.
    \param nn_i       2D array [(n_points-1) x n_points] containing indices of (n_points - 1)
                      nearest neighbors for each point in X.
    \param nn_d       2D array [(n_points-1) x n_points] containing distances to (n_points - 1)
                      nearest neighbors for each point in X.
    \param rldist     Pointer to a value greater than all distances in nn_d (used as infinity).
    \param rn_points  Pointer to the number of points in X (number of columns in nn_i and nn_d).
    \param edges      Output 2D array [2 x (n_points - 1)] containing edges of the MST of X.
    \param edge_lens  Output array of edge lengths in the MST.

    \note The function assumes that memory for output arrays (edges and edge_lens)
          has been allocated by the caller.
    \note The function uses dynamic memory allocation for internal data structures
          and frees this memory before returning.
*/
void C_mstree(const int    *riinit,
              const int    *nn_i,
              const double *nn_d,
              const double *rldist,
              const int    *rn_points,
                    int    *edges,
                    double *edge_lens)
{
    int iinit = riinit[0];
    int n_points  = rn_points[0];
    int n_points_minus_one = n_points - 1; // number of rows of nn_i and nn_d as well as the number of columns of edges
    int n_points_minus_two = n_points_minus_one - 1;
    double ldist = rldist[0];
    int nT  = 0; // The current number of elements in the MST.

    int *T  = (int*)calloc(n_points + 1, sizeof(int)); // T[i] = 1, if i is in the MST (that I am also going to call T)
    CHECK_PTR(T);
    int *iT = (int*)calloc(n_points + 1, sizeof(int)); // iT[i] is the index of the i-th element added to the tree.
    CHECK_PTR(iT);
    int *cl = (int*)calloc(n_points + 1, sizeof(int)); // cl[i] is the index of the row of nn_i with the smallest distance from i to non-T (elements not yet in T)
    CHECK_PTR(cl);

    // Initialization
    nT = 0;
    iT[nT++] = iinit;
    T[iinit] = 1;
    double min_dist;
    double d;
    int edge_start = 0;
    int edge_end = 1;
    int ir;        // holds i * n_points_minus_one
    int i, j;
    int iedge = 0; // edge index
    int iedge2;    // holds iedge * 2
    while ( iedge < n_points_minus_one )
    {
        min_dist = ldist;
        // Finding element of T with the smallest distance to non-T elements of X
        for ( int k = 0; k < nT; k++ )
        {
            i  = iT[k];
            ir = i * n_points_minus_one; // accessing i-th column of nn_i and nn_d
            if ( cl[i] > n_points_minus_two ) continue;
            j = nn_i[cl[i] + ir];
            d = nn_d[cl[i] + ir];
            if ( (d < min_dist) && (T[j] == 0) )
            {
                min_dist   = d;
                edge_start = i;
                edge_end   = j;
            }
        }
        // edges is implemented as 2 rows, n_points_minus_one columns array
        iedge2 = iedge * 2;
        edges[    iedge2] = edge_start;
        edges[1 + iedge2] = edge_end;
        edge_lens[iedge++] = min_dist;
        T[edge_end] = 1;
        iT[nT++] = edge_end;
        for ( int k = 0; k < nT; k++ )
        {
            i  = iT[k];
            ir = i * n_points_minus_one;
            while ( cl[i] < n_points_minus_one && T[ nn_i[cl[i] + ir] ] == 1 ) {
                cl[i]++;
            }
        }
    }

    free(T);
    free(iT);
    free(cl);
}
