# Preserved qualification-harness corrections

The first archive command failed before installation or engine execution because private-only R-devel library settings hid the existing RcppEigen dependency. The corrected environment explicitly retains read-only dependency libraries. The failed archive log, its command record and environment-initial.json remain preserved; archive-v2 succeeds.

The first numerical entry (the small strict nonuniform-curve case on R-devel) completed and exactly matched its saved R result. The certificate helper then raised KeyError because it assumed retry metadata exists in a strict-policy trace. Strict traces deliberately preserve their earlier schema. The corrected checker validates the same full numerical certificate and applies retry-unit checks only to records with retry metadata. No engine behavior, source archive or input changes.

The continuation uses a new numerical-v2 directory, carries the original entry and process in cumulative accounting, and checks that saved completed output without rerunning it. Remaining scheduled entries are launched once. The original numerical-v1 ledger and outputs are retained. Planned entry/attempt/resource ceilings and acceptance checks are unchanged.

## Independent finding F1 — process exit during cleanup

The independent auditor demonstrated a race between polling a child and sending a cleanup signal in the public Python builder. ProcessLookupError could prevent wait(), while the final record still claimed reaped with a null return code. The same unsafe signal pattern existed in this stage's command supervisor.

Both now tolerate a vanished process group, attempt bounded wait after signalling, and escalate to a second bounded wait after SIGKILL. Cleanup errors are retained. A null return code produces termination_unconfirmed rather than reaped. The initial timeout or interruption is preserved. Eleven deterministic controls exercise each actual implementation: success, nonzero exit, launch failure, timeout, kill escalation, signal race, interruption, interruption with a signal race, unconfirmed termination, signal permission error and interruption during cleanup. These 22 controls launch no child or engine. The original source, report/PDF and numerical evidence remain preserved.

The corrected package is rebuilt and installed into a separate public-interface-f1 evidence root for both declared R runtimes. Fresh public backend setup, targeted tests, full package checks and guide checks qualify the packaging correction. No numerical implementation or R graph code changed, so no additional author numerical trajectory is scheduled; the auditor controls independent replay. The original 56-entry numerical census is retained rather than passed off as execution of the corrected builder.

The auditor's follow-up found that a child exiting zero just after the deadline could still make the stage supervisor return success. The supervisor now exits nonzero whenever the wall limit was reached, retaining the actual child return code and wall_limit reason separately. The 22 controls now assert the supervisor's returned exit status, including the zero-exit signal race. This follow-up changes no package inputs.
