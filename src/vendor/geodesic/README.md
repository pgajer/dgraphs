# Geodesic source provenance

Six headers are derived from https://github.com/mojocorp/geodesic at commit
`7b08bfb03c444819a31f216cb1e0a3fb9528f806`. Copyright (c) 2008 Danil Kirsanov,
MIT license; the full notice is in `inst/licenses/Geodesic-MIT.txt`.

The package uses the Mitchell-Mount-Papadimitriou interval-propagation method
implemented by this library, including its fixed `SMALLEST_INTERVAL_RATIO=1e-6`.
The word "exact" is the upstream algorithm's name, not a numerical certificate
or a statement about the original smooth quadratic surface.

Local adaptations:

- Line endings are normalized to LF.
- `geodesic_runtime.h` supplies exception-based invariant checks in all builds
  and a discarding diagnostic stream instead of console output.
- The exact algorithm owns every allocated interval in a unique-pointer map.
  Upstream interval-list clearing only discarded pointers; the local ownership
  also releases intervals when a resource stop or exception interrupts an update.
- Allocation, propagation and traceback poll a caller-supplied interrupt/time
  callback. Live intervals and propagation steps have explicit limits; traceback
  has a 65536-point limit. These stops do not publish unfinished paths.
- Interval fields are initialized, and non-trivial interval objects are copied
  by typed assignment, not `memcpy`.
- Copying the owning algorithm object is disabled.

The interval propagation formulas and the upstream small-interval cutoff are
unchanged. The package wrapper validates mesh indices, edge incidence and
triangle angles before calling this implementation, scales coordinates, and
checks reconstructed length, endpoints and domain containment afterward.
