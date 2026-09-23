#pragma once
#include <array>
#include <string>
#include <vector>
#include <variant>
#include <cstdint>
#include <cstddef>

namespace ian {
using Vector = std::vector<double>;
using Matrix = std::vector<Vector>;
using Indices = std::vector<int>;
using Edges = std::vector<std::array<int, 2>>;
inline constexpr int schema_version = 1;
inline constexpr const char* numerical_policy = "IAN evaluated-LP 1.0";

struct Input {
    int version = schema_version;
    std::string policy = numerical_policy;
    Matrix features, distances;
    std::vector<std::string> specimen_ids;
    // Optional specimen-level metadata; duplicates may have different participants.
    std::vector<std::string> participant_ids;
};
struct Mapping {
    Indices representatives, member_to_profile;
    std::vector<std::string> specimen_ids, profile_ids, participant_ids;
};
struct Graph {
    Edges edges;
    Vector edge_lengths, internal_upper;
    Indices degrees, components, isolates;
    double distance_multiplier = 1;
};
enum class Stage { graph, scales, affinity };
enum class ErrorKind { none, input, unsupported, numerical, observer, cancelled, internal };
struct Error {
    ErrorKind kind = ErrorKind::none;
    std::string code, message;
};
struct Result {
    int version = schema_version;
    std::string policy = numerical_policy;
    Mapping mapping;
    Graph graph;
    Vector scales, internal_scales, stats, weighted_stats;
    Matrix affinity;
    double multiplier = 0;
    int solves = 0, last_iteration = 0;
    // Validated in-memory stages; these flags do not promise durable storage.
    bool graph_valid = false, scales_valid = false, affinity_valid = false, complete = false;
    Error error;
};
// Typed event payloads. No JSON representation is used by the engine or observer.
struct SolverSettings {
    std::uint32_t max_iter{};
    double time_limit{};
    bool verbose{};
    double max_step_fraction{};
    double tol_gap_abs{};
    double tol_gap_rel{};
    double tol_feas{};
    double tol_infeas_abs{};
    double tol_infeas_rel{};
    double tol_ktratio{};
    double reduced_tol_gap_abs{};
    double reduced_tol_gap_rel{};
    double reduced_tol_feas{};
    double reduced_tol_infeas_abs{};
    double reduced_tol_infeas_rel{};
    double reduced_tol_ktratio{};
    bool equilibrate_enable{};
    std::uint32_t equilibrate_max_iter{};
    double equilibrate_min_scaling{};
    double equilibrate_max_scaling{};
    double linesearch_backtrack_step{};
    double min_switch_step_length{};
    double min_terminate_step_length{};
    std::uint32_t max_threads{};
    bool direct_kkt_solver{};
    int direct_solve_method{};
    bool static_regularization_enable{};
    double static_regularization_constant{};
    double static_regularization_proportional{};
    bool dynamic_regularization_enable{};
    double dynamic_regularization_eps{};
    double dynamic_regularization_delta{};
    bool iterative_refinement_enable{};
    double iterative_refinement_reltol{};
    double iterative_refinement_abstol{};
    std::uint32_t iterative_refinement_max_iter{};
    double iterative_refinement_stop_ratio{};
    bool presolve_enable{};
    bool input_sparse_dropzeros{};
    std::string direct_solve_method_name = "qdldl";
    bool settings_layout_verified = true;
};
struct Validation { double max_normalized_violation, max_absolute_violation, objective_relative_error; };
struct DualCheck { double stationarity, negative, relative_gap; };
struct SolveRecord {
    SolverSettings settings;
    std::string site;
    double C;
    Vector A_data;
    std::vector<std::uintptr_t> A_indices, A_indptr;
    std::array<std::size_t,2> A_shape;
    Vector b, c, upper;
    Indices active;
    Vector scales, dual;
    std::string status;
    double objective;
    std::uint32_t iterations;
    bool accepted;
    Validation validation;
    DualCheck dual_check;
    double seconds;
    int number = -1;
};
struct Decision {
    double location, dispersion, threshold, raw_threshold, floored_threshold, cap;
    Vector stats;
    Indices candidates;
    Vector threshold_margins;
    double median_residual;
};
struct GraphSnapshot { Edges edges; Indices degrees; Vector upper; Indices components, isolates; };
struct MappingEvent { Mapping mapping; };
struct ProcessedEvent { Matrix D1, D2; double scl; Edges initial_edges; };
struct IterationEvent { GraphSnapshot graph; double scl; };
struct KernelEvent { Matrix affinity; Vector scales; };
struct VolumeEvent { Vector ratios, scales; Indices degrees; bool multiscale; };
struct TuneStartEvent { GraphSnapshot graph; double C, minC, maxC; bool recycled; };
struct RetuneEvalEvent { double C, median, minC, maxC; int bisection_index; double median_margin, lower_margin, upper_margin; };
struct RetuneStopEvent { double C, median, minC, maxC; bool median_target_met, boundary_stop, cap_reached; int bisection_updates; };
struct PrunedEvent { GraphSnapshot graph; Indices selected; Edges removed; };
struct GraphStopEvent { GraphSnapshot graph; bool converged; std::string reason; };
struct CompleteEvent { Edges edges; Vector scales; Matrix affinity; Vector stats, wstats; Indices isolates; };
struct PredicateEvent { double C, median, median_margin; bool converged; };
using EventPayload = std::variant<MappingEvent, ProcessedEvent, IterationEvent, SolveRecord,
    KernelEvent, VolumeEvent, TuneStartEvent, RetuneEvalEvent, RetuneStopEvent,
    Decision, PrunedEvent, GraphStopEvent, CompleteEvent, PredicateEvent>;
inline const char* event_name(const MappingEvent&) { return "mapping"; }
inline const char* event_name(const ProcessedEvent&) { return "processed"; }
inline const char* event_name(const IterationEvent&) { return "iteration"; }
inline const char* event_name(const SolveRecord&) { return "solve"; }
inline const char* event_name(const KernelEvent&) { return "kernel"; }
inline const char* event_name(const VolumeEvent&) { return "volume"; }
inline const char* event_name(const TuneStartEvent&) { return "tune_start"; }
inline const char* event_name(const RetuneEvalEvent&) { return "retune_eval"; }
inline const char* event_name(const RetuneStopEvent&) { return "retune_stop"; }
inline const char* event_name(const Decision&) { return "decision"; }
inline const char* event_name(const PrunedEvent&) { return "pruned"; }
inline const char* event_name(const GraphStopEvent&) { return "graph_stop"; }
inline const char* event_name(const CompleteEvent&) { return "complete"; }
inline const char* event_name(const PredicateEvent&) { return "predicate"; }
struct Event {
    std::string name, phase;
    int iteration;
    EventPayload payload;
};
// A completed pruning or graph boundary; no live solver or retuning bracket.
struct RestartState {
    int version = 1;
    std::string policy = numerical_policy, source, configuration, input_hash, boundary;
    Mapping mapping;
    Edges edges;
    Indices degrees;
    Vector upper, last_stats;
    double multiplier = 0, distance_multiplier = 1;
    int iteration = 0, solves = 0;
    bool cache = false;
};
class Observer {
public:
    virtual ~Observer() = default;
    virtual void on_event(const Event&) {}
    virtual void on_stage(Stage, const Result&) {}
    // Returning false cancels after this accepted boundary. The caller owns persistence.
    virtual bool on_checkpoint(const RestartState&) { return true; }
};
// Synchronous call. Input is borrowed read-only; returned values own their memory.
// Observer references are borrowed for the callback only. Each call has fresh state.
// Callback failures stop execution and return a structured error with partial results.
// Resource exhaustion is not guaranteed to be recoverable. No concurrency promise.
Result run(const Input&, Observer* observer = nullptr);
Result resume(const Input&, const RestartState&, Observer* observer = nullptr);
std::string source_identity();
std::string configuration_identity();
const char* error_kind_name(ErrorKind);
}
