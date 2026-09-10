# L13 Candidate Nursery Activation Stage 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Activate the missing `L13` candidate nurseries in runtime by making `Workflow / Guard / Bias / Export / RiskPattern` real governed artifacts that flow through turn results, lineage summaries, and current operator surfaces.

**Architecture:** Keep the landed `Stage 1 governance spine` intact and add a conservative nursery derivation layer on top of the existing runtime path in `EBrainRuntimeCoordinator`. Nursery families remain additive to the current `UpdateTicket / ExperienceCandidate / Seal / Gate` chain, and their pressure is surfaced through the existing lineage, replay, bridge, and facts summaries instead of through a new UI system.

**Tech Stack:** Swift, Swift Testing, XCTest, BehavioralAISubstrate package modules, Before app bridge/summaries.

---

### Task 1: Add Stage 2 contract coverage and failing tests

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaCoreTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASEBrainSchemaGovernanceRegistryTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASHostKitTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BeforeTests/DeveloperDecisionReplayBuilderTests.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BeforeTests/BehavioralAISubstrateBridgeTests.swift`

- [ ] **Step 1: Add schema-level failing tests for `RiskPatternCandidate` and nursery summary counts**

Add assertions for:

```swift
#expect(governedObjects.contains("RiskPatternCandidate"))
#expect(actualVersions["RiskPatternCandidate"] == BASRiskPatternCandidate.currentSchemaVersion)
#expect(
    BASEBrainSchemaGovernanceRegistry.entry(for: "RiskPatternCandidate")?.migrationTestIDs
    == ["schema.risk_pattern_candidate.current", "schema.risk_pattern_candidate.backward"]
)
```

and a schema round-trip test like:

```swift
let riskPattern = BASRiskPatternCandidate(
    patternID: "risk.pattern.high_pressure",
    sourceRefs: ["turn.1"],
    riskDomain: "high_pressure",
    triggerSignals: ["manipulation", "delay"],
    severity: 0.81,
    recurrenceScore: 0.52,
    sovereignReviewRequired: true,
    shadowTrialState: "pending"
)
```

- [ ] **Step 2: Add runtime/surface failing tests for nursery activation**

Add assertions in `BASHostKitTests` that:

```swift
XCTAssertFalse(turn.workflowCandidates.isEmpty)
XCTAssertFalse(turn.learningExportBundles.isEmpty)
XCTAssertEqual(turn.evolutionLineageSummary.governanceSummary?.workflowCandidateCount, 1)
```

for a low-risk reusable turn, and:

```swift
XCTAssertFalse(turn.guardTemplateCandidates.isEmpty)
XCTAssertFalse(turn.riskPatternCandidates.isEmpty)
XCTAssertFalse(turn.biasRecords.isEmpty)
XCTAssertTrue(turn.learningExportBundles.isEmpty)
```

for a guarded high-risk turn.

- [ ] **Step 3: Add replay/bridge failing expectations for nursery pressure text**

Change expected summary lines to include nursery details, for example:

```swift
"L13 governance • candidates 1 • shadow 1 pending/1 • seal 1 pending/1 • version 1 • retract 1 pending/1 • nursery workflow 1 • guard 1 • bias 1 • risk 1 • export 0 • gate hold"
```

- [ ] **Step 4: Run the targeted tests to verify they fail for the right reason**

Run:

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter 'BASEBrainSchemaCoreTests|BASEBrainSchemaGovernanceRegistryTests|BASHostKitTests'
```

and:

```bash
xcodebuild -project /Users/changgeng/Project/Project06/Project06/Before.xcodeproj -scheme Before -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.3.1' -only-testing:BeforeTests/BehavioralAISubstrateBridgeTests -only-testing:BeforeTests/DeveloperDecisionReplayBuilderTests CODE_SIGNING_ALLOWED=NO test
```

Expected: failures referencing missing `RiskPatternCandidate`, missing nursery arrays/counts, and outdated governance-line expectations.

### Task 2: Implement nursery contracts and lineage carrying

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/EBrainEvolutionGovernanceCore.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASAdmin/EBrainSchemaGovernanceRegistry.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASMemory/MemoryCore.swift`

- [ ] **Step 1: Add `BASRiskPatternCandidate`**

Implement:

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

- [ ] **Step 2: Register `RiskPatternCandidate` in schema governance**

Add the registry entry with migration test IDs:

```swift
["schema.risk_pattern_candidate.current", "schema.risk_pattern_candidate.backward"]
```

- [ ] **Step 3: Extend `BASEBrainTurnResult` to carry nursery artifacts**

Add arrays for:

```swift
public var workflowCandidates: [BASWorkflowCandidate]
public var guardTemplateCandidates: [BASGuardTemplateCandidate]
public var biasRecords: [BASBiasRecord]
public var riskPatternCandidates: [BASRiskPatternCandidate]
public var learningExportBundles: [BASLearningExportBundle]
```

and wire them through init/coding keys/decode/encode with empty defaults for backward compatibility.

- [ ] **Step 4: Extend `BASEvolutionLineageSummary.GovernanceSummary`**

Add:

```swift
public let workflowCandidateCount: Int
public let guardTemplateCandidateCount: Int
public let biasRecordCount: Int
public let riskPatternCandidateCount: Int
public let learningExportBundleCount: Int
public let pendingNurseryCandidateCount: Int
```

with defaulted init parameters so old call sites keep decoding cleanly.

### Task 3: Emit nursery artifacts from the runtime path

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator.swift`

- [ ] **Step 1: Extend the private governance artifact bundle**

Add:

```swift
let workflowCandidates: [BASWorkflowCandidate]
let guardTemplateCandidates: [BASGuardTemplateCandidate]
let biasRecords: [BASBiasRecord]
let riskPatternCandidates: [BASRiskPatternCandidate]
let learningExportBundles: [BASLearningExportBundle]
```

- [ ] **Step 2: Emit conservative nursery families inside `buildEvolutionGovernanceArtifacts(...)`**

Use heuristics aligned with the approved Stage 2 spec:

```swift
let isLowRiskReusable = riskCard.riskLevel.rawValue == BASBrainRiskLevel.low.rawValue || riskCard.riskLevel == .medium
let isProtectiveMode = output.mode == .delay || output.mode == .block || output.mode == .replace
let hasConflictPressure = ticket.conflictFlag || needsTrial
let hasRiskPatternPressure = riskCard.riskLevel >= .high || output.explanationCodes.isEmpty == false
```

Emit:

- `WorkflowCandidate` for low-risk reusable turns
- `GuardTemplateCandidate` for protective turns
- `BiasRecord` for conflict/pending-governance turns
- `RiskPatternCandidate` for elevated-risk structured patterns
- `LearningExportBundle` only when no pending trial/seal/retraction remains and all safety booleans are true

- [ ] **Step 3: Include nursery counts in lineage summary synthesis**

Populate:

```swift
workflowCandidateCount: workflowCandidates.count,
guardTemplateCandidateCount: guardTemplateCandidates.count,
biasRecordCount: biasRecords.count,
riskPatternCandidateCount: riskPatternCandidates.count,
learningExportBundleCount: learningExportBundles.count,
pendingNurseryCandidateCount: ...
```

- [ ] **Step 4: Pass nursery arrays into the final turn result**

Wire the new arrays into the returned `BASEBrainTurnResult`.

### Task 4: Surface nursery pressure through existing operator paths

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate/Sources/BASHostKit/EBrainConsoleSupport.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/Before/App/Services/DeveloperDecisionReplayBuilder.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionEvolutionEBrainFactsBundle.swift`

- [ ] **Step 1: Extend governance summary strings**

Keep the current `L13 governance` prefix, but append nursery counts when present:

```swift
"nursery workflow \(workflowCount)"
"guard \(guardCount)"
"bias \(biasCount)"
"risk \(riskPatternCount)"
"export \(exportCount)"
```

- [ ] **Step 2: Use the lineage summary as the shared source when available**

Favor the expanded `GovernanceSummary` fields in replay/facts builders so live and replayed turns share the same wording.

- [ ] **Step 3: Keep wording current-repo honest**

Do not rename any string to:

- `Shadow Trial Theater`
- `Version Arboretum`
- `Retraction Furnace`

This stage surfaces nursery pressure only.

### Task 5: Verify green and summarize residual gaps

**Files:**
- No new product files

- [ ] **Step 1: Run focused BehavioralAISubstrate tests**

```bash
swift test --package-path /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate --filter 'BASEBrainSchemaCoreTests|BASEBrainSchemaGovernanceRegistryTests|BASHostKitTests'
```

Expected: PASS

- [ ] **Step 2: Run focused Before app bridge/replay tests**

```bash
xcodebuild -project /Users/changgeng/Project/Project06/Project06/Before.xcodeproj -scheme Before -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.3.1' -only-testing:BeforeTests/BehavioralAISubstrateBridgeTests -only-testing:BeforeTests/DeveloperDecisionReplayBuilderTests CODE_SIGNING_ALLOWED=NO test
```

Expected: PASS

- [ ] **Step 3: Summarize what landed and what still belongs to later full-body phases**

Confirm in the final handoff that this stage delivered:

- candidate nursery activation
- lineage/surface nursery pressure
- conservative governed export gating

and that the following remain for later phases:

- full `Shadow Trial Theater`
- full `Version Arboretum`
- full `Retraction Furnace`
- cross-layer `L8-L14 evolution interface fabric`
- future furnace workbench
