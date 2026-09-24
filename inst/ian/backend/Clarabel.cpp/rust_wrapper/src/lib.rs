mod algebra;
mod core;
mod solver;
mod utils;

// Qualification probe for the pinned no-SDP adapter.
#[no_mangle]
pub extern "C" fn dgraphs_ian_settings_layout(index: usize) -> usize {
 type S = clarabel::solver::implementations::default::ffi::DefaultSettingsFFI<f64>;
 let layout=[std::mem::size_of::<S>(),std::mem::align_of::<S>(),
 std::mem::offset_of!(S,max_iter),
 std::mem::offset_of!(S,time_limit),
 std::mem::offset_of!(S,verbose),
 std::mem::offset_of!(S,max_step_fraction),
 std::mem::offset_of!(S,tol_gap_abs),
 std::mem::offset_of!(S,tol_gap_rel),
 std::mem::offset_of!(S,tol_feas),
 std::mem::offset_of!(S,tol_infeas_abs),
 std::mem::offset_of!(S,tol_infeas_rel),
 std::mem::offset_of!(S,tol_ktratio),
 std::mem::offset_of!(S,reduced_tol_gap_abs),
 std::mem::offset_of!(S,reduced_tol_gap_rel),
 std::mem::offset_of!(S,reduced_tol_feas),
 std::mem::offset_of!(S,reduced_tol_infeas_abs),
 std::mem::offset_of!(S,reduced_tol_infeas_rel),
 std::mem::offset_of!(S,reduced_tol_ktratio),
 std::mem::offset_of!(S,equilibrate_enable),
 std::mem::offset_of!(S,equilibrate_max_iter),
 std::mem::offset_of!(S,equilibrate_min_scaling),
 std::mem::offset_of!(S,equilibrate_max_scaling),
 std::mem::offset_of!(S,linesearch_backtrack_step),
 std::mem::offset_of!(S,min_switch_step_length),
 std::mem::offset_of!(S,min_terminate_step_length),
 std::mem::offset_of!(S,max_threads),
 std::mem::offset_of!(S,direct_kkt_solver),
 std::mem::offset_of!(S,direct_solve_method),
 std::mem::offset_of!(S,static_regularization_enable),
 std::mem::offset_of!(S,static_regularization_constant),
 std::mem::offset_of!(S,static_regularization_proportional),
 std::mem::offset_of!(S,dynamic_regularization_enable),
 std::mem::offset_of!(S,dynamic_regularization_eps),
 std::mem::offset_of!(S,dynamic_regularization_delta),
 std::mem::offset_of!(S,iterative_refinement_enable),
 std::mem::offset_of!(S,iterative_refinement_reltol),
 std::mem::offset_of!(S,iterative_refinement_abstol),
 std::mem::offset_of!(S,iterative_refinement_max_iter),
 std::mem::offset_of!(S,iterative_refinement_stop_ratio),
 std::mem::offset_of!(S,presolve_enable),
 std::mem::offset_of!(S,input_sparse_dropzeros),
 ];
 *layout.get(index).unwrap_or(&usize::MAX)
}
