# Independent audit coordination

The project owner granted standing authorization on 23 September 2026 for the
IAN implementer/coordinator to initiate independent audits as needed, communicate
directly with the existing **IAN auditor** task, address corrective findings, and
request independent re-review without waiting for another owner prompt.

The authorization follows the owner's explicit request to coordinate the helix
arithmetic audit through completion. The subsequent instruction extends it to the
adapter settings-layout repair, broader platform qualification and future IAN
work that needs independent review.

## Working procedure

At a reviewable milestone, send the auditor a concrete handoff identifying source
revisions, executable/build identities, methods, evidence locations, complete
accounting, known failures and the exact claims proposed for acceptance. Ask for
an independent disposition and a direct reply when the audit is complete or a
material blocker needs coordination. Preserve the submitted source and evidence.

The auditor controls its review and uses an isolated checkout and separate
evidence directory. The implementer resolves corrective findings, preserves the
original failure record, tests the correction and resubmits a versioned response.
Record the independent closure before reporting the issue resolved. Do not
describe an implementer check as an independent audit.

Actual platform executions, source inspection and cross-compilation must remain
separate claims. A successful test on one host does not qualify untested operating
systems, processor architectures or toolchains. Record unavailable resources and
the precise remaining qualification work rather than implying broad portability.

Audit acceptance is bounded to the named evidence and versions. Numerical-policy
adoption, merging, public export, production readiness and scale-ladder advancement
retain their separate project decisions; an audit request does not settle them.

## Task routing

- IAN implementer: `01a0af2e-f7b8-7810-91c8-ce3d55ff9d0a`, host `local`.
- IAN auditor: `01a0aa64-fed3-7281-8d05-9d7a9b680c12`, host `local`.
- Codex project: `93260d31-2100-4675-beec-6b9a6d6a4bda`.

Reconfirm task identity if these routing details become stale. This is standing
coordination authorization, not a scheduled automation.
