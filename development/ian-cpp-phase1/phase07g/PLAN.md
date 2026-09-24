# Phase 07G: exact-data cross-interface replay

Authorized by Pawel after Phase07F independent acceptance without corrective findings.
Base: ec65a871e5f06c5a6e6c6ecccd947d4b0970ff7f. This plan precedes implementation
and new solves. Study completion, acceptance, policy adoption and expansion are separate.

## Question and fixed experiment

Determine whether the terminal helix outcome follows the one-binary64-step RHS
change or differs between interfaces when supplied identical backend arrays.
Freeze the native and Python terminal LPs separately from Phase07F. Preserve
original JSON and generate lossless binary64 CSC inputs, normalized by the saved
maximum upper bound. Verify dimensions, index ordering, explicit zeros, P=0,
objective, one nonnegative cone, and normalization before solving. Each client
records the actual arrays supplied to its backend before constructing a solver.
Record effective settings, compiler flags, dependency identities and iteration
histories as well as raw primal, dual and slack vectors and original-unit checks.

Eight serial fresh-process solves: native interface/native input, Python interface/
Python input, Python interface/native input, native interface/Python input, then
repeat these four cells in reverse order. Each uses one fresh solver, accepted
normalized retry settings (three tolerances 1e-11, 300 iterations, one thread,
QDLDL, presolve disabled), no subsequent retry and unchanged 1e-7 certificate
checks and Solved status requirement. Preserve every result including refusals.
Native links the existing accepted backend without rebuilding it. Python uses the
existing environment. Explicitly record wrapper settings not exposed by the other
interface. No backend installation, settings search or alternative algorithm.

Both own-input baselines must reproduce their original engine status, iterations,
primal/dual/slack vectors and objectives exactly before causal interpretation of
the crossed cells. All eight cells may be collected if a baseline fails, but the
interpretation gate then remains closed. Repeat agreement excludes timing fields.
Compare status, numerical acceptance and frozen scale tolerance separately.
Outcomes following input support perturbation sensitivity on these pinned builds;
identical-input divergence instead leaves an interface/build/execution difference.
Neither establishes uniqueness, general conditioning or later graph compatibility.

## Controls and bounds

No-solve checks must detect a one-step coefficient perturbation, index changes,
and status rejection independently of certificate inequalities. Verify Python's
CVXPY canonical arrays against the direct replay formulation without solving.
Commit executable sources before any new solve. Use the accepted sampled child
supervisor: at most eight attempts, 120 seconds per process, 600 child seconds
total, 4 GiB process-tree RSS, 2 GiB per-process and 16 GiB study output, 20 GiB free.
Resource failure stops remaining cells; preserve partial records. History callbacks
only observe and never terminate. Record subprocess and physical-solve counts.

New source is confined to phase07g and coordinator/ROADMAP.md; new evidence to
worker/phase07g and its adjacent handoff. Preserve all earlier source/evidence,
auditor areas and the accepted runtime. Freeze checksums and provide a factual
report and implementer handoff. No full trajectories, gated ladder inputs,
quadform solves, scale expansion, policy relaxation, package work or deployment.
