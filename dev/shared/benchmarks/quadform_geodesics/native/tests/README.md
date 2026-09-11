# Native Component Regressions

Run from the package root with an available C++17 compiler:

```sh
clang++ -std=c++17 -O1 -g -fsanitize=address,undefined \
  -ffp-contract=off -fno-fast-math -I src \
  -I dev/shared/benchmarks/quadform_geodesics/native/tests/stubs \
  dev/shared/benchmarks/quadform_geodesics/native/tests/audit_regressions.cpp \
  -o /tmp/geosmooth-component-tests
/tmp/geosmooth-component-tests
```

These tests exercise repeated-coordinate occurrence identifiers, an exact
graph-cost counterexample, and cancellation, overflow and subnormal heights.
They include the production core directly. The stub replaces only R interrupt
and error entry points; it does not test R interruption or result conversion.
The package's `test-quadform-audit-regressions.R` covers returned heights,
short initial subdivisions and incomplete-exploration labels through R.

The native test is separate from installed package tests and does not add a
runtime dependency. Sanitizer availability depends on the compiler/platform.

## Exact Rounding

The word-level discarded-bit scan is checked against the original bit-by-bit
rounding rule, including every leading-bit position in both accumulator sizes,
word boundaries, ties, carries, signed zero, subnormal values and overflow.
Random dense and sparse accumulators supplement these boundary checks.

```sh
clang++ -std=c++17 -O1 -g -fsanitize=address,undefined \
  -ffp-contract=off -fno-fast-math -I src \
  dev/shared/benchmarks/quadform_geodesics/native/tests/exact_rounding.cpp \
  -o /tmp/geosmooth-exact-rounding-tests
/tmp/geosmooth-exact-rounding-tests
```

These comparisons test preservation of the previous rounding behavior, not an
independent proof that the previous rule is correct.

## Exact Addition

`exact_add.cpp` compares every accumulator word, sign and leading-word index
with the original term-based addition after each operand. It covers both
accumulator sizes, every binary64 power-of-two exponent, signed zero,
cancellation, dense carries, full-range random sequences and invalid operands.
Compile it with the same flags as `exact_rounding.cpp`. The optimized path
handles same-sign additions directly; opposite signs retain the original
cancellation code. Equality of the full state is stronger than agreement of
the rounded output alone.
