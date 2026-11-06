rcpp_compute_graph_endpoint_scores <- function(adj_list,
                                               weight_list,
                                               layout_3d,
                                               scales,
                                               neighborhood,
                                               q,
                                               neighbor_weighting,
                                               gaussian_sigma,
                                               min_neighborhood_size) {
    .Call(
        "_dgraphs_rcpp_compute_graph_endpoint_scores",
        adj_list,
        weight_list,
        layout_3d,
        scales,
        neighborhood,
        q,
        neighbor_weighting,
        gaussian_sigma,
        min_neighborhood_size,
        PACKAGE = "dgraphs"
    )
}

rcpp_graph_multi_source_support_by_scale <- function(adj_list,
                                                     weight_list,
                                                     local_max_by_scale,
                                                     radius) {
    .Call(
        "_dgraphs_rcpp_graph_multi_source_support_by_scale",
        adj_list,
        weight_list,
        local_max_by_scale,
        radius,
        PACKAGE = "dgraphs"
    )
}

rcpp_graph_greedy_maxima_suppression_by_scale <- function(adj_list,
                                                          weight_list,
                                                          local_max_by_scale,
                                                          score_by_scale,
                                                          radius) {
    .Call(
        "_dgraphs_rcpp_graph_greedy_maxima_suppression_by_scale",
        adj_list,
        weight_list,
        local_max_by_scale,
        score_by_scale,
        radius,
        PACKAGE = "dgraphs"
    )
}
