# Core AI run-cert — asset DONE + parity-validated; only the Swift-on-iOS-27 app run remains

**Status (UPDATED 2026-06-10):** the Apple `aimodelc`-CLI block was **BYPASSED** via the Python `coreai_torch`
converter. `BASContextClassifier.aimodel` is built + bundled + **run-validated in the coreai Python runtime
(5/5 argmax vs PyTorch, logits-MAE ~1e-6)**. The DeviceTestApp **builds clean under Xcode 27** (sim + device).
The ONLY remaining item is the Swift `BASCoreAIContextClassifierAdapter` run on **real iPhone Air hardware**:
- **Simulator is impossible** — `CoreAI.framework` is not in `iPhoneSimulator27.0.sdk` (device-only framework).
- **Device run is gated only on the iPhone Air being unlocked + connected + trusted** (it last reported
  `unavailable` → devicectl error 4016). One command finishes it: `MODE=device bash scripts/run-coreai-e2e-cert.sh`.
The original Apple-blocker write-up below is kept for the record (now moot — we don't need `aimodelc`).
**Full diagnosis + resolution:** [`ADR_041_COREAI_ONDEVICE_ADAPTER_SHADOW.md`](ADR_041_COREAI_ONDEVICE_ADAPTER_SHADOW.md) §6 + §6.1.

---

## ORIGINAL FILING (kept for the record — the aimodelc CLI path; now bypassed)

**Status:** BLOCKED on Apple, not on us. Scaffolding is in place + committed; resume is one script when Apple ships a fix.
**Date filed:** 2026-06-10
**Full diagnosis:** [`ADR_041_COREAI_ONDEVICE_ADAPTER_SHADOW.md`](ADR_041_COREAI_ONDEVICE_ADAPTER_SHADOW.md) §6.

## The one deferred item

Produce the Core AI `.aimodel` for the context-classifier shadow, then run-certify it:
1. `bash scripts/coreai-build-aimodel.sh` → `Sources/BASAppleAdapters/Resources/BASContextClassifier.aimodel`
2. Uncomment the `.copy("Resources/BASContextClassifier.aimodel")` resource in `Package.swift` (BASAppleAdapters target)
3. `swift test --disable-swift-testing` + `bash scripts/coreai-compile-check.sh` → still green
4. `bash scripts/run-coreai-e2e-cert.sh` (MODE=sim, then MODE=device) → record `📊 coreai-e2e` parity/latency (R1: n=1/beta/experimental)

## Why it's blocked (the incident — 2026-06-10)

Apple's **Xcode 27 beta 1 shipped its Metal Toolchain component out of sync with the app build**:

| Thing | Build |
|---|---|
| Xcode 27 beta app | `27A5194`**`q`** (sub-build **17**) |
| Only Metal Toolchain on Apple's asset server | `27A5194`**`o`** (sub-build **15**, cryptex `v27.1.5194.15`) |

`aimodelc` (the Core AI `.aimodel` compiler, from the `q` app) requires an **exactly-build-matching** Metal
Toolchain; only the lagging `o` build exists (`xcodebuild -downloadComponent MetalToolchain -buildVersion 27A5194q`
→ `Failed fetching catalog`). The `metal` shader compiler tolerates `o` and works; only `aimodelc`'s gate is
exact. **Verified it is NOT our code / config / xcode-select:** the operator ran `sudo xcode-select -s <beta>`
with the `o` toolchain correctly selected — `aimodelc` rejected it identically. (This whole class of Metal-Toolchain
"missing / version-lag" bug has dogged Xcode 26 across betas + release; it is an Apple-side recurring defect.)

**Important:** this blocks ONLY producing a `.aimodel`. Everything else works — the Core AI framework/API
compiles (compile-cert PASSED), and *running* an existing `.aimodel` does NOT need the Metal Toolchain.

**"Just grab an Apple sample model" does NOT work either:** `apple/coreai-models` ships Python *export recipes*,
not pre-converted `.aimodel` files — making any `.aimodel` (sample or ours) goes through the same blocked
export/compile stack. So there is currently NO `.aimodel` obtainable on this machine.

## Unblock trigger

A later **Xcode 27 beta** that ships a **build-matched Metal Toolchain** (or fixes `aimodelc`'s exact-match gate),
OR installing an Xcode build whose number equals the available `27A5194o` toolchain. Apple betas land ~weekly, and
iOS 27 is itself pre-GA (fall 2026), so this run-cert is not on a critical path. **Re-test cheaply at any time:**
`DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun aimodelc compile <a .mlmodel> --output /tmp/probe.aimodel`
— if it stops saying "requires the Metal Toolchain", the fix has landed → run the 4 steps above.

## Scaffold already in place (committed — NOT lost)

- **Code (real, compile-certified):** `BASCoreAINDArrayBridge`, `BASCoreAIModelRunner`, `BASCoreAIContextClassifierAdapter`,
  `BASCoreAIShadowComparison` (`Sources/BASAppleAdapters/`) — gated `#if canImport(CoreAI)` + `@available(iOS 27, macOS 27, *)`,
  no-framework fallback keeps the default 26.5 suite green.
- **On-device probe:** `BAS_COREAI_E2E` in `DeviceTestApp/Sources/App/BASEnduranceAppRunner.swift` (logs `📊 coreai-e2e`).
- **Scripts:** `scripts/{coreai-build-aimodel.sh, coreai-compile-check.sh, run-coreai-e2e-cert.sh}`.
- **Resource slot:** a commented `.copy("Resources/BASContextClassifier.aimodel")` placeholder in `Package.swift`
  (uncomment once the asset exists — kept commented so the build doesn't error on a missing resource).
- **Honesty:** Core AI is labeled `experimental`; the CoreML incumbent is NOT replaced; compile-cert ≠ run-cert
  (the live NDArray readback / input-output-name wiring is type-checked but never run — the genuine residual).
