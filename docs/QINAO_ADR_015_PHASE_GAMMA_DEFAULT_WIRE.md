# ADR-015: Phase Gamma Default-Wire Doctrine — proposal (chapter 三百三六 / M823)

**Status**: PROPOSED (pending user / architecture review)
**Date**: 2026-05-07
**Supersedes**: none
**Related**: ADR-013 (per-layer concurrency), ADR-014 (OPT-IN → PROD migration)
**Branch**: `next-gen-architecture-2026-05-07`

## Context

Chapters 三百二〇-三百三五 (附录 X) shipped 13 typed primitives bridging chapter 一百七十七's 5 real `.mlpackage` files into the typed `BASLayerMLHead` protocol + canonical mesh registry. The chain is now:

- Doctrinally clean (single-source-of-truth, anti-magic-number, Sendable)
- Real-model validated (gated E2E tests against all 5 .mlpackage files)
- Hint-class only (red line 7 preserved)
- 0 default behavior change (per ADR-014 OPT-IN → PROD doctrine)

**Hosts that DON'T explicitly opt in see exactly the same execution profile as before chapter 三百二〇.**

This is the explicit Phase Gamma boundary. **Should the substrate's default execution path consult the mesh?**

## Three options

### Option A: Stay opt-in forever (ADR-014 status quo)

- Hosts call `BASChengluHostRuntimeBuilder.build(...)` explicitly
- `BASHostRuntime.runChengluCanonicalSweep(input:)` only invoked by host-side orchestration
- Default `BASHostRuntime.startSession(...)` does NOT consult mesh

**Pros**: zero risk of regression in existing hosts; mesh is purely an additive observability layer; compatible with ADR-014 strict reading.

**Cons**: real production benefit only realized when hosts opt in; default substrate behavior remains unchanged forever; mesh effectively dead-code for non-opt-in users.

### Option B: Opt-in via configuration flag (recommended)

- Add `BASHostConfiguration.consultsMesh: Bool` (default `false`)
- When `true`, `BASHostRuntime.startSession(...)` calls `runChengluCanonicalSweep` automatically and emits hint reason codes into audit ledger
- When `false`, identical to Option A (zero behavior change)

**Pros**:
- Default behavior unchanged (preserves Option A safety)
- Host adoption is a single config field, not a new code path
- Audit emission gives observability without decision-path mutation
- Reversible per host (turn off if regression observed)

**Cons**:
- Adds a new public config field (small API surface growth)
- Hosts that adopt must validate their own E2E behavior
- Doctrine question: can audit emission alone count as "consultation"? Or does it need permit-gate hint surface too?

### Option C: Default-on for all hosts (aggressive)

- `BASHostRuntime.startSession(...)` ALWAYS consults mesh when `meshRegistry: nil` is the sole disable
- All existing hosts get mesh consultation behavior in next BAS update

**Pros**: production benefit immediately realized; no per-host adoption required; "the mesh activates by default" matches user's "全面 彻底 激发" intent.

**Cons**:
- Breaks ADR-014 OPT-IN → PROD doctrine
- Existing hosts may see changed audit ledger content (new `mesh-coreml:*` codes appearing)
- Performance overhead (~2-50ms per turn for cascade walk) imposed without consent
- If any future bug surfaces in mesh consultation, ALL hosts affected — no gradual rollback

## Recommendation

**Option B (configuration-flag opt-in)** is the doctrine-cleanest path. Specifically:

1. Add `BASHostConfiguration.consultsMesh: Bool = false` (default off)
2. When `true`, `runTurn` (or whichever path is the default execution loop) calls `runChengluCanonicalSweep(...)` between L1 wake and L11 permit synthesis
3. Hint reason codes emitted into audit ledger via chapter 三百二三 + 三百三〇 prefix
4. Hint OUTPUT does NOT mutate permit.mode or verdict.level (red line 7 preserved)
5. Hosts that want default-on at their level set `consultsMesh: true` in their hostConfig
6. Substrate-wide default-on (Option C) deferred to chapter 四百+ after Option B has been live for ≥3 chapters

## Doctrinal questions for review

1. **Audit-only vs hint-surface**: should mesh consultation also surface hints to permit synthesizers (e.g. influence the L11 risk gate's threshold), or strictly observability emit?

2. **Default-on prerequisites**: what would have to be true before flipping default to `true`? Suggested gate: ≥3 chapters of opt-in usage with no regressions + multi-host empirical data.

3. **Cost tracking**: should the mesh consultation be counted against the L1 budget slice, or carried as separate observability overhead?

4. **Performance ceiling**: should default-on enforce a max-cascade-time budget? E.g. cascade hard-stops after 50ms total, abandons remaining layers, emits `mesh-coreml:budget-exceeded` reason code?

5. **Failure mode**: what happens if mesh consultation throws? Suggested: catch + emit `mesh-coreml:cascade-failed:<reason>` audit code; substrate continues without mesh hints.

## Decision pending

This ADR is **PROPOSED**, not adopted. Implementation requires:
- User / architecture review
- Answers to the 5 doctrinal questions above
- Updated `BASHostConfiguration` schema (chapter 一百三 versioning doctrine)
- New default-on tests + regression baseline

Auto-mode session (this chapter) does not commit to any of the above without explicit user direction.

## Honest scope acknowledgement

The附录 X chain is doctrinally and reality-test ready for Phase Gamma adoption. The remaining gap is **doctrine review**, not engineering work. This ADR captures the proposal; the user (or future architecture review) decides whether/when to flip the default.
