#include "identity.hpp"
#include "json_adapter.hpp"
#include "digest.hpp"
namespace ian::io {
std::string input_identity(const Input& input) {
    Json j{{"version",input.version},{"policy",input.policy},
        {"features",input.features},{"distances",input.distances},{"ids",input.specimen_ids},
        {"participants",input.participant_ids}};
    if(input.preserve_connectivity)j["pruning_policy"]=connected_pruning_policy;
    return digest(j.dump());
}
}
