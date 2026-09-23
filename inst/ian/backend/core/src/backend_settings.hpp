#pragma once
#include <cstddef>
extern "C" size_t dgraphs_ian_settings_layout(size_t);
namespace ian::detail {
inline void verify_backend_abi() {
 const size_t layout[]={sizeof(ClarabelDefaultSettings),alignof(ClarabelDefaultSettings),
 offsetof(ClarabelDefaultSettings,max_iter),
 offsetof(ClarabelDefaultSettings,time_limit),
 offsetof(ClarabelDefaultSettings,verbose),
 offsetof(ClarabelDefaultSettings,max_step_fraction),
 offsetof(ClarabelDefaultSettings,tol_gap_abs),
 offsetof(ClarabelDefaultSettings,tol_gap_rel),
 offsetof(ClarabelDefaultSettings,tol_feas),
 offsetof(ClarabelDefaultSettings,tol_infeas_abs),
 offsetof(ClarabelDefaultSettings,tol_infeas_rel),
 offsetof(ClarabelDefaultSettings,tol_ktratio),
 offsetof(ClarabelDefaultSettings,reduced_tol_gap_abs),
 offsetof(ClarabelDefaultSettings,reduced_tol_gap_rel),
 offsetof(ClarabelDefaultSettings,reduced_tol_feas),
 offsetof(ClarabelDefaultSettings,reduced_tol_infeas_abs),
 offsetof(ClarabelDefaultSettings,reduced_tol_infeas_rel),
 offsetof(ClarabelDefaultSettings,reduced_tol_ktratio),
 offsetof(ClarabelDefaultSettings,equilibrate_enable),
 offsetof(ClarabelDefaultSettings,equilibrate_max_iter),
 offsetof(ClarabelDefaultSettings,equilibrate_min_scaling),
 offsetof(ClarabelDefaultSettings,equilibrate_max_scaling),
 offsetof(ClarabelDefaultSettings,linesearch_backtrack_step),
 offsetof(ClarabelDefaultSettings,min_switch_step_length),
 offsetof(ClarabelDefaultSettings,min_terminate_step_length),
 offsetof(ClarabelDefaultSettings,max_threads),
 offsetof(ClarabelDefaultSettings,direct_kkt_solver),
 offsetof(ClarabelDefaultSettings,direct_solve_method),
 offsetof(ClarabelDefaultSettings,static_regularization_enable),
 offsetof(ClarabelDefaultSettings,static_regularization_constant),
 offsetof(ClarabelDefaultSettings,static_regularization_proportional),
 offsetof(ClarabelDefaultSettings,dynamic_regularization_enable),
 offsetof(ClarabelDefaultSettings,dynamic_regularization_eps),
 offsetof(ClarabelDefaultSettings,dynamic_regularization_delta),
 offsetof(ClarabelDefaultSettings,iterative_refinement_enable),
 offsetof(ClarabelDefaultSettings,iterative_refinement_reltol),
 offsetof(ClarabelDefaultSettings,iterative_refinement_abstol),
 offsetof(ClarabelDefaultSettings,iterative_refinement_max_iter),
 offsetof(ClarabelDefaultSettings,iterative_refinement_stop_ratio),
 offsetof(ClarabelDefaultSettings,presolve_enable),
 offsetof(ClarabelDefaultSettings,input_sparse_dropzeros),
 };
 for(size_t i=0;i<sizeof(layout)/sizeof(layout[0]);++i) require(layout[i]==dgraphs_ian_settings_layout(i),"backend_settings_abi_mismatch");
}
inline Json captured_settings(const ClarabelDefaultSettings& s) {
 Json j;
 j["max_iter"] = s.max_iter;
 j["time_limit"] = std::isfinite(s.time_limit) ? Json(s.time_limit) : Json("Infinity");
 j["verbose"] = s.verbose;
 j["max_step_fraction"] = s.max_step_fraction;
 j["tol_gap_abs"] = s.tol_gap_abs;
 j["tol_gap_rel"] = s.tol_gap_rel;
 j["tol_feas"] = s.tol_feas;
 j["tol_infeas_abs"] = s.tol_infeas_abs;
 j["tol_infeas_rel"] = s.tol_infeas_rel;
 j["tol_ktratio"] = s.tol_ktratio;
 j["reduced_tol_gap_abs"] = s.reduced_tol_gap_abs;
 j["reduced_tol_gap_rel"] = s.reduced_tol_gap_rel;
 j["reduced_tol_feas"] = s.reduced_tol_feas;
 j["reduced_tol_infeas_abs"] = s.reduced_tol_infeas_abs;
 j["reduced_tol_infeas_rel"] = s.reduced_tol_infeas_rel;
 j["reduced_tol_ktratio"] = s.reduced_tol_ktratio;
 j["equilibrate_enable"] = s.equilibrate_enable;
 j["equilibrate_max_iter"] = s.equilibrate_max_iter;
 j["equilibrate_min_scaling"] = s.equilibrate_min_scaling;
 j["equilibrate_max_scaling"] = s.equilibrate_max_scaling;
 j["linesearch_backtrack_step"] = s.linesearch_backtrack_step;
 j["min_switch_step_length"] = s.min_switch_step_length;
 j["min_terminate_step_length"] = s.min_terminate_step_length;
 j["max_threads"] = s.max_threads;
 j["direct_kkt_solver"] = s.direct_kkt_solver;
 j["direct_solve_method"] = s.direct_solve_method;
 j["static_regularization_enable"] = s.static_regularization_enable;
 j["static_regularization_constant"] = s.static_regularization_constant;
 j["static_regularization_proportional"] = s.static_regularization_proportional;
 j["dynamic_regularization_enable"] = s.dynamic_regularization_enable;
 j["dynamic_regularization_eps"] = s.dynamic_regularization_eps;
 j["dynamic_regularization_delta"] = s.dynamic_regularization_delta;
 j["iterative_refinement_enable"] = s.iterative_refinement_enable;
 j["iterative_refinement_reltol"] = s.iterative_refinement_reltol;
 j["iterative_refinement_abstol"] = s.iterative_refinement_abstol;
 j["iterative_refinement_max_iter"] = s.iterative_refinement_max_iter;
 j["iterative_refinement_stop_ratio"] = s.iterative_refinement_stop_ratio;
 j["presolve_enable"] = s.presolve_enable;
 j["input_sparse_dropzeros"] = s.input_sparse_dropzeros;
 j["direct_solve_method_name"]="qdldl"; j["settings_layout_verified"]=true; return j;
}
}
