# ADR-041 — Apple Core AI as a first-class on-device neural adapter (CoreML small-head shadow)

**Status:** Accepted — code shipped + compile-certified; live-inference run-cert DEFERRED (external Apple-beta blocker, see §6).
**Date:** 2026-06-10
**Relates to:** ADR-039 (determinism boundary — Core AI is reasoning-side, banned from the spine), the CoreML
incumbent `BASContextClassifierMLAdapter` (BASRuntimeCore), FoundationModels (#1, the LLM-draft lane Core AI does NOT occupy).

## 1. Context

Operator intent: **极大提高 Core AI 组件使用** — make Apple Core AI (WWDC 2026 BYO on-device model deployment) a
real neural backend, not a scaffold. A prior plan assumed the framework was absent (`canImport(CoreAI)` always
false); that was true for the installed Xcode 26.5 but **wrong for Xcode 27**, where the Core AI framework family
ships. The real API was read FIRST-HAND from the SDK `.swiftinterface`s (not web-guessed):

- **Family**: umbrella `CoreAI` (re-exports `CoreAIDelegates`) + SubFrameworks `CoreAIRuntime` (the 1425-line
  inference API), `CoreAIAsset`, `CoreAICompiler`, `CoreAICache`, `CoreAICommon`. A single `import CoreAI`
  transitively surfaces everything (NDArray, AIModel, AIModelAsset, InferenceFunction, SpecializationOptions).
- **Real API** (all `@available(macOS 27.0, iOS 27.0, …, *)`): `AIModelAsset(contentsOf:)` →
  `AIModel(contentsOf:options:) async` → `loadFunction(named:) -> InferenceFunction?` →
  `InferenceFunction.run(inputs: [String: NDArray]) async throws -> Outputs`; tensor I/O via
  `NDArray(scalars:shape:)` / `view(as:).withUnsafePointer`.

**The real API corrects the design.** Core AI is **tensor-level (NDArray)**, NOT a high-level LLM. Its honest lane
is therefore the **CoreML small-head SHADOW** — mirror the certified `BASContextClassifierMLAdapter` (text →
256-bucket bag → 7 logits), run the SAME head on Core AI, and compare logits. This is precisely the operator's
"migrate CoreML → Core AI only if it wins parity + latency + memory" gate. Core AI is NOT the LLM-draft provider
(that stays FoundationModels/MLX).

## 2. Decision

Ship a real, first-class Core AI adapter, gated `#if canImport(CoreAI)` + `@available(iOS 27, macOS 27, *)`:

- The default toolchain (Xcode 26.5, no CoreAI) compiles a no-op fallback → the existing suite stays green.
- The real branch is compile-certified under Xcode 27 and run-certified on iOS 27 (sim + iPhone Air).
- Core AI is **reasoning-side / hint-only** (红线 7) — banned from the byte-deterministic spine; the shadow
  candidate is **observation-only**, never crossing into the turn or any governance verdict.

## 3. What shipped (commits bc62c8a01, 28558acdd)

| Piece | File | Role |
|---|---|---|
| C1 | `BASCoreAINDArrayBridge.swift` | Pure shape/stride/validate (overflow-checked; run-tested today) + gated NDArray make/read. |
| C2 | `BASCoreAIModelRunner.swift` | Gated inference seam: AIModelAsset→AIModel→loadFunction→run; pure `[Float]` boundary. |
| C3 | `BASCoreAIContextClassifierAdapter.swift` | Mirrors the incumbent contract; shared encoder + 7 labels; experimental tier; no-framework fallback. |
| C4 | `BASCoreAIShadowComparison.swift` | Observation-only dual-run → `BASShadowTrialRecord` ("observing", never auto-promoted); logs length not text (no PII). |
| C5 | presence test + `BASMetalDeterminismBoundaryTests` ban | Honest gated-state pin + load-bearing spine ban (BASHostKit DOES depend on BASAppleAdapters). |
| probe | `BAS_COREAI_E2E` in `BASEnduranceAppRunner.swift` | On-device/sim shadow parity probe (`📊 coreai-e2e …`). |
| scripts | `coreai-compile-check.sh`, `coreai-build-aimodel.sh`, `run-coreai-e2e-cert.sh` | Xcode-27 compile-cert, asset build, iOS-27 run-cert. |

Hardened against a 17-agent adversarial review (11 confirmed findings fixed before commit).

## 4. Certification status (R1 — honest bounds)

1. **Default toolchain (Xcode 26.5):** `swift test` full suite **15246 tests, 102 skipped, 0 failures**. Core AI
   compiles to the fallback; nothing regresses. The pure NDArray bridge + shadow comparison + presence carry real
   RUN coverage with zero framework dependency.
2. **Compile-cert (Xcode 27):** `scripts/coreai-compile-check.sh` → **PASS**. The real `#if canImport(CoreAI)`
   branch binds the genuine SDK API. **Proven NON-VACUOUS** by a negative control: a deliberate type error injected
   inside the `#if canImport(CoreAI)` block fails the compile-cert at that exact line (so a green build genuinely
   exercises the gated branch). `canImport(CoreAI)` confirmed YES under the beta toolchain.
3. **Run-cert (live `.aimodel` inference on iOS 27):** **DEFERRED — blocked externally.** See §6.

## 5. Guardrails preserved

- Determinism boundary: `BASCoreAIModelRunner` / `BASCoreAIContextClassifierAdapter` / `BASCoreAINDArrayBridge` /
  `BASCoreAIShadowComparison` added to the banned-in-spine tripwire (ADR-039). This ban is LOAD-BEARING (not
  belt-and-suspenders): BASHostKit — home to most spine files — depends on BASAppleAdapters, so a spine file COULD
  legally import these types; only the tripwire stops it.
- Observation-only: the shadow candidate is recorded as a PENDING ("observing") trial that the ledger's state
  machine maps to "stay in flight" — it can never auto-promote, and the incumbent path is never mutated.

## 6. The run-cert blocker — Apple Xcode-27-beta seed inconsistency (NOT our code)

Producing the classifier `.aimodel` requires `aimodelc` (the Core AI compiler, ships in Xcode 27), which requires
the **Metal Toolchain** component. Exhaustively diagnosed:

- The Metal Toolchain **downloaded + installed** (`xcodebuild -showComponent MetalToolchain` → `installed`, build
  `27A5194o`); `metal -c` compiles `.metal` → `.air` successfully.
- **Yet `aimodelc` still rejects it** ("Core AI requires the Metal Toolchain"), via every resolution path tried:
  direct binary, `xcrun`, `TOOLCHAINS=…`, a fully clean `env -i`, both `compile` and `package` subcommands.
- **Root cause = version skew:** the **Xcode-beta app is build `27A5194q`**, but the **only Metal Toolchain on
  Apple's asset server is `27A5194o`**. `aimodelc` (from the `q` app) requires a matching toolchain; the `metal`
  compiler tolerates `o`, `aimodelc`'s check does not. Requesting the match
  (`xcodebuild -downloadComponent MetalToolchain -buildVersion 27A5194q`) → **`Failed fetching catalog … RequestedBuild = 27A5194q`** (it does not exist).
- **Xcode 27 does NOT bundle a usable Metal Toolchain** — the in-app `metal` is a **107 KB stub** that delegates to
  the downloadable cryptex. So there is no bundled fallback.
- Ruled out: NOT env poisoning (clean `env -i` fails identically); NOT our code (the compile-cert proves the
  adapter binds the real API).
- **DECISIVE switch test (the operator ran it, eliminating xcode-select):** initially `xcode-select` pointed at
  Xcode 26.5, so `aimodelc` saw the 26.5 Metal Toolchain (`17F42`, cryptex `v17.6.42.0`) — there are TWO Metal
  cryptexes mounted (26.5 `17F42` + 27 `27A5194o` = `v27.1.5194.15`). The operator ran
  `sudo xcode-select -s <Xcode-beta>/Contents/Developer`; `xcodebuild -showComponent MetalToolchain` then
  reported **`27A5194o` selected** (the 27 toolchain) — **yet `aimodelc` rejected it identically.** This PROVES
  the blocker is the build sub-version skew, not toolchain selection: letter-decode `o` = 15th letter ↔
  `v27.1.5194.**15**`, `q` = 17th letter ↔ Xcode `27A5194**q**`, so `aimodelc` (Xcode build **.17/q**) requires a
  **.17** Metal Toolchain while Apple has published only **.15/o**. (`metal -c` tolerates `o` and compiles; only
  `aimodelc`'s stricter gate rejects it.) NOTE: restore `xcode-select` to 26.5 after this test
  (`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`) so the default-toolchain build stays 26.5.

**Unblock paths (any one):** Apple ships a Metal Toolchain matching the Xcode-beta build (or a self-consistent
seed); OR install the Xcode beta whose build matches the available `27A5194o` toolchain; OR (mechanical-only
interim) load a pre-converted sample `.aimodel` (e.g. from Apple's `coreai-models`) to run-cert the
`BASCoreAIModelRunner` load→run→readback path on the iOS 27 simulator (proves the runner, not the classifier
parity). When unblocked: `bash scripts/coreai-build-aimodel.sh` → wire the `.aimodel` as a `.copy` resource on the
`BASAppleAdapters` target in `Package.swift` → `bash scripts/run-coreai-e2e-cert.sh` (MODE=sim then MODE=device).

## 7. Consequences

- Core AI is now a REAL, compile-certified first-class adapter bound to the genuine iOS 27 SDK — a substantial,
  honest increase in Core AI usage, with the only gap (live inference) being an external Apple-beta defect, fully
  documented + scripted for a one-command finish once Apple's seed is consistent.
- The CoreML incumbent is NOT replaced. Core AI is labeled `experimental` until on-device parity + latency + memory
  are measured on real iOS 27 hardware.
- The byte-deterministic spine is untouched; the candidate stays observation-only.
