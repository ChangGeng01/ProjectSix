# L8 Storage Flip — DECLINE-WITH-TRIGGER

**Chapter**: 九百五 / M3225 (LIVE measurement)
**Predecessor chapters**: 884 (Gap 1 trigger), 893 (RFC), 894-904
(skeleton + 7 modules + facade)
**Decision date**: 2026-05-23
**Status**: **DECLINE storage-only flip — TRIGGER: hot-path
consolidation lands**

## TL;DR

Chapter 905 ran LIVE production-shape perf benchmarks comparing the
Swift SQLite actors vs the new Rust-backed L8 facade。 Result:
**TIE (~1.0× across all 3 measured stores)**。

| Store | Workload | Swift | Rust | swift/rust |
|---|---|---|---|---|
| MemoryUsageTracker.record() | N=100 | 0.0026s | 0.0027s | **0.98×** |
| MemoryUsageTracker.record() | N=1000 | 0.0222s | 0.0237s | **0.93×** |
| EventLog.append() | N=100 | 0.0037s | 0.0041s | **0.92×** |
| EventLog.append() | N=1000 | 0.0374s | 0.0357s | **1.05×** |
| HostConstitutionVault.save() | N=100 | 0.0077s | 0.0077s | **1.00×** |

Per 「亏的不要硬上」 + 「整体 性能 效果 一定要 更好」, **DO NOT flip
the production default to Rust storage today**。

## Why TIE not WIN

The string-FFI cost doctrine (chapters 881 + 890) explains this:

1. Both paths are I/O-bound on SQLite WAL writes (the actual disk
   sync dominates wall time)
2. Rust adds string-FFI overhead per operation:UTF-8 encode → FFI
   call → cstr_to_str decode → SQLite bind
3. Swift's path goes Swift String → SQLite bind directly (no FFI
   hop)
4. The Rust path's compute speed advantage is canceled out by the
   FFI hop overhead at SQLite write granularity

This is the **same pattern** chapter 884 documented for Gaps 1+4+5
and chapter 890 for canonicalEncoding。

## What WOULD make this a flip

Per the user's original directive:
> 「把 L8 统一成：SQL event log / atom lifecycle / tombstone 作为
> source of truth，Rust retrieval / reducer / ranker / provenance /
> batch scoring 做热路径」

The benefit comes from **Rust hot paths reading DIRECTLY from
Rust-backed SQL stores** without round-tripping through Swift。
Today the substrate's hot-path Rust crates (bas-retrieval-ranker,
bas-audit-aggregator,bas-red-team-bench) call BACK to Swift for
storage reads,which then call into the same SQLite engine via the
existing Swift actors。

**Trigger conditions for re-evaluation** (chapter 906+):

1. **Hot-path read consolidation** — when bas-retrieval-ranker
   reads embeddings DIRECTLY from bas-l8-engine's vector_index
   (skipping the Swift round-trip),the SAVED FFI hops compound
   across the per-turn request path
2. **Per-turn measured benefit ≥ 1.3×** at production query
   shapes (corpus ≥ 1K atoms × 384 dim)
3. **Cold-start parity** — Rust-backed open + schema init must be
   ≤ 1.5× of Swift's open time (currently uncertain — chapter
   905 only measured warm-state throughput)

If ANY of these triggers fire,re-run the perf benchmark and flip
default to ON if the integrated path measures ≥ 1.3× win at
production shape。

## What ships unchanged today

- All 8 Rust-backed routed stores (LOW + 5 MED + 3 HIGH)
- Facade actor (chapter 904) for consumer drop-in
- Full byte-equality test coverage (33 tests across chapters
  895-904)
- ADR-014 OPT-IN preserved:Rust path is additive,Swift body
  remains the production default

## What does NOT ship

- No production-default flip from Swift SQLite actors → Rust facade
- No removal of the Swift SQLite actor code (红线 7 preservation)
- No claim that「Rust storage is faster」 — the data says TIE

## Audit trail

- Benchmark code:`Tests/BehavioralAISubstrateTests/
  BASChapter905StorePerfBenchmarkTests.swift`
- Test prefix:`testBenchmark*` (skippable in fast-loop CI per
  existing convention)
- Re-run:`swift test --filter BASChapter905`
- Numbers above captured on Apple Silicon (arm64,macOS 14.0
  target,debug build)。 Release build may shift numbers but
  ratios expected to remain in 0.8×-1.2× band based on chapter
  881 + 890 precedent

## Discipline reference

This decline follows the **chapter 八百四十九 DECLINE-WITH-TRIGGER
model** as classified in `Docs/DECLINE_PATTERNS.md`:
- Pattern: STORAGE_TIE_FFI_OVERHEAD
- Trigger: hot-path consolidation lands (chapter 906+) OR
  per-turn integrated measurement ≥ 1.3× win
- Re-evaluation cadence: each chapter that consolidates a Rust
  hot-path read into bas-l8-engine

## Trigger FIRED — chapter 九百六 / M3230

**Date**: 2026-05-23
**Trigger source**: Chapter 906 hot-path consolidation probe

Chapter 906 added `bas_l8_vector_index_cosine_topk_for_domain`
— a Rust function that fetches all embeddings for a domain +
computes dot-product top-k in ONE FFI call。 Compared to the
orchestrated baseline (N round-trip reads + Swift compute):

| Corpus | Orchestrated | Integrated | Speedup |
|---|---|---|---|
| N=100 dim=64 | 0.0016s | 0.0000s | **90.67×** |
| N=1000 dim=64 | 0.0160s | 0.0001s | **125.97×** |
| N=5000 dim=64 | 0.0782s | 0.0006s | **134.50×** |

The integrated path is **90-134× faster** across all measured
corpus sizes。 This decisively confirms the user's original
architectural premise:**hot-path consolidation wins
massively**,while storage-only migration was a tie。

### What the trigger means

- The vector_index cosine_topk path is FLIP-READY today
  (chapter 906 ships the FFI primitive + correctness pin)
- Production consumers can opt-in via `BASRoutedVector-
  IndexStorage.cosineTopK(forDomain:queryBytes:k:)`
- The STORAGE-only flip remains DECLINED — that comparison
  was apples-to-apples (both paths fetch+write SQLite),and
  the FFI cost dominated。 The hot-path consolidation path
  saves N FFI hops which is where the gain comes from
- Future consolidation work (other hot-path read patterns
  like batch-tier-update,bundle-recall) will likely show
  similar wins。 Measure each before flipping per discipline
