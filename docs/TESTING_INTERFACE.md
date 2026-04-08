# Testing Interface

Before keeps model override controls out of the user-facing app UI.

Use `DecisionTestingInterface` when tests, automation, or developer tooling need to:

- switch the active model provider
- pin deterministic behavior
- disable provider fallbacks
- inspect runtime telemetry for provider usage, fallbacks, and cache behavior
- inspect recent model traces
- build replay data from recent saved decisions

## Launch Environment Keys

The app reads these values at launch and folds them into the stored preferences without changing unrelated user settings:

- `BEFORE_TEST_INTELLIGENCE_MODE`
  - accepted values: `off`, `assistive`
- `BEFORE_TEST_MODEL_PROVIDER`
  - accepted values: `template`, `foundationModels`, `gemmaE4B`
- `BEFORE_TEST_ALLOW_FALLBACKS`
  - accepted truthy values: `1`, `true`, `yes`, `on`
  - accepted falsy values: `0`, `false`, `no`, `off`
- `BEFORE_TEST_MODEL_STUB_PROFILE`
  - accepted values: `smoke`
  - when present, Before bypasses live model providers and uses a deterministic testing stub for refinement and reminder selection
- `BEFORE_TEST_INFERENCE_BACKEND`
  - accepted values: `auto`, `systemManaged`, `coreMLPreferred`, `metalPreferred`, `cpuOnly`
  - when present, Before keeps the choice internal and test-only, but resolves Gemma runtime policy against the current device capabilities
- `BEFORE_TEST_SKIP_ONBOARDING`
  - accepted truthy values: `1`, `true`, `yes`, `on`
  - when present, Before skips the onboarding gate for that launch only
- `BEFORE_TEST_CLEAN_LAUNCH`
  - accepted truthy values: `1`, `true`, `yes`, `on`
  - when present, Before clears persisted workspace state and local decision data before the app becomes interactive

## XCTest / UI Test Usage

You can build a consistent launch environment from code:

```swift
let environment = DecisionTestingInterface.launchEnvironment(
    intelligenceMode: .assistive,
    preferredProvider: .gemmaE4B,
    allowFallbacks: false,
    stubProfile: .smoke,
    inferenceBackendPolicy: .cpuOnly,
    skipOnboarding: true,
    cleanLaunch: true
)
```

And apply it to an app launch:

```swift
let app = XCUIApplication()
app.launchEnvironment.merge(environment) { _, new in new }
app.launch()
```

## Runtime Snapshot

For tests that need a single readout of the current model stack:

```swift
let snapshot = DecisionTestingInterface.runtimeSnapshot()
```

This snapshot includes:

- effective preferences
- active testing stub profile, if one was injected
- effective inference backend policy
- current device capability snapshot
- resolved Gemma backend path for the current environment
- active runtime status
- Apple Foundation Models availability
- Gemma provider availability
- Gemma bundle status
- Gemma local runtime status

For a full diagnostics package that also includes telemetry, recent traces, and replay:

```swift
let export = await DecisionTestingInterface.runtimeExport(
    quick: quickEvents,
    balance: balanceRecords,
    mirror: mirrorRecords
)
```

This export bundles:

- runtime snapshot
- provider/fallback/backend telemetry
- cache telemetry
- recent traces
- recent replay entries
- a compact summary with cache hit rate, fallback rate, average request latency, and dominant Gemma backend

The summary now also exposes:

- average request duration across all intelligence work
- average request duration grouped by decision kind
- average request duration grouped by active provider
- average request duration grouped by resolved Gemma backend

## Trace And Replay Helpers

These helpers stay available for tests and tooling, but are not surfaced in the app UI:

- `DecisionTestingInterface.runtimeExport(...)`
- `DecisionTestingInterface.intelligenceTelemetrySnapshot(...)`
- `DecisionTestingInterface.cacheTelemetrySnapshot(...)`
- `DecisionTestingInterface.recentTraces(...)`
- `DecisionTestingInterface.clearTraces(...)`
- `DecisionTestingInterface.recentReplay(...)`
- `DecisionTestingInterface.resetTransientIntelligenceState(...)`

Trace and replay access is `@MainActor`, matching the debug store’s threading model. Telemetry and cache snapshots are async because they read actor-backed stores.

## Design Rules

- Keep the user-facing app free of developer-only controls.
- Prefer launch-environment overrides for tests over hidden debug toggles.
- Treat model provider switching as a testing and automation concern, not a normal settings concern.
- Prefer the testing stub when UI tests or smoke tests need stable model output without depending on Gemma or Apple runtime availability.
- Keep quick verdict ownership in the deterministic rules layer, even when assistive model refinement is enabled.
- Treat CPU / Core ML / Metal choice as an internal runtime policy, not as a user-facing setting.
