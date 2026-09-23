#pragma once
#include <ian/core.hpp>
#include <cmath>
// Field projection shared by JSON persistence and the direct R object adapter.
// It does not construct messages or feed values back into the engine.
namespace ian::serialization {
template<class Out> void fields(Out& out, const SolverSettings& x) {
 if(std::isfinite(x.time_limit)) out.field("time_limit",x.time_limit); else out.field("time_limit",std::string("Infinity"));
 out.field("max_iter", x.max_iter);
 out.field("verbose", x.verbose);
 out.field("max_step_fraction", x.max_step_fraction);
 out.field("tol_gap_abs", x.tol_gap_abs);
 out.field("tol_gap_rel", x.tol_gap_rel);
 out.field("tol_feas", x.tol_feas);
 out.field("tol_infeas_abs", x.tol_infeas_abs);
 out.field("tol_infeas_rel", x.tol_infeas_rel);
 out.field("tol_ktratio", x.tol_ktratio);
 out.field("reduced_tol_gap_abs", x.reduced_tol_gap_abs);
 out.field("reduced_tol_gap_rel", x.reduced_tol_gap_rel);
 out.field("reduced_tol_feas", x.reduced_tol_feas);
 out.field("reduced_tol_infeas_abs", x.reduced_tol_infeas_abs);
 out.field("reduced_tol_infeas_rel", x.reduced_tol_infeas_rel);
 out.field("reduced_tol_ktratio", x.reduced_tol_ktratio);
 out.field("equilibrate_enable", x.equilibrate_enable);
 out.field("equilibrate_max_iter", x.equilibrate_max_iter);
 out.field("equilibrate_min_scaling", x.equilibrate_min_scaling);
 out.field("equilibrate_max_scaling", x.equilibrate_max_scaling);
 out.field("linesearch_backtrack_step", x.linesearch_backtrack_step);
 out.field("min_switch_step_length", x.min_switch_step_length);
 out.field("min_terminate_step_length", x.min_terminate_step_length);
 out.field("max_threads", x.max_threads);
 out.field("direct_kkt_solver", x.direct_kkt_solver);
 out.field("direct_solve_method", x.direct_solve_method);
 out.field("static_regularization_enable", x.static_regularization_enable);
 out.field("static_regularization_constant", x.static_regularization_constant);
 out.field("static_regularization_proportional", x.static_regularization_proportional);
 out.field("dynamic_regularization_enable", x.dynamic_regularization_enable);
 out.field("dynamic_regularization_eps", x.dynamic_regularization_eps);
 out.field("dynamic_regularization_delta", x.dynamic_regularization_delta);
 out.field("iterative_refinement_enable", x.iterative_refinement_enable);
 out.field("iterative_refinement_reltol", x.iterative_refinement_reltol);
 out.field("iterative_refinement_abstol", x.iterative_refinement_abstol);
 out.field("iterative_refinement_max_iter", x.iterative_refinement_max_iter);
 out.field("iterative_refinement_stop_ratio", x.iterative_refinement_stop_ratio);
 out.field("presolve_enable", x.presolve_enable);
 out.field("input_sparse_dropzeros", x.input_sparse_dropzeros);
 out.field("direct_solve_method_name",x.direct_solve_method_name);
 out.field("settings_layout_verified",x.settings_layout_verified);
}
template<class Out> void fields(Out& out, const Validation& x) {
 out.field("max_normalized_violation", x.max_normalized_violation);
 out.field("max_absolute_violation", x.max_absolute_violation);
 out.field("objective_relative_error", x.objective_relative_error);
}
template<class Out> void fields(Out& out, const DualCheck& x) {
 out.field("stationarity", x.stationarity);
 out.field("negative", x.negative);
 out.field("relative_gap", x.relative_gap);
}
template<class Out> void fields(Out& out, const Mapping& x) {
 out.field("representatives", x.representatives);
 out.field("member_to_profile", x.member_to_profile);
 out.field("specimen_ids", x.specimen_ids);
 out.field("profile_ids", x.profile_ids);
}
template<class Out> void fields(Out& out, const GraphSnapshot& x) {
 out.field("edges", x.edges);
 out.field("degrees", x.degrees);
 out.field("upper", x.upper);
 out.field("components", x.components);
 out.field("isolates", x.isolates);
}
template<class Out> void fields(Out& out, const Decision& x) {
 out.field("location", x.location);
 out.field("dispersion", x.dispersion);
 out.field("threshold", x.threshold);
 out.field("raw_threshold", x.raw_threshold);
 out.field("floored_threshold", x.floored_threshold);
 out.field("cap", x.cap);
 out.field("stats", x.stats);
 out.field("candidates", x.candidates);
 out.field("threshold_margins", x.threshold_margins);
 out.field("median_residual", x.median_residual);
}
template<class Out> void fields(Out& out, const SolveRecord& x) {
 if(x.number>=0) out.field("number",x.number);
 if(x.logical_solve>=0) {
  out.field("logical_solve",x.logical_solve); out.field("attempt",x.attempt);
  out.field("numerical_policy",x.policy); out.field("solver_tolerance",x.solver_tolerance);
  out.field("solver_status",x.solver_status); out.field("retry_eligible",x.retry_eligible);
  if(x.attempt==1) {
   out.field("solver_units",x.solver_units); out.field("backend_rhs",x.backend_rhs);
   out.field("backend_primal",x.backend_primal); out.field("backend_dual",x.backend_dual);
   out.field("backend_slack",x.backend_slack); out.field("backend_objective",x.backend_objective);
   out.field("backend_res_primal",x.backend_res_primal); out.field("backend_res_dual",x.backend_res_dual);
  }
 }
 out.field("canonical_shape",x.A_shape);
 out.field("canonical_soc",Indices{});
 out.field("settings", x.settings);
 out.field("site", x.site);
 out.field("C", x.C);
 out.field("A_data", x.A_data);
 out.field("A_indices", x.A_indices);
 out.field("A_indptr", x.A_indptr);
 out.field("A_shape", x.A_shape);
 out.field("b", x.b);
 out.field("c", x.c);
 out.field("upper", x.upper);
 out.field("active", x.active);
 out.field("scales", x.scales);
 out.field("dual", x.dual);
 out.field("status", x.status);
 out.field("objective", x.objective);
 out.field("iterations", x.iterations);
 out.field("accepted", x.accepted);
 out.field("validation", x.validation);
 out.field("dual_check", x.dual_check);
 out.field("seconds", x.seconds);
}
template<class Out> void fields(Out& out, const MappingEvent& x) {
 fields(out,x.mapping);
}
template<class Out> void fields(Out& out, const ProcessedEvent& x) {
 out.field("D1", x.D1);
 out.field("D2", x.D2);
 out.field("scl", x.scl);
 out.field("initial_edges", x.initial_edges);
}
template<class Out> void fields(Out& out, const IterationEvent& x) {
 fields(out,x.graph);
 out.field("scl", x.scl);
}
template<class Out> void fields(Out& out, const KernelEvent& x) {
 out.field("affinity", x.affinity);
 out.field("scales", x.scales);
}
template<class Out> void fields(Out& out, const VolumeEvent& x) {
 out.field("ratios", x.ratios);
 out.field("scales", x.scales);
 out.field("degrees", x.degrees);
 out.field("multiscale", x.multiscale);
}
template<class Out> void fields(Out& out, const TuneStartEvent& x) {
 fields(out,x.graph);
 out.field("C", x.C);
 out.field("minC", x.minC);
 out.field("maxC", x.maxC);
 out.field("recycled", x.recycled);
}
template<class Out> void fields(Out& out, const RetuneEvalEvent& x) {
 out.field("C", x.C);
 out.field("median", x.median);
 out.field("minC", x.minC);
 out.field("maxC", x.maxC);
 out.field("bisection_index", x.bisection_index);
 out.field("median_margin", x.median_margin);
 out.field("lower_margin", x.lower_margin);
 out.field("upper_margin", x.upper_margin);
}
template<class Out> void fields(Out& out, const RetuneStopEvent& x) {
 out.field("C", x.C);
 out.field("median", x.median);
 out.field("minC", x.minC);
 out.field("maxC", x.maxC);
 out.field("median_target_met", x.median_target_met);
 out.field("boundary_stop", x.boundary_stop);
 out.field("cap_reached", x.cap_reached);
 out.field("bisection_updates", x.bisection_updates);
}
template<class Out> void fields(Out& out, const PrunedEvent& x) {
 fields(out,x.graph);
 out.field("selected", x.selected);
 out.field("removed", x.removed);
}
template<class Out> void fields(Out& out, const GraphStopEvent& x) {
 fields(out,x.graph);
 out.field("converged", x.converged);
 out.field("reason", x.reason);
}
template<class Out> void fields(Out& out, const CompleteEvent& x) {
 out.field("edges", x.edges);
 out.field("scales", x.scales);
 out.field("affinity", x.affinity);
 out.field("stats", x.stats);
 out.field("wstats", x.wstats);
 out.field("isolates", x.isolates);
}
template<class Out> void fields(Out& out, const PredicateEvent& x) {
 out.field("C", x.C);
 out.field("median", x.median);
 out.field("median_margin", x.median_margin);
 out.field("converged", x.converged);
}
template<class Out> void fields(Out& out, const Event& e) {
 out.field("event",e.name); out.field("phase",e.phase); out.field("iteration",e.iteration);
 std::visit([&](const auto& value){fields(out,value);},e.payload);
}
}
