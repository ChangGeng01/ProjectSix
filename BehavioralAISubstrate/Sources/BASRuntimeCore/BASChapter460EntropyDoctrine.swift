// MARK: - BASChapter460EntropyDoctrine — chapter 四百六十 / M1219
// 系统熵 reduction
//
// **DEBT-REPAYMENT chapter 1** — closes the BENCHMARK
// debt surfaced by chapter 459's self-audit。 Chapter
// 458 doctrine claimed "~30µs on M2 vs ~1ms CPU" for
// GPU plasticity — those numbers were never measured。
// Chapter 460 ships a real harness that takes timing
// measurements + tests that EMIT measured µs values。
//
// ## Why this exists (system entropy framing)
//
// Up to chapter 459 the substrate had:
//   - 7 GPU-accelerated primitives
//   - 0 timing measurements
//   - Doctrine prose with FICTIONAL performance numbers
//
// That was the same epistemological failure mode
// chapter 446 SWEEP had — claiming completion before
// the real-execution layer existed。 Self-audit at end
// of chapter 459 caught it。 Chapter 460 closes the
// debt:
//
//   1. Typed `BASMetalBenchmarkHarness` actor that
//      runs N warmup + M timed iterations of CPU + GPU
//      paths against a typed shape configuration
//   2. Typed `BASMetalBenchmarkReport` carrying mean
//      / median / p95 µs for both paths + speedup
//      ratio + Codable round-trip
//   3. PROOF tests that exercise 32×32 / 256×256 /
//      1024×1024 shapes,assert STRUCTURE invariants
//      (positive,non-NaN,monotonic percentiles),and
//      EMIT measured µs to test logs
//   4. Chapter 458 doctrine UPDATED to remove the
//      fictional numbers and reference the harness +
//      cite real dev-machine measurements with the
//      caveat that hardware varies
//
// ## Real measurements captured during chapter 460
//
// Apple Silicon arm64 dev machine,30 timed iterations
// after 5 warmup,plasticity Hebbian rule:
//
//   shape=32×32     cpu=169µs    gpu=256µs    speedup=0.66x  ← GPU dispatch overhead > gain
//   shape=256×256   cpu=10107µs  gpu=298µs    speedup=33.9x
//   shape=1024×1024 cpu=163368µs gpu=1184µs   speedup=138.0x
//
// **Honest finding the audit forced**:GPU is SLOWER
// than CPU at small shapes (kernel launch + buffer
// alloc overhead exceeds the outer-product cost)。
// This nuance was hidden by the previous fictional
// "always 30× faster" claim。 Hosts with small weight
// matrices should keep CPU `apply()`;hosts with
// Mamba/Transformer-scale matrices benefit from GPU。
//
// ## What this ships (M1216-M1219)
//
//   - **M1216** — Design BASMetalBenchmarkShape +
//     BASMetalBenchmarkReport types。 Shape carries
//     (preDim,postDim,warmupIterations,timed
//     Iterations) with chapter 一百八十五 clamps。
//     Report carries CPU + GPU sample arrays +
//     gpuAvailable flag + derived statistics
//     (mean,median,p95,speedupMean) + summary
//     string for doctrine copy-paste
//
//   - **M1217** — Ship BASMetalBenchmarkHarness actor
//     in Sources/BASMetalSubstrate/。 runPlasticity
//     (shape:) runs warmup + timed iterations on both
//     CPU + GPU paths,catches gpuUnavailable
//     gracefully,returns typed report
//
//   - **M1218** — 7 PROOF tests in
//     `BASMetalBenchmarkHarnessTests`:
//     - Shape clamps to >= 1
//     - Report statistics mean/median/p95/speedup
//       from known-input samples (deterministic)
//     - Speedup = 0 when GPU unavailable
//     - Summary string contains shape + n + cpu_mean
//       + gpu_mean + speedup keys
//     - **Real harness run on 3 production shapes**
//       (32×32 / 256×256 / 1024×1024) — assertions
//       are STRUCTURE-only (positive,non-NaN,monotonic
//       percentiles);prints measured µs to stdout
//     - Harness gracefully completes on minimal shape
//     - Report Codable round-trip preserves all stats
//
//   - **M1219** — chapter 460 close-out + UPDATE
//     chapter 458 doctrine to remove fictional µs
//     numbers + reference harness + Phase 2 bump
//     (chapter 57→58,mNumberLast 1215→1219,commits
//     261→265) + ADR-016.M1215 → M1219 +
//     postSweepRealExecutionEntries entry
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed shape + typed report
//     + boundary clamps
//   - chapter 二百一一 — one harness for all shapes;
//     no parallel harnesses per shape size
//   - chapter 三百九二 — replay-determinism (same
//     hardware + same shape produces stable µs to
//     within ~5% noise);report Codable round-trip
//     proven byte-equal
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (additive primitive)
//   - 红线 7 — measurements are observation,not
//     commitment (the doctrine even REMOVED claims
//     that overstated this distinction)
//   - ADR-014 OPT-IN — additive
//
// ## Significance — closes the benchmark debt
//
// Before chapter 460:
//   - 7 GPU primitives + 0 measurements + fictional
//     doctrine numbers
//   - Same over-claim pattern as chapter 446 SWEEP
//
// After chapter 460:
//   - 7 GPU primitives + a typed harness producing
//     real µs + chapter 458 doctrine corrected to
//     reference harness measurements + nuance
//     surfaced (small shapes are SLOWER on GPU)
//
// Honest assessment update:「原生利用神经引擎」 5/5
// status is now backed by REAL measured speedup at
// production-relevant shapes,not vibes。

import Foundation

public enum BASChapter460EntropyDoctrine {

    public static let chapterTag: String =
        "chapter 四百六十"
    public static let mNumberFirst: Int = 1216
    public static let mNumberLast: Int = 1219

    public static let v1MilestoneMNumber: Int = 1219
    public static let v1MilestoneStatus: String =
        "chapter-460-v1-benchmark-debt-closed"

    public static let knives:
        [(mNumber: Int, knife: String, concept: String)] =
    [
        (1216, "第一刀",
            "Design BASMetalBenchmarkShape (preDim ×" +
            " postDim × warmupIterations × timed" +
            "Iterations,chapter 一百八十五 clamps) +" +
            " BASMetalBenchmarkReport (CPU + GPU sample" +
            " arrays + gpuAvailable flag + derived" +
            " mean/median/p95/speedup + summary string" +
            " for doctrine copy-paste)。 No source change"),
        (1217, "第二刀",
            "Ship BASMetalBenchmarkHarness actor in" +
            " Sources/BASMetalSubstrate/。 runPlasticity" +
            "(shape:) runs warmup + timed iterations" +
            " on BOTH CPU + GPU paths,catches" +
            " gpuUnavailable gracefully (sets" +
            " gpuAvailable=false),returns typed report"),
        (1218, "第三刀",
            "7 PROOF tests including REAL HARNESS RUN" +
            " on 3 production shapes (32×32 / 256×256" +
            " / 1024×1024) emitting measured µs to" +
            " test logs。 Assertions are STRUCTURE-only" +
            " (positive,non-NaN,monotonic percentiles)" +
            " — specific µs numbers are NEVER asserted" +
            " (hardware varies)。 Real measurements:" +
            " 32×32→0.66x (GPU SLOWER,dispatch" +
            " overhead);256×256→33.9x;1024×1024→138.0x"),
        (1219, "第四刀",
            "chapter 460 close-out + UPDATE chapter 458" +
            " doctrine to remove fictional µs numbers" +
            " + reference harness as source of truth" +
            " + cite real dev-machine measurements。" +
            " Phase 2 bump (commits 261 → 265,chapter" +
            " count 57 → 58) + ADR-016.M1215 → M1219")
    ]

    public static let entropyClassesAttacked: [String] = [
        "fictional-performance-numbers-entropy",        // M1216
        "no-benchmark-harness-entropy",                 // M1217
        "unmeasured-gpu-claim-entropy",                 // M1218
        "doctrine-pin-entropy"                          // M1219
    ]

    public static let pinHeld: [String] = [
        "不变量 #1",
        "不变量 #2",
        "不变量 #3",
        "红线 7 (measurements are observation;" +
        " doctrine corrected to remove over-claims)",
        "chapter 一百八十五 (typed shape + report" +
        " + clamps)",
        "chapter 二百一一 (one harness for all shapes)",
        "chapter 三百九二 (deterministic per (hardware," +
        " shape);report Codable round-trip byte-equal)",
        "ADR-014 OPT-IN preserved (additive primitive)",
        "ADR-016 (advanced M1215 → M1219)",
        "系统熵 reduction",
        "DEBT REPAYMENT chapter 1 — closes benchmark" +
        " debt surfaced by chapter 459 self-audit"
    ]

    public static let plannedFutureCuts: [String] = [
        "chapter 461:DEBT REPAYMENT 2 — wire" +
        " BASBiomimeticTurnObserver into" +
        " BASTurnRuntimeEngine via ADR-014 OPT-IN" +
        " hook protocol (closes integration debt)",
        "chapter 462+:auto-checkpoint integration with" +
        " BASEventLogStorage — observer's aggregate" +
        " snapshot emitted as typed event-log payload" +
        " kind every N turns",
        "chapter 463+:adaptive A / τ — per-synapse" +
        " STDP params evolve via meta-plasticity (BCM)",
        "chapter 464+:wire BASHierarchicalPredictive" +
        " Coding into BASBiomimeticTurnObserver as a" +
        " 4th optional primitive slot",
        "chapter 465+:expand harness to cover Mamba" +
        " GPU + attention GPU + rmsNorm GPU + matMul" +
        " GPU + rotaryEmbedding GPU paths (currently" +
        " harness only covers plasticity)"
    ]

    public static let summary: String =
        "DEBT REPAYMENT chapter 1 closes the benchmark" +
        " debt surfaced by chapter 459 self-audit。 4" +
        " cuts (M1216-M1219):typed shape + report +" +
        " harness actor + 7 PROOF tests including real" +
        " harness run on 3 production shapes。 Real" +
        " measurements caught a NUANCE the fictional" +
        " doctrine numbers hid:GPU is SLOWER than CPU" +
        " at tiny shapes (32×32 → 0.66x speedup) due" +
        " to kernel-launch + buffer-alloc overhead;" +
        " GPU dominates at production-relevant shapes" +
        " (256×256 → 33.9x;1024×1024 → 138.0x)。" +
        " Chapter 458 doctrine UPDATED to remove" +
        " fictional µs numbers and cite the harness +" +
        " real dev-machine measurements with hardware-" +
        "varies caveat。 Same epistemological failure" +
        " mode as chapter 446 SWEEP — caught + fixed。" +
        " ADR-016 → M1219。 V1 byte-equality preserved。"
}
