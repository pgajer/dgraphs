// Standalone regression test: compile with -I src; no R dependency.
#include "quadform_geodesics_exact.h"
#include <cassert>
#include <iostream>
#include <random>

template<int Base, size_t Words>
double bitwise_reference(const qgn::ExactDyadic<Base,Words>& value) {
  if (value.top < 0) return 0;
  int high = value.top*32;
  uint32_t word = value.words[value.top];
  while (word >>= 1) ++high;
  int shift = std::max(high-52,-1074-Base);
  uint64_t significand = 0;
  for (int i = high; i >= shift; --i)
    significand = (significand << 1) | value.bit(i);
  bool sticky = false;
  for (int i = 0; i < shift-1; ++i)
    if (value.bit(i)) { sticky = true; break; }
  if (value.bit(shift-1) && (sticky || (significand & 1))) ++significand;
  double result = std::ldexp(static_cast<double>(significand),Base+shift);
  return value.negative ? -result : result;
}

uint64_t bits(double x) {
  uint64_t result;
  std::memcpy(&result,&x,sizeof(result));
  return result;
}

template<int Base, size_t Words>
size_t check_rounding(std::mt19937_64& rng) {
  using Value = qgn::ExactDyadic<Base,Words>;
  size_t checks = 0;
  auto check = [&](Value value) {
    for (bool negative : {false,true}) {
      value.negative = negative;
      assert(bits(value.rounded()) == bits(bitwise_reference(value)));
      ++checks;
    }
  };
  auto set = [](Value& value, int i) {
    if (i >= 0 && i < static_cast<int>(Words*32)) {
      value.words[i/32] |= uint32_t(1) << (i%32);
      value.top = std::max(value.top,i/32);
    }
  };
  check(Value{});
  // Every possible leading-bit position, including subnormal and overflow
  // ranges. Probe ties, both parities, and sticky bits next to word boundaries.
  for (int high = 0; high < static_cast<int>(Words*32); ++high) {
    Value value;
    set(value,high);
    check(value);
    int shift = std::max(high-52,-1074-Base);
    for (bool odd : {false,true}) {
      Value tie = value;
      if (odd) set(tie,shift);
      set(tie,shift-1);
      check(tie);
      for (int low : {0,1,30,31,32,33,63,64,shift-2,
                      ((shift-1)/32)*32-1,((shift-1)/32)*32}) {
        if (low < 0 || low >= shift-1) continue;
        Value sticky = tie;
        set(sticky,low);
        check(sticky);
      }
    }
    Value carry;
    for (int i = std::max(0,shift); i <= high; ++i) set(carry,i);
    set(carry,shift-1);
    check(carry);
  }
  for (int k = 0; k < 50000; ++k) {
    Value value;
    int high = static_cast<int>(rng()%(Words*32));
    int low = k%2 ? 0 : static_cast<int>(rng()%(high+1));
    for (int i = low/32; i <= high/32; ++i)
      value.words[i] = static_cast<uint32_t>(rng());
    value.words[high/32] &= UINT32_MAX >> (31-high%32);
    value.words[low/32] &= UINT32_MAX << (low%32);
    set(value,high);
    check(value);
  }
  return checks;
}

int main() {
  std::mt19937_64 rng(20260910);
  size_t checks = check_rounding<-1074,68>(rng);
  checks += check_rounding<-3222,198>(rng);
  qgn::ExactDyadic<-3222,198> tiny;
  tiny.words[0] = 1; tiny.top = 0; tiny.negative = true;
  assert(bits(tiny.rounded()) == UINT64_C(0x8000000000000000));
  qgn::ExactLength tie;
  tie.add(1); tie.add(std::ldexp(1.,-53));
  assert(tie.rounded() == 1);
  tie.add(std::numeric_limits<double>::denorm_min());
  assert(tie.rounded() == std::nextafter(1.,2.));
  std::cout << checks << " bitwise rounding comparisons passed, plus signed-zero and tie checks.\n";
}
