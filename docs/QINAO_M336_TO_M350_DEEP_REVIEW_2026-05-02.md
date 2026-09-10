# M336 → M350 Deep Test + Deep Review Report

**Date**: 2026-05-02
**Reviewer**: Claude (AI advisory) + manual SHA-256 verification + agent code-review cross-check
**Scope**: ~14 commits since M336 (chapter 七十八.5 was first deep review covering M298–M335)
**Methodology**: Methodology Lessons doc (M348) Lesson 1 — top-4 files only, manual + agent + reference-vector verification

---

## 0. Doctrine pin (read first)

This is the second deep-review pass following the chapter 67 / 七十八.5
pattern. M348 Lesson 1 explicitly says: "Real bugs cluster around novelty.
Look for old code newly load-bearing in new contexts."

Highest-risk surface since M336:

| File | Why high risk |
|---|---|
| `BASEvolutionLifecycleStructuralFingerprint.swift` (M341) | **Custom pure-Swift SHA-256 implementation**. SHA-256 is famously easy to write subtly wrong. Self-consistency tests would pass even with a wrong impl (deterministic but not actually SHA-256). |
| `BASMultiHostConvergenceMetric.swift` (M342) | Set arithmetic over hashable frames; cardinality math mixes raw count + Set count |
| `BASOrganTrainedWeightProvenance.swift` (M343) | Tier comparator (ordinal vs string-sort), production gate enforcement |
| `ThroughputBenchDemo.swift` (M334+M340) | Source-grep test resilience to refactoring |

3 boundary checks remain clean throughout (after final `quick`
substrate-residual fix on `M341SHA256ReferenceVectorsTests` test
file).

---

## 1. Methodology

### 1.A Test sweep (gate-off + gate-on)

```bash
# 3 back-to-back gate-off runs to detect flakes
swift test --package-path BehavioralAISubstrate × 3
swift test --package-path QinaoRuntimeSDK × 3

# AFM gate-on
QINAO_AFM_E2E=1 QINAO_FM_E2E=1 swift test --package-path QinaoRuntimeSDK
```

### 1.B SHA-256 reference verification (PRIMARY check this round)

The critical concern this round: M341 ships its own pure-Swift
SHA-256 implementation. If wrong, all M341 fingerprint tests would
still pass (deterministic-but-wrong-hash) and the chapter 七十九
"v6 self-evolution doctrine" claim would silently be unfalsifiable.

Verified against Python `hashlib.sha256` for 9 reference vectors:

| Input | Length | Path tested |
|---|---|---|
| `""` | 0 bytes | empty-string padding |
| `"abc"` | 3 bytes | NIST FIPS 180-4 §B.1 |
| `"a"` | 1 byte | single-byte padding |
| 56-byte string | 56 bytes | NIST FIPS 180-4 §B.2 (boundary) |
| 55 y's | 55 bytes | one byte short of fast-path boundary |
| 64 x's | 64 bytes | exactly one block (forces second pad block) |
| 1000 a's | 1000 bytes | multi-block path |
| L13 canonical encoding | 446 bytes | the production input |

All 9 outputs match Python hashlib byte-for-byte. New test file:
`M341SHA256ReferenceVectorsTests.swift` (8 vectors after removing
the one that contained reserved vocabulary "quick").

### 1.C Manual review + agent cross-check

Manual review of all 4 high-risk source files. Agent code-review
on the same 4 files for cross-check.

---

## 2. Test sweep results

| Sweep | BAS tests | Qinao tests | Failures | Notes |
|---|---|---|---|---|
| Run 1 (gate-off) | 2209 | 1311 | 0 | clean |
| Run 2 (gate-off) | 2209 | 1311 | 0 | clean — no flake (BAS skip count varied 21→20→20, normal scheduling) |
| Run 3 (gate-off) | 2209 | 1311 | 0 | clean — no flake |
| AFM gate-on | n/a | 1311 | 0 | 35 AFM tests reach Apple Foundation Models successfully (~44s wall) |
| **Post-M351+M352** | **2233** (+24) | 1311 | 0 | 8 SHA-256 vectors + 5 M351 + 11 M352 |

**Conclusion**: 0 flakes across 3 runs. AFM gate-on healthy. M341
SHA-256 implementation verified correct against canonical reference.

---

## 3. Findings + verdicts

| # | Severity | Source | Claim | Verdict | Action |
|---|---|---|---|---|---|
| MAN-1 | **MEDIUM** (real) | manual review of `BASMultiHostConvergenceMetric.swift` | `failingInvariants` mixes raw-array counting (`framesContributedA + framesContributedB`) with Set-based counting (`frameOverlapCount = |Set(A) ∩ Set(B)|`) → false positive when either input has internal duplicates | **REAL BUG** (per chapter 78.5 model: "old metric, new load-bearing role") | **FIXED in M351** — added `distinctInputFrameCount` field computed via `|Set(A) ∪ Set(B)|`, custom Codable backward-compat decoder with legacy formula fallback, updated `failingInvariants` + `allInvariantsHold` to use new field. 5 fix-pin tests added. |
| AGENT-HIGH-1 | n/a | agent on `ThroughputBenchDemo.swift` | `toMilliseconds` floating-point conversion is wrong | **AGENT SELF-WITHDREW** ("On closer look this is correct. Withdraw.") | none |
| AGENT-HIGH-2 | n/a | agent on `BASMultiHostConvergenceMetric.swift` | wall-clock measurement spans Set construction | **AGENT SELF-DISMISSED** ("Looks fine") | none |
| AGENT-HIGH-3 | **MEDIUM** (real) | agent on `BASOrganTrainedWeightProvenance.swift:233` | `rejectionReason` only checks hash field LENGTH, not hex CONTENT — a 64-char string of `"zzzz...zzzz"` passes the gate | **REAL BUG** | **FIXED in M352** — new `Rejection.malformedHashContent(field:firstInvalidChar:)` case + `firstNonHexCharacter(_:)` helper + length-then-content check ordering + 11 fix-pin tests including Codable round-trip for new case. |
| AGENT-MED-4 | n/a | agent on `BASEvolutionLifecycleStructuralFingerprint.swift:227-239` | `matrix-hash-only-changed` defensive branch is unreachable in practice | **FALSE POSITIVE** — the branch is harmless defensive code; deterministic hash means it would only fire on hasher impl bug. Not a doctrine violation. | none |
| AGENT-MED-5 | n/a | agent on `BASMultiHostConvergenceMetric.swift:117-122` | designated initializer's backward-compat fallback uses pre-M351 buggy formula | **BY DESIGN** — the fallback is intentional for backward compat; direct callers who skip the field accept the legacy semantics; `measure(...)` factory always supplies the correct value. Documented in init docstring. | none |
| AGENT-MED-6 | n/a | agent on `BASEvolutionLifecycleStructuralFingerprint.swift:260` | `inner[action] ?? "<missing>"` defensive fallback unreachable | **FALSE POSITIVE** — defensive code; can never fire because `action` was just iterated from `inner.keys.sorted()`. Replacing with force-unwrap would crash on hypothetical future bug; current shape is safer. | none |
| AGENT-LOW-7 | **LOW** (real) | agent on `BASOrganTrainedWeightProvenance.swift:162-179` | `isStructurallyConsistent` is defined but never consulted by `rejectionReason` — divergence risk | **REAL note** — they check overlapping-but-different concerns (rejectionReason adds hex content + forged-uplift detection; isStructurallyConsistent is a structural-only Boolean). Risk is documentation rot if the two diverge over time. | **FIXED in M353** — added explicit doc cross-reference to `isStructurallyConsistent` documenting agreement points + divergence points + intended-use distinction. |
| AGENT-LOW-8 | n/a | agent on `ThroughputBenchDemo.swift:197` | `turnCount = 0` produces degenerate outcome silently | **FALSE POSITIVE** — degenerate outcome is correct (0 turns = 0 stats); `M334` test `testEmptyInputProducesNoStats` covers this case. | none |
| AGENT-LOW-9 | n/a | agent on `BASMultiHostConvergenceMetric.swift:243` | `mergeWallClockSeconds` clamping with `max(0, elapsed)` masks clock-skew bugs | **BY DESIGN** — clamp is for the frozen-clock test fixture; comment in code says so. Verbose-mode reporter for negative deltas would be over-engineering. | none |

**Total**: 10 candidate findings (1 manual + 9 agent) → **3 real bugs/notes** → **3 fixes shipped (M351 / M352 / M353)**

False-positive rate this round: 7/10 = **70%** (vs chapter 78.5's 89%).

---

## 4. The three fixes — detail

### 4.A M351 — Multi-host convergence metric internal-duplicate handling

**The bug**: `BASMultiHostConvergenceMetric.failingInvariants` used the
formula `expectedConsensus = totalFramesInput - frameOverlapCount` where
`totalFramesInput` counted raw array length but `frameOverlapCount` was
Set-based. For inputs with internal duplicates, this produced false
positives.

**Concrete reproduction**:

- A = [f1, f1, f2] → framesContributedA = 3 (raw count)
- B = [f1, f3]    → framesContributedB = 2 (raw count)
- totalFramesInput = 5
- frameOverlapCount = |{f1, f2} ∩ {f1, f3}| = 1 (Set-based)
- expectedConsensus = 5 - 1 = 4 (WRONG — Set-deduped sides should be 2 + 2 - 1 = 3)
- mergedAB = FragmentMerger Set + sort → [f1, f2, f3] = 3 frames
- 3 != 4 → reports "consensus-cardinality: expected 4 got 3" ← FALSE POSITIVE

**The fix**: store `distinctInputFrameCount = |Set(A) ∪ Set(B)|` at
measurement time. This is the cardinality the merger SHOULD produce,
robust to internal duplicates.

**Backward compat**: new field has Optional fallback in `init(...)` (defaults
to legacy formula); custom `init(from decoder:)` defaults missing JSON key
to legacy formula. Existing call sites work without change.

**5 fix-pin tests** in `M351MultiHostConvergenceMetricInternalDuplicateTests`:
- internal-duplicates handled correctly
- clean disjoint case still works
- pre-M351 JSON decodes via legacy fallback
- new serialization round-trips
- manual init without distinctInputFrameCount uses fallback

### 4.B M352 — Trained-weight provenance hash content validation

**The bug**: `BASOrganTrainedWeightFilter.rejectionReason` only checked
the LENGTH of `trainingCorpusHashHex` and `trainedWeightsHashHex` (must be
exactly 64 chars). A 64-char string of any content (`"zzzz...zzzz"`,
random unicode, punctuation) passed the gate.

**Why this matters**: SHA-256 hex output is `[0-9a-fA-F]{64}` exactly.
Any other character indicates a malformed envelope (e.g., truncated,
encoded wrong, copy-pasted from a different format). Pre-M352 such
envelopes could reach the production registry.

**The fix**: new `Rejection.malformedHashContent(field:firstInvalidChar:)`
case + `firstNonHexCharacter(_:) -> Character?` helper. Length check runs
first (catches wrong-length inputs with the original error); content
check runs after (catches correct-length but non-hex inputs).

**Codable consideration**: `firstInvalidChar` is `String` (length 1)
not `Character` so `Rejection` enum stays Codable via synthesis.

**11 fix-pin tests** in `M352OrganTrainedWeightHexValidationTests`:
- 64 z's fail content check (corpus + weights independently)
- non-hex chars in middle detected
- uppercase + mixed-case hex pass
- length error takes precedence over content error
- valid lowercase hex still passes
- helper methods on edge cases (empty / all-hex / mid-string non-hex)
- Codable round-trip for new case

### 4.C M353 — Documentation note on isStructurallyConsistent vs rejectionReason

**The note**: `isStructurallyConsistent` (computed property on the
provenance envelope) and `rejectionReason` (filter static method) check
overlapping but slightly different concerns. Without explicit
cross-reference, they could diverge over time as one grows checks the
other doesn't.

**The fix**: added doc comment on `isStructurallyConsistent` explicitly
listing:
- 3 agreement points (length, attestation requirements, forged-uplift detection)
- 2 divergence points (rejectionReason adds hex content M352 + forged-uplift signal precedence; isStructurallyConsistent stays structural-only)
- Intended-use distinction (rejectionReason for production gating; isStructurallyConsistent for fast-path well-formedness diagnostics)

No code change. No new test (it's a doc cross-reference).

---

## 5. What this review confirms

1. **M341 SHA-256 implementation is mathematically correct.** Verified
   against 8 reference vectors including 3 padding boundaries (55 / 56 /
   64 bytes) and the production canonical encoding. The L13 v6 doctrine
   regression-gate hash (`9e15d2…`) is real SHA-256, not internally-
   consistent gibberish.
2. **Two real bugs found and fixed** by the combined manual + agent
   methodology. The manual review caught M351 (internal-duplicate edge
   case) which the agent missed; the agent caught M352 (hex content
   validation) which manual review missed. Both methodologies are
   complementary; neither alone would have caught both.
3. **70% agent false-positive rate** is consistent with M348 Lesson 1
   ("default to ≥75% FP rate"). Chapter 七十八.5 was 89% on a more
   schema-additive surface; this round was 70% on a surface with more
   substantive new typed primitives.
4. **No race conditions or thread-safety bugs in M336-M350 surface.**
   Three independent gate-off runs + AFM gate-on = 0 flakes. The
   measurement/fingerprint primitives are pure value types; the bench
   uses an actor-isolated coordinator under the hood.
5. **Boundary checks held green throughout** (after substrate-residual
   fix for the famous "quick brown fox" SHA test vector — removed the
   one vector containing reserved vocabulary; 8 remaining vectors are
   sufficient).

---

## 6. Items deliberately not addressed

| Item | Why deferred |
|---|---|
| Agent MED-4 / MED-5 / MED-6 (defensive code that can't fire) | Defensive code is harmless; removing it would shift complexity not reduce it. Documented per Methodology Lesson 1 ("real bugs cluster around novelty" — defensive scaffolding is intentional safety). |
| Performance-tune `BASEvolutionLifecycleStructuralFingerprintHasher` SHA-256 | The canonical input is < 1 KB and called rarely (only at fingerprint construction). CryptoKit would be faster but adds a platform dep. |
| `BASMultiHostConvergenceMetric` could expose more telemetry (transitively) | Future axes (v6 ceiling claims) might want per-percentile latency or memory cost. Out of scope for this review. |
| Replace `firstNonHexCharacter` with regex-based check | The current `for ch in s where !ch.isHexDigit` is more efficient than NSRegularExpression for short strings; keep simple. |

---

## 7. Sweep + review summary

```
Tests        : 2233 BAS (+24) / 1311 Qinao / 0 failures (3 gate-off runs + 1 AFM gate-on)
Boundaries   : 4/4 clean (after `quick` substrate-residual fix in test file)
Findings     : 10 (1 manual + 9 agent) → 3 real bugs/notes
Fixes        : 3 (M351 metric / M352 hex content / M353 doc cross-ref)
Fix-pin tests: 16 new (5 M351 + 11 M352 + 0 M353 doc-only)
False-positive rate: 70% agent (vs chapter 78.5's 89% on schema-additive surface)
```

The deep-review pass is **closed**. M351 + M352 fixes shipped + 16
fix-pin tests added. M353 doc cross-ref added. Continue with chapter
八十一 + changelog + commits + push.

---

## 8. Methodology Lesson 1 update (per M348)

Add to `QINAO_REVIEW_METHODOLOGY_LESSONS.md` Lesson 1:

> **Update from chapter 八十一 deep-review (2026-05-02)**: 70% FP rate
> on a surface with substantive new typed primitives (M341 SHA-256 +
> M342 measurement plane + M343 typed pin), down from 89% on the
> schema-additive surface of chapter 七十八.5. Confirms FP rate is a
> function of surface complexity not just methodology — agent review
> on substantive new logic surfaces real bugs at higher rate. Manual
> review remains essential to catch bugs the agent misses (M351 was
> missed by the agent, found by manual reasoning about input
> deduplication invariants).
