# Quadratic Connector Length References

`quadform-edge-lengths.csv` records exact double-precision input coordinates
and symmetric matrix coefficients in hexadecimal floating-point notation,
with a rounded reference and 90 displayed decimal digits from a
300-decimal-digit independent reference calculation. Five regressions have
narrow speed minima that adaptive quadrature failed to resolve. Thirty
constructed cases vary minimum location and width. Twelve other cases cover
identity, flat, constant-slope, near-constant-slope, extreme-scale and
cancellation behavior, including the eight-unit quadrature counterexample.

For h=b-a, c=||h||, x=2a^T A h and y=2b^T A h, the reference evaluates

    H(v) = (v sqrt(c^2+v^2) + c^2 asinh(v/c))/2
    length = (H(y)-H(x))/(y-x).

It uses the constant value hypot(c,x) when x=y, and zero for identical
endpoints. All input arithmetic and primitive differences are computed using
Boost.Multiprecision with 300 decimal digits. Production instead uses scaled,
cancellation-free divided differences; it does not require Boost. Tests allow
one additional double-rounding allowance when reading the reference column.
Hexadecimal values preserve exact input bits, including subnormal coordinates,
without relying on decimal conversion of very small exponents.
