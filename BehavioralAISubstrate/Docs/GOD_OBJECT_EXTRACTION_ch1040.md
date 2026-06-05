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
| — | `BASAutoRouteRanker` net | **3802 → 2861 lines (−25%)** | |
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

The self-contained domains (tokenizer, activations, dream-loop, mamba) are **done**. The remaining
`BASAutoRouteRanker` FFI-routing domains (ledger/crypto, tribunal, KG-codec, event-extractor,
int8/aggregations, importance, organ-router) share `private` wire-format/hex helpers, so each needs a
helper-widening step first — safe + byte-equal but entangled, diminishing cosmetic return. Left as an
optional follow-up.
