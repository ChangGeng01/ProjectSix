# SampleHost — substrate reference iOS host

Standalone SPM iOS package demonstrating BASHostKit integration。 The only
living reference host for BehavioralAISubstrate post-Before-severance
(2026-05-20)。

## Build

Pure-macOS `swift build` from this directory **will fail** — SampleHost
uses UIKit + iOS-only SwiftUI patterns。 Build via xcodebuild targeting
the iOS Simulator:

```sh
cd SampleHost
xcodebuild build \
    -scheme SampleHost \
    -destination 'platform=iOS Simulator,name=iPhone 17e' \
    CODE_SIGNING_ALLOWED=NO
```

For real-device deployment:

```sh
xcodebuild build \
    -scheme SampleHost \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    DEVELOPMENT_TEAM=<your-team-id> \
    -allowProvisioningUpdates
```

## Test

```sh
cd SampleHost
xcodebuild test \
    -scheme SampleHost \
    -destination 'platform=iOS Simulator,name=iPhone 17e' \
    CODE_SIGNING_ALLOWED=NO
```

CI runs this on every push (see `/.github/workflows/test.yml`
`samplehost-tests` job)。

## Package shape

- **Library target `SampleHost`** — 59 Swift files at the package root:
  - 38 cross-platform helpers (bench infrastructure, BASHostKit invocation,
    JSONL runners, CoreML inference wrappers)
  - 11 SwiftUI-only iOS views (panels, ChengluStressPanel,
    LLMExtractionDemoView, etc.)
  - 5 UIKit-using iOS files (App entry, Model, BenchThermalGate,
    ChengluStressRunner, Hybrid/Legacy bench entries)
  - 5 CoreML packages as resources (`.copy`):
    `ChengluLatencyHead_v0.mlpackage`,`ChengluLengthHead_v0.mlpackage`,
    `ChengluMultiHead_v0.mlpackage`,`ChengluPermitPredict_v0.mlpackage`,
    `ChengluPreflight_v0.mlpackage`
  - 1 safetensors LoRA file (`qinao_curriculum_lora_m247.safetensors`)
    as `.process` resource

- **Test target `SampleHostTests`** — 7 XCTest files in
  `Tests/SampleHostTests/` (relocated from `/SampleHostTests/` at
  reconstitution time for SPM-canonical layout)。 Most tests
  `@testable import SampleHost` + `import BASHostKit`。

## Dependencies

- `BehavioralAISubstrate` via sibling path dep (`../BehavioralAISubstrate`)
  - Imports:`BASHostKit`,`BASOrgan`,`BASRuntimeCore`,`BASMLXAdapter`

External adopters cloning this monorepo replace the path dep with a
git-pinned dep + a versioned tag — see `BehavioralAISubstrate/VERSIONING.md`
+ `INTEGRATION.md` for the SDK consumption shape。

## What SampleHost demonstrates

- `BASHostKit` integration via `SampleHostBASHostConfigBundles.swift`
  (configuration construction)
- `BASHostRuntime.startSession` via `SampleHostBASHostInvocation.swift`
- `BASOrgan` + `BASRuntimeCore` direct usage (bench harnesses)
- CoreML pre-flight + permit-predict + multi-head + length / latency
  regression heads (via `CoreMLPreflightInference` + siblings)
- `BASMLXAdapter` for on-device Gemma / Qinao LoRA inference

## What SampleHost does NOT demonstrate yet

Honest scope acknowledgment:

- **No deep L14 sovereign verdict** exercise — the test surface uses the
  substrate's default verdict path but doesn't drive edge cases
- **No L11 SQL persistence** opt-in — the L11 risk observation ledger is
  in-memory throughout
- **No L9 dream-loop scoring** stress
- **No L8 memory pruning** at scale
- **No multi-session continuity** across cold restarts

These are tracked in the「Reference integration shallow」 SDK readiness gap
documented in `BehavioralAISubstrate/BRANCH_SUMMARY.md`。 A deeper
reference host that exercises L1-L14 in production-shaped flow is on the
substrate's roadmap (not scheduled)。

## History

- 2026-05-21 — Reconstituted as standalone SPM package。 `Package.swift`
  added,`SampleHostTests/` moved to `Tests/SampleHostTests/`,CI re-enabled。
- 2026-05-20 — Before severance:SampleHost lost its build path (was a
  scheme inside Before.xcodeproj,which moved to `Archive/Legacy/`)。
- Pre-2026-05-20 — SampleHost lived as a scheme in Before.xcodeproj,
  shared the build tree with the legacy Before iOS app。
