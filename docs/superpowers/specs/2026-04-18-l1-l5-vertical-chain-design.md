# L1-L5 Vertical Chain Design

## Goal

Build a repository-real delivery path for `L1-L5` that makes the existing eBrain runtime stop behaving like five partially-adjacent surfaces and instead behave like one explicit vertical chain:

`L1 runtime policy + budget`
`-> L2 provider/thought contract`
`-> L3 session fold/checkpoint runtime`
`-> L4 foundation capability + compatibility gate`
`-> L5 host profile + host gate`

The result should be that runtime execution, checkpoint persistence, replay/export, and host control surfaces all agree on the same `L1-L5` facts.

## Scope

This design covers repository-deliverable work for:

- `L1 灯芯层`
- `L2 脑肉层`
- `L3 折叠肺`
- `L4 地平线层`
- `L5 宿纹层`

This design does not pretend to finish external training infrastructure. `L4` remains a repository-side capability and compatibility layer, not a fake training pipeline.

`L3` 的第二阶段仓库实现已经单独跟踪在 [EBRAIN_L3_FOLDED_LUNG_V2.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_L3_FOLDED_LUNG_V2.md)。这份 vertical-chain 设计继续描述 `L1-L5` 的总链路，不重复展开 `L3 v2` 的细节。

## Current State

The repository already has most of the raw pieces:

- `L1` exists as `BASDeviceState`, `BASBudgetFrame`, `BASDeviceRoute`, thermal guard levels, runtime planning, and adaptive provider planning.
- `L2` exists as service contracts and `BASThoughtFrame`, but provider capability, thought quality tier, and fallback semantics are still too implicit.
- `L3` exists as `ThoughtFold`, `DecisionSessionEngine`, replay/export, checkpoint anchors, and shared recovery surfaces.
- `L4` exists mostly as planning language and provider catalog assumptions, but it is not an explicit runtime-visible capability frame.
- `L5` exists as `BASHostProfile`, host gate, rollback/delete semantics, and host-aware risk and render behavior.

The gap is not “missing all layers”. The gap is that `L1-L5` still leak across multiple seams:

- runtime execution
- checkpoint anchors
- replay/export summaries
- flight deck
- evolution/testing surfaces

Those seams still reconstruct or infer too much of the same chain independently.

## Design Decision

Use a **vertical-chain approach** instead of “finish each layer in isolation”.

That means the main work is to make `L1-L5` explicit in one typed chain that survives:

1. turn execution
2. session/checkpoint persistence
3. replay/export
4. host/evolution inspection

This is better than a layer-by-layer sweep because the current repository already has substantial per-layer work landed. The highest-value missing piece is consistent end-to-end behavior, not more isolated definitions.

## Chosen Architecture

### 1. L1 remains the authoritative runtime-entry layer

`BASDeviceState` and `BASBudgetFrame` stay authoritative for runtime posture. We do not create a second app-side budget contract.

What changes:

- runtime planning results become part of a stable `L1-L5` chain payload instead of being re-summarized ad hoc in checkpoints and exports
- route, precision, thermal guard, maintenance eligibility, and downgrade reasons become easier to compare across turn, replay, and session recovery

### 2. L2 becomes an explicit provider/thought capability contract

The repository does not currently need a fake “real Scout/Core model”. It needs a runtime-visible contract for:

- which provider path produced the turn
- what thought capability tier was used
- whether execution was full, degraded, preview, or heuristic
- what structured-head guarantees are safe to assume

This will be represented as a typed capability frame rather than only scattered provider selection details.

This is the main repo-side completion for `L2`.

### 3. L4 becomes a foundation capability and compatibility gate

`L4` remains external for training, but repository code must still know:

- which foundation family/tier a provider path represents
- whether replay/checkpoint compatibility should trust that foundation capability
- whether downgrade or replay inspection should describe the turn as production, preview, heuristic, or unavailable

This means `L4` becomes an explicit metadata gate attached to the `L2` provider contract, not a hidden assumption in product copy.

### 4. L3 persists the whole L1-L5 chain, not just outcome facts

`DecisionSessionEngine` and checkpoint anchors already persist strong runtime facts. The next step is to make sure the persisted chain explicitly carries:

- `L1` budget/runtime posture
- `L2` provider/thought capability
- `L4` foundation compatibility
- `L5` host profile version and host gate context

The objective is that recovery, replay matching, and export stop re-deriving these from partial fields when the original turn already knew them.

### 5. L5 stays on the critical path

`BASHostProfile` and host gate are already first-class. The remaining requirement is to guarantee that:

- provider downgrade paths do not bypass host gate semantics
- checkpoint/replay inspection keeps the host profile lineage visible
- update and replay surfaces can answer “which host version and gate posture shaped this turn?”

That is a chain-consistency problem, not a UI copy problem.

## New Repository Contract

Introduce a shared typed `L1-L5` execution descriptor carried through the runtime chain.

Working name:

- `BASEBrainExecutionCapabilityFrame`

Responsibilities:

- represent the `L2` provider execution tier and thought capability
- represent the `L4` foundation family/tier/compatibility posture
- expose downgrade/preview/heuristic reasons in structured form
- be attachable to:
  - `BASEBrainTurnResult`
  - checkpoint anchor facts
  - runtime export / flight deck
  - replay diagnostics

It should not duplicate:

- `BASBudgetFrame`
- `BASHostProfile`

Instead it should reference the parts missing between them: provider execution and foundation capability.

## Package Breakdown

### Package A: L1-L2-L4 runtime capability spine

Build the typed capability frame and attach it to live turn execution.

Includes:

- capability type definition
- provider/foundation tier mapping
- degrade reason taxonomy
- runtime coordinator integration
- tests proving route + capability posture are explicit and deterministic

### Package B: L3 checkpoint and replay capture

Persist the new capability frame through session/checkpoint/replay/export seams.

Includes:

- session checkpoint anchor payload updates
- replay selection context updates where needed
- export and flight deck propagation
- compatibility tests across live turn and replay surfaces

### Package C: L5 host profile chain hardening

Ensure host profile lineage and gate context remain explicit across the same chain.

Includes:

- explicit host-version/runtime-host markers in the shared chain
- checkpoint/export parity
- tests proving replay/export cannot silently drop host gate posture

### Package D: surface parity for the L1-L5 chain

Make inspection surfaces consume the same typed facts instead of reconstructing them.

Includes:

- testing runtime export
- system flight deck
- shared replay/evolution facts surfaces
- targeted parity tests, not a new UI rewrite

## Testing Strategy

This design uses repo-real verification, not documentation-only confidence.

Required test classes:

- schema/contract tests for new typed `L1-L5` capability frame
- runtime coordinator tests proving deterministic capability mapping under route and downgrade conditions
- session/checkpoint tests proving the frame survives persistence/recovery
- replay/export/flight deck tests proving parity with live turn results
- host profile tests proving gate lineage is not dropped on downgrade/replay

Required build checks:

- focused `xcodebuild test` for touched suites
- `generic/platform=iOS Simulator` build after each package

## Non-Goals

- implementing external `L4` training curriculum, checkpoint training, or model production pipelines
- pretending `L2` already has a new real model beyond current provider/runtime availability
- broad UI redesign
- full `L6-L13` work in this pass

## Risks

### Risk 1: duplicating existing runtime facts

If the new capability frame duplicates too much of `BASBudgetFrame` or `BASHostProfile`, the chain becomes harder to trust.

Mitigation:

- keep `L1` and `L5` as authoritative types
- only add the missing provider/foundation capability seam

### Risk 2: checkpoint compatibility churn

Changing persisted checkpoint/runtime anchor payloads can destabilize replay matching.

Mitigation:

- additive fields first
- compatibility-preserving defaults
- replay and runtime export regression tests in the same package

### Risk 3: placeholder L2/L4 semantics becoming product lies

If preview/heuristic execution is labeled like a full foundation runtime, the repository becomes misleading.

Mitigation:

- explicit capability tiers
- explicit preview/heuristic/unavailable states
- no marketing copy in the core contract

## Success Criteria

This `L1-L5` pass is complete when:

- live turn execution has a typed `L1-L5` capability spine
- replay/checkpoint/export surfaces preserve the same chain without ad hoc reconstruction
- host gate lineage stays visible across downgrade and recovery paths
- provider/foundation posture is explicit, testable, and never mislabeled as more complete than it is
