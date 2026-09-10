# L13 Candidate Nursery Activation Stage 2 Design

## Summary

This design defines the first repo-real code step from the landed `L13 Stage 1 governance spine` toward the `full-body evolution furnace`.

`Stage 2` activates the missing candidate nurseries in runtime:

- `WorkflowCandidate`
- `GuardTemplateCandidate`
- `BiasRecord`
- `LearningExportBundle`
- `RiskPatternCandidate`

The intent is not to build the full `L13` in one pass. The intent is to make these families real runtime artifacts, feed them from the existing `UpdateTicket / thought / risk / rendered-output` path, and expose their pressure through the existing lineage and operator surfaces.

## Why This Stage Exists

The current repository already ships:

- `UpdateTicket`
- `ExperienceCandidate`
- `ShadowTrialRecord`
- `VersionDelta`
- `RetractionOrder`
- `EvolutionSeal`
- checkpoint lineage
- promotion gate
- governance summary on facts / replay / control surfaces

What is still missing is the actual nursery body for the remaining growth families. Today:

- `WorkflowCandidate`
- `GuardTemplateCandidate`
- `BiasRecord`
- `LearningExportBundle`

exist as schema-level placeholders only, and:

- `RiskPatternCandidate`

does not exist in runtime contracts at all.

Without this stage, `L13` still behaves like a governed spine with one main candidate stream, not like a real multi-family furnace.

## Scope

### In Scope

- add `BASRiskPatternCandidate`
- emit runtime nursery families from the existing turn pipeline
- extend turn results so nursery artifacts travel with the rest of the `L13` governance objects
- extend `BASEvolutionLineageSummary.GovernanceSummary` so nursery counts and pressure are visible without a new UI subsystem
- update existing console / facts / replay / bridge summaries to mention nursery pressure
- add focused schema and host-runtime tests

### Out Of Scope

- full `Shadow Trial Theater`
- full `Version Arboretum`
- full `Retraction Furnace`
- dedicated furnace workbench UI
- automatic candidate promotion
- `L8-L14` full interface fabric
- `WP15` training platform or offline distillation orchestration

## Design Principles

### 1. Keep Stage 1 Honest

This stage is additive. It must not replace the existing `UpdateTicket + experience candidate + seal/gate` chain.

### 2. Candidate Families Must Be Distinct

`Workflow`, `Guard`, `Bias`, `Risk`, and `Export` must not collapse into one generic tag list. Each family needs a concrete runtime object and a family-specific derivation rule.

### 3. No Fake Full-Body Claims

This stage must not rename itself into `Shadow Trial Theater` or `Version Arboretum`. It activates candidate nurseries only.

### 4. Surface Through Existing Operator Paths

The nursery signal should show up through:

- lineage summary
- replay summary
- facts bundle
- console summaries

This avoids a premature parallel UI tree.

## Runtime Contracts

### New Contract

Add:

- `BASRiskPatternCandidate`

Proposed shape:

```swift
public struct BASRiskPatternCandidate: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var patternID: String
    public var sourceRefs: [String]
    public var riskDomain: String
    public var triggerSignals: [String]
    public var severity: Double
    public var recurrenceScore: Double
    public var sovereignReviewRequired: Bool
    public var shadowTrialState: String
}
```

`RiskPatternCandidate` belongs in the fixed `L13` family list because the full-body master spec explicitly includes risk-pattern growth as a distinct nursery.

### Existing Contracts That Become Runtime-Carrying

`BASEBrainTurnResult` should gain arrays for:

- `workflowCandidates`
- `guardTemplateCandidates`
- `biasRecords`
- `riskPatternCandidates`
- `learningExportBundles`

These are parallel to the already-landed:

- `experienceCandidates`
- `shadowTrialRecords`
- `versionDeltas`
- `retractionOrders`
- `evolutionSeals`

## Derivation Rules

The rules should stay heuristic and conservative in Stage 2. The goal is governed activation, not perfect semantics.

### WorkflowCandidate

Emit when a turn shows a stable, low-risk, reusable operating path.

Primary signals:

- low or medium risk
- no conflict flag
- answer or compare mode
- at least one concrete alternative action or reusable recommendation pattern
- no active blocked promotion reasons

Interpretation:

- this turn may have produced a reusable task flow

### GuardTemplateCandidate

Emit when the system used a protective path worth remembering.

Primary signals:

- delay / block / replace mode
- high risk or strong guard posture
- manipulation hints, boundary touches, or substitute actions present

Interpretation:

- this turn may have produced a reusable guard template

### BiasRecord

Emit when the turn carries evidence of repeated drift, over-guarding, conflict, or unstable governance pressure.

Primary signals:

- `conflictFlag == true`
- pending retraction
- pending shadow trial under elevated risk
- high uncertainty / critique-heavy stop reason where action still approached promotion

Interpretation:

- the system should remember that a bias-shaped failure or near-failure occurred

### RiskPatternCandidate

Emit when risk structure itself looks reusable.

Primary signals:

- high risk
- non-empty reason codes or manipulation hints
- sovereign escalation hints
- blocked domains or protected permit membranes

Interpretation:

- this turn may have exposed a reusable risk pattern that future turns should watch for

### LearningExportBundle

Emit only for turns that are safe to export as future learning skeletons.

Primary signals:

- scrubbed candidate refs exist
- no pending shadow-trial requirement
- no pending retraction
- seal is already `sealed`
- sovereign-safe / privacy-safe booleans remain true

Interpretation:

- this turn may be exportable as a governed learning skeleton

## Governance Summary Extension

`BASEvolutionLineageSummary.GovernanceSummary` should be extended with:

- `workflowCandidateCount`
- `guardTemplateCandidateCount`
- `biasRecordCount`
- `riskPatternCandidateCount`
- `learningExportBundleCount`
- `pendingNurseryCandidateCount`

`pendingNurseryCandidateCount` gives surfaces one compact pressure line without inventing a second summary model.

## Surface Strategy

### Console

`EBrainConsoleSupport` should mention nursery pressure alongside host/governance context, for example:

- workflow count
- guard count
- bias count
- risk-pattern count
- export count

### Replay / Facts / Bridge

Existing `L13 governance` text can grow into:

- candidates
- shadow
- seal
- version
- retract
- nursery

without changing the top-level narrative shape.

The important constraint is that the copy remains additive and current-repo honest.

## Testing Strategy

### Schema

- registry coverage includes `RiskPatternCandidate`
- encoding/decoding coverage for `RiskPatternCandidate`

### Runtime

Low-risk reusable turn should produce:

- `ExperienceCandidate`
- `WorkflowCandidate`
- optional `LearningExportBundle`
- no pending shadow trial

High-risk guarded turn should produce:

- `GuardTemplateCandidate`
- `BiasRecord` or `RiskPatternCandidate`
- no unsafe export bundle

Conflict-heavy turn should produce:

- `BiasRecord`
- `RiskPatternCandidate` when risk is elevated
- gate state remains consistent with existing Stage 1 expectations

### Surface

Existing replay / facts text should render nursery counts without breaking current `L13 governance` wording.

## Risks

### Risk 1: Everything Emits Everything

If the heuristics are too loose, every turn will generate every family and the nursery becomes noise.

Mitigation:

- conservative emission thresholds
- explicit tests for non-emission on simple turns

### Risk 2: Export Bundles Become a Hidden Promotion Path

If `LearningExportBundle` is emitted too eagerly, it can act like shadow promotion.

Mitigation:

- only emit export bundles when seal/retraction/trial state is already clean

### Risk 3: Surface Copy Overclaims Full-Body Status

If summaries speak as if nursery activation equals full-body completion, the repository truth degrades.

Mitigation:

- keep wording anchored to `nursery pressure`
- do not rename surfaces into `Shadow Trial Theater` or `Version Arboretum`

## Success Criteria

This stage is successful when:

1. all five missing nursery families exist as real runtime artifacts
2. low-risk and high-risk turns produce clearly different family mixes
3. lineage and replay show nursery pressure without a new UI subsystem
4. Stage 1 gate behavior remains intact
5. the repository can honestly say `L13` has moved from governed spine to partial nursery-bearing runtime, but not yet to full-body
