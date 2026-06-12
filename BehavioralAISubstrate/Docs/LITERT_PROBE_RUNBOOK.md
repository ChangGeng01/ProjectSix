# LiteRT-LM E4B Probe — Deploy Run-Book

Goal: answer the two open questions from `LITERT_LM_STUDY.md` on the real iPhone Air —
**(1)** does Gemma-3n E4B (the model MLX jetsam-kills) actually load + decode within the iOS
per-process limit via LiteRT-LM's mmap'd weights (study claim: ~961 MB physical footprint on the
CPU path), and **(2)** does `Conversation.cancel()` interrupt an in-flight Metal decode (escaping the
ADR-038 wedge).

The probe code (`DeviceTestApp/Sources/App/BASLiteRTE4BProbe.swift`, knob `BAS_LITERT_E4B_PROBE=1`)
is **already in the project and build-green** — it compiles to a SAFE SKIP STUB until the LiteRTLM
package is added. This run-book is the deploy sequence.

> **Do NOT run this while the 10h dual-device A/B sweep is live** — deploying a new build interrupts
> the running endurance run. Wait for that to finish (frees the devices), or use a third device.

## Step 0 — prerequisites (the four real blockers)

1. **The model.** Download the gated `gemma-3n-E4B-it-int4.litertlm` from HuggingFace
   (`google/gemma-3n-E4B-it-litert-lm`, accept Gemma terms) — ~3.66 GB. Also grab the E2B file for
   a lighter sanity pass if wanted.
2. **The entitlement on the App ID.** In the Apple Developer portal, enable
   `com.apple.developer.kernel.increased-memory-limit` (+ `extended-virtual-addressing`) for the
   `com.changgeng.basdevicetest` App ID, then regenerate the provisioning profile. Without this the
   signed build will NOT get the raised jetsam ceiling (and adding the entitlements file to a profile
   that lacks it FAILS signing).
3. **The SPM package** (coordinates below).
4. **A free device** (the 10h A/B must be done).

## Step 1 — add the LiteRTLM SPM package (then compile-verify the probe)

Add the official binary package to `DeviceTestApp/BASDeviceTest.xcodeproj` (Xcode → File → Add Package
Dependencies, or edit the project):

```
Package:  https://github.com/google-ai-edge/LiteRT-LM   (product: LiteRTLM)
Version:  exact 0.13.1
Platforms: iOS 15+ / macOS 12+
Binary:   CLiteRTLM.xcframework.zip
          sha256 7ff01c42106b754748b5dd3036a4a57161b25ebf523e705bebc1219061852362
Linker:   -Xlinker -all_load
```
Adding it flips `#if canImport(LiteRTLM)` true and activates the real probe. **COMPILE-VERIFY NOW** —
the probe body is written against the documented v0.13.1 Swift API (`actor Engine(engineConfig:)` /
`EngineConfig` / `Backend.cpu/.gpu` / `Conversation.sendMessageStream` / `.cancel()`); the binding is
"Early Preview" so fix any signature drift at this step (it will be the only place that fails to
compile).

## Step 2 — wire the entitlements (probe build only)

Point the probe build's `CODE_SIGN_ENTITLEMENTS` at `DeviceTestApp/Resources/BASLiteRTProbe.entitlements`
(the two memory entitlements). Leave the default `BASDeviceTestApp.entitlements` empty so the normal
MLX build is unchanged. (Consider a dedicated build configuration / scheme for the probe.)

## Step 3 — build + install + stage the model

```bash
xcodebuild -project DeviceTestApp/BASDeviceTest.xcodeproj -scheme BASDeviceTestApp \
  -destination "id=<DEVICE_UDID>" -allowProvisioningUpdates build
xcrun devicectl device install app --device <DEVICE_UDID> "<built .app>"
# stage the model into the app container Documents:
xcrun devicectl device copy to --device <DEVICE_UDID> \
  --domain-type appDataContainer --domain-identifier com.changgeng.basdevicetest \
  --source <path>/gemma-3n-E4B-it-int4.litertlm --destination Documents/gemma-3n-E4B-it-int4.litertlm
```

## Step 4 — run the probe

```bash
xcrun devicectl device process launch --terminate-existing --device <DEVICE_UDID> \
  --environment-variables '{"BAS_ENDURANCE_AUTOSTART":"1","BAS_LITERT_E4B_PROBE":"1"}' \
  com.changgeng.basdevicetest
```
Optional `BAS_LITERT_MODEL_PATH` to override the model path.

## Step 5 — read the evidence

Pull `litert-probe-*.log` from Documents (`devicectl device copy from … Documents`). Key lines:
```
📊 litert-probe baseline_phys_mb=…
📊 litert-probe RESULT backend=cpu loaded=… phys_mb=… delta_mb=… decode_tokens=… tok_per_s=… note=…
📊 litert-probe RESULT backend=gpu loaded=… phys_mb=… …
```
**Verdict criteria:**
- **The central claim:** does `backend=cpu` show `phys_mb` well under the 3376 MB jetsam cap (study
  says ~961 MB)? If yes, LiteRT runs E4B where MLX can't — confirmed on BAS hardware.
- **GPU reality:** `backend=gpu` `phys_mb` is expected near ~3380 MB (resident Metal weights) — likely
  the jetsam-risk path; the mmap win is CPU-only.
- **Throughput:** decode `tok_per_s` (study: E4B CPU ≈ 9.7, GPU ≈ 25.1) — is the CPU path fast enough?
- **Cancellation (extend the probe):** add a mid-decode `cancel()` test and confirm it interrupts the
  Metal decode (the `cancel_interrupted` field) — a yes would also escape the ADR-038 wedge.

## Step 6 — promote (only if the probe pays)

If E4B fits + acceptable tps + cancellable/no-wedge → promote to a real `BASLiteRTOrganAdapter`
(the 3-method `BASOrganAdapter` conformance + a `.litert` `BASProviderKind` case, `.experimental`
`BASCertificationTier`), per `LITERT_LM_STUDY.md` §6.5. Otherwise record the DECLINE with the measured
numbers — a negative result is output (亏的不要).
