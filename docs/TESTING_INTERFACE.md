# Testing Interface

Before keeps model override controls out of the user-facing app UI.

Use `DecisionTestingInterface` when tests, automation, or developer tooling need to:

- switch the active model provider
- pin deterministic behavior
- disable provider fallbacks
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

## XCTest / UI Test Usage

You can build a consistent launch environment from code:

```swift
let environment = DecisionTestingInterface.launchEnvironment(
    intelligenceMode: .assistive,
    preferredProvider: .gemmaE4B,
    allowFallbacks: false,
    stubProfile: .smoke
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
- active runtime status
- Apple Foundation Models availability
- Gemma provider availability
- Gemma bundle status
- Gemma local runtime status

## Trace And Replay Helpers

These helpers stay available for tests and tooling, but are not surfaced in the app UI:

- `DecisionTestingInterface.recentTraces(...)`
- `DecisionTestingInterface.clearTraces(...)`
- `DecisionTestingInterface.recentReplay(...)`

Trace and replay access is `@MainActor`, matching the debug store’s threading model.

## Design Rules

- Keep the user-facing app free of developer-only controls.
- Prefer launch-environment overrides for tests over hidden debug toggles.
- Treat model provider switching as a testing and automation concern, not a normal settings concern.
- Prefer the testing stub when UI tests or smoke tests need stable model output without depending on Gemma or Apple runtime availability.
- Keep quick verdict ownership in the deterministic rules layer, even when assistive model refinement is enabled.
