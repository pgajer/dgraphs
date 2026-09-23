#pragma once
// Diagnostic-only interface, not installed or part of the consumer API.
#include <ian/core.hpp>
namespace ian::testing {
Result run_with_fault(const Input&, Observer*, const std::string&);
std::string fixed_probe(const std::string&, Observer*);
std::string legacy_stages(const std::string&);
}
