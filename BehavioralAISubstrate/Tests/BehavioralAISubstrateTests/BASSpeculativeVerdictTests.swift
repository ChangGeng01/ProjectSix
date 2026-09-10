import XCTest
@testable import BASAppleAdapters
import BASMemory

/// 结构大重构 — Phase 5: the speculative-decoding ENABLE gate + its ledger composer.
///
/// Mirrors the CoreAI verdict tests: the strict default-deny truth table, the today-reality canary, and the
/// composer's paired-only / correctness-AND / skip-foreign honesty rules.
final class BASSpeculativeVerdictTests: XCTestCase {

    private typealias Verdict = BASSpeculativeMigrationVerdict
    private typealias Composer = BASSpeculativeShadowComposer

    // MARK: - 1. The gate truth table

    func testFullWinEnables() {
        let e = Verdict.Evidence(
            mode: "greedy", correctnessVerified: true, acceptanceRate: 0.8,
            speculativeMeanLatencyMillis: 1.0, baselineMeanLatencyMillis: 2.0,   // 50% faster
            dualPeakMemoryBytes: 3_000_000_000, memoryBudgetBytes: 6_000_000_000, // fits
            sampleCount: 60, pairedLatencySampleCount: 60, distinctDeviceCount: 2)
        let v = Verdict.decide(evidence: e)
        XCTAssertEqual(v.recommendation, .enable)
        XCTAssertTrue(v.reasonCodes.contains(Verdict.Reason.latencyWin))
        XCTAssertTrue(v.reasonCodes.contains(Verdict.Reason.memoryFits))
        XCTAssertTrue(v.reasonCodes.contains(Verdict.Reason.correctnessVerified))
    }

    func testCorrectnessFailureIsDecisiveEvenWithLatencyWin() {
        let e = Verdict.Evidence(
            mode: "sampling", correctnessVerified: false,                        // FAILED
            speculativeMeanLatencyMillis: 1.0, baselineMeanLatencyMillis: 2.0,   // would-be win
            dualPeakMemoryBytes: 3_000_000_000, memoryBudgetBytes: 6_000_000_000,
            sampleCount: 60, pairedLatencySampleCount: 60, distinctDeviceCount: 2)
        let v = Verdict.decide(evidence: e)
        XCTAssertEqual(v.recommendation, .doNotEnable,
            "a faster but INCORRECT decoder must never enable — correctness is a hard gate")
        XCTAssertTrue(v.reasonCodes.contains(Verdict.Reason.correctnessFailed))
    }

    func testLatencyLossDoesNotEnable() {
        let e = Verdict.Evidence(
            mode: "greedy", correctnessVerified: true,
            speculativeMeanLatencyMillis: 2.5, baselineMeanLatencyMillis: 2.0,   // slower
            dualPeakMemoryBytes: 3_000_000_000, memoryBudgetBytes: 6_000_000_000,
            sampleCount: 60, pairedLatencySampleCount: 60, distinctDeviceCount: 2)
        let v = Verdict.decide(evidence: e)
        XCTAssertEqual(v.recommendation, .doNotEnable)
        XCTAssertTrue(v.reasonCodes.contains(Verdict.Reason.latencyLoss))
    }

    func testLatencyTieDoesNotEnable() {
        let e = Verdict.Evidence(
            mode: "greedy", correctnessVerified: true,
            speculativeMeanLatencyMillis: 1.98, baselineMeanLatencyMillis: 2.0,  // within 5% margin
            dualPeakMemoryBytes: 3_000_000_000, memoryBudgetBytes: 6_000_000_000,
            sampleCount: 60, pairedLatencySampleCount: 60, distinctDeviceCount: 2)
        let v = Verdict.decide(evidence: e)
        XCTAssertEqual(v.recommendation, .doNotEnable, "a within-noise tie is no benefit — don't pay the cost")
        XCTAssertTrue(v.reasonCodes.contains(Verdict.Reason.latencyTie))
    }

    func testMemoryExceedsDoesNotEnable() {
        let e = Verdict.Evidence(
            mode: "greedy", correctnessVerified: true,
            speculativeMeanLatencyMillis: 1.0, baselineMeanLatencyMillis: 2.0,
            dualPeakMemoryBytes: 7_500_000_000, memoryBudgetBytes: 6_000_000_000, // OOM risk
            sampleCount: 60, pairedLatencySampleCount: 60, distinctDeviceCount: 2)
        let v = Verdict.decide(evidence: e)
        XCTAssertEqual(v.recommendation, .doNotEnable, "dual residency that exceeds the budget would OOM/wedge")
        XCTAssertTrue(v.reasonCodes.contains(Verdict.Reason.memoryExceeds))
    }

    func testTodayRealityIsInsufficientEvidence() {
        // Greedy correctness verified on host, but no on-device latency/memory + below the device/sample bar.
        let e = Verdict.Evidence(
            mode: "greedy", correctnessVerified: true,
            sampleCount: 1, distinctDeviceCount: 1)
        let v = Verdict.decide(evidence: e)
        XCTAssertEqual(v.recommendation, .insufficientEvidence,
            "today: correctness host-proven, but no measured latency/memory + n=1/single-device ⇒ insufficient")
        XCTAssertTrue(v.reasonCodes.contains(Verdict.Reason.latencyNoEvidence))
        XCTAssertTrue(v.reasonCodes.contains(Verdict.Reason.memoryNoEvidence))
        XCTAssertTrue(v.reasonCodes.contains(Verdict.Reason.samplesBelowMin))
        XCTAssertTrue(v.reasonCodes.contains(Verdict.Reason.devicesBelowMin))
    }

    // MARK: - 2. Composer: record → evidence

    private func record(_ effects: [String], scope: String = "speculative-decode") -> BASShadowTrialRecord {
        BASShadowTrialRecord(
            trialID: "t", candidateRef: "spec", trialScope: scope,
            observedEffects: effects, completionState: "observing")
    }

    func testComposerFoldsPairedLatencyAndCorrectnessAnd() {
        let records = [
            record(["mode: greedy", "correctness_verified: true", "acceptance_rate: 0.8",
                    "speculative_latency_ms: 1.0", "baseline_latency_ms: 2.0"]),
            record(["mode: greedy", "correctness_verified: true", "acceptance_rate: 0.7",
                    "speculative_latency_ms: 1.2", "baseline_latency_ms: 2.0"]),
        ]
        let c = Composer.compose(records: records, mode: "greedy", distinctDeviceCount: 2,
                                 dualPeakMemoryBytes: 3_000_000_000, memoryBudgetBytes: 6_000_000_000)
        XCTAssertEqual(c.parsedRecordCount, 2)
        XCTAssertEqual(c.pairedLatencySampleCount, 2)
        XCTAssertEqual(c.evidence.correctnessVerified, true)
        XCTAssertEqual(c.evidence.speculativeMeanLatencyMillis!, 1.1, accuracy: 1e-9)
        XCTAssertEqual(c.evidence.baselineMeanLatencyMillis!, 2.0, accuracy: 1e-9)
        XCTAssertEqual(c.evidence.acceptanceRate!, 0.75, accuracy: 1e-9)
    }

    func testComposerCorrectnessIsHardAND() {
        let records = [
            record(["mode: sampling", "correctness_verified: true", "speculative_latency_ms: 1.0"]),
            record(["mode: sampling", "correctness_verified: false", "speculative_latency_ms: 1.0"]),
        ]
        let c = Composer.compose(records: records, mode: "sampling", distinctDeviceCount: 2)
        XCTAssertEqual(c.evidence.correctnessVerified, false,
            "any single record refuting correctness ⇒ aggregate FALSE (a hard AND)")
    }

    func testComposerSkipsForeignAndMalformed() {
        let records = [
            record(["mode: greedy", "speculative_latency_ms: 1.0"]),                 // valid (unpaired)
            record(["mode: greedy", "speculative_latency_ms: 1.0"], scope: "other"), // foreign scope
            record(["mode: greedy", "speculative_latency_ms: not-a-number"]),        // malformed required
            record(["mode: greedy", "speculative_latency_ms: 1.0", "correctness_verified: maybe"]), // malformed optional
        ]
        let c = Composer.compose(records: records, mode: "greedy", distinctDeviceCount: 1)
        XCTAssertEqual(c.parsedRecordCount, 1, "only the one valid in-scope record parses")
        XCTAssertEqual(c.skippedRecordCount, 2, "the malformed in-scope records are skipped (foreign isn't counted)")
        XCTAssertNil(c.evidence.speculativeMeanLatencyMillis, "unpaired ⇒ no latency mean")
    }

    func testComposerDecideAndRenderAreDeterministic() {
        let records = [
            record(["mode: greedy", "correctness_verified: true", "speculative_latency_ms: 1.0",
                    "baseline_latency_ms: 2.0"]),
        ]
        let (v1, c1) = Composer.decide(records: records, mode: "greedy", distinctDeviceCount: 1)
        let (v2, c2) = Composer.decide(records: records, mode: "greedy", distinctDeviceCount: 1)
        XCTAssertEqual(v1.recommendation, v2.recommendation)
        XCTAssertEqual(Composer.render(verdict: v1, composition: c1),
                       Composer.render(verdict: v2, composition: c2))
        XCTAssertEqual(v1.recommendation, .insufficientEvidence,
            "one device, one sample, no memory evidence ⇒ insufficient (never auto-enables)")
        XCTAssertTrue(Composer.render(verdict: v1, composition: c1).contains("observation-only"))
    }

    // MARK: - 3. Audit-3 fixes

    func testZeroPeakIsNoEvidenceNotFits() {
        // AUDIT FIX: peak=0 means "no measurement" (MLX stats unavailable), never MEMORY_FITS.
        let e = Verdict.Evidence(
            mode: "greedy", correctnessVerified: true,
            speculativeMeanLatencyMillis: 1.0, baselineMeanLatencyMillis: 2.0,
            dualPeakMemoryBytes: 0, memoryBudgetBytes: 6_000_000_000,
            sampleCount: 60, pairedLatencySampleCount: 60, distinctDeviceCount: 2)
        let v = Verdict.decide(evidence: e)
        XCTAssertEqual(v.recommendation, .insufficientEvidence,
            "a zero peak is a missing measurement — must be NO_EVIDENCE, not a vacuous fit")
        XCTAssertTrue(v.reasonCodes.contains(Verdict.Reason.memoryNoEvidence))
        XCTAssertFalse(v.reasonCodes.contains(Verdict.Reason.memoryFits))
    }

    func testUnpairedRecordsCannotInflateSampleCountPastPairedFloor() {
        // AUDIT FIX: 60 samples but only 3 paired ⇒ the latency means rest on n=3 ⇒ samplesBelowMin.
        let e = Verdict.Evidence(
            mode: "greedy", correctnessVerified: true,
            speculativeMeanLatencyMillis: 1.0, baselineMeanLatencyMillis: 2.0,
            dualPeakMemoryBytes: 3_000_000_000, memoryBudgetBytes: 6_000_000_000,
            sampleCount: 60, pairedLatencySampleCount: 3, distinctDeviceCount: 2)
        let v = Verdict.decide(evidence: e)
        XCTAssertEqual(v.recommendation, .insufficientEvidence,
            "latency evidence resting on 3 pairs must not enable just because 60 unpaired records exist")
        XCTAssertTrue(v.reasonCodes.contains(Verdict.Reason.samplesBelowMin))
    }

    func testComposerIsolatesModes() {
        // AUDIT FIX: greedy and sampling records are never pooled into one verdict.
        let records = [
            record(["mode: greedy", "correctness_verified: false", "speculative_latency_ms: 9.0",
                    "baseline_latency_ms: 1.0"]),                                       // greedy lane: bad
            record(["mode: sampling", "speculative_latency_ms: 1.0", "baseline_latency_ms: 2.0"]),
        ]
        let g = Composer.compose(records: records, mode: "greedy", distinctDeviceCount: 1)
        let m = Composer.compose(records: records, mode: "sampling", distinctDeviceCount: 1)
        XCTAssertEqual(g.parsedRecordCount, 1)
        XCTAssertEqual(m.parsedRecordCount, 1)
        XCTAssertEqual(g.evidence.correctnessVerified, false, "greedy lane sees ONLY its own failure")
        XCTAssertNil(m.evidence.correctnessVerified,
            "the sampling lane is untouched by the greedy lane's correctness failure (no pooling)")
        XCTAssertEqual(m.evidence.speculativeMeanLatencyMillis!, 1.0, accuracy: 1e-9,
            "sampling latency mean excludes the greedy record")
        XCTAssertEqual(g.evidence.mode, "greedy")
        XCTAssertEqual(m.evidence.mode, "sampling")
    }

    func testParserRejectsNonFiniteAndOutOfRangeValues() {
        // AUDIT hardening: nan/inf latencies and out-of-range acceptance must never poison the means.
        let records = [
            record(["mode: greedy", "speculative_latency_ms: nan"]),
            record(["mode: greedy", "speculative_latency_ms: inf"]),
            record(["mode: greedy", "speculative_latency_ms: -1"]),
            record(["mode: greedy", "speculative_latency_ms: 1.0", "baseline_latency_ms: nan"]),
            record(["mode: greedy", "speculative_latency_ms: 1.0", "acceptance_rate: 1.5"]),
            record(["mode: greedy", "speculative_latency_ms: 1.0"]),   // the one valid record
        ]
        let c = Composer.compose(records: records, mode: "greedy", distinctDeviceCount: 1)
        XCTAssertEqual(c.parsedRecordCount, 1, "all five corrupted records are rejected")
        XCTAssertEqual(c.skippedRecordCount, 5)
    }
}
