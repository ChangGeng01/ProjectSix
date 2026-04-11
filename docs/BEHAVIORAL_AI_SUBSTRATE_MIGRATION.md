# BehavioralAISubstrate Migration Notes

## Host Import Migration

Move host code from low-level BAS imports:

- `BASRuntimeCore`
- `BASMemory`
- `BASPolicy`
- `BASOrchestration`
- `BASObservability`
- `BASEvaluation`
- `BASAppleAdapters`
- `BASAdmin`

to:

```swift
import BASHostKit
```

## Host Dependency Migration

Preferred target dependency shape:

- app host: `BASHostKit`
- watch host: `BASHostKit`
- widget host: `BASHostKit`
- debug/admin UI: use `BASHostKit` re-exported admin types unless a deliberate low-level dependency is required for tests

## Runtime Migration

New façade entry points:

- `BASHostRuntime.bootstrap(_:)`
- `BASHostRuntime.handleEntryIntent(_:)`
- `BASHostRuntime.startSession(_:)`
- `BASHostRuntime.reopen(_:)`
- `BASHostRuntime.refreshCurrentBrain(for:)`
- `BASHostRuntime.schedulePredictiveIntervention(for:)`

These should replace host-owned orchestration when building new surfaces.

## Reference Hosts

- [`Before`](/Users/changgeng/Project/Project06/Project06/Before) remains the full reference host.
- [`SampleHost`](/Users/changgeng/Project/Project06/Project06/SampleHost) is the minimal façade integration host.

## Breaking Change Policy

- This private SDK intentionally evolves quickly.
- Breaking changes are allowed.
- Every breaking change must update:
  - this migration note
  - [`BEHAVIORAL_AI_SUBSTRATE_CHANGELOG.md`](/Users/changgeng/Project/Project06/Project06/docs/BEHAVIORAL_AI_SUBSTRATE_CHANGELOG.md)
  - the affected host sample or façade tests
