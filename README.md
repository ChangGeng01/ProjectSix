# Before

Before is a local-first decision OS for iPhone.

It is not a streak app, not a blocker, and not a shame machine. The current build supports three decision depths inside one shared system:

- `Quick`: 3-question stoplight flow for fast, regret-prone decisions
- `Balance`: 4-panel trade-off board for everyday choices
- `Mirror`: 5-panel workspace for heavier personal questions
- route preview and starter prompts from the home screen
- configurable quick buffer duration
- post-decision reflection and reminder capture
- Tomorrow Box for delayed reconsideration
- history details, reopen flow, and review profiles
- Home / History / Settings tabs
- Home Screen + Lock Screen widgets
- App Intents / Shortcuts / Siri entry groundwork
- assistive intelligence with provider routing and deterministic fallbacks

## Stack

- `SwiftUI`
- `SwiftData`
- `WidgetKit`
- `App Intents`
- `UserNotifications`
- `XcodeGen`

## Project Structure

- `project.yml`: XcodeGen spec
- `BehavioralAISubstrate/`: private substrate Swift Package
- `Before/`: main iOS app
- `SampleHost/`: minimal façade-only host example
- `BeforeWidgetExtension/`: widget target
- `BeforeTests/`: unit tests for the rules and reminder templates
- `docs/`: model packaging and testing-interface notes

## Generate The Project

```bash
xcodegen generate
```

This creates [`Before.xcodeproj`](/Users/changgeng/Project/Project06/Project06/Before.xcodeproj).

## Build

```bash
xcodebuild -project Before.xcodeproj -scheme Before -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Test

```bash
xcodebuild -project Before.xcodeproj -scheme Before -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' CODE_SIGNING_ALLOWED=NO test
```

## Notes

- The widget extension uses an app group placeholder: `group.com.changgeng.before`.
- Widget surfaces only use safe generic copy and never show raw user-written reminders.
- Personal data stays local in this build.
- The 13-layer execution blueprint and appendices now live in [docs/EBRAIN_13L_EXECUTION_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_EXECUTION_V12.md) and [docs/EBRAIN_13L_APPENDICES_V12.md](/Users/changgeng/Project/Project06/Project06/docs/EBRAIN_13L_APPENDICES_V12.md).
- `BASHostKit` is now the preferred host-facing integration surface for the private substrate SDK.
- `Before` remains the full reference host, while `SampleHost` proves the minimal façade integration path.
- The quick verdict engine remains rule-based and intentionally lightweight.
- Apple Foundation Models can refine local copy on supported devices.
- Gemma 4 E4B is prepared as a bundled `.litertlm` asset under `Before/Resources/Models`, with runtime fallback to Apple or deterministic copy when unavailable.
- Model switching for tests is driven through `DecisionTestingInterface` and launch environment overrides instead of in-app developer UI.
- Tests can pin a deterministic `smoke` stub provider through launch environment when refinement paths need stable output without a live model runtime.
- See `/Users/changgeng/Project/Project06/Project06/docs/TESTING_INTERFACE.md` for launch keys and examples.
- The project currently includes `121` XCTest cases and `8` Swift Testing cases covering routing, restoration, storage, reminders, review insights, typed preferences, testing overrides, stub-model injection, and model-provider fallback behavior.
