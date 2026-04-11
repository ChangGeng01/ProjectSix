# BehavioralAISubstrate

`BehavioralAISubstrate` is the private Apple-only substrate that powers `Before` and can now be integrated by other host apps inside this monorepo.

## Products

- `BASHostKit`: façade-first host integration surface
- `BASRuntimeCore`: routing, execution budgets, provider planning
- `BASMemory`: event, memory, brain, projection, governed retrieval
- `BASPolicy`: boundary, policy, risk, release controls
- `BASOrchestration`: prompt contract, workflow, execution lanes
- `BASObservability`: traces, telemetry, replay, inspection
- `BASEvaluation`: calibration, regression, drift
- `BASAdmin`: flight deck, console, capability coverage
- `BASAppleAdapters`: Apple-specific lifecycle, handoff, reopen, notification, runtime bridges

## Integration Strategy

Default hosts should import `BASHostKit`.

```swift
import BASHostKit

let runtime = BASHostRuntime(
    configuration: BASHostConfiguration(),
    dependencies: BASHostDependencySet()
)

let result = runtime.startSession(
    BASHostSessionRequest(
        kind: .quick,
        mode: .quick,
        surface: .app,
        prompt: "Should I do this right now?"
    )
)
```

The façade returns:

- `BASHostSessionResult.currentBrain`
- `BASHostSessionResult.projection`
- `BASHostSessionResult.consoleSnapshot`
- `BASHostSessionResult.notices`
- `BASHostSessionResult.followUpActions`

## Reference Hosts

- [`Before`](/Users/changgeng/Project/Project06/Project06/Before): full product shell
- [`SampleHost`](/Users/changgeng/Project/Project06/Project06/SampleHost): minimal façade-only iOS host

## Current Delivery Model

- Apple-only
- private integration SDK
- fast-evolving contract
- monorepo source of truth
- ready to split into a dedicated private SDK repo later

## Validation

Primary validation lives in:

- `swift test --package-path BehavioralAISubstrate`
- `xcodebuild test -scheme Before`
- `xcodebuild test -scheme BeforeUISmoke`
- `xcodebuild test -scheme SampleHost`
- `xcodebuild build -scheme BeforeWatch CODE_SIGNING_ALLOWED=NO`

## Import Boundary

Host targets should use `BASHostKit`, not low-level BAS module imports.

Run:

```bash
./scripts/check_sdk_import_boundaries.sh
```
