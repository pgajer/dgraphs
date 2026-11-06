# Standalone ANN error regression

From the repository root, compile `ann-errors.cpp` together with `src/ANN/*.cpp`
using C++17 and `-Iinst/include`, then run the executable. For example:

```sh
c++ -std=c++17 -Iinst/include tests/native/ann-errors.cpp src/ANN/*.cpp -o /tmp/dgraphs-ann-errors
/tmp/dgraphs-ann-errors
```

The test checks fatal and warning propagation, invalid point dimensions,
priority-queue overflow, repeated invalid searches and successful searches after
an error. Run with AddressSanitizer and UndefinedBehaviorSanitizer when supported.
This standalone test requires a C++ compiler and is separate from R CMD check;
R-level boundary validation is exercised in `testthat/test-native-safety.R`.
