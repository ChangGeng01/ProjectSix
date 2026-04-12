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
- `workflowProfile: .primary / .comparative / .reflective`
- `preferredProfile: .primary`

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

Host-facing code should now use a host-owned compatibility layer to map product identifiers into generic substrate identifiers. Product language belongs in host presentation and mapping layers, not in substrate-facing raw values.

`Before` now owns that translation explicitly:

- [`BeforeProductCompatibility`](/Users/changgeng/Project/Project06/Project06/Before/Shared/Domain/BeforeProductCompatibility.swift)
- [`BeforeLegacyMigration`](/Users/changgeng/Project/Project06/Project06/Before/Shared/Domain/BeforeLegacyMigration.swift)

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

## Residual Enforcement

Substrate residual enforcement is now split across two gates:

- `./scripts/check_substrate_residuals.sh`
- `./scripts/check_sdk_import_boundaries.sh`

The residual scan now covers:

- `BehavioralAISubstrate/Sources`
- `BehavioralAISubstrate/README.md`
- non-whitelisted package tests

Legacy `Before` vocabulary is only allowed inside explicit rejection coverage that proves the substrate rejects host-era identifiers. Generic package fixtures, prompt tests, runtime tests, and public-facing README copy should stay on substrate vocabulary.

## Reference Prompt Vocabulary Migration

Reference prompt slot vocabulary is now host-owned.

Substrate defaults now prefer neutral prompt schema keys and labels such as:

- state keys:
  - `entry_context`
  - `current_drive`
  - `anticipated_shift`
  - `pull`
  - `counterforce`
  - `durable_priority`
- evidence labels:
  - `Present view`
  - `Later view`
  - `Current verdict`
  - `Priority label`
  - `Recurring tension`

If a host previously depended on substrate defaults for branded prompt keys or evidence labels, move them into a host-owned `BASReferencePromptBehavior.slotVocabularyByKindID` override.

Typical host-owned vocabulary concerns:

- prompt field keys like `scenario`, `motivation`, `want`, `concern`, `self_lens`
- evidence labels like `Current perspective`, `After perspective`, `Focus title`, `Core tension`, `Next action`
- reminder prompt field names like `current_prompt`

Example pattern:

```swift
let behavior = BASReferencePromptBehavior(
    slotVocabularyByKindID: [
        BASSemanticTaskKind.primaryID: BASReferencePromptSlotVocabulary(
            stateKeysBySlotID: [
                "scenario": "scenario"
            ],
            evidenceLabelsBySlotID: [
                "current_perspective": "Current perspective"
            ]
        )
    ]
)
```

This keeps substrate prompt compilation generic while letting each host keep its own vocabulary, copy, and product worldview.

Hosts should apply the same rule to:

- execution-profile thresholds and explanation copy
- memory-derivation copy, IDs, and provenance language
- predictive-intervention copy and reasons
- bootstrap risk heuristics and alias policy

Those belong in host compatibility layers such as [`BeforeProductCompatibility`](/Users/changgeng/Project/Project06/Project06/Before/Shared/Domain/BeforeProductCompatibility.swift), not inside substrate defaults.

## Reference Prompt Request Surface Migration

Reference prompt request and builder APIs now prefer substrate-generic names.

Preferred substrate-facing types:

- `BASPrimaryRefinementPromptRequest`
- `BASComparativeRefinementPromptRequest`
- `BASReflectiveRefinementPromptRequest`
- `BASSelectionPromptRequest`

Preferred substrate-facing builders:

- `primaryEnvelope(...)`
- `comparativeEnvelope(...)`
- `reflectiveEnvelope(...)`
- `selectionEnvelope(...)`

Legacy request types and helpers are no longer part of the substrate contract. If a host still carries legacy vocabulary, migrate it at the host edge and keep branded wording in host-owned slot vocabulary plus presentation behavior.

In `Before`, that migration now belongs in:

- [`BeforeProductCompatibility`](/Users/changgeng/Project/Project06/Project06/Before/Shared/Domain/BeforeProductCompatibility.swift)
- [`BeforeLegacyMigration`](/Users/changgeng/Project/Project06/Project06/Before/Shared/Domain/BeforeLegacyMigration.swift)

## Reference Hosts

- [`Before`](/Users/changgeng/Project/Project06/Project06/Before) remains the full reference host.
- [`SampleHost`](/Users/changgeng/Project/Project06/Project06/SampleHost) is the minimal façade integration host.

## Breaking Change Policy

- This private SDK intentionally evolves quickly.
- Breaking changes are allowed.
- Substrate compatibility shims for `Before` vocabulary are intentionally removed instead of preserved.
- Every breaking change must update:
  - this migration note
  - [`BEHAVIORAL_AI_SUBSTRATE_CHANGELOG.md`](/Users/changgeng/Project/Project06/Project06/docs/BEHAVIORAL_AI_SUBSTRATE_CHANGELOG.md)
  - the affected host sample or façade tests
