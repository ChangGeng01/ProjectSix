# Toolchain / API currency audit — 2026-06-30

Outcome of a 7-point "is the project non-latest?" audit against local `Xcode 27.0 (27A5194q)` / `Swift 6.4`
and the latest public Apple / MLX / coremltools info. Every repo claim was re-verified against the live files;
external (post-Jan-2026-cutoff) claims were web-checked and are marked as such.

**Headline: the audit was factually true (7/7 repo facts confirmed), but the *actionable* surface is tiny —
most "non-latest" points are deliberate, justified choices, not staleness.** The MLX LLM main stack is current
(vendor re-vendored 2026-06-11 to `mlx-swift-lm 3.31.x`). The genuinely-lagging surfaces are the Apple
new-interface adapter path, the CoreML/CoreAI production tradeoff (deliberately not migrated), and
manifest/doc declarations.

## Per-point verdict

| # | Claim | Verdict | Actual value (verified) | Disposition |
|---|-------|---------|-------------------------|-------------|
| P1 | first-party `swift-tools-version: 6.0` vs toolchain 6.4 | TRUE | all 3 manifests line 1 = `6.0` | **LEAVE** — compat floor (see D1) |
| P2 | min-OS iOS 18 / macOS 14 / watchOS 11 | TRUE | as stated | **LEAVE + this note** (see D2) |
| P3 | FM path uses bare `LanguageModelSession()` | TRUE | 3 SampleHost sites | **LEAVE** — intentional (see D3) |
| P4 | CoreML still prod; CoreAI `doNotMigrate` | TRUE | `COREAI_RUNCERT_BACKLOG.md` GATE CLOSED, 112×2 paired | **LEAVE** — evidence-backed |
| P5 | convert pipeline = coremltools `.mlpackage` + CoreAI bypass | TRUE | both `convert.py` + `convert_coreai.py` exist | **LEAVE** — ADR-041 shadow-test |
| P6 | vendor manifests old (mlx-swift 5.12 / swift-syntax 5.8 / yyjson 5.0) | TRUE | exact | **LEAVE** — compat floors on fresh code |
| P7 | doc says app `SWIFT_VERSION = 5.10` | FALSE (doc was wrong) | reality = `6.0` everywhere (`project.yml:33`, pbxproj 2×6.0) | **FIXED** 2026-06-30 (5.10→6.0) |

## Decisions

**D1 — first-party `swift-tools-version` stays `6.0` (do not bump to 6.4).**
`swift-tools-version` is the *minimum toolchain that can build the package*, not a declaration of what you use.
The manifests use no 6.4-only PackageDescription features (they build fine at 6.0), and `QinaoRuntimeSDK` is a
consumed SDK — a `6.0` floor = broader consumer-toolchain compatibility. Bumping to 6.4 would raise the build
floor for zero functional gain. Same reasoning as P6 (vendor) — a low floor is a feature, not staleness. Bump
only if a specific 6.4 manifest feature is ever needed.

**D2 — iOS 18 minimum is a deliberate +1 margin, not dependency-forced.**
Verified transitive dependency floors: `mlx-swift` / `mlx-swift-lm` = iOS 17, `swift-transformers` / `swift-jinja`
/ `swift-huggingface` = iOS 16, `swift-syntax` = iOS 13, `LiteRT-LM` = iOS 15. The binding runtime constraint is
**iOS 17 (MLX)**; our declared `iOS 18` is one version above it. The watchOS 11 floor is documented (ADR-035); the
iOS 18 (vs the iOS-17-possible) floor was previously **undocumented** — this note is the record. Keep iOS 18
unless MLX-era (iOS 17) device coverage becomes a product goal, in which case iOS 17 is the lowest MLX-compatible
floor.

**D3 — the 3 SampleHost bare `LanguageModelSession()` sites are INTENTIONAL; do not "route them through the adapter".**
`SampleHostAFMBenchEntry.swift:~144` benchmarks *raw* Apple Foundation Models latency/success — routing it through
`AppleFoundationOrganAdapter` would corrupt the measurement (it would time adapter+FM, not raw FM).
`SampleHostSinglePromptTests.swift:~54` is a raw-AFM probe; `SampleHostLLMHelpers.callAFM:~153` is a sample helper
parallel to `callGemma` showing the direct call. SampleHost is a *demo/bench* host — raw usage is the point. The
**production** FM path (`AppleFoundationOrganAdapter.swift:131`) already wraps `LanguageModelSession` correctly
inside the `BASOrganAdapter` contract. (An automated review mis-flagged these as "architecture debt"; reading what
they are dissolved it. A guard comment is placed at the bench site.)

## Forward backlog (not yet actionable)

**FM provider abstraction — WWDC26 `LanguageModelExecutor` / provider pattern** (front MLX / third-party models
through Apple's Foundation Models entry). This is the one genuine *future* architecture item. It is **not** a
cleanup and must not be built speculatively:
- iOS 27 API; its exact Swift signatures are currently **web-corroborated only** (WWDC26 session 339 + secondary
  write-ups), **not** Apple-doc-byte-verified (the docs page is JS-rendered).
- Adopt only after the API surface is doc-verified, and then **prototype-and-measure** — none of the logged
  MLX-jetsam / streaming-fidelity constraints are waived by it.
- The natural seam is `AppleFoundationOrganAdapter` (already conforms to `BASOrganAdapter`), not the SampleHost
  demo sites.

## External-claim provenance (post-Jan-2026 cutoff — web-checked, not from training)

- Xcode 27.0 ships Swift 6.4 — **web-confirmed** (beta evidence).
- Core AI positioned as the new on-device BYO-model framework — **web-confirmed** (iOS 27 "What's New").
- `coremltools 9.0` stable (2025-11), `mlx-swift-lm 3.31.x` — **web-confirmed** (PyPI / GitHub). Note:
  `mlx-swift-lm` (3.x) ≠ core `mlx-swift` (vendored manifest 5.12) — different packages.
- WWDC26 `LanguageModelExecutor` provider API signatures — **web-corroborated, NOT doc-verified** (see backlog).
