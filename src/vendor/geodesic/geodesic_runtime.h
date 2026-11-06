// dgraphs integration support; not part of the upstream algorithm.
#pragma once
#include <stdexcept>
#include <ostream>
#include <streambuf>
#include <functional>
#include <map>
#include <memory>
namespace geodesic {
struct Invariant : std::runtime_error {using std::runtime_error::runtime_error;};
struct ResourceLimit : std::runtime_error {using std::runtime_error::runtime_error;};
class NullBuffer : public std::streambuf {
  int_type overflow(int_type c) override{return traits_type::not_eof(c);}
};
inline std::ostream& diagnostic_stream(){static NullBuffer b;static std::ostream out(&b);return out;}
}
#define GEODESIC_ASSERT(x) do {if(!(x))throw geodesic::Invariant("Mesh invariant: " #x);} while(false)
