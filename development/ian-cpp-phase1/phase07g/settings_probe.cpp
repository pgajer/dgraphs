// No solver construction or solve: reconstruct deterministic settings from pinned defaults.
extern "C" {
#include <clarabel.h>
}
#include <json.hpp>
#include <iostream>
#include <cmath>
int main(){auto s=clarabel_DefaultSettings_default();s.verbose=false;s.max_iter=300;s.max_threads=1;s.direct_solve_method=QDLDL;s.presolve_enable=false;s.tol_feas=s.tol_gap_abs=s.tol_gap_rel=1e-11;nlohmann::json j;
j["max_iter"]=s.max_iter;
j["time_limit"]=s.time_limit;
j["verbose"]=s.verbose;
j["max_step_fraction"]=s.max_step_fraction;
j["tol_gap_abs"]=s.tol_gap_abs;
j["tol_gap_rel"]=s.tol_gap_rel;
j["tol_feas"]=s.tol_feas;
j["tol_infeas_abs"]=s.tol_infeas_abs;
j["tol_infeas_rel"]=s.tol_infeas_rel;
j["tol_ktratio"]=s.tol_ktratio;
j["reduced_tol_gap_abs"]=s.reduced_tol_gap_abs;
j["reduced_tol_gap_rel"]=s.reduced_tol_gap_rel;
j["reduced_tol_feas"]=s.reduced_tol_feas;
j["reduced_tol_infeas_abs"]=s.reduced_tol_infeas_abs;
j["reduced_tol_infeas_rel"]=s.reduced_tol_infeas_rel;
j["reduced_tol_ktratio"]=s.reduced_tol_ktratio;
j["equilibrate_enable"]=s.equilibrate_enable;
j["equilibrate_max_iter"]=s.equilibrate_max_iter;
j["equilibrate_min_scaling"]=s.equilibrate_min_scaling;
j["equilibrate_max_scaling"]=s.equilibrate_max_scaling;
j["linesearch_backtrack_step"]=s.linesearch_backtrack_step;
j["min_switch_step_length"]=s.min_switch_step_length;
j["min_terminate_step_length"]=s.min_terminate_step_length;
j["max_threads"]=s.max_threads;
j["direct_kkt_solver"]=s.direct_kkt_solver;
j["direct_solve_method"]=s.direct_solve_method;
j["static_regularization_enable"]=s.static_regularization_enable;
j["static_regularization_constant"]=s.static_regularization_constant;
j["static_regularization_proportional"]=s.static_regularization_proportional;
j["dynamic_regularization_enable"]=s.dynamic_regularization_enable;
j["dynamic_regularization_eps"]=s.dynamic_regularization_eps;
j["dynamic_regularization_delta"]=s.dynamic_regularization_delta;
j["iterative_refinement_enable"]=s.iterative_refinement_enable;
j["iterative_refinement_reltol"]=s.iterative_refinement_reltol;
j["iterative_refinement_abstol"]=s.iterative_refinement_abstol;
j["iterative_refinement_max_iter"]=s.iterative_refinement_max_iter;
j["iterative_refinement_stop_ratio"]=s.iterative_refinement_stop_ratio;
j["presolve_enable"]=s.presolve_enable;
j["direct_solve_method"]="qdldl";if(!std::isfinite(s.time_limit))j["time_limit"]="inf";std::cout<<j.dump()<<'\n';}
