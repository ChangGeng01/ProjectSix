# BehavioralAISubstrate

`BehavioralAISubstrate` is a private Apple-only substrate for behavior-aware host apps. `Before` is the first reference host, not the shape of the substrate itself.

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

Product language stays in the host. The substrate exposes generic workflow and lifecycle vocabulary, while hosts translate their own mode names, tabs, and branded flows at the edge.

```swift
import BASHostKit

let runtime = BASHostRuntime(
    configuration: BASHostConfiguration(
        workflowBehavior: BASHostWorkflowBehaviorConfiguration(hostNamespace: "host"),
        presentation: BASHostPresentationConfiguration()
    ),
    dependencies: BASHostDependencySet()
)

let result = runtime.startSession(
    BASHostSessionRequest(
        kind: .interactive,
        workflowProfile: .rapid,
        surface: .application,
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

Hosts can also inject their own:

- workflow titles
- workflow template IDs
- workflow memory source mapping
- workflow retrieval defaults
- host namespace for verification and projection provenance
- lifecycle titles
- lifecycle notices
- follow-up action phrasing
- predictive intervention copy
- reopen wording

through `BASHostConfiguration.presentation`, so the substrate keeps generic behavior while each host keeps its own product DNA.

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
