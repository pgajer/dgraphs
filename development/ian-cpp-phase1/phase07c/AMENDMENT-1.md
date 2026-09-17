# Phase07C execution amendment

The first full panel (panel-v1, source d8fab3d) is retained as preliminary evidence.
Its core used the intended arithmetic, but a test-client-only edit after CMake
configuration did not refresh the source fingerprint embedded in the core. The
recorded fingerprint 4e12217b79b7049cc23f1cb3533f19155d23c09c70a98e57729c7f476592923d
therefore differs from the complete compiled source set. The difference is the
addition of filesystem output-directory creation in the observer test client.
Do not treat that fingerprint as matching the submitted source. Add explicit
CMake source/configuration dependencies, verify the computed identity before
launch, and repeat the full panel with a clean build. Preserve the first build,
logs and panel. Both panels count toward the original study budgets.

The Python stage-only probe writes stages.json but no status.json. The original
runner mislabeled its successful zero-solve process as REFUSED. Its stage values
and comparisons passed. Correct only this bookkeeping in the repeated panel.

The preliminary helix attempted 19 solves and exhausted its eighth retry during
initial tuning, before any accepted pruning checkpoint. Seven earlier retries
passed. Keep the numerical policy unchanged. If confirmed, record the natural
resume-after-retry test as unavailable, and exercise that operational path using
one explicitly labeled damaged first solution on the small PreSSMat fixture.
The injected first attempt halves the returned primal vector and objective;
the retry is a normal fresh solve. Compare uninterrupted and cancel/resume runs
under that same test setup. This is operational evidence, not a natural recovery
claim. Mutated checkpoint policy/source/configuration refusals use this checkpoint.
No new solver setting, geometry, scale expansion or adoption is added.
