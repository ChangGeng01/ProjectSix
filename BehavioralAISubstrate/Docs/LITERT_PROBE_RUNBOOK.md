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

1. **The model** — see the full acquisition recipe in "Step 0.1" below.
2. **The entitlement on the App ID.** In the Apple Developer portal, enable
   `com.apple.developer.kernel.increased-memory-limit` (+ `extended-virtual-addressing`) for the
   `com.changgeng.basdevicetest` App ID, then regenerate the provisioning profile. Without this the
   signed build will NOT get the raised jetsam ceiling (and adding the entitlements file to a profile
   that lacks it FAILS signing).
3. **The SPM package** (coordinates below).
4. **A free device** (the 10h A/B must be done).

## Step 0.1 — acquire the gated model (do this first; it's the long-pole)

The model is a **GATED** HuggingFace repo (license `gemma`; "This repository is publicly accessible,
but you have to accept the conditions to access its files" — requests are processed immediately).

- **Repo:** `google/gemma-3n-E4B-it-litert-lm`  · **File:** `gemma-3n-E4B-it-int4.litertlm` (~3.66 GB)
- **Lighter sanity pass (optional):** `google/gemma-3n-E2B-it-litert-lm` → `gemma-3n-E2B-it-int4.litertlm`
  (~2.96 GB) — useful to confirm the plumbing before committing the big download.

**One-time access:**
1. Sign in to huggingface.co, open the repo page, click through to **accept the Gemma terms**
   (instant approval).
2. Create a **read** access token: huggingface.co → Settings → Access Tokens → New token (role: read).

**Download (huggingface-cli, the recommended path):**
```bash
# install if needed:  pip install -U "huggingface_hub[cli]"
huggingface-cli login                 # paste the read token (or: export HF_TOKEN=hf_xxx)
huggingface-cli download google/gemma-3n-E4B-it-litert-lm \
  gemma-3n-E4B-it-int4.litertlm \
  --local-dir ~/litert-models
# → ~/litert-models/gemma-3n-E4B-it-int4.litertlm
```
(Equivalent: `python -c "from huggingface_hub import hf_hub_download;
hf_hub_download('google/gemma-3n-E4B-it-litert-lm','gemma-3n-E4B-it-int4.litertlm',
local_dir='~/litert-models')"`. The LiteRT-LM CLI's `--from-huggingface-repo` flag also auto-downloads
to its own cache, but for the probe you want the raw file to stage onto the device — use the CLI
download above.)

**Verify before staging:** confirm the file is a real ~3.6 GB binary (not a 1 KB LFS pointer):
`ls -lh ~/litert-models/gemma-3n-E4B-it-int4.litertlm`. If it's tiny, the LFS object didn't fetch —
re-run with the token set.

## ✅ Step 1 RESOLVED (2026-06-20): integrated as a VENDORED LOCAL package — build GREEN

The 2026-06-12 LFS blocker AND a second SwiftPM wall are both solved; the LiteRT-enabled app now builds.
The recipe (two non-obvious gotchas):

1. **Use a LOCAL package, NOT a remote `url:` ref.** LiteRT's `Package.swift` puts
   `.unsafeFlags(["-Xlinker","-all_load"])` on the `LiteRTLM` target. SwiftPM FORBIDS depending on an
   unsafe-flags product via ANY external reference (version OR revision) — both fail with
   *"package product 'LiteRTLM-product' … uses unsafe build flags."* Only **local/path** references are
   allowed unsafe flags. So vendor it.
2. **Vendor the wrapper from the v0.13.1 TAG, not `main`.** `main`'s `swift/Engine.swift` calls a newer C
   symbol (`litert_lm_conversation_config_set_stream_tool_calls`) absent from the released binary →
   *"cannot find … in scope."* The **v0.13.1 tag** (`a0afb5a…`) wrapper is matched to its binary. (Note:
   the v0.13.1 tag's `Package.swift` actually points its `binaryTarget` URL at the **v0.13.0** xcframework
   — that wrapper↔binary pairing is the consistent one; don't "fix" the URL to v0.13.1.)

**Exact steps used:**
```bash
# clone + checkout the matching tag (LFS-skip avoids the broken android .so)
GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/google-ai-edge/LiteRT-LM /tmp/litert-lm-src
git -C /tmp/litert-lm-src fetch --depth 1 origin tag v0.13.1 && git -C /tmp/litert-lm-src checkout v0.13.1
# vendor ONLY the manifest + swift wrapper (the xcframework downloads from the release URL; rest of repo unused)
mkdir -p Vendor/LiteRT-LM && cp /tmp/litert-lm-src/Package.swift Vendor/LiteRT-LM/ && cp -R /tmp/litert-lm-src/swift Vendor/LiteRT-LM/
# wire into DeviceTestApp/BASDeviceTest.xcodeproj as XCLocalSwiftPackageReference relativePath "../Vendor/LiteRT-LM"
#   + XCSwiftPackageProductDependency {productName=LiteRTLM} + PBXBuildFile in the app Frameworks phase.
#   Do NOT add app-level -all_load (the package's target-level unsafe flag already propagates).
xcodebuild -project DeviceTestApp/BASDeviceTest.xcodeproj -scheme BASDeviceTestApp -destination "id=<UDID>" \
  -allowProvisioningUpdates -skipPackagePluginValidation build   # → BUILD SUCCEEDED; BASLiteRTE4BProbe real body now active
```
The 5 probe API fixes (Message("…") positional, `try await createConversation`, `chunk.toString`, `try EngineConfig`)
are compile-verified against the real v0.13.1 API. **Only remaining gate: the gated model (Step 0.1).** Steps 3-6 below
resume once it's staged. Original blocker notes kept below for history.

## ⚠️ Step 1 BLOCKER (2026-06-12): the LiteRTLM SPM package does not currently resolve

Diagnosed on the dev box (git-lfs INSTALLED, so this is NOT a local tooling gap):
```
swift build → error: 'litert-lm': Couldn't check out revision … :
  Downloading prebuilt/android_arm64/libLiteRtGpuAccelerator.so … Smudge error …
  remote missing object 776b194…  → smudge filter lfs failed
```
**The LiteRT-LM repo references a Git-LFS object (`prebuilt/android_arm64/libLiteRtGpuAccelerator.so`)
that is MISSING from the remote LFS store.** SwiftPM clones the whole repo (to read `Package.swift`)
and the checkout fails on that object — so the package cannot be added by `url:` at all right now. This
is an UPSTREAM packaging bug on Google's side, not something this repo can fix.

What IS available (so a workaround exists): the iOS binary
`CLiteRTLM.xcframework.zip` (v0.13.1, ~80 MB) downloads fine from the GitHub release (separate from the
broken LFS object). What's NOT obtainable without a working clone: the `LiteRTLM` Swift wrapper source
(the guessed `swift/Sources/LiteRTLM/` path 404s — the real layout is only visible from the clone).

**Paths forward (operator decision):**
1. WAIT for Google to repair the LFS object / cut a fixed tag — then `url:` resolution works (preferred).
2. VENDOR it: locate the real `swift/` wrapper layout via the GitHub tree API, vendor those sources +
   declare a LOCAL `binaryTarget(path:)` against the downloaded `CLiteRTLM.xcframework` — bypasses the
   repo clone entirely. Substantial; only worth it if the probe is urgent and (1) is slow.

Until then the probe stays a build-green guarded SKIP stub (`BASLiteRTE4BProbe.swift` /
`BASVerifierLaneABProbe`-style harness ready); steps 1-6 below resume once a resolvable package exists.

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
- **Cancellation (built in):** the `cancel_interrupted=` field + the `note=…cancel[…]…` detail report
  the dedicated mid-decode test — a long decode with `convo.cancel()` fired ~2s in from a concurrent
  task. `cancel_interrupted=true` means the stream stopped promptly after cancel → **LiteRT decode is
  interruptible → escapes the ADR-038 uncancellable wedge** (the biggest possible win).
  `NOT-interrupted-*` (ran to cap / 60s deadline / slow-stop) means it's the same wall MLX hits. (Honest
  caveat: a true zero-token hard-hang would block the probe itself — backstopped by the external kill.)

## Step 6 — promote (only if the probe pays)

If E4B fits + acceptable tps + cancellable/no-wedge → promote to a real `BASLiteRTOrganAdapter`
(the 3-method `BASOrganAdapter` conformance + a `.litert` `BASProviderKind` case, `.experimental`
`BASCertificationTier`), per `LITERT_LM_STUDY.md` §6.5. Otherwise record the DECLINE with the measured
numbers — a negative result is output (亏的不要).
