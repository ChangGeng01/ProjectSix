# BehavioralAISubstrate

`BehavioralAISubstrate` is a private Apple-only substrate for behavior-aware host apps. It is the canonical **14-layer 电子脑** (L1-L14). The legacy `Before` reference host was severed 2026-05-20 — see `/Archive/Legacy/` at the repo root.

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

Product language stays in the host. The substrate exposes generic workflow and lifecycle vocabulary, while each host translates its own mode names, tabs, branded flows, and legacy identifiers at the edge through host-owned compatibility and migration layers.

```swift
import BASHostKit

var configuration = BASHostConfiguration.fixtureGeneric
configuration.workflowBehavior = BASHostWorkflowBehaviorConfiguration(
    hostNamespace: "host"
)

let runtime = BASHostRuntime(
    configuration: configuration,
    dependencies: BASHostDependencySet()
)

let result = runtime.startSession(
    BASHostSessionRequest(
        kind: .interactive,
        workflowProfile: .primary,
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
- execution-profile thresholds and runtime explanation copy
- prompt vocabulary, guards, and presentation copy
- memory-derivation IDs, headlines, and provenance wording
- host namespace for verification and projection provenance
- lifecycle titles
- lifecycle notices
- follow-up action phrasing
- predictive intervention copy
- reopen wording
- legacy identifier compatibility
- bootstrap alias and fallback policy

through `BASHostConfiguration.presentation`, `BASHostConfiguration.workflowBehavior`, and `BASHostConfiguration.lifecycleBehavior.currentBrainBootstrapBehavior`, so the substrate keeps generic behavior while each host keeps its own product DNA.

## Reference Hosts

- [`SampleHost`](/Users/changgeng/Project/Project06/Project06/SampleHost): minimal façade-only iOS host (the substrate's only living reference)
- Legacy `Before` host preserved at `/Archive/Legacy/Before/` for historical reference; not built, not tested, not on the substrate's dependency graph.

## Current Delivery Model

- Apple-only
- private integration SDK
- fast-evolving contract
- monorepo source of truth
- ready to split into a dedicated private SDK repo later

## Validation

Primary validation lives in:

- `cd BehavioralAISubstrate && swift build` (SPM,no Xcode required)
- `cd BehavioralAISubstrate && swift test` (~13k tests,~85s sweep)
- `xcodebuild test -scheme SampleHost` (optional Apple-platform integration smoke)

## Import Boundary

Host targets should use `BASHostKit`, not low-level BAS module imports.

Run:

```bash
./scripts/check_sdk_import_boundaries.sh
```

This also runs `./scripts/check_substrate_residuals.sh`, which fails if legacy host vocabulary leaks back into the substrate sources, README, or non-whitelisted package tests.
