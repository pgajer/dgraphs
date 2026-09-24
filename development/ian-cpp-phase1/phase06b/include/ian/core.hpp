#pragma once
#include <array>
#include <string>
#include <vector>

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
struct Event {
    std::string name, phase;
    int iteration;
    // Optional schema-1 diagnostic JSON. Not needed to consume typed results.
    std::string json;
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
