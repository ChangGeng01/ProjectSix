# M423 Profile Report — Full-Stack-Bench Hot Paths (chapter 一百一)

**Date**: 2026-05-03
**Chapter**: 一百一 (M423)
**Trigger**: User instruction "全面改造不满意至满意" → I confessed M420's optimization-leverage assumption was un-profiled → this is the actual profile.

## Methodology

1. Built `QinaoSampleHost` in release mode (`swift build -c release`) — release binary at `/Users/changgeng/Project/Project06/Project06/QinaoRuntimeSDK/.build/arm64-apple-macosx/release/QinaoSampleHost`
2. Launched `--full-stack-bench` with `QINAO_BENCH_FULL_STACK_SESSIONS=10000`
3. Sampled with `/usr/bin/sample <pid> 8 1 -file /tmp/profile_release.txt` (8 seconds at 1ms intervals)
4. Captured 6086 samples on the main concurrent dispatch queue running `runFullStackBench`

## Top hot paths (sample count >= 90)

| Function | Samples | % of total |
|---|---|---|
| `String.init(format:_:)` (Foundation) | 94-99 | ~1.5% per site |
| `BASEBrainRuntimeCoordinator.fingerprint(for:)` | 96-98 | ~1.6% |
| `BASHostRuntime.fingerprint(for:)` | 95 | ~1.5% |
| `BASObservabilityInspector.replayFingerprint(for:)` | 95 | ~1.5% |
| `BASHostConstitution.vaultSnapshot(...)` | 99 | ~1.6% |
| `__JSONEncoder.wrapGeneric` (Foundation) | 97 | ~1.6% |
| `_JSONKeyedEncodingContainer.encode<A>` (Foundation) | 97-99 | ~1.6% |
| `_JSONUnkeyedEncodingContainer.encode<A>` (Foundation) | 95 | ~1.5% |
| `BASEBrainTurnResult.evolutionFoldedLungSummary.getter` | 95 | ~1.5% |
| `BASEBrainRuntimeCoordinator.buildThoughtFold` (closure #5 + line 10188) | 95-99 | ~1.6% |
| `BASHostRuntimeEBrainNeuralCoreService.materializeRiskBindings(...)` | 99 | ~1.6% |
| `BASExecutionTrace.encode(to:)` | 99 | ~1.6% |
| `BASHostRuntimeEBrainRiskService.calibrateRisk(...)` | 91 | ~1.5% |
| `BASEBrainRuntimeCoordinator.runTurn(_:)` (line 3780) | 90 | ~1.5% |
| `BASEBrainConsoleSupport.mergedSnapshot(_:with:)` | 90 | ~1.5% |
| `BASContextServicing.analyzeContext(...)` | 90 | ~1.5% |

## What this REVEALS

### 1. The actual top-leverage optimization target is `fingerprint(for:)`

[BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator+TraceDetails.swift:25-29](../BehavioralAISubstrate/Sources/BASHostKit/EBrainRuntimeCoordinator+TraceDetails.swift):

```swift
func fingerprint(for value: String) -> String {
    SHA256.hash(data: Data(value.utf8))
        .compactMap { String(format: "%02x", $0) }
        .joined()
}
```

**Each fingerprint call invokes `String(format: "%02x", byte)` 32 times** (once per SHA-256 byte). String-format parsing has high fixed cost; for hex-byte conversion there's a much faster path (lookup table, manual char encoding, etc.).

Counting fingerprint call sites: at least 3 (`buildThoughtFold` calls coordinator's, `BASHostRuntime.fingerprint(for:)` is a sibling, `BASObservabilityInspector.replayFingerprint(for:)` is another). Each call costs ~96 samples = ~1.6% of total. Combined: **~5% of total bench time spent in `String(format: "%02x", ...)` from fingerprint computations.**

A faster hex-byte formatter would directly recover ~5% of full-stack-bench p50.

### 2. JSON encoding for audit/lifecycle is ~5% of total

`__JSONEncoder.wrapGeneric` + `KeyedEncodingContainer.encode` + `UnkeyedEncodingContainer.encode` together count for ~3 × 95 = ~285 samples ≈ 4.7%. This is `BASExecutionTrace.encode(to:)` + similar Codable-driven serialization for audit ledger entries.

### 3. M420's M402-M410 string allocation was NOT a top hot path

The M420 optimization replaced 4 inline array literals with static-let constants. **None of those array allocations show up in the top hot paths.** Confirms M421's stat-rigorous finding that M420 had no measurable bench impact — there's no real time being spent on the M402-M410 array allocations because they're dwarfed by `String(format:)` and JSON encoding.

### 4. What M420 SHOULD HAVE been

If I had profiled FIRST, I would have seen `fingerprint(for:)` and gone straight there. The "M402 worldview-projection caching" claim was a guess based on what I happened to be reading recently (Kunlun chapters), not based on actual cost. **This is exactly the "premature optimization without profiling" anti-pattern.**

## Real next-optimization candidates (in leverage order)

1. **`fingerprint(for:)` hex-byte formatter** — replace `String(format: "%02x", $0)` with manual lookup table or `String(byte, radix: 16, uppercase: false)` with leading-zero fix. Estimated: -3% to -5% of full-stack-bench p50.

2. **JSON-encoder hot paths** — `BASExecutionTrace.encode(to:)` + similar use Codable. Investigate if a hand-rolled encoder for the hottest types saves time. Estimated: -2% to -4%.

3. **`buildThoughtFold` closures** — multiple closures consume `String(format:)` directly. Audit for consolidation. Estimated: -1% to -3%.

4. **`BASHostConstitution.vaultSnapshot(...)`** — 1.6% of total per turn. Look for redundant work. Estimated: -1% to -2%.

## Doctrine codification

**For future bench-claim work**: do NOT propose an optimization without first profiling. The profile takes ~3 minutes (`swift build -c release` + 8s sample + parse). The cost of skipping profile is shipping un-measurable optimizations that look like noise (M420 pattern).

Codified for `docs/QINAO_DEEP_REVIEW_DOCTRINE.md` (will be updated in M427):

> Performance-optimization milestones MUST include a profile-first step:
> 1. Build release binary
> 2. Sample 5-10s during the target bench
> 3. Identify top hot paths above noise threshold
> 4. ONLY THEN propose where to optimize
>
> Without this step, "I'll optimize X to save Y%" is speculation. The "M420 saves -8.6%" claim from chapter 一百 was un-profiled speculation that turned out to be statistical noise.

## Status

- **Profile captured**: 6086 main-thread samples, top hot paths identified
- **M420 leverage claim retracted**: profile confirms M420's target was not on the hot path
- **Future targets identified**: `fingerprint(for:)` hex-byte formatter is the highest-leverage near-term win (~3-5%)
- **Doctrine codified**: profile-first requirement for perf milestones

The actual `fingerprint(for:)` optimization is **NOT in this M423 scope** — that's a separate M-numbered milestone if the user wants to pursue it. M423's job was: **profile to find the real cost sources, not guess**. Done.
