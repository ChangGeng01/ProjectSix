# Integration Walkthrough

A concrete 5-step guide to adopting BASHostKit in your own host。 Compatible
with substrate v0.56.0+。

This doc exists because SampleHost is intentionally minimal (façade smoke
only — see VERSIONING.md for why)。 If you need a deeper reference of how
to actually USE L1-L14 features beyond startup, work through this doc。

---

## Prerequisites

- macOS / iOS host project using Swift Package Manager
- Xcode 16+ (Swift 6.0 toolchain)
- Your project's Package.swift adds BehavioralAISubstrate as a dependency:

```swift
dependencies: [
    .package(path: "../BehavioralAISubstrate"),
    // or .package(url: "...", branch: "main") for git-based consumers
],
targets: [
    .target(
        name: "YourHost",
        dependencies: [
            .product(name: "BASHostKit", package: "BehavioralAISubstrate"),
        ]
    ),
]
```

**Default rule:** import `BASHostKit` and nothing else from the substrate。
The other 15 .library products (BASRuntimeCore,BASMemory,BASPolicy,etc.)
are dependency implementations,not host-facing API。 If you need to import
one of them directly,you're outside the recommended SDK surface — see
README's「Import Boundary」 section first。

---

## Step 1 — Construct a BASHostConfiguration

```swift
import BASHostKit

var configuration = BASHostConfiguration.fixtureGeneric

// Optional:tell the substrate your host's namespace for verification +
// projection provenance。 String is host-controlled — defaults to "host"。
configuration.workflowBehavior = BASHostWorkflowBehaviorConfiguration(
    hostNamespace: "yourhost"
)

// Optional but recommended:set the safety confidence threshold。 The
// substrate uses this to gate when its decision-cognition cascade
// flags an input as「needs caller verification」。 Range 0.5-0.99;
// default 0.85。 Higher = more permissive,Lower = more guards fire。
configuration.cognition.safetyConfidenceThreshold = 0.85
```

**Crash contract:** if you pass values violating the precondition contract
documented in the README「Runtime crash contracts」 section, the app crashes
at config-validation time。 Test your config under XCTest before shipping。

---

## Step 2 — Construct a BASHostRuntime

```swift
let dependencies = BASHostDependencySet()    // defaults are fine for
                                              // most hosts

let runtime = BASHostRuntime(
    configuration: configuration,
    dependencies: dependencies
)
```

The runtime composes 14 internal layers (L1-L14) into a single object you
talk to。 You don't see the layers directly — BASHostKit's façade hides
them behind `runtime.startSession(...)` + a few inspection accessors。

---

## Step 3 — Start a session

```swift
let result = runtime.startSession(
    BASHostSessionRequest(
        kind: .interactive,             // .interactive / .background / .reopen
        workflowProfile: .primary,      // .primary / .fast / .deep
        surface: .application,          // .application / .watch / .widget /
                                        // .notification
        prompt: "Should I commit this code change?"
    )
)
```

`startSession` is synchronous + complete:by the time it returns,the
substrate has run the full 14-layer cascade on your prompt:lease + organ
math + thought-fold observation + dream-loop scoring + tri-self court +
risk plane + sovereign verdict + audit ledger seal + evolution governance
+ projection。

---

## Step 4 — Read the result

```swift
// The current cognitive state derived from the session:
let brain = result.currentBrain
print("Decision confidence:", brain.decisionConfidence)
print("Risk band:", brain.riskBand)             // .low / .medium / .high / .critical
print("Permit mode:", brain.permitMode)         // .answer / .pause / .deny / .mirror
print("Sovereign verdict:", brain.sovereignVerdict)

// The projection (a host-displayable summary):
let projection = result.projection
print("Headline:", projection.headline)
print("Goals:", projection.goals)
print("Constraints:", projection.constraints)
print("Calibration status:", projection.calibrationStatus)

// Console snapshot (debug + inspection — only useful with BASAdmin import):
let snapshot = result.consoleSnapshot
// ... typed admin / inspection data

// User-facing notices the host should surface:
for notice in result.notices {
    print("Notice:", notice.title, "—", notice.body)
}

// Suggested follow-up actions:
for action in result.followUpActions {
    print("Follow-up:", action.label)
}
```

---

## Step 5 — Persist + reload (optional)

If your host needs cross-launch continuity (most do):

### Auto-router calibration (per-device perf tuning)

```swift
// At app launch, before first session:
let cacheURL = applicationSupportURL
    .appendingPathComponent("bas-calibration.json")
let report = BASCognitiveBrain.loadOrCalibrateAutoRoute(
    cacheURL: cacheURL
)
// 10-30s on first cold start, ~10ms on subsequent loads (cache hit)。
// Schema bumps trigger automatic recalibration — see MIGRATING.md。
```

### L11 risk observation persistence (optional opt-in,chapter 七百五十四)

```swift
import BASPolicy

let storageURL = applicationSupportURL
    .appendingPathComponent("risk-observations.sqlite")
let storage = try BASRiskObservationsSQLiteStorage(
    databaseURL: storageURL
)
BASRiskObservationLedger.sharedStorage = storage
// L11 risk plane now persists across cold restarts。
// Reload at next launch:
let observations = try BASRiskObservationLedger
    .loadFromSharedStorage(sessionID: yourSessionID)
```

### History stores (memory atom usage tracking)

```swift
import BASMemory

let tracker = BASMemoryUsageTracker()
let sqlStore = BASSQLBrainHistoryStore(tracker: tracker)
// Pass to BASCognitiveBrain init via the brain's optional history-store params
// (see BASCognitiveBrain.makeWithDefaults documentation)。
```

---

## Common patterns

### Reading the substrate's typed enums

The substrate uses sum types extensively。 Common ones you'll switch on:

```swift
switch brain.permitMode {
case .answer: // proceed
case .pause:  // wait for user confirmation
case .deny:   // do not execute
case .mirror: // execute,but display a「we're mirroring this」 disclosure
}

switch brain.sovereignVerdict {
case .clear:      // L14 sovereign cleared the action
case .review:     // L14 flagged for human review
case .quarantine: // L14 quarantined,don't execute
}

switch brain.riskBand {
case .low, .medium, .high, .critical: // numeric ordering matches severity
}
```

### Handling thermal pressure (L1)

The substrate's L1 lease layer responds to thermal pressure。 If your host
runs on iOS hardware:

```swift
import BASLeaseLife

// At app launch, configure thermal slowdown sensitivity:
let leasePolicy = BASLeaseThermalPolicy(
    slowdownMultiplier: 2.0,       // double cycle time when thermal hot
    sampleInterval: 5.0             // poll thermal state every 5 seconds
)
runtime.applyLeasePolicy(leasePolicy)
```

### Cross-session memory retrieval (L8)

```swift
import BASMemory

let memoryQuery = BASMemoryRetrievalQuery(
    sessionID: yourSessionID,
    topK: 10,
    confidenceFloor: 0.5
)
let retrieved = await runtime.retrieveMemory(query: memoryQuery)
// retrieved is [BASMemoryAtom] sorted by composite-score。
```

---

## What's NOT in this walkthrough

Out-of-scope for the 5-minute integration:

- **L13 Evolution Furnace** — only matters once your host has been deployed
  long enough to accumulate experience candidates。 See
  `Sources/BASHostKit/EBrainRuntimeCoordinator+EvolutionGovernance.swift`
  for the L13 API surface when you're ready。
- **Custom prompt vocabulary** — see
  `BASHostConfiguration.presentation.prompt`。
- **Predictive interventions** — see
  `BASHostConfiguration.workflowBehavior.predictiveIntervention`。
- **Custom adapter integration** — see
  `BASChatCompletionsAdapter` + `BASMLXAdapter` for adapter contract examples。
  Implementing a custom adapter is a chapter-shaped effort,not a 5-min step。

---

## Verify your integration

```bash
# Build green:
swift build

# Your host tests should pass:
swift test

# Substrate self-tests should still pass:
cd path/to/BehavioralAISubstrate && swift test
# Expected: 12,965 tests / 31 skipped / 0 failures (substrate 0.56.0)
```

---

## When something doesn't work

1. **Build fails with「missing module BASXxxYyy」** — Package.swift's deps
   only declare `BASHostKit`,but you imported `BASRuntimeCore` or
   `BASMemory` directly。 Either add the explicit product to your deps,or
   refactor to import via BASHostKit。
2. **App crashes at startup with `precondition` violation** — read the
   README「Runtime crash contracts」 section,find your violating field,
   fix the config value (likely a 0 you should have set positive)。
3. **`loadOrCalibrateAutoRoute` takes 30+ seconds on every launch** —
   the cache file path likely isn't writable,or it's getting
   periodically deleted by your host's storage layer。 Verify the path
   survives app launches。
4. **Tests pass in isolation but fail in full sweep** — file an issue
   with the failing test name and full sweep order。 This shouldn't happen
   post-chapter-七百五十七 第四刀 (atomID parity deterministic timestamp),
   but if it does,it's a regression。

---

## Where to ask follow-up questions

- For SDK-shape questions:see README + this doc + VERSIONING.md
- For upgrade-path questions:see MIGRATING.md
- For internal-architecture questions:see BRANCH_SUMMARY.md (chapter-shaped
  historical record) + docs/superpowers/plans/* (planning records)
- For specific test failures:run with `--verbose` first,then file an issue

This doc is consumer-shaped。 The internal docs are historical-record-shaped。
If you need to choose,start consumer-shaped。
