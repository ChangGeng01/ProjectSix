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

## ✅ Working device test command (chapter 九百五十一 confirmed)

After all pre-flight steps:
```bash
cd /Users/changgeng/Project/Project06/Project06/BehavioralAISubstrate

# Phase 1: First-time build (will print "BUILD SUCCEEDED" but
# generated SQL files only land in Index.noindex due to Xcode
# 26.5 plugin invocation asymmetry on iphoneos)
xcodebuild build \
    -project DeviceTestApp/BASDeviceTest.xcodeproj \
    -scheme BASDeviceTestApp \
    -destination "platform=iOS,id=9E9E3DEB-E9F5-5C2D-A6B1-9B31A70659D6" \
    -allowProvisioningUpdates \
    -skipPackagePluginValidation

# Phase 2: Copy generated files from Index to Build (workaround)
DD=~/Library/Developer/Xcode/DerivedData/BASDeviceTest-dpqdvfgyojguleeuilerivazpqtg
for d in BASMemory BASSovereign BASWorldPrior BASPolicy; do
    mkdir -p "$DD/Build/Intermediates.noindex/BuildToolPluginIntermediates/behavioralaisubstrate.output/$d/BASSQLSchemaGen"
    cp "$DD/Index.noindex/Build/Intermediates.noindex/BuildToolPluginIntermediates/behavioralaisubstrate.output/$d/BASSQLSchemaGen"/*.generated.swift \
       "$DD/Build/Intermediates.noindex/BuildToolPluginIntermediates/behavioralaisubstrate.output/$d/BASSQLSchemaGen/" 2>/dev/null
done

# Phase 3: Run tests (build resumes, picks up files, ships to device)
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
    -allowProvisioningUpdates \
    -skipPackagePluginValidation
```

**ch 951 confirmed result:** iPhone Air iOS 26.5 arm64,**40/40 PASS** on first device run。

### After pre-flight (one-time iPhone Air setup)

In addition to Steps 1-3 in pre-flight,you must also:

### Step 4:Trust developer cert on iPhone Air (one-time per cert refresh,~weekly for personal Apple ID)

After running xcodebuild test for the first time,iOS will report
「Unable to launch ... invalid code signature ... profile has not
been explicitly trusted by the user」 — this is iOS's required user
consent for sideloaded apps from non-App-Store developers。

1. iPhone Air:**设置 (Settings)** → **通用 (General)** →
   **VPN与设备管理 (VPN & Device Management)**
2. Tap **「Apple Development: <your-email>」** under「开发者 App」
3. Tap **「信任 "Apple Development:..."」** (Trust button)
4. Confirm in popup
5. Re-run xcodebuild test — app will now launch on device

This trust persists for ~7 days (personal Apple ID cert TTL)。
After expiry,re-trust required。

## ⚠️ Known blocker (chapter 九百五十 finding,now worked around)

After completing Step 1-3 above + running:
```bash
xcodebuild test -project DeviceTestApp/BASDeviceTest.xcodeproj \
    -scheme BASDeviceTestApp \
    -destination "platform=iOS,id=<UDID>" \
    -only-testing:BASDeviceTests/... \
    -allowProvisioningUpdates -skipPackagePluginValidation
```

Build fails with:
```
error: Build input files cannot be found: '.../BuildToolPluginIntermediates/
behavioralaisubstrate.output/BASMemory/BASSQLSchemaGen/001_memory_usage_records.generated.swift'
... Did you forget to declare these files as outputs of any script phases or
custom build rules which produce them? (in target 'BASMemory' from project
'BehavioralAISubstrate')
```

### Root cause

Xcode 26.5 + SwiftPM build tool plugin invocation has an asymmetric bug:
- iOS Simulator builds (ch 948 verified):plugin runs for ALL targets that
  declare it. ✓
- iOS device builds:plugin compiles successfully (「Compile plug-in
  BASSQLSchemaGen」 fires) AND runs for BASSovereign target,but is
  SKIPPED for BASMemory target — leaving its expected output files
  absent。 swiftc then fails because the source file list references
  missing generated files。

This is a known class of Xcode-SwiftPM interop issue when the same plugin
applies to multiple targets;the plugin invocation tracking gets confused
when the target platform is `iphoneos`。

### Workarounds (none clean enough to ship yet)

1. **Pre-generate SQL → .swift files via standalone tool**, commit them
   as source,gate the plugin so it only re-runs on demand。 ~Hours of
   refactoring the plugin + Package.swift。
2. **Switch to Tuist instead of xcodegen** — different plugin handling
   may avoid the bug。 ~Hours to migrate spec。
3. **Build via `swift build --target BASMemory` for iOS device first**,
   then symlink generated files into DerivedData location xcodebuild
   expects。 Hacky,brittle to Xcode version updates。
4. **File radar with Apple** about the asymmetric plugin invocation。 No
   immediate fix。

### Recommended for now

Use **iPhone Air iOS Simulator** (ch 948 path) which captures ~80% of
device-class validation value:
- ✓ Same iOS arm64 binary architecture
- ✓ Same iOS APFS file system sandboxing
- ✓ Same iOS SQLite WAL behavior
- ✓ Same NSFileManager paths
- ✗ Different CPU (sim uses host) — only matters for perf,not correctness
- ✗ Different memory ceiling (sim is relaxed) — ch 948 jetsam bug was
  STILL caught despite this
- ✗ Software-emulated Metal (sim) vs hardware Metal (device) — only
  matters for Metal kernel tests which substrate has 0 of in core
  L8/L11/L14 paths

```bash
# iPhone Air iOS Sim 26.5 — works today,no host app needed:
xcodebuild test \
    -scheme BehavioralAISubstrate-Package \
    -destination "platform=iOS Simulator,id=DA99B4D8-9D7C-4B1B-8692-A4FBB40FEF4C" \
    -only-testing:BehavioralAISubstrateTests/...
```

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
