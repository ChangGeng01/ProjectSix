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

## Stack

- `SwiftUI`
- `SwiftData`
- `WidgetKit`
- `App Intents`
- `UserNotifications`
- `XcodeGen`

## Project Structure

- `project.yml`: XcodeGen spec
- `Before/`: main iOS app
- `BeforeWidgetExtension/`: widget target
- `BeforeTests/`: unit tests for the rules and reminder templates

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
- The quick verdict engine remains rule-based and intentionally lightweight.
- The project currently includes 47 passing unit tests covering routing, restoration, storage, reminders, review insights, and typed preferences.
