# Phase07: complete the fixed 500-profile panel after a shared refusal

The first batch at source `9fe9ee6` completed the 120-profile regression and
attempted the 500-profile helix. Native and evaluated Python agree through both
solves and both reject solve 2: normalized constraint residual
2.6877102747778647e-7 exceeds the unchanged 1e-7 allowance. Their saved primal and
dual vectors are identical. The original-expression control rejects solve 1 at
1.5750401345031977e-7. No graph or resumable boundary exists in these three runs.

The driver applied its gate to all later inputs, including the other three fixed
500-profile inputs. This was more restrictive than necessary to prevent size
expansion: it left the intended geometry panel untested even though the two
implementation paths agreed on the failed calculation. Preserve ladder-v1 and
its original gated ledger exactly. Before executing any remaining input, record
this bounded continuation in ladder-v2:

- Execute the already frozen cloud, separated lobes and PreSSMat inputs at 500,
  each in native and evaluated Python. Execute the prescribed original-expression
  lobe control. Do not repeat the helix or regression solves.
- Continue within this fixed 500 panel after a shared numerical refusal only
  when native/evaluated trace comparisons pass. Stop subsequent principal inputs
  at an unexplained implementation difference or resource limit.
- Keep all 1,000-profile tests gated. This continuation cannot reopen that gate.
- Count original and continuation solver calls, elapsed time and output against
  the same study-wide limits. No fixture, numerical criterion, checkpoint cadence,
  solver setting or algorithm changes. All generated 1,000 inputs remain unused.

This is a coordinator decision within the authorized scale study. It improves
coverage of the frozen panel without expanding size, searching new candidates,
or interpreting a rejected solve as success. The original negative result stands.
