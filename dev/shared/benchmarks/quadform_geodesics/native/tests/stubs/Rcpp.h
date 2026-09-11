#pragma once
#include <stdexcept>
namespace Rcpp {
inline void checkUserInterrupt() {}
template<class... T> void stop(const char* message, T...) { throw std::runtime_error(message); }
}
