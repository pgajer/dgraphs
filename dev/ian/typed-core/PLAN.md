# Typed core messages: bounded refactor

Authorized 23 September 2026. Base: 9fbabc6a5d36098f896936cd79e8f7a963ec363c.
Replace internal JSON inputs, mappings, solver results/settings, decisions, events
and stage handoffs with named C++ structures and a variant of typed event payloads.
R observers project those structures directly into the existing R diagnostic schema.
Numerical arithmetic, ordering, tolerances, solver configuration and error semantics
remain unchanged. Canonical JSON input fingerprinting is isolated at a persistence
boundary to preserve its format. Optional JSON serializers support traces, legacy
test entry points and disk checkpoints. Historical source/evidence stays read-only.

Before numerical execution, freeze this plan and source. Bounds: at most 36 engine
calls and 400 solver attempts across this refactor's schedules, at most 80 attempts
per call and 96 specimens. Tests include the existing 13-call/77-attempt interface
panel; full traces for four old/new small reference fixtures; a typed-observer,
checkpoint/cancel/resume/refusal test; and existing six fixed decision controls.
Reuse stored reference outputs, but make fresh old-version full traces where none
were retained. Record each invocation and attempted solve; expected failures count.
No 500/1000-scale runs, new policy or scientific profiles.

Require exact old/new numerical and discrete outputs and trace payloads, excluding
elapsed timing, build/source identity and the documented trace-format description.
Retain every R diagnostic field and its type/shape. Test no-JSON compilation of the
numerical/event headers, optional JSON serialization, and direct typed observers.
Exercise checkpoint round-trip and resumed equivalence, cancellation/observer
failure and malformed restart. Rebuild/install in a new private library, run the
existing package regression selection and inspect outputs. Compilation and package
installation do not optimize. Failures and corrections remain in evidence.

This is author qualification. Independent review, public export, portability,
performance claims and the larger scale ladder remain separate.
