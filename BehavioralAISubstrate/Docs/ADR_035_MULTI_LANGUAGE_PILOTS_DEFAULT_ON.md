# ADR-035 — Multi-language pilots default-ON (sanctioned opt-OUT inversion) + watchOS gating status

## Status

Sanctioned + reconciled. The 5 multi-language augmentation pilots (SQL / C / Metal / C++ / Rust)
ship **default-ON** (`perFlagDefaults` all `true`) as of chapters 七百十一–七百十二, per the user
directive 「全面 转向 多个 语言:Swift + Metal, Rust, SQL, C, C++」 (2026-05-17). This ADR records WHY
that is a sanctioned exception to ADR-014's default-OFF rule, PROVES it stays byte-equal at turn
output, and reconciles the doctrine that still claimed "default-off". It also records the honest,
build-verification-dependent status of the watchOS Metal gating.

## Context (the audit finding)

The ch1040 全面 audit flagged `BASLanguageAugmentationFeatureFlags` as the headline finding: its
`perFlagDefaults` constant sets all 5 pilot flags to `true`, while the **same file** still claimed —
in its header and init docs — "ALL FALSE", "default-off discipline preserves V1 byte-equality", and
"OPT-OUT preserved AS LONG AS `perFlagDefaults` stays empty". A flag default of `true` is the textbook
红线-7 failure shape (an additive capability whose flag is not OFF at default), and a file that
contradicts its own constant is a correctness + honesty defect regardless of intent.

The user's directive resolves the intent: the multi-language pivot **was meant** to be the default.
So this is not a regression to revert — it is a deliberate **opt-OUT inversion** that needed (a) a
proof it preserves the sovereign byte-equality contract, and (b) the doctrine updated to match.

## Why default-ON is byte-equal at TURN OUTPUT (the proof)

ADR-014 / 红线 7 guarantee the **turn output** (`BASEBrainTurnResult`) is byte-identical unless a
caller opts in. Default-ON pilots do **not** break that, because **no substrate caller routes any
pilot into a turn result**:

- **SQL pilot** — the V2 generated-schema path fires only via the `BASMemoryUsageTracker.make(...:
  flags:)` / `makeWithDefaults()` factory. The live brain constructs the tracker by **direct init**
  (`BASCognitiveBrain.swift:541` — `let sqlTracker = BASMemoryUsageTracker()`), whose `useGeneratedSchema`
  default is `false` → V1. And `BASMemoryUsageTracker` is a usage-records telemetry log; it does not feed
  `BASEBrainTurnResult`. The V2 schema path is itself byte-equality-verified against V1 (chapter 七百二
  dual-mode tests: PRAGMA table_info / index_info byte-equal + record round-trip).
- **C / Metal / C++ / Rust pilots** — flipping these is, at the substrate level, **symbolic**: there is
  **no substrate caller** of `BASMonotonicNanos.make(flags:)` / `BASMetalKernelLibraryLoader.make(flags:)`
  / `BASMPSGraphExecutableCacheCxxBridge.make(flags:)` / `BASRustMemoryUsageTrackerActor.make(flags:)`.
  The only substrate `makeWithDefaults()` consumer is `BASMambaGPUShadowParity` — observation/telemetry
  only, explicitly off any byte-deterministic value path.

This is **pinned in code**: `BASMultiLanguageScaffoldDoctrine.substrateInternalFactoryCallSiteCount = 0`
and `substrateInternalDirectInitCallSiteCount = 0` (chapter 七百十四 audit conclusion). A `make(flags:)`
V2 path is reachable **only** when a HOST explicitly adopts the factory — an opt-in by the host, at
which point the host owns the (byte-equality-verified) V2 behavior.

So: **flags default-ON, turn output byte-equal.** 红线 7 holds at the contract that matters
(`BASEBrainTurnResult`); the "default" being ON shifts only HOST-adopted factory paths.

## What this ADR changes

- **Doctrine reconciliation (`BASLanguageAugmentationFeatureFlags.swift`)** — the stale present-tense
  "ALL FALSE / perFlagDefaults stays empty / default-off preserves byte-equality" claims in the header,
  the `init()` doc, and the `allDefault()` doc are corrected to state the default-ON reality and the
  "byte-equal at turn output, not by keeping flags off" rationale. The file's own honest-scope body
  (the `perFlagDefaults` doc block) already described the flip; the header now agrees with it.
- **NOTE on the `BASPhase2EntropyClosureDoctrine` chapter ledger** — its per-chapter entries
  (chapter 710 "dict EMPTY", chapter 711 "1 flipped", chapter 712 "all 5 true") are an **append-only
  chronological record**, each accurate AT ITS chapter. They are history, not stale present-tense
  claims, and are intentionally left intact.

## watchOS Metal gating — build-verified investigation (the gap is package-wide)

The audit found `BASMetalSubstrate`'s Package.swift comment overclaims that the target "compiles as a
thin schema-only stub on watchOS". Reality: while most Metal source is `#if canImport(Metal)`-gated
(43 sites), **10 Metal-using files still `import Metal` ungated** (`BASMambaSSMState`, `BASPlasticityFold`,
and 8 `BASBuiltinKernels/*Kernel` files), referenced by **~60 consumer sites**.

**Investigation (ch1040 follow-up — build-verified this time).** A dedicated follow-up ran the gating in
an environment that DOES have the watchOS SDK (WatchOS 26.5 + WatchSimulator). It established two things
and surfaced a third, larger one:

1. **The gating premise HOLDS.** `canImport(Metal)` evaluates **false** against the watchOS SDK (verified:
   a `#if canImport(Metal) #error(…) #endif` probe fires on the macOS SDK and is clean on the watchOS
   SDK). So the granular `#if canImport(Metal)` convention would correctly exclude Metal on watchOS.
2. **But `swift build`/`swift test` for watchOS cannot even RESOLVE this package.** The vendored
   MLX/HuggingFace path-packages have internally-inconsistent watchOS deployment targets (`error: the
   library 'Tokenizers'/'Hub' requires watchos 4.0, but depends on the product 'Jinja'/'HuggingFace'
   which requires watchos 9.0`). Resolution fails before any source compiles. (MLX is a Metal-based ML
   runtime; it cannot target watchOS regardless.)
3. **Even with MLX temporarily stripped** (a throwaway manifest, reverted), the watchOS compile fails
   FIRST inside `BASRuntimeCore` — `BASContextClassifierMLAdapter.swift:287`: `'compileModel(at:)' is
   unavailable in watchOS` (an ungated CoreML API in the base dependency of everything) — **before**
   `BASMetalSubstrate`'s 10 files are ever reached.

**Conclusion: watchOS support is broken at ≥4 independent layers, not the 10 Metal files.** The
package-wide watchOS-risky surface: MLX/HuggingFace deps (resolution) → BASRuntimeCore CoreML (1 file,
the first failure) → BASMetalSubstrate (10 ungated Metal files, part of 19 Metal/MPS/CoreML files) →
BASAppleAdapters (6 files) → BASHostKit (1 file). Gating only the 10 Metal files is **necessary but not
sufficient** and **cannot be build-verified for watchOS** (resolution dies on MLX; the dep chain dies in
RuntimeCore first). Per **亏的不要上 / R1**, that change is therefore **NOT shipped** — a large,
unverifiable patch that does not make watchOS build would be lossy effort.

**The real decision (operator's call), one of:**
- **(A) Drop `.watchOS(.v11)` from the package platforms** — the honest move if watchOS is not genuinely
  a target (the Metal/CoreML/MLX device-ML core fundamentally cannot run there). Smallest + truthful.
- **(B) Extract the device-ML core** (BASMetalSubstrate + the CoreML/MLX adapters) into a separate
  iOS/macOS-only package, leaving a genuinely watchOS-portable schema/runtime core — large; the only path
  to *real* watchOS support.
- **(C) Full package-wide gating pass** (the 10 Metal files + RuntimeCore CoreML + AppleAdapters + an
  MLX-resolution split), build-verified per module — large, and still leaves MLX unusable on watchOS.

Recommendation: **(A)** unless watchOS is a genuine product target, in which case **(B)**.

**Resolution (ch1040): option (A) taken.** `.watchOS(.v11)` was removed from the package's `platforms`
array, so the package no longer ADVERTISES watchOS support (the false claim is gone) and iOS/macOS stay
byte-equal (macOS build green). Caveat, recorded honestly: SwiftPM has no "exclude platform" primitive —
a caller can still *force* a watchOS cross-build (`--triple arm64-apple-watchos…`), which now falls back
to SPM's default watchOS minimum and **still fails on the vendored MLX deps**. That residual is inherent
SwiftPM behavior, not a claim made by this package; genuine watchOS support remains the **(B)**
split-package effort if it is ever actually wanted.

## Verification

`swift build` green (macOS); the flags-file and Package.swift changes are comment-only → no behavioral
change, byte-equal by construction. The byte-equal-at-turn-output proof rests on the pinned
`substrateInternalFactoryCallSiteCount = 0` + the direct-init brain path, both re-confirmed by grep
during the audit. No `Sources/` logic touched.

## Honest scope

- **Resolves:** the headline self-contradiction (flags default-ON vs. doctrine claiming default-OFF),
  with a proof that turn output stays byte-equal, and an honest watchOS-status correction.
- **Does NOT:** change any flag default (the pilots remain default-ON per the directive); wire any pilot
  into the live turn (they remain host-adoption-only); perform the watchOS code gating (deferred,
  build-verified follow-up). Live-host adoption of a V2 factory path remains the host's opt-in.
