#pragma once
#include <cstddef>
#include <cstdint>
#include <limits>
#include <stdexcept>
#include <type_traits>

namespace ian_r {
// Limits come from R dimensions/vector lengths and the core's signed-index
// arithmetic, not the sizes selected for experimental qualification.
inline void matrix_dimensions(std::size_t rows, std::size_t columns, std::size_t vector_limit) {
    const auto index_limit=std::size_t(std::numeric_limits<int>::max());
    if(rows>index_limit || columns>index_limit ||
       (rows && columns>vector_limit/rows) ||
       (rows && columns>(std::numeric_limits<std::size_t>::max()/sizeof(double))/rows))
        throw std::runtime_error("IAN matrix dimensions exceed the R/native representation range");
}
inline void input_dimensions(std::size_t rows,std::size_t columns,std::size_t vector_limit) {
    // Core ranking/heap arithmetic includes 2 * a signed vertex count.
    if(rows>std::size_t(std::numeric_limits<int>::max()/2))
        throw std::runtime_error("IAN input dimensions exceed the native vertex-index range");
    matrix_dimensions(rows,columns,vector_limit);
    matrix_dimensions(rows,rows,vector_limit);
}
template<class T> bool integer_as_double(T value) {
    static_assert(std::is_integral_v<T>);
    constexpr std::uint64_t exact_limit=std::uint64_t(1)<<53;
    if constexpr(std::is_signed_v<T>) {
        const auto v=static_cast<std::int64_t>(value);
        // R reserves INT_MIN as its integer NA sentinel.
        if(v>std::numeric_limits<int>::min() && v<=std::numeric_limits<int>::max())return false;
        if(v < -static_cast<std::int64_t>(exact_limit) || v > static_cast<std::int64_t>(exact_limit))
            throw std::runtime_error("IAN integer cannot be represented exactly in R");
    } else {
        const auto v=static_cast<std::uint64_t>(value);
        if(v<=std::uint64_t(std::numeric_limits<int>::max()))return false;
        if(v>exact_limit)throw std::runtime_error("IAN integer cannot be represented exactly in R");
    }
    return true;
}
}
