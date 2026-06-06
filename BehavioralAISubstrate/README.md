# BehavioralAISubstrate

`BehavioralAISubstrate` is a private Apple-only substrate for behavior-aware host apps. It is the canonical **14-layer 电子脑** (L1-L14). The legacy `Before` reference host was severed 2026-05-20 — see `/Archive/Legacy/` at the repo root.

## Products

16 libraries + 1 executable, exported from `Package.swift`. Hosts should
default to importing `BASHostKit` only;the other modules are dependency
implementations that BASHostKit composes on the host's behalf。 Advanced
integrations (debug consoles, custom orchestration, host-side bench harnesses)
may import lower-level modules directly,subject to the import-boundary check
documented at the bottom of this README。

### Façade layer (the only recommended entry point for most hosts)

- `BASHostKit`: façade-first host integration surface — composes everything
  below into one `BASHostRuntime`。 Default import for all hosts。

### Runtime + decision-plane layer (L3-L12)

- `BASRuntimeCore`: routing, execution budgets, provider planning,
  thought-fold observations,calibration store (L3-L7, L9 coordinator,L12)
- `BASMemory`: event, memory, brain, projection, governed retrieval,
  vector index,KV cache,SQL persistence (L8)
- `BASPolicy`: boundary, policy, risk plane, permit escalation,release
  controls (L11)
- `BASOrchestration`: prompt contract, workflow, execution lanes,
  tri-self court (L10)
- `BASObservability`: traces, telemetry, replay, inspection (L12)
- `BASEvaluation`: calibration, regression, drift detection

### Bottom-half infrastructure layer (L1, L2, L4, L14)

- `BASLeaseLife`: lease lifecycle, thermal + budget gating (L1)
- `BASOrgan`: neural organ math kernels, adapter routing,model provider
  abstraction (L2)
- `BASWorldPrior`: world prior knowledge inflow (L4)
- `BASSovereign`: sovereign verdict + audit ledger,token authority,
  CryptoKit chain primitives (L14) — **3 of the 3 production-default Rust
  flips live here** (chain seal 1.24×,verdict engine 13.84×)

### Adapter + capability layer (host-pluggable)

- `BASAppleAdapters`: Apple-specific lifecycle, handoff, reopen, notification,
  runtime bridges
- `BASChatCompletionsAdapter`: generic remote-LLM organ (HTTP / chat
  completions API)
- `BASMLXAdapter`: on-device MLX-Swift adapter (Gemma + similar local models)
- `BASMetalSubstrate`: Metal kernels — SSM scan,batched cosine,
  FlashAttention,scaled-dot-product attention (MSL),MPSGraph
  attention (chapter 八百七十 wire,2.31-3.09× faster than FA at
  production attention shapes),MPSGraph MatMul actor (chapter
  八百七十一 split-flip,1.07-1.38× over MSL at workProduct ≥ 256³,
  default ON via `BASCognitiveBrain.mpsGraphMatMul` + auto-routed
  `BASCognitiveBrain.matMulAuto`),RoPE,RMSNorm,etc.
  (Note:`.metalMatMulMPSGraph` enum case is a historical naming
  legacy and actually routes to MSL,not MPSGraph — see chapter
  八百七十一 narrative;the true MPSGraph path is
  `.metalMatMulMPSGraphActor`。)

- `BASMemory`: in-memory atom store + vector retrieval。
  `BASVectorIndex.topK` (chapter 七百十八 + chapter 八百七十二) now
  default-routes through Rust+rayon batched cosine — **268× faster
  at 1K corpus,490× faster at 5K corpus** vs the Swift per-pair
  loop。 Auto-selects between sequential SIMD (corpus < 3000) and
  rayon-parallel chunked v2 (corpus ≥ 3000) per
  `BASAutoRouteThresholds.batchedCosineRayonMinRows`。

- `BASRuntimeCore.BASAutoRouteRanker`: per-op routing decisions
  with measured M-series defaults。 Public threshold struct
  `BASAutoRouteThresholds` (Codable schema v3 post chapter 八百七十七)
  is host-overridable for per-device tuning。 **Migration note:**
  existing v2 on-device calibration caches are NOT breaking-
  upgraded — the v3 schema decoder rejects v2 with
  `.staleCache(reason: "schema version mismatch")` and the host
  re-calibrates on next launch (graceful degradation per
  `BASAutoRouteCalibrationStore.validate(...)`)。 No host-code
  change required;the first post-upgrade launch is slightly
  slower while calibration runs。

### Admin + debug surfaces (opt-in)

- `BASAdmin`: flight deck, console, capability coverage — `BASHostKit`
  hosts gated to debug/inspection surfaces only (enforced by
  `check_sdk_import_boundaries.sh`)

### Executables

- `BASBrainCLI`: command-line runner for substrate primitives — used by
  bench harnesses + diagnostic scripts

## Integration Strategy

Default hosts should import `BASHostKit`.

Product language stays in the host. The substrate exposes generic workflow and lifecycle vocabulary, while each host translates its own mode names, tabs, branded flows, and legacy identifiers at the edge through host-owned compatibility and migration layers.

```swift
import BASHostKit

var configuration = BASHostConfiguration.fixtureGeneric
configuration.workflowBehavior = BASHostWorkflowBehaviorConfiguration(
    hostNamespace: "host"
)

let runtime = BASHostRuntime(
    configuration: configuration,
    dependencies: BASHostDependencySet()
)

let result = runtime.startSession(
    BASHostSessionRequest(
        kind: .interactive,
        workflowProfile: .primary,
        surface: .application,
        prompt: "Should I do this right now?"
    )
)
```

The façade returns:

- `BASHostSessionResult.currentBrain`
- `BASHostSessionResult.projection`
- `BASHostSessionResult.consoleSnapshot`
- `BASHostSessionResult.notices`
- `BASHostSessionResult.followUpActions`

Hosts can also inject their own:

- workflow titles
- workflow template IDs
- workflow memory source mapping
- workflow retrieval defaults
- execution-profile thresholds and runtime explanation copy
- prompt vocabulary, guards, and presentation copy
- memory-derivation IDs, headlines, and provenance wording
- host namespace for verification and projection provenance
- lifecycle titles
- lifecycle notices
- follow-up action phrasing
- predictive intervention copy
- reopen wording
- legacy identifier compatibility
- bootstrap alias and fallback policy

through `BASHostConfiguration.presentation`, `BASHostConfiguration.workflowBehavior`, and `BASHostConfiguration.lifecycleBehavior.currentBrainBootstrapBehavior`, so the substrate keeps generic behavior while each host keeps its own product DNA.

## Reference Hosts

- [`SampleHost`](/Users/changgeng/Project/Project06/Project06/SampleHost): minimal façade-only iOS host (the substrate's only living reference)
- Legacy `Before` host preserved at `/Archive/Legacy/Before/` for historical reference; not built, not tested, not on the substrate's dependency graph.

## Current Delivery Model

- Apple-only
- private integration SDK
- fast-evolving contract
- monorepo source of truth
- ready to split into a dedicated private SDK repo later

## Validation

Primary validation lives in:

- `cd BehavioralAISubstrate && swift build` (SPM,no Xcode required)
- `cd BehavioralAISubstrate && swift test --disable-swift-testing`
  (headless XCTest gate; monolithic `swift test` still hits a
  swift-testing helper SIGBUS in headless macOS)
- `xcodebuild test -scheme SampleHost` (optional Apple-platform integration smoke)

## Import Boundary

Host targets should use `BASHostKit`, not low-level BAS module imports.

Run:

```bash
./scripts/check_sdk_import_boundaries.sh
```

This also runs `./scripts/check_substrate_residuals.sh`, which fails if legacy host vocabulary leaks back into the substrate sources, README, or non-whitelisted package tests.

## Runtime crash contracts (read before passing config values)

The substrate uses `precondition(...)` + `fatalError(...)` for init-time
invariants — if a host passes a value that violates the documented contract,
the app will **crash in production** (no runtime recovery)。 These guard against
silently-wrong behavior downstream and are deliberate。 Documented foot-guns:

### `BASCognitiveOSConvenience` (host config validation)

| Field | Contract | Crash if violated |
|---|---|---|
| `stateFoldInterval` | `> 0` seconds | yes |
| `graphExtractInterval` | `> 0` seconds | yes |
| `graphExtractEventCap` | `> 0` events | yes |
| `thermalSlowdownMultiplier` | `>= 1` (1.0 = no slowdown) | yes |
| `thermalSampleInterval` | `> 0` seconds | yes |

### `HostPresentationConfigurationsCore`

Four `fatalError("Unavailable")` sites on intentionally-blocked init paths。
Concrete shape:if you construct a `BASHostPresentationConfiguration` through
a code path the substrate hasn't whitelisted for your host kind,you get
a hard crash with the「Unavailable」message。 Use the recommended factory:
`BASHostConfiguration.fixtureGeneric.presentation` or your host's typed
config bundle。 Don't bypass through reflection or partial init。

### `BASSovereignAuditLedger` (L14)

One `fatalError(...)` at the entry-point of the chain-seal hot path,fires
ONLY if the canonical-bytes encoding produces a length the Rust verifier
rejects as malformed。 Cannot fire in normal substrate usage (chapter
七百十六 byte-equality test pins this);included as a 安全 floor against
future refactor regressions。

### `BASTrainingDataExporter` / `BASTrainingExampleSublimator`

`precondition(pageSize > 0)`,`precondition(pinned >= 0)`,
`precondition(flushThreshold > 0)` — bench-harness config validation。
Affects only bench / training-data workflows,not the live substrate runtime。

### How to test your host's config

Run your host's startup smoke under XCTest with the same `BASHostConfiguration`
you'll ship。 If a precondition fires,XCTest reports it as a hard test
failure with the violating field name + value。 No runtime recovery — fix
the config。
