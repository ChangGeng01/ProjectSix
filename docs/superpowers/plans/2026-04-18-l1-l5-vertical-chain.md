# L1-L5 Vertical Chain Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `L1-L5` behave as one explicit runtime-to-replay chain by introducing a typed execution capability frame and threading it through runtime export, checkpoint/replay, flight deck, and host-facing inspection.

**Architecture:** Add a shared `L1-L5` capability contract that carries the missing seam between `BASBudgetFrame` and `BASHostProfile`: provider execution posture, foundation capability tier, and downgrade reasons. Integrate it first into live runtime/export, then persist it across session/checkpoint/replay, then harden host lineage parity and final surface consumption.

**Tech Stack:** Swift, SwiftUI app services, BehavioralAISubstrate package types, `xcodebuild` simulator tests.

---

### Task 1: Package A - Live Capability Spine

**Files:**
- Create: `/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionEBrainExecutionCapabilityFrame.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionTestingRuntimeExport.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionSystemFlightDeck.swift`
- Test: `/Users/changgeng/Project/Project06/Project06/BeforeTests/DecisionTestingInterfaceTests.swift`
- Test: `/Users/changgeng/Project/Project06/Project06/BeforeTests/DeveloperDecisionReplayBuilderTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
func testRuntimeExportBuildsExecutionCapabilityFrameForFoundationProvider() async {
    let export = await DecisionTestingInterface.runtimeExport(
        quick: [],
        balance: [],
        mirror: [],
        preferences: DecisionTestingInterface.configuredPreferences(
            preferredProvider: .foundationModels
        ),
        traceLimit: 0,
        replayLimit: 0
    )

    XCTAssertEqual(export.executionCapabilityFrame?.activeProviderID, "foundationModels")
    XCTAssertEqual(export.executionCapabilityFrame?.foundationTierID, "system_managed")
}

func testFlightDeckSummaryCarriesExecutionCapabilityLine() {
    let summary = makeProtectiveTurn().systemFlightDeckSummary

    XCTAssertEqual(summary.executionTierID, "live_runtime")
    XCTAssertEqual(summary.foundationTierID, "turn_native")
}
```

- [ ] **Step 2: Run the focused tests to verify they fail**

Run:

```bash
xcodebuild -project /Users/changgeng/Project/Project06/Project06/Before.xcodeproj \
  -scheme Before \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4' \
  -derivedDataPath /tmp/before-l1l5-package-a-r0 \
  CODE_SIGNING_ALLOWED=NO \
  test \
  -only-testing:BeforeTests/DecisionTestingInterfaceTests \
  -only-testing:BeforeTests/DeveloperDecisionReplayBuilderTests
```

Expected: compile or assertion failures because `executionCapabilityFrame`, `executionTierID`, or `foundationTierID` do not exist yet.

- [ ] **Step 3: Add the typed capability frame and wire live export**

```swift
struct DecisionEBrainExecutionCapabilityFrame: Equatable, Sendable {
    let activeProviderID: String
    let preferredProviderID: String
    let fallbackProviderID: String?
    let providerTrackID: String
    let executionTierID: String
    let foundationTierID: String
    let reasonCodes: [String]
}
```

Add a builder in `DecisionTestingRuntimeExport` that derives this from:

- `runtimeSnapshot.runtimeStatus`
- `registeredProviders`
- `runtimeSnapshot.foundationStatus`
- `runtimeSnapshot.openModelRuntimeStatus`
- `runtimeSnapshot.gemmaRuntimeStatus`

Then expose it on:

- `DecisionTestingRuntimeExport.executionCapabilityFrame`
- `DecisionSystemEBrainSummary`
- `BASEBrainTurnResult.systemFlightDeckSummary`

- [ ] **Step 4: Run the focused tests to verify they pass**

Run the same `xcodebuild test` command from Step 2.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add \
  /Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionEBrainExecutionCapabilityFrame.swift \
  /Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionTestingRuntimeExport.swift \
  /Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionSystemFlightDeck.swift \
  /Users/changgeng/Project/Project06/Project06/BeforeTests/DecisionTestingInterfaceTests.swift \
  /Users/changgeng/Project/Project06/Project06/BeforeTests/DeveloperDecisionReplayBuilderTests.swift
git commit -m "feat: add live l1-l5 execution capability frame"
```

### Task 2: Package B - Session / Checkpoint / Replay Persistence

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionSessionEngine.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionTestingRuntimeExport.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/Before/App/Services/DeveloperDecisionReplayBuilder.swift`
- Test: `/Users/changgeng/Project/Project06/Project06/BeforeTests/DecisionSessionEngineTests.swift`
- Test: `/Users/changgeng/Project/Project06/Project06/BeforeTests/DecisionTestingRuntimeExportCompatibility.swift`
- Test: `/Users/changgeng/Project/Project06/Project06/BeforeTests/DeveloperDecisionReplayBuilderTests.swift`

- [ ] **Step 1: Write the failing persistence tests**

```swift
func testCheckpointAnchorPreservesExecutionCapabilityFrame() async throws {
    let context = try await makeSessionEngineEvaluationContext()
    let checkpoint = try await persistCheckpoint(from: context)

    XCTAssertEqual(checkpoint.eBrain.executionCapability?.activeProviderID, "foundationModels")
    XCTAssertEqual(checkpoint.eBrain.executionCapability?.foundationTierID, "system_managed")
}
```

- [ ] **Step 2: Run the focused tests to verify they fail**

Run:

```bash
xcodebuild -project /Users/changgeng/Project/Project06/Project06/Before.xcodeproj \
  -scheme Before \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4' \
  -derivedDataPath /tmp/before-l1l5-package-b-r0 \
  CODE_SIGNING_ALLOWED=NO \
  test \
  -only-testing:BeforeTests/DecisionSessionEngineTests \
  -only-testing:BeforeTests/DecisionTestingRuntimeExportCompatibility \
  -only-testing:BeforeTests/DeveloperDecisionReplayBuilderTests
```

Expected: FAIL because checkpoint/replay payloads do not yet carry the frame.

- [ ] **Step 3: Add capability-frame persistence to checkpoint and replay seams**

```swift
struct DecisionSessionCheckpointExecutionCapability: Codable, Equatable, Sendable {
    let activeProviderID: String
    let preferredProviderID: String
    let fallbackProviderID: String?
    let providerTrackID: String
    let executionTierID: String
    let foundationTierID: String
    let reasonCodes: [String]
}
```

Persist it additively in checkpoint anchor payloads and replay builder summaries, then teach runtime export compatibility adapters to preserve it when reconstructing summaries.

- [ ] **Step 4: Run the focused tests to verify they pass**

Run the same `xcodebuild test` command from Step 2.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add \
  /Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionSessionEngine.swift \
  /Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionTestingRuntimeExport.swift \
  /Users/changgeng/Project/Project06/Project06/Before/App/Services/DeveloperDecisionReplayBuilder.swift \
  /Users/changgeng/Project/Project06/Project06/BeforeTests/DecisionSessionEngineTests.swift \
  /Users/changgeng/Project/Project06/Project06/BeforeTests/DecisionTestingRuntimeExportCompatibility.swift \
  /Users/changgeng/Project/Project06/Project06/BeforeTests/DeveloperDecisionReplayBuilderTests.swift
git commit -m "feat: persist l1-l5 capability frame through checkpoints"
```

### Task 3: Package C - Host Profile and Host Gate Parity

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionTestingRuntimeExport.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionEvolutionEBrainFactsBundle.swift`
- Test: `/Users/changgeng/Project/Project06/Project06/BeforeTests/DecisionTestingInterfaceTests.swift`
- Test: `/Users/changgeng/Project/Project06/Project06/BeforeTests/DecisionEvolutionEngineTests.swift`

- [ ] **Step 1: Write the failing host-lineage parity tests**

```swift
func testExecutionCapabilityFrameRetainsHostGateParityAcrossReplay() async {
    let export = await makeRuntimeExportWithReplayCheckpoint()

    XCTAssertEqual(export.effectiveEBrainFactsBundle?.executionCapabilityLine, "Foundation system_managed • Track builtInSystem")
    XCTAssertEqual(export.flightDeck.eBrainSummary?.hostGatePercent, 37)
}
```

- [ ] **Step 2: Run the focused tests to verify they fail**

Run:

```bash
xcodebuild -project /Users/changgeng/Project/Project06/Project06/Before.xcodeproj \
  -scheme Before \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4' \
  -derivedDataPath /tmp/before-l1l5-package-c-r0 \
  CODE_SIGNING_ALLOWED=NO \
  test \
  -only-testing:BeforeTests/DecisionTestingInterfaceTests \
  -only-testing:BeforeTests/DecisionEvolutionEngineTests
```

Expected: FAIL because replay/evolution facts do not yet expose the unified capability line.

- [ ] **Step 3: Wire host and capability parity into shared runtime facts**

```swift
extension DecisionEvolutionEBrainFactsBundle {
    var executionCapabilityLine: String? {
        guard let frame = executionCapabilityFrame else { return nil }
        return "Foundation \(frame.foundationTierID) • Track \(frame.providerTrackID)"
    }
}
```

Ensure the same frame powers:

- runtime facts bundle
- replay diagnostics
- evolution summary/facts surfaces

- [ ] **Step 4: Run the focused tests to verify they pass**

Run the same `xcodebuild test` command from Step 2.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add \
  /Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionTestingRuntimeExport.swift \
  /Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionEvolutionEBrainFactsBundle.swift \
  /Users/changgeng/Project/Project06/Project06/BeforeTests/DecisionTestingInterfaceTests.swift \
  /Users/changgeng/Project/Project06/Project06/BeforeTests/DecisionEvolutionEngineTests.swift
git commit -m "feat: keep l1-l5 host parity in runtime facts"
```

### Task 4: Package D - Final Surface Parity and Build Gate

**Files:**
- Modify: `/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionSystemFlightDeck.swift`
- Modify: `/Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionCapabilityCoverageBuilder.swift`
- Test: `/Users/changgeng/Project/Project06/Project06/BeforeTests/DecisionCapabilityCoverageBuilderTests.swift`
- Test: `/Users/changgeng/Project/Project06/Project06/BeforeTests/DecisionTestingInterfaceTests.swift`

- [ ] **Step 1: Write the failing parity tests**

```swift
func testCapabilityCoverageMatchesRuntimeExecutionCapabilityFrame() async {
    let export = await makeRuntimeExport()
    let coverage = DecisionCapabilityCoverageBuilder.build(from: export)

    XCTAssertEqual(coverage.executionTierID, export.executionCapabilityFrame?.executionTierID)
    XCTAssertEqual(coverage.foundationTierID, export.executionCapabilityFrame?.foundationTierID)
}
```

- [ ] **Step 2: Run the focused tests to verify they fail**

Run:

```bash
xcodebuild -project /Users/changgeng/Project/Project06/Project06/Before.xcodeproj \
  -scheme Before \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4' \
  -derivedDataPath /tmp/before-l1l5-package-d-r0 \
  CODE_SIGNING_ALLOWED=NO \
  test \
  -only-testing:BeforeTests/DecisionCapabilityCoverageBuilderTests \
  -only-testing:BeforeTests/DecisionTestingInterfaceTests
```

Expected: FAIL because coverage and flight-deck surfaces do not yet consume the same frame.

- [ ] **Step 3: Finish surface parity and run the build gate**

```swift
struct DecisionCapabilityCoverage {
    let executionTierID: String?
    let foundationTierID: String?
}
```

Consume the shared capability frame from:

- `DecisionSystemFlightDeck`
- `DecisionCapabilityCoverageBuilder`
- any remaining summary surfaces touched by the new frame

- [ ] **Step 4: Run tests and the simulator build**

Run:

```bash
xcodebuild -project /Users/changgeng/Project/Project06/Project06/Before.xcodeproj \
  -scheme Before \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4' \
  -derivedDataPath /tmp/before-l1l5-package-d-r1 \
  CODE_SIGNING_ALLOWED=NO \
  test \
  -only-testing:BeforeTests/DecisionCapabilityCoverageBuilderTests \
  -only-testing:BeforeTests/DecisionTestingInterfaceTests

xcodebuild -project /Users/changgeng/Project/Project06/Project06/Before.xcodeproj \
  -scheme Before \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  build
```

Expected: both commands succeed.

- [ ] **Step 5: Commit**

```bash
git add \
  /Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionSystemFlightDeck.swift \
  /Users/changgeng/Project/Project06/Project06/Before/App/Services/DecisionCapabilityCoverageBuilder.swift \
  /Users/changgeng/Project/Project06/Project06/BeforeTests/DecisionCapabilityCoverageBuilderTests.swift \
  /Users/changgeng/Project/Project06/Project06/BeforeTests/DecisionTestingInterfaceTests.swift
git commit -m "feat: finish l1-l5 surface parity"
```

