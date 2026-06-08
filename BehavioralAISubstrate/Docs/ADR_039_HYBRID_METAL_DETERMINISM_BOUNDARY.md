# ADR-039 — Hybrid Metal/CPU determinism boundary (the doctrine for real GPU compute)

> **Status: ACCEPTED — Phase 0 LANDED (the enforcement primitive + tripwire). Phases 1–4 are the wiring,
> each opt-in / on-device-gated.** The operator's rule for moving REAL compute onto Metal (GPU) without
> forfeiting the substrate's byte-determinism. Governs the phased Metal roadmap (L8 retrieval, SSM, the
> kernel router, the endurance instrumentation).

## 1. Context

The substrate ships a rich Metal library (raw dispatchers + MPSGraph kernels + Mamba SSM + classifiers /
registry / thermal policy) but it is **100% probe/telemetry** — `brain.process()` / `runTurn` invoke
none of it (`substrateInternalFactoryCallSiteCount = 0`). The operator wants real GPU compute on the main
chain. Two facts make this dangerous without a rule:

1. **Metal is non-bit-reproducible.** GPU FMA-reordering + scheduling mean a Metal float result is not
   replayable bit-for-bit. The substrate, by contrast, is **byte-deterministic / replay-stable** (ch883):
   the same inputs must reproduce the same verdict, the same durable write, the same replay digest. Metal
   on the value path breaks that — irreversibly, on the affected path.
2. **Metal can WEDGE uncancellably.** ADR-038 proved on real hardware that a synchronous Metal eval owns
   its thread until the GPU returns; a Swift task cannot cancel it; a per-turn timeout was tried and
   REMOVED because it hangs in teardown. Prevention + an external watchdog are the only levers.

## 2. The RULE (operator's hard doctrine)

- **REQUIRE byte-determinism → CPU / Rust (Metal FORBIDDEN):** Storage, Memory (durable atom store / SQL /
  vector-index persistence), Event Log, Replay, **Governance** (the risk → permit → verdict → commit-token
  spine).
- **ALLOW approximate → Metal (non-byte-equal opt-in OK):** Embedding, LLM decode, Planning, Reasoning,
  Animation, Perception.
- **THE BOUNDARY RULE:** a Metal result must NEVER cross into the byte-deterministic spine raw. It may
  compute an approximate retrieval *ranking* or a reasoning *signal*, but its output must not feed the
  verdict / risk-permit / durable-write / replay path unless it is first **snapped to determinism** by an
  audited CPU-deterministic projection.

Worked boundaries (verified against the code):
- **L8 retrieval**: the *ranking* (cosine/topK) is approximate → Metal-OK (ADR-036 already made cosineTopK
  the sole sanctioned non-byte-equal path). The atom *store* + *identity* (content-derived `atomID`) stay
  CPU/Rust; the seam returns `(atomID, score)` and the spine consumes only `atomID` — the Metal `score`
  orders the bundle, never persisted.
- **SSM (Mamba)**: `ssmCaution` mutates `boundRiskCard.totalRisk` → the verdict (governance — verified at
  `EBrainRuntimeCoordinator+RunTurn.swift:547-550`). It therefore stays **CPU** (`BASSSMScanCPUReference`).
  Metal SSM is allowed only on a NON-governance reasoning sink (it must not feed the verdict, and its
  state must never fold back into the deterministic `request.priorSSMState`).

## 3. Enforcement — in the TYPE SYSTEM, not just prose (Phase 0, LANDED)

Defense in depth; no single mechanism is trusted alone:

1. **Type quarantine — `BASApproxValue<T>`** (`Sources/BASMetalSubstrate/BASApproxValue.swift`). Metal
   dispatchers (as each is quarantined per-phase) return `BASApproxValue<T>` carrying a
   `BASComputeProvenance` (`.metal` / `.cpuFallback`). It has **no raw getter**; the only exits are
   `snapToDeterministic(...)` (an audited crossing returning a `BASBoundaryCrossingRecord`) and
   `approximateOnly()` (the approximate-side escape hatch). Spine functions take plain `T`, so a
   `BASApproxValue<T>` cannot be passed in without an explicit, named, audited crossing.
2. **Seam separation** — at the L8 seam, the *ranking* is approximate but the *atom store/identity* stay
   CPU/Rust (the spine consumes only `atomID`).
3. **Source-honesty tripwire** (`Tests/.../BASMetalDeterminismBoundaryTests.swift`, LANDED + green) — a
   build-time test that greps the byte-deterministic spine files and FAILS if any references a Metal
   dispatcher, `BASApproxValue`, or `approximateOnly`. Adding a new spine writer requires updating its
   allowlist, or the guard has a hole. (This also folds in the deferred WS5 Metal source-honesty work.)
4. **Audited crossings** — every `snapToDeterministic` emits a `BASBoundaryCrossingRecord`, so a replay
   can prove every Metal→spine crossing went through a deterministic snap, not a raw leak.

## 4. The verification gate (R1 / 亏的不要上)

Nothing ships/claims-"Metal is live here" on macOS-green alone. Each phase is:
- **opt-in / default-off / byte-equal-off** (a host that doesn't elect it is bit-identical);
- **parity-verified** (Metal ≈ CPU within a stated tolerance — the `BASMambaGPUShadowParity` 1e-5 pattern),
  per kernel, before it goes live;
- **wedge-safe by construction**: CPU/Rust fallback on ANY Metal failure; the deterministic path is NEVER
  blocked on a Metal call; hangs are detected by instrumentation (Phase 1 records + heartbeat) + an
  external watchdog (in-process cancellation is impossible — ADR-038);
- **on-device certified** (iPhone Air). A phase that wedges on-device **retreats to its documented
  fallback** + records the honest failure (ADR-038-style), never a forced enablement.

## 5. The phased roadmap (this ADR is the doctrine; the phases are the wiring)

- **Phase 0 (LANDED):** this ADR + `BASApproxValue` + the spine tripwire.
- **Phase 1:** per-Metal-kernel execution records (did-GPU-run / timing / fallback) + endurance log line
  + a hang-detection heartbeat (observability FIRST — you cannot safely wire Metal live without it).
- **Phase 2:** L8 retrieval ranking → Metal (new topK kernel, sync seam, Rust fallback).
- **Phase 3:** a real MPSGraph-vs-raw-Metal-vs-CPU dispatch router (deterministic CHOICE, approximate
  COMPUTE) for attention / RMSNorm / softmax + a thermal-critical→CPU branch.
- **Phase 4:** Metal SSMScan on a NON-governance reasoning sink (`ssmCaution` stays CPU).

## 6. Honest scope

- **Decode logits / sampling / masking are OUT** — they live inside closed MLX-Swift; there is no
  substrate hook without forking MLX. Only the substrate-owned post-process TEXT ops are reachable.
- Metal on the value path is **non-byte-equal by nature** — sanctioned ONLY on the approximate side.
  Governance / Memory-storage / Event-log / Replay stay CPU/Rust **forever**.
- No in-process Metal-wedge recovery exists or is added (ADR-038) — prevention + external watchdog only.
- This ADR supersedes the scattered "Metal is observation-only" notes (`BASMetalKernelLibraryLoader`,
  the classifier/policy `consultedByExecutorInProduction=false` comments) with one governing rule.

## 7. On-device cert — PASSED (Metal runs on the iPhone Air GPU), 2026-06-08

The Metal mechanisms (Phases 1-3) were certified on real hardware via a boot-time `BAS_METAL_SMOKE` in the
endurance runner (topK dispatch + on-device parity vs the CPU reference + the router decision). The cert
surfaced — and fixed — TWO real blockers behind the long-standing "probe-only / Metal contributes 0 to
live decode" status:

1. **The V2-guard.** `BASMetalKernelLibraryLoader.library()` short-circuits to `.metalUnavailableOnPlatform`
   unless `useMetalKernelV2: true` is requested (default false) — any caller using the default loader never
   reached the GPU. (`canImport(Metal)` is true on-device; it was NOT a real Metal-unavailable.)
2. **Source-vs-metallib.** SPM's `.process(...metal)` COMPILES all kernel `.metal` files into ONE
   `default.metallib`; the iOS-app bundle ships ONLY that (no `.metal` SOURCE), so the loader's runtime
   source-compile path threw `resourceURLMissing` on-device. Fixed: `library()` now prefers
   `device.makeDefaultLibrary(bundle:)` (the precompiled lib), falling through to source-compile.

**Result (iPhone Air, iOS 26.5):**
`📊 ch1025 metal-smoke gpu=true topk_ms=8.33 parity_set_ok=true max_score_err=0.000000 routing=ane-native hits=5`
— the Metal topK ran on the GPU, selected the SAME rows as the CPU reference, scores matching to 6 decimals.
**First on-device execution of the substrate's own Metal kernels, with parity.** The macOS parity test
(`useMetalKernelV2: true`) independently runs on the Mac GPU + passes.

**Honest scope:** this certifies the Metal MECHANISMS (dispatch + parity + records + the router decision)
on-device — the core claim "the substrate's Metal kernels really execute on the GPU + agree with CPU" is
now PROVEN, not inferred. It does NOT yet put Metal on the LIVE cascade: the L8 retrieval seam (corpus
extraction + the sync-bridge wiring) + Phase 4 (SSM reasoning) remain the live-integration work.
