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
inline ian::SolverSettings captured_settings(const ClarabelDefaultSettings& s) {
 ian::SolverSettings out;
 out.max_iter = s.max_iter;
 out.time_limit = s.time_limit;
 out.verbose = s.verbose;
 out.max_step_fraction = s.max_step_fraction;
 out.tol_gap_abs = s.tol_gap_abs;
 out.tol_gap_rel = s.tol_gap_rel;
 out.tol_feas = s.tol_feas;
 out.tol_infeas_abs = s.tol_infeas_abs;
 out.tol_infeas_rel = s.tol_infeas_rel;
 out.tol_ktratio = s.tol_ktratio;
 out.reduced_tol_gap_abs = s.reduced_tol_gap_abs;
 out.reduced_tol_gap_rel = s.reduced_tol_gap_rel;
 out.reduced_tol_feas = s.reduced_tol_feas;
 out.reduced_tol_infeas_abs = s.reduced_tol_infeas_abs;
 out.reduced_tol_infeas_rel = s.reduced_tol_infeas_rel;
 out.reduced_tol_ktratio = s.reduced_tol_ktratio;
 out.equilibrate_enable = s.equilibrate_enable;
 out.equilibrate_max_iter = s.equilibrate_max_iter;
 out.equilibrate_min_scaling = s.equilibrate_min_scaling;
 out.equilibrate_max_scaling = s.equilibrate_max_scaling;
 out.linesearch_backtrack_step = s.linesearch_backtrack_step;
 out.min_switch_step_length = s.min_switch_step_length;
 out.min_terminate_step_length = s.min_terminate_step_length;
 out.max_threads = s.max_threads;
 out.direct_kkt_solver = s.direct_kkt_solver;
 out.direct_solve_method = static_cast<int>(s.direct_solve_method);
 out.static_regularization_enable = s.static_regularization_enable;
 out.static_regularization_constant = s.static_regularization_constant;
 out.static_regularization_proportional = s.static_regularization_proportional;
 out.dynamic_regularization_enable = s.dynamic_regularization_enable;
 out.dynamic_regularization_eps = s.dynamic_regularization_eps;
 out.dynamic_regularization_delta = s.dynamic_regularization_delta;
 out.iterative_refinement_enable = s.iterative_refinement_enable;
 out.iterative_refinement_reltol = s.iterative_refinement_reltol;
 out.iterative_refinement_abstol = s.iterative_refinement_abstol;
 out.iterative_refinement_max_iter = s.iterative_refinement_max_iter;
 out.iterative_refinement_stop_ratio = s.iterative_refinement_stop_ratio;
 out.presolve_enable = s.presolve_enable;
 out.input_sparse_dropzeros = s.input_sparse_dropzeros;
 return out;
}
}
