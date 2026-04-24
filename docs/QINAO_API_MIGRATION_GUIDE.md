# Qinao SDK API Migration Guide

This document captures the breaking changes and preferred
migration paths introduced across the M121-M155 evolution of
`QinaoRuntime.sendSession`. Hosts reading this should treat it
as the canonical migration reference — every break is documented
here before it lands.

---

## M152 — `TurnInputs` value type (RECOMMENDED)

**Status**: available, optional (legacy 22-param overload still
works).

**Context**: `sendSession` grew to 22 positional parameters
across M121-M147 as one-per-layer gates and sovereign refs
accumulated. The 22-param signature works but is read-unfriendly.

### Before (legacy 22-param)

```swift
try await runtime.sendSession(
    obs,
    coordinatorSeverity: .pass,
    coverageBudgetCeiling: 1.0,
    expectedCoverageLayerIDs: ["L14"],
    plannedBudget: nil,
    turnDurationSeconds: nil,
    additionalCoverageSummaries: nil,
    surfaceRetryPolicy: .default,
    contextFrame: nil,
    decomposeFrame: nil,
    memoryBundle: myMemoryBundle,
    thoughtFrame: myThoughtFrame,
    updateTickets: [],
    neuralOrganMap: nil,
    renderedOutput: nil,
    candidateFrontier: nil,
    jurisdictionMap: nil,
    contaminationLineages: [],
    timeLockRef: nil,
    pendingActionDigest: nil,
    pendingMutationDigest: nil,
    pendingMemoryDigest: nil)
```

### After (TurnInputs, property-set)

```swift
var inputs = QinaoRuntime.TurnInputs(
    observations: obs,
    coordinatorSeverity: .pass)
inputs.memoryBundle = myMemoryBundle
inputs.thoughtFrame = myThoughtFrame
try await runtime.sendSession(inputs)
```

### After (TurnInputs, fluent single-expression)

```swift
try await runtime.sendSession(
    .init(observations: obs, coordinatorSeverity: .pass)
        .with {
            $0.memoryBundle = myMemoryBundle
            $0.thoughtFrame = myThoughtFrame
        })
```

### Field map

| Legacy positional arg           | `TurnInputs` field                |
|---------------------------------|-----------------------------------|
| `observations`                  | `observations` (required)         |
| `coordinatorSeverity`           | `coordinatorSeverity` (required)  |
| `coverageBudgetCeiling`         | `coverageBudgetCeiling` (= 1.0)   |
| `expectedCoverageLayerIDs`      | `expectedCoverageLayerIDs` (= ["L14"]) |
| `plannedBudget`                 | `plannedBudget` (= nil)           |
| `turnDurationSeconds`           | `turnDurationSeconds` (= nil)     |
| `additionalCoverageSummaries`   | `additionalCoverageSummaries` (= nil) |
| `surfaceRetryPolicy`            | `surfaceRetryPolicy` (= .default) |
| `contextFrame`                  | `contextFrame` (= nil)            |
| `decomposeFrame`                | `decomposeFrame` (= nil)          |
| `memoryBundle`                  | `memoryBundle` (= nil)            |
| `thoughtFrame`                  | `thoughtFrame` (= nil)            |
| `updateTickets`                 | `updateTickets` (= [])            |
| `neuralOrganMap`                | `neuralOrganMap` (= nil)          |
| `renderedOutput`                | `renderedOutput` (= nil)          |
| `candidateFrontier`             | `candidateFrontier` (= nil)       |
| `jurisdictionMap`               | `jurisdictionMap` (= nil)         |
| `contaminationLineages`         | `contaminationLineages` (= [])    |
| `timeLockRef`                   | `timeLockRef` (= nil)             |
| `pendingActionDigest`           | `pendingActionDigest` (= nil)     |
| `pendingMutationDigest`         | `pendingMutationDigest` (= nil)   |
| `pendingMemoryDigest`           | `pendingMemoryDigest` (= nil)     |

### Equivalence guarantee

The M153 `QinaoRuntimeM153LegacyParityTests` suite proves both
overloads produce byte-identical outcomes on the same semantic
input — audit severity / parity / coverage / surface decision /
all 13 sovereign frame refs / all 12 render frame refs / residue
completeness all match. Migration is a behavior-preserving
refactor.

### Deprecation timeline

- **Now (post-M157)**: both overloads live. `TurnInputs`
  overload is the RECOMMENDED path documented in doc comments +
  this guide. Legacy signature is a thin delegator that builds
  a TurnInputs and calls the new overload.
- **Future (no explicit target)**: when no production call site
  uses the legacy signature, it will be marked
  `@available(*, deprecated, ...)`. After one more release
  cycle it will be removed.
- Hosts that see no immediate need to migrate: no rush. The
  legacy signature is not planned for removal in any near-term
  release.

---

## M145 — `TurnOutcome.surfaceDecision` non-optional (BREAKING)

**Status**: landed M145. Source-level break for direct
construction of `TurnOutcome`.

### Before

```swift
let outcome = TurnOutcome(
    audit: ...,
    coverage: ...,
    sessionHalted: false)
// outcome.surfaceDecision: BASSurfaceDecision? (might be nil)
if let d = outcome.surfaceDecision { /* use d */ }
```

### After

```swift
let decision = QinaoRuntime.deriveSurfaceDecision(
    auditSeverity: .pass,
    coverageSeverity: .clean,
    auditRef: "audit.id")
let outcome = TurnOutcome(
    audit: ...,
    coverage: ...,
    sessionHalted: false,
    surfaceDecision: decision)   // ← required
// outcome.surfaceDecision: BASSurfaceDecision (never nil)
```

### Why

Every production return path in sendSession already populated
surfaceDecision deterministically (pinned M125/M126/M131). The
option wrapper was dead weight — callers had to unwrap a value
that can never be nil in production. M145 tightens the type.

### Migration

- `if let d = outcome.surfaceDecision { ... }` → use
  `outcome.surfaceDecision` directly (optional binding is now a
  no-op; the compiler will warn that `let` is unnecessary).
- `try XCTUnwrap(outcome.surfaceDecision)` → same, no-op on a
  non-optional; tests continue to compile unchanged.
- `TurnOutcome(audit:..., coverage:..., sessionHalted:...)`
  without surfaceDecision → **compile error**. Provide a value
  via `QinaoRuntime.deriveSurfaceDecision(...)` or take one off
  an existing outcome.

---

## M125 → M144 → M147 — `sovereignFrame` + `renderFrame` ref
  population (additive)

**Status**: all optional refs now have population paths via
`sendSession` parameters. No existing call site breaks; new
fields just stop being nil when the relevant source is passed.

Adding a `contextFrame: ctx` argument post-M134 does not change
any existing output — it adds an L6 observation summary to the
bundle + triggers the M144 `situationRef` synthesis on the
render frame when the decompose frame is ALSO passed. Identical
backward-compat.

---

## M152 → M154 — Phase-3 auto-inject pipeline (internal)

**Status**: internal refactor. No behavior change, no API
change. Documented here only so future readers understand the
`AutoInjectPipeline` private struct that appears in the source.

Pre-M154 Phase 3 had 14 per-layer blocks each doing 4 lines of
append-and-track boilerplate. Post-M154 each block does one
`pipeline.inject(_:_:)` call. Same observable behavior;
~30 lines of ceremony removed.

---

## Testing utilities — `QinaoTestFixture` (M155)

**Status**: available for any test file in
`QinaoRuntimeSDK/Tests/QinaoRuntimeSDKTests/Shared/`.

### Before (per-file)

Each test file defined its own `makeRuntime()`:

```swift
actor ToolRecorder { ... }
struct Fixture: Sendable { runtime; sovereign; ... }
private func makeRuntime(...) async -> Fixture {
    // ~50 lines of substrate wiring
}
```

### After (shared)

```swift
let fx = await QinaoTestFixture.make()
// or customized:
let fx = await QinaoTestFixture.make(
    hostID: "host.my-test",
    activeVersion: "host.v2",
    withLifecycle: true)
```

M155 bulk-migrated 14 existing test files to the shared factory,
deleting ~1000 lines of duplicated boilerplate. New test files
should always use `QinaoTestFixture.make(...)`.
