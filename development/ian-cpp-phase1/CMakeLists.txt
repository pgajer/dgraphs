cmake_minimum_required(VERSION 3.13)
project(ian_lp_replay LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CLARABEL_SOURCE)
  message(FATAL_ERROR "Set CLARABEL_SOURCE to the pinned private Clarabel.cpp checkout")
endif()
# Build the official Rust wrapper with its lockfile and consume the shipped C ABI.
# No regenerated C++ binding/Eigen interface is used, so cbindgen is not needed.
find_program(CARGO_EXECUTABLE cargo REQUIRED)
set(RUST_TARGET "${CMAKE_BINARY_DIR}/rust-target")
set(RUST_LIBRARY "${RUST_TARGET}/release/${CMAKE_SHARED_LIBRARY_PREFIX}clarabel_c${CMAKE_SHARED_LIBRARY_SUFFIX}")
add_custom_target(clarabel_core
  COMMAND ${CMAKE_COMMAND} -E env CARGO_TARGET_DIR=${RUST_TARGET}
          ${CARGO_EXECUTABLE} build --manifest-path ${CLARABEL_SOURCE}/rust_wrapper/Cargo.toml --release --locked
  BYPRODUCTS ${RUST_LIBRARY}
  VERBATIM)
add_executable(ian_lp_replay replay.cpp)
add_dependencies(ian_lp_replay clarabel_core)
target_include_directories(ian_lp_replay PRIVATE ${CLARABEL_SOURCE}/include)
target_link_libraries(ian_lp_replay PRIVATE ${RUST_LIBRARY})
target_compile_options(ian_lp_replay PRIVATE -Wall -Wextra -Wpedantic)
