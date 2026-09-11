// Compile with -I src. The original term-based addition is the state oracle.
#include "quadform_geodesics_exact.h"
#include <cassert>
#include <iostream>
#include <random>

template<int Base, size_t Words>
void original_add(qgn::ExactDyadic<Base,Words>& value, double x) {
  qgn::BinaryPart p(x);
  value.term({static_cast<uint32_t>(p.mantissa),static_cast<uint32_t>(p.mantissa >> 32)},
             p.exponent,p.negative);
}

template<int Base, size_t Words>
size_t check_add(std::mt19937_64& rng) {
  using Value = qgn::ExactDyadic<Base,Words>;
  size_t checks = 0;
  auto step = [&](Value& actual, Value& expected, double x) {
    actual.add(x); original_add(expected,x);
    assert(actual.words == expected.words);
    assert(actual.top == expected.top && actual.negative == expected.negative);
    ++checks;
  };
  for (int exponent = -1074; exponent <= 1023; ++exponent) {
    for (double sign : {-1.,1.}) {
      Value actual,expected;
      double x = sign*std::ldexp(1.,exponent);
      for (double y : {x,x,0.,-0.,-x,-x,x,-x}) step(actual,expected,y);
      step(actual,expected,sign*std::nextafter(std::abs(x),INFINITY));
      step(actual,expected,-sign*std::nextafter(std::abs(x),INFINITY));
    }
  }
  for (int trial = 0; trial < 1000; ++trial) {
    Value actual,expected;
    for (int j = 0; j < 513; ++j) {
      uint64_t raw = rng();
      if (((raw >> 52) & 2047) == 2047) raw ^= UINT64_C(1) << 52;
      if (trial%3 == 0) raw &= ~(UINT64_C(1) << 63);
      if (trial%3 == 1) raw |= UINT64_C(1) << 63;
      double x; std::memcpy(&x,&raw,8);
      step(actual,expected,x);
      if (trial%7 == 0) step(actual,expected,-x);
    }
  }
  // Carry propagation through long strings of full words, with either sign.
  for (int end = 0; end < static_cast<int>(Words)-2; ++end) {
    Value actual;
    actual.top = end;
    for (int j = 0; j <= end; ++j) actual.words[j] = UINT32_MAX;
    for (bool negative : {false,true}) {
      Value a = actual; a.negative = negative; Value b = a;
      step(a,b,negative ? -std::numeric_limits<double>::denorm_min() :
                         std::numeric_limits<double>::denorm_min());
    }
  }
  return checks;
}

int main() {
  std::mt19937_64 rng(20260911);
  size_t count = check_add<-1074,68>(rng)+check_add<-3222,198>(rng);
  for (double x : {INFINITY,-INFINITY,NAN}) {
    qgn::ExactLength value;
    bool threw = false;
    try { value.add(x); } catch(const std::domain_error&) { threw = true; }
    assert(threw);
  }
  qgn::ExactDyadic<-1074,2> tiny;
  bool threw = false;
  try { tiny.add(std::numeric_limits<double>::denorm_min()); }
  catch(const std::overflow_error&) { threw = true; }
  assert(threw);
  qgn::ExactDyadic<0,68> coarse;
  threw = false;
  try { coarse.add(.5); } catch(const std::overflow_error&) { threw = true; }
  assert(threw);
  std::cout << count << " exact-addition state comparisons passed, plus exception checks.\n";
}
