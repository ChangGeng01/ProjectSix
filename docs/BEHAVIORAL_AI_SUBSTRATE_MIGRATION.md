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

## Façade Vocabulary Migration

`BASHostKit` now treats product semantics as host-owned, not substrate-owned.

Move façade inputs from product language:

- `kind: .quick / .balance / .mirror / .reminder / .watchHandoff`
- `mode: .quick / .balance / .mirror`
- `preferredMode: .quick`

to generic host language:

- `kind: .interactive / .ambient / .reopen / .handoff / .widget / .notification`
- `workflowProfile: .rapid / .deliberate / .reflective`
- `preferredProfile: .rapid`

`Before` should keep its own `quick / balance / mirror` vocabulary in host mappings and translate into the façade at the edge.

The same separation now applies to presentation and truth-state copy:

- substrate-facing identifiers: `primary / comparative / reflective`
- host-facing product labels: keep app-specific labels, button text, preview headings, and branded phrasing inside the host

In practice, hosts should supply:

- mode titles
- workflow presentation titles
- session titles
- preview field labels
- follow-up action phrasing
- branded flow copy
- product-specific reopen wording

while the substrate should own only:

- routing
- memory governance
- policy
- compaction
- structured truth shape
- generic mode identifiers

The same rule now applies to entry and lifecycle plumbing:

- substrate-facing: `capture / present / reopen / resume / routedInput`
- host-facing: keep product-owned terms like `quickCapture`, `openMode`, `reopenTomorrowItem`, and `resumeCurrentDecision` if they still fit the app

Legacy host raw values are still accepted by bridge builders during migration, but new substrate-facing code should prefer the generic vocabulary.

## Host Presentation Migration

When a host needs product-specific language, inject it through `BASHostConfiguration.presentation` instead of editing substrate defaults.

Typical host-owned presentation concerns:

- workflow names shown to users
- fallback session titles
- lifecycle titles such as initial bootstrap or scene refresh
- lifecycle notices shown in console or debug surfaces
- host-flavored follow-up actions
- predictive intervention titles, details, and fallback reasons
- reopen wording and host-specific slowdown copy
- empty-prompt fallback goal copy

Example pattern:

```swift
let runtime = BASHostRuntime(
    configuration: BASHostConfiguration(
        presentation: hostOwnedPresentation
    )
)
```

This keeps the SDK façade generic while allowing each host to keep its own product DNA.

## Host Workflow Behavior Migration

Hosts should now also inject workflow behavior through `BASHostConfiguration.workflowBehavior`.

Typical host-owned workflow behavior concerns:

- workflow template IDs
- workflow-specific retrieval defaults
- workflow-to-memory-source mapping
- verification snapshot namespace
- projection provenance namespace

Example pattern:

```swift
let runtime = BASHostRuntime(
    configuration: BASHostConfiguration(
        workflowBehavior: hostOwnedWorkflowBehavior,
        presentation: hostOwnedPresentation
    )
)
```

This keeps substrate execution generic while moving workflow strategy DNA back into the host.

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
