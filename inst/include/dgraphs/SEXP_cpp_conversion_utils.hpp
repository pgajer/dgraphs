#ifndef DGRAPHS_SEXP_CPP_CONVERSION_UTILS_HPP
#define DGRAPHS_SEXP_CPP_CONVERSION_UTILS_HPP

#include "dgraphs/set_wgraph.hpp"

#include <map>
#include <memory>
#include <set>
#include <stdexcept>
#include <unordered_map>
#include <utility>
#include <vector>

#include <R.h>
#include <Rinternals.h>

using std::size_t;

SEXP create_R_list(const std::vector<std::vector<std::vector<double>>>& X_traj,
                   const std::vector<double>& median_kdistances);

std::unique_ptr<std::vector<std::vector<double>>> Rmatrix_to_cpp(SEXP Rmatrix);

std::unique_ptr<std::vector<std::vector<int>>> R_list_of_ivectors_to_cpp_vector_of_ivectors(SEXP Rgraph);

std::vector<std::vector<int>> convert_adj_list_from_R(SEXP s_adj_list);
std::vector<std::vector<double>> convert_weight_list_from_R(SEXP s_weight_list);

std::unique_ptr<std::vector<std::vector<double>>> R_list_of_dvectors_to_cpp_vector_of_dvectors(SEXP Rvectvect);

std::unique_ptr<std::vector<double>> Rvect_to_CppVect_double(SEXP Ry);

std::map<std::pair<int,int>, std::vector<int>> shortest_paths_Rlist_to_cpp_map(SEXP s_shortest_paths);

SEXP convert_wgraph_to_R(const set_wgraph_t& graph);

SEXP convert_set_to_R(const std::set<int>& set);
SEXP convert_map_set_to_R(const std::map<int, std::set<int>>& map_set);

SEXP convert_map_vector_set_to_R(const std::map<std::pair<int,int>, std::vector<std::set<int>>>& map_vec_set);
std::map<std::pair<int,int>, std::vector<int>> convert_R_to_map_vector(SEXP Rlist);

SEXP convert_map_vector_to_R(const std::map<std::pair<int,int>, std::vector<int>>& map_vec);
SEXP convert_procells_to_R(const std::map<std::pair<int,int>, std::set<int>>& procells);

SEXP convert_vector_int_to_R(const std::vector<int>& vec);
SEXP convert_vector_double_to_R(const std::vector<double>& vec);
SEXP convert_vector_bool_to_R(const std::vector<bool>& vec);

SEXP convert_vector_vector_int_to_R(const std::vector<std::vector<int>>& vec);
SEXP convert_vector_vector_double_to_R(const std::vector<std::vector<double>>& vec);
SEXP convert_vector_vector_bool_to_R(const std::vector<std::vector<bool>>& vec);

SEXP convert_vector_vector_double_to_matrix(const std::vector<std::vector<double>>& data);

SEXP convert_vector_vector_vector_double_to_R(const std::vector<std::vector<std::vector<double>>>& data);

SEXP convert_map_int_vector_int_to_R(const std::unordered_map<int, std::vector<int>>& cpp_map_int_vect_int);
SEXP convert_map_int_vector_int_to_R(const std::unordered_map<int, std::vector<int>>& cpp_map_int_vect_int,
									 const std::vector<int>& names);
SEXP Cpp_map_int_set_int_to_Rlist(const std::unordered_map<int, std::set<int>>& cpp_map_int_set_int);

SEXP uptr_vector_of_pairs_to_R_matrix(const std::unique_ptr<std::vector<std::pair<int, int>>>& cpp_vector);
SEXP cpp_vector_of_pairs_to_R_matrix(const std::vector<std::pair<int, int>>& cpp_vector);

SEXP flat_vector_to_R_matrix(const std::vector<double>& flat_matrix, int nrow, int ncol);

#endif // DGRAPHS_SEXP_CPP_CONVERSION_UTILS_HPP
