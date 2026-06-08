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

## 8. Phase 2 L8 live seam — built, hardened (3-perspective audit), on-device cert PENDING

The L8 live seam (`BASMetalCosineTopKSeam`, opt-in `BAS_L8_METAL_TOPK`) wires the certified Metal topK into
`BASL8RoutedMemoryService.retrieve()` over the **in-Swift snapshot corpus** — the Rust corpus has NO dump
FFI, but the snapshot is already a flat `[Float]` in Swift with `rowIndex→atomID` direct. Default
byte-equal-off; taken only on the snapshot path (a Rust seam wins precedence). A 3-perspective review
(correctness / boundary+wedge+honesty / concurrency+quality) surfaced and FIXED:

- **Safety (C-1):** the branch now guards `dim>0 && query.count==dim && uniform-dim snapshot` (the flat GPU
  corpus can't tolerate ragged dims; the CPU path can) and `cpuReference` guards `query.count==dim` (it
  indexed `query[d]` for d in 0..<dim → a short query trapped). A mismatched query skips Metal → CPU.
- **CPU-identical membership (M-1):** the seam requests `k = snap.count` (ALL rows) so the SHARED
  deterministic tail (floor → sort by score-desc, atomID-asc → prefix topK) decides membership — the
  dispatcher's own rowIndex tie-break never leaks into the selection (the prior `selectTopK(topK)` tie-broke
  by rowIndex while the CPU path tie-breaks by atomID → divergent sets at a K-th-score tie).
- **Wedge containment (HIGH-2):** a single-in-flight GATE bounds a genuine GPU hang to ONE leaked task —
  the dispatch task clears the gate only on actual completion, so a hung dispatch keeps the gate closed and
  every subsequent retrieve falls back to CPU (the bridge already unblocks the caller at the timeout).
- **Telemetry honesty:** the seam now captures the Metal fault string (was `try?`→`error: nil`, so the
  records' `errors` column was structurally 0), distinguishes timeout from fault, and stamps real
  start/end mono-ns. Pre-warm now uses the REAL embedding dim (was dim=4).

**HONEST LIMITS (亏的不要上 / 诚实):**
1. **Perf at snapshot scale is a LOSS.** The snapshot is bounded by `selfPopulateCap` (≈64). The on-device
   smoke measured `topk_ms≈8.3` for a tiny corpus; Rust-SIMD cosine over ≤64 rows is microseconds. So at
   the ONLY scale this seam currently fires, Metal is ~1000× slower (GPU dispatch/encode/round-trip ≫ the
   µs CPU cosine). It is a **mechanism demonstration, not a perf win** — default-off is MANDATORY; enabling
   it by default would be 亏的不要上. The real win needs a LARGE corpus (the future global-recall path via a
   Rust corpus-dump FFI), where GPU dispatch amortizes.
2. **Approximate + NOT replay-stable.** The Metal score becomes `atom.confidence` on the reasoning-side
   bundle, which IS in the `BASEBrainTurnResultReplayDigest` preimage (synthesized Codable, not
   canonicalized). The Metal score is non-bit-reproducible, so a host that computes a replay digest over the
   routed backend would get a non-reproducible digest. The byte-determinism SPINE (durable store /
   event-log / governance verdict) is VERIFIED Metal-free (only `atomID` crosses); but the Metal L8 seam
   **must NOT be combined with replay-over-routed-backend** until the snap-pattern lands. The default-off
   posture + the single (non-replaying) endurance-runner wirer keep every shipping config doctrine-clean.
3. **Future replay-safe design:** Metal SCREENS the corpus to top-M candidates, then a CPU
   `snapToDeterministic` re-scores those M (deterministic + the GPU still does the O(N·D) screen). This pays
   ONLY at large corpus (where M ≪ N), which is exactly where Metal is also a perf win — so the two unlocks
   land together, not at snapshot scale.

**Status:** macOS-certified (`BASMetalL8SeamTests` + `BASMetalTopKParityTests` + spine tripwire + cascade
byte-equal net; DeviceTestApp builds for the iPhone Air). **On-device cert PENDING an awake device** (the
device slept between the §7 smoke cert and the L8 run, so the launched app was iOS-suspended).

## 9. Phase 4 — Metal SSMScan → non-governance reasoning sink (the sharpest boundary)

The CPU `ssmCaution` operator (`BASSSMCautionInput` → `boundRiskCard.totalRisk` → the sovereign verdict)
stays the AUTHORITATIVE, byte-deterministic value path — UNCHANGED. Phase 4 adds a SECOND, opt-in path that
runs the Metal `SSMScan` kernel on the SAME per-turn data without ever touching governance:

- **The seam:** `EBrainRuntimeCoordinator` gains a default-nil `ssmReasoningInputSink` + an
  `ssmMetalReasoningEnabled` flag (mirroring `ssmCautionObservationSink`). When both are set, `runTurn` emits
  the per-turn DETERMINISTIC scan input (`BASMambaTurnSignalBuilder.scanInput` — the same pure builder the
  CPU path is built from) to the sink. `runTurn` runs NO Metal (stays sync + Metal-free → the spine tripwire
  still passes; it references only the pure builder + a value type).
- **Host runs Metal OFF the turn thread:** `BASSSMMetalReasoning.run` dispatches `BASMetalSSMScanDispatcher`
  asynchronously and reduces the output to a reasoning magnitude (mean |y|). Because the Metal runs OFF the
  sync turn thread, a Metal wedge (ADR-038, uncancellable) can NEVER block the deterministic path — STRICTER
  than Phase 2's bounded sync-bridge, chosen deliberately for the governance-ADJACENT SSM.
- **The boundary (why flag-on == flag-off byte-for-byte):** the Metal reasoning signal is emitted ONLY via
  the sink; it never enters the returned `BASEBrainTurnResult` (the replay-digest preimage), never feeds the
  verdict / permit / commit / render / seal, and its state NEVER folds into `request.priorSSMState` (the CPU
  `ssmStateOut` owns the deterministic recurrence). Proven by `BASSSMMetalReasoningRunTurnTests`: flag-on
  emits the REAL per-turn input yet the DECISION (risk / level / factors / choice / permit / verdict /
  render) is byte-identical to flag-off — STRONGER than the CPU ssmCaution, which can RAISE risk.
- **Why a SEPARATE sink (not the ssmCaution one):** the CPU caution path is governance (it can raise the
  verdict input); the Metal reasoning path is non-governance (it raises nothing). Distinct sinks make the
  boundary explicit + the byte-identical proof unconditional.

**Cert status:** macOS-certified (the boundary proof + Metal-vs-CPU magnitude parity ≤1e-4 on the Mac GPU;
spine tripwire green; DeviceTestApp builds). **On-device SSM GPU+parity** is certified by an extension to the
`BAS_METAL_SMOKE` boot block (it now ALSO dispatches the SSMScan kernel + logs
`📊 ssm-metal-smoke gpu=.. parity_mae=..`) — **PENDING an awake device** (batched with the Phase-2 L8 cert).
The live per-turn reasoning emission over a long endurance run (the host wiring the sink end-to-end) is the
operational follow-up; the MECHANISM + the BOUNDARY are proven.
