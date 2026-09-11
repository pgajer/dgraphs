#ifndef GEOSMOOTH_QUADFORM_GEODESICS_EXACT_H
#define GEOSMOOTH_QUADFORM_GEODESICS_EXACT_H

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <limits>
#include <stdexcept>
#include <vector>

namespace qgn {
// Finite binary64 values are signed integers times powers of two. These small
// accumulators avoid intermediate rounding, including cancellation in u^T A u.
struct BinaryPart {
  uint64_t mantissa;
  int exponent;
  bool negative;
  explicit BinaryPart(double x) {
    static_assert(std::numeric_limits<double>::is_iec559 &&
                  std::numeric_limits<double>::digits == 53 && sizeof(double) == 8,
                  "IEEE binary64 arithmetic required");
    if (!std::isfinite(x)) throw std::domain_error("Nonfinite exact operand");
    uint64_t bits; std::memcpy(&bits,&x,8);
    int e = static_cast<int>((bits >> 52) & 2047);
    mantissa = bits & UINT64_C(0xfffffffffffff);
    if (e) mantissa |= UINT64_C(0x10000000000000);
    exponent = e ? e-1075 : -1074;
    negative = (bits >> 63) != 0;
  }
};

template<int Base, size_t Words> struct ExactDyadic {
  std::array<uint32_t,Words> words{};
  bool negative = false;
  int top = -1;
  int magnitude_compare(const ExactDyadic& b) const {
    if (top != b.top) return top < b.top ? -1 : 1;
    for (int i = top; i >= 0; --i)
      if (words[i] != b.words[i]) return words[i] < b.words[i] ? -1 : 1;
    return 0;
  }
  int compare(const ExactDyadic& b) const {
    if (negative != b.negative) return negative ? -1 : 1;
    int order = magnitude_compare(b); return negative ? -order : order;
  }
  void add(const ExactDyadic& b) {
    if (b.top < 0) return;
    if (negative == b.negative) {
      uint64_t carry = 0; int end = std::max(top,b.top);
      for (int i = 0; i <= end || carry; ++i) {
        if (i >= static_cast<int>(Words)) throw std::overflow_error("Exact accumulator capacity");
        uint64_t v = uint64_t(words[i])+b.words[i]+carry;
        words[i] = static_cast<uint32_t>(v); carry = v >> 32; top = i;
      }
    } else {
      int order = magnitude_compare(b);
      if (order < 0) { ExactDyadic tmp = b; tmp.add(*this); *this = tmp; return; }
      uint64_t borrow = 0;
      for (int i = 0; i <= top; ++i) {
        uint64_t rhs = uint64_t(b.words[i])+borrow, lhs = words[i];
        words[i] = static_cast<uint32_t>(lhs-rhs); borrow = lhs < rhs;
      }
      while (top >= 0 && words[top] == 0) --top;
      if (top < 0) negative = false;
    }
  }
  void term(const std::vector<uint32_t>& digits, int exponent, bool sign) {
    ExactDyadic t; t.negative = sign;
    int shift = exponent-Base;
    if (shift < 0) throw std::overflow_error("Exact accumulator exponent");
    size_t offset = static_cast<size_t>(shift/32); int bit = shift%32;
    for (size_t i = 0; i < digits.size(); ++i) {
      uint64_t v = uint64_t(digits[i]) << bit;
      if (offset+i+1 >= Words) throw std::overflow_error("Exact accumulator capacity");
      t.words[offset+i] |= static_cast<uint32_t>(v);
      t.words[offset+i+1] |= static_cast<uint32_t>(v >> 32);
    }
    t.top = static_cast<int>(offset+digits.size());
    while (t.top >= 0 && t.words[t.top] == 0) --t.top;
    if (t.top < 0) t.negative = false;
    add(t);
  }
  void add(double x) {
    BinaryPart p(x);
    if (top >= 0 && negative != p.negative) {
      term({static_cast<uint32_t>(p.mantissa),static_cast<uint32_t>(p.mantissa >> 32)},
           p.exponent,p.negative);
      return;
    }
    int shift = p.exponent-Base;
    if (shift < 0) throw std::overflow_error("Exact accumulator exponent");
    size_t offset = static_cast<size_t>(shift/32); int bit = shift%32;
    if (offset+2 >= Words) throw std::overflow_error("Exact accumulator capacity");
    if (!p.mantissa) return;
    // A shifted binary64 significand occupies at most three words. Add it
    // directly, then propagate carry, without a full temporary accumulator.
    uint64_t low = uint64_t(static_cast<uint32_t>(p.mantissa)) << bit;
    uint64_t high = (p.mantissa >> 32) << bit;
    std::array<uint32_t,3> digits{{static_cast<uint32_t>(low),
      static_cast<uint32_t>((low >> 32) | high),static_cast<uint32_t>(high >> 32)}};
    uint64_t carry = 0;
    for (size_t i = 0; i < digits.size() || carry; ++i) {
      if (offset+i >= Words) throw std::overflow_error("Exact accumulator capacity");
      uint64_t value = uint64_t(words[offset+i])+carry+(i < digits.size() ? digits[i] : 0);
      words[offset+i] = static_cast<uint32_t>(value); carry = value >> 32;
      top = std::max(top,static_cast<int>(offset+i));
    }
    while (top >= 0 && words[top] == 0) --top;
    negative = p.negative;
  }
  void product(double a, double b, double c) {
    std::vector<uint32_t> digits{1}; int exponent = 0; bool sign = false;
    for (double x : {a,b,c}) {
      BinaryPart p(x); exponent += p.exponent; sign ^= p.negative;
      std::array<uint32_t,2> m{{static_cast<uint32_t>(p.mantissa),
                              static_cast<uint32_t>(p.mantissa >> 32)}};
      std::vector<uint32_t> next(digits.size()+2,0);
      for (size_t i = 0; i < digits.size(); ++i) {
        uint64_t carry = 0;
        for (size_t j = 0; j < 2; ++j) {
          uint64_t v = uint64_t(digits[i])*m[j]+next[i+j]+carry;
          next[i+j] = static_cast<uint32_t>(v); carry = v >> 32;
        }
        next[i+2] = static_cast<uint32_t>(carry);
      }
      while (next.size() > 1 && next.back() == 0) next.pop_back();
      digits.swap(next);
    }
    term(digits,exponent,sign);
  }
  bool bit(int i) const { return i >= 0 && static_cast<size_t>(i/32) < Words &&
                               ((words[i/32] >> (i%32)) & 1); }
  double rounded() const {
    if (top < 0) return 0;
    int high = top*32; uint32_t v = words[top];
    while (v >>= 1) ++high;
    // Keep 53 significant bits, or the subnormal quantum, whichever is coarser.
    int shift = std::max(high-52,-1074-Base);
    uint64_t significand = 0;
    for (int i = high; i >= shift; --i) significand = (significand << 1) | bit(i);
    bool sticky = false;
    // Test discarded bits below the rounding bit a word at a time.
    if (shift > 1) {
      size_t full = static_cast<size_t>((shift-1)/32);
      for (size_t i = 0; i < std::min(full,Words); ++i)
        if (words[i]) { sticky = true; break; }
      int remainder = (shift-1)%32;
      if (!sticky && remainder && full < Words)
        sticky = (words[full] & ((uint32_t(1) << remainder)-1)) != 0;
    }
    if (bit(shift-1) && (sticky || (significand & 1))) ++significand;
    double result = std::ldexp(static_cast<double>(significand),Base+shift);
    return negative ? -result : result;
  }
};

// 2176 bits cover sums of far more than the permitted 513 local graph edges.
using ExactLength = ExactDyadic<-1074,68>;
inline double surface_height(const std::array<double,4>& a, const std::array<double,2>& p) {
  // Three finite binary64 factors range from 2^-3222 to less than 2^3072.
  ExactDyadic<-3222,198> value;
  for (size_t i = 0; i < 2; ++i) for (size_t j = 0; j < 2; ++j)
    value.product(a[2*i+j],p[i],p[j]);
  return value.rounded();
}
} // namespace qgn
#endif
