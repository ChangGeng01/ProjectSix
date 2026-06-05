# God-object extraction (audit ch1040)

The ch1040 全面 audit flagged two oversized files as HIGH god-objects: `BASAutoRouteRanker.swift`
(3802 lines, 93 cross-domain static funcs) and `BASCognitiveBrain.swift` (4226 lines). This log records
the byte-equal extraction work + an honest correction of one of the audit's own premises.

## Discipline

Every split is a **pure relocation / behavior-preserving delegation** — same symbols, call sites
unchanged, byte-equal — verified by `swift build` + the relevant suites (and, for the brain, the
end-to-end `BASCognitiveBrainCascadeDigestTests` which hashes the full turn result). ADR-014 / 红线 7,
R1, 亏的不要上, conventional commits, no Co-Authored-By.

## Splits landed

| # | What | Result | Verify |
|---|---|---|---|
| 1 | `BASAutoRouteRanker` → `+Tokenizer.swift`: the 5 BPE FFI passthroughs | `opaqueHandle` temporarily widened `fileprivate`→`internal` | BASChapter722Bpe* (30) |
| 2 | `BASAutoRouteRanker` → `+Activations.swift`: gelu/silu routing + Swift fallbacks | public + private fallbacks moved together (no widening) | Activation/BASChapter711; cascade-digest (6) |
| 3 | `BASBpeTokenizerHandle` class → `+Tokenizer.swift` (reunites the tokenizer domain) | `opaqueHandle` restored to `fileprivate` (widening reverted) | BASChapter722Bpe* (30) |
| 5 | `BASAutoRouteRanker` → `+DreamLoop.swift`: L9 dream-loop / dominance-order (i32+f64) / telemetry + test seam (+`atomicAdd1`) | self-contained (no widening) | BASChapter748/836/838 (21) + cascade-digest (6) |
| 6 | `BASAutoRouteRanker` → `+Mamba.swift`: Mamba SSM-scan routing (seq + parallel) | self-contained | mamba suites + cascade-digest (6) |
| 7 | `BASAutoRouteRanker` → `+WireFormat.swift`: shared big-endian byte/buffer helpers | widened `private`→`internal` (cross-domain) | cascade-digest (6) + importance byte-equality (7) |
| 8 | `BASAutoRouteRanker` → **13 domain files** (+Linalg/+Cosine/+Crypto/+Importance/+ProvenanceFilter/+RiskPlane/+Tribunal/+Sovereign/+Verdict/+KGCodec/+EventExtractor/+OrganRouter/+Reducers) | single-pass MARK-range extraction; `swiftNaiveCosine` widened `private`→`internal` | cascade-digest (6) + 197-test domain sweep |
| — | `BASAutoRouteRanker` net | **3802 → 502 lines — UNDER the 800 cap** (17 domain files) | |
| 4 | `BASCognitiveBrain` → `BASCognitiveMetalKernels.swift` (collaborator actor) | **4226 → 3843 lines**; collaborator 502 | cascade-digest (6) + 113 kernel call-site tests + sovereign (29) |

## Honest correction of the audit (split 4)

The audit's code-quality agent sketched the brain's matmul/attention/rmsnorm/etc. as *"pure numerics,
zero actor-state references — trivially extractable to a stateless `enum BASCognitiveKernels`."*
**That was wrong.** Reading the bodies showed all 12 candidate methods (a) read the injected
`metalLibraryLoader` and (b) **lazily create + cache dispatcher instances on the actor**
(`if metalMatMulDispatcher == nil { metalMatMulDispatcher = … }`). They are **stateful actor methods**,
not pure numerics — a stateless enum would have broken the dispatcher caching (perf + behavior change),
i.e. NOT byte-equal.

So the real refactor is a **stateful collaborator**, not a stateless enum:
- `BASCognitiveMetalKernels` (an `actor`) owns `metalLibraryLoader` (a shared reference to the brain's)
  + the 9 dispatcher/kernel/cache props + **10** of the methods.
- The brain keeps `public let metalLibraryLoader` (used by ~15 other sites) and **forwards** each kernel
  call to the collaborator, so the ~100 external call sites stay byte-equal.
- The **2 ANE-tier orchestrators** (`matMulAutoWithANETier` / `attentionAutoWithANETier`) stay on the
  brain — they depend on brain-local ANE telemetry (`BASANEConsultedResult`, `recordANEConsultation`)
  and call the brain's `matMulAuto`/`attentionAuto` forwarders.

Lesson: the audit's per-file extraction *sizes* were optimistic; reading the code before cutting is what
keeps a sovereign-path refactor byte-equal. (Catching this is the value of doing it carefully, not
trusting the sketch.)

## Remaining (mapped, not done)

**DONE (ch1040 WS1):** `BASAutoRouteRanker` is now **fully decomposed** — every routing domain lives in
its own `+Domain.swift` (17 files) and the base is **502 lines, under the 800-line cap**. The shared
`private` wire-format helpers were lifted to `+WireFormat.swift` (widened `internal`); the remaining
domains were extracted in one verified single-pass.

## DONE — `BASCognitiveBrain` fully decomposed (brain splits 1–4)

After the collaborator split above (which corrected the audit's "pure kernels" premise), the brain was
**3846 → 634 lines (−84%), now under the 800-line cap**, across 4 byte-equal `extension BASCognitiveBrain`
splits (the designated inits + the core `process` loop + memory-session boundaries stay in the actor body
— Swift requires designated inits in-type):

| Split | Extracted | New files | Base |
|-------|-----------|-----------|------|
| 1 | top-level value types (Codable snapshots) | `+ResultTypes` (406), `+PilotTypes` (459) | 3846 → 3011 |
| 2 | math/Metal kernels (cosine/rmsnorm/matmul/attention + ANE ch999/ch1000 8-op) | `+Kernels` (279), `+KernelsANE` (595) | 3011 → 2172 |
| 3 | summary DTO · derived signals · history queries · pilots · health | `+Summary` (517), `+Pilots` (360), `+Health` (268) | 2172 → 1079 |
| 4 | static factories + safety/risk verdict + cascade digest | `+Construction` (214), `+SafetyVerdict` (271) | 1081 → **634** |

**Widening (all byte-equal, visibility-only):** split 2 widened `metalKernels` `private→internal`; split 3
widened 5 actor members the moved methods read (`summaryHistory`, `currentNanos` `private→internal`;
`metalSignalThreshold`, `summaryCallCount`, `healthSnapshotAutoCaptureEvery` `fileprivate→internal`);
split 4 needed **zero** widening. A `Duration→UInt64` build error in split 3 was a *cascade* from
`currentNanos` being inaccessible — it vanished once that member was widened (not an independent bug).

**Verification:** `swift build` green per split; `BASCognitiveBrainCascadeDigestTests` (6, full-turn
byte-equality) green after **every** split; a 103-test sweep across 10 suites (determinism · cosine/matmul/
ANE/flash kernels · facade+factory · history queries · health · pilots · all-pilots) green at HEAD. Pure
relocation + visibility-only widening ⇒ byte-equal: every call site (`BASCognitiveBrain.x`) is unchanged.
