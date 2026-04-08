# Before

Before is an iPhone-first impulse calibrator.

It is not a streak app, not a blocker, and not a shame machine. The Phase 1 build focuses on a fast single-player flow:

- 4 scenarios: `Buy`, `Eat`, `Scroll`, `Other`
- 3-question quick check
- 2 perspectives + 1 verdict
- 90-second soft buffer
- post-check reflection
- light history
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
- Personal data stays local in this Phase 1 build.
- The current implementation keeps the verdict engine rule-based and intentionally lightweight.
