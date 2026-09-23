#include "engine.hpp"
#ifdef INCLUDE_NLOHMANN_JSON_HPP_
#error Numerical engine headers must not include JSON
#endif
static_assert(std::variant_size_v<ian::EventPayload> == 15);
int main(){ian::Input in;ian::Decision d{};ian::SolveRecord s{};return int(in.features.size()+d.candidates.size()+s.scales.size());}
