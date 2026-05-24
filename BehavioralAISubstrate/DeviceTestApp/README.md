# BAS Device Test Host App

chapter 九百四十九 / M3450 — Xcode iOS host app target for running
BehavioralAISubstrate tests on real iPhone Air device。

## Why this exists

SwiftPM (`swift test`) cannot host a test bundle on a real iOS
device — it only works on macOS host + iOS Simulator。 To run
tests on an actual iPhone (iPhone Air per user directive),we
need an **iOS app target** that wraps the test bundle。

This directory:
- `project.yml` — xcodegen spec (regenerate `.xcodeproj` via
  `xcodegen generate`)
- `Sources/App/` — minimal SwiftUI app (just hosts the test
  bundle,no real UI matters)
- `Resources/Info.plist` — bundle metadata
- `BASDeviceTest.xcodeproj/` — generated Xcode project

## ⚠️ Pre-flight (one-time setup,you do in Xcode GUI)

The CLI alone can't complete this — Apple's signing infrastructure
requires Xcode to have an Apple ID logged in。 Cert in keychain
is NOT enough。

### Step 1:Add Apple ID to Xcode

1. Open **Xcode → Settings (⌘,)** → **Accounts** tab
2. Click **`+`** → **Apple ID**
3. Sign in with the Apple ID associated with team `U4ZLQM8399`
   (likely the same one that owns `com.changgeng.before`,
   `au.carelink.CareLink`,etc。 per existing provisioning
   profiles)
4. Verify the team **`U4ZLQM8399 (Chang Geng)`** appears in
   the team list under your Apple ID
5. Close Xcode Settings

### Step 2:Register iPhone Air with the team

1. Plug iPhone Air via USB-C (UDID
   `9E9E3DEB-E9F5-5C2D-A6B1-9B31A70659D6`)
2. Unlock device + trust this Mac if prompted
3. Open Xcode → **Window → Devices and Simulators (⌘⇧2)**
4. Select your iPhone in the left panel
5. If not yet registered for development:click **「Use for
   Development」** button (Xcode auto-registers the UDID with
   team U4ZLQM8399 under your Apple ID)
6. Wait ~10s for the registration to complete
7. Close Devices window

### Step 3:Open BASDeviceTest.xcodeproj once (lets Xcode
auto-refresh the provisioning profile to include the new device)

1. `open DeviceTestApp/BASDeviceTest.xcodeproj`
2. Select **BASDeviceTestApp** target → **Signing & Capabilities**
3. Confirm「**Automatically manage signing**」 is checked
4. Confirm Team = `Chang Geng (U4ZLQM8399)`
5. Xcode will auto-fetch the new provisioning profile
6. Close Xcode

## Run device test (CLI,after pre-flight)

```bash
cd /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate

# Smoke test single L8 fuzz on iPhone Air device
xcodebuild test \
    -project DeviceTestApp/BASDeviceTest.xcodeproj \
    -scheme BASDeviceTestApp \
    -destination "platform=iOS,id=9E9E3DEB-E9F5-5C2D-A6B1-9B31A70659D6" \
    -only-testing:BASDeviceTests/BASChapter946FourteenLayerFuzzSmokeTests/testL8AtomLifecycleFuzzRoundTrip \
    -allowProvisioningUpdates

# Full L8 substance + 14-layer fuzz + concurrent race on device
xcodebuild test \
    -project DeviceTestApp/BASDeviceTest.xcodeproj \
    -scheme BASDeviceTestApp \
    -destination "platform=iOS,id=9E9E3DEB-E9F5-5C2D-A6B1-9B31A70659D6" \
    -only-testing:BASDeviceTests/BASChapter934AtomLifecycleFullRowTests \
    -only-testing:BASDeviceTests/BASChapter935DeletionManifestFullRowTests \
    -only-testing:BASDeviceTests/BASChapter936UserStateFullRowTests \
    -only-testing:BASDeviceTests/BASChapter937VersionTreeFullRowTests \
    -only-testing:BASDeviceTests/BASChapter938EventLogFullRowTests \
    -only-testing:BASDeviceTests/BASChapter926FixBackfillCoverageTests \
    -only-testing:BASDeviceTests/BASChapter946FourteenLayerFuzzSmokeTests \
    -only-testing:BASDeviceTests/M603FourteenLayerSmokeTests \
    -allowProvisioningUpdates
```

## What's tested on device vs simulator

| Test class | Simulator (passes today) | Device (your next step) |
|---|---|---|
| L8 substance closure (ch 934-938) | ✓ all pass | TBD — real APFS sync barriers |
| Cross-engine race (ch 944) | ✓ pass | TBD — real iOS file locking semantics |
| foreign_keys diagnostic (ch 944) | ✓ pass | TBD — real device libsqlite3 binding |
| 14-layer fuzz (ch 946 + M603) | ✓ pass | TBD — real iOS jetsam + memory pressure |
| Evolutionary search (ch 948 fix) | ✓ pass | TBD — real A18 chip core scheduling |

## Troubleshooting

- **「No Accounts」 error** → Step 1 above (Xcode Settings → Accounts)
- **「Provisioning profile doesn't include device」** → Step 2 (Devices → Use for Development)
- **「No signing certificate」** → cert is in keychain,but team in
  project.yml must match the cert's TeamIdentifier (currently
  `U4ZLQM8399` per cert subject)
- **「Tool-hosted testing is unavailable on device destinations」** →
  this is the original blocker。 The presence of `TEST_HOST` +
  `BUNDLE_LOADER` in BASDeviceTests target settings (per
  project.yml) is what fixes it。

## Files

- `project.yml` — xcodegen spec (commit-tracked source of truth)
- `Sources/App/BASDeviceTestApp.swift` — SwiftUI app entry
- `Resources/Info.plist` — bundle metadata
- `BASDeviceTest.xcodeproj/` — generated,DO NOT edit by hand
  (regenerate via `xcodegen generate`)
