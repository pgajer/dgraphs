# Dependency and reference declarations

No IAN source code is vendored here. Mathematical conventions and numerical
acceptance thresholds are derived from the pinned upstream IAN source and the
local frozen EXP-038 adapter named in the report. This is a new, small replay
client, fixture exporter, validator, driver and report authored for this task.

- IAN 1.1.2, revision `06606ab27b52a1ea60daebae082a0e6752625521`: BSD-3-Clause,
  copyright Luciano Dyballa 2022. Its two inspected local source files match
  downloads from that revision exactly. License text is preserved privately in
  `worker/setup/IAN-LICENSE.txt` and is available at
  <https://github.com/dyballa/IAN/blob/06606ab27b52a1ea60daebae082a0e6752625521/LICENSE>.
- Clarabel.cpp `0de6259a3edfd5cc041ec42b2148599ce63e73cb`: Apache-2.0;
  <https://github.com/oxfordcontrol/Clarabel.cpp/blob/0de6259a3edfd5cc041ec42b2148599ce63e73cb/LICENSE.md>.
- Clarabel.rs `25540f559592068d0c8a80e46ded1b21760212a1` (v0.11.1): Apache-2.0;
  <https://github.com/oxfordcontrol/Clarabel.rs/blob/v0.11.1/LICENSE.md>.
- dgraphs currently declares MIT plus its LICENSE file. No package metadata or
  licensing is changed by this prototype.

The private native build links the official Rust wrapper as a dynamic library.
The checked-in Cargo lock captures resolved Rust dependencies; Python versions
are in `requirements-lock.txt`. Official headers are consumed from the private
dependency checkout. The final path uses the C ABI from C++, so Eigen and
cbindgen are not needed by the client build. The failed stock CMake setup used
Eigen 5.0.1 and tried cbindgen 0.29.4; those are not runtime requirements here.

This inventory records inspected declarations; it is not a complete transitive
license audit or a distribution/legal certification. A future redistributed
package must retain applicable notices and assess all dependencies and binary
redistribution terms. Nothing has been released or installed into R libraries.
