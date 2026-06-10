import XCTest
@testable import BASAppleAdapters

/// E1+E2 — the CoreML→Core AI migration GATE (`BASCoreAIMigrationVerdict`) + the parity corpus aggregator
/// (`BASCoreAIShadowComparison.aggregate`). PURE + framework-free, so the full truth table runs under the
/// default toolchain. The spine of the operator's doctrine ("亏的不要" / "migrate only if it WINS") lives here:
/// the gate must NEVER recommend `.migrate` on a tie, on missing evidence, or on a single device — and run
/// against TODAY's evidence (n=1, single device, parity-only) it must return `.insufficientEvidence`.
final class BASCoreAIMigrationVerdictTests: XCTestCase {

    // MARK: - Builders

    private func result(agree: Bool, mae: Float?) -> BASCoreAIShadowComparison.Result {
        .init(incumbentLabel: "task", candidateLabel: agree ? "task" : "chat",
              labelsAgree: agree, logitsMAE: mae, candidateLatencyMillis: 1)
    }

    private func parity(n: Int, agree: Int, mae: Float?) -> BASCoreAIShadowComparison.ParitySummary {
        .init(sampleCount: n, labelsAgreeCount: agree,
              labelAgreementRate: n == 0 ? 0 : Double(agree) / Double(n),
              maeSampleCount: mae == nil ? 0 : n, meanLogitsMAE: mae, maxLogitsMAE: mae)
    }

    // MARK: - 1. Aggregator

    func testAggregateEmptyCorpusIsHonestlyZeroNotOne() {
        let s = BASCoreAIShadowComparison.aggregate([])
        XCTAssertEqual(s.sampleCount, 0)
        XCTAssertEqual(s.labelsAgreeCount, 0)
        XCTAssertEqual(s.labelAgreementRate, 0, "no samples ⇒ 0 agreement, NOT a vacuous 1.0")
        XCTAssertEqual(s.maeSampleCount, 0)
        XCTAssertNil(s.meanLogitsMAE)
        XCTAssertNil(s.maxLogitsMAE)
    }

    func testAggregateAllAgreeFullRate() {
        let s = BASCoreAIShadowComparison.aggregate([
            result(agree: true, mae: 0.001), result(agree: true, mae: 0.003)])
        XCTAssertEqual(s.sampleCount, 2)
        XCTAssertEqual(s.labelAgreementRate, 1.0)
        XCTAssertEqual(s.maeSampleCount, 2)
        XCTAssertEqual(try XCTUnwrap(s.maxLogitsMAE), 0.003, accuracy: 1e-7)
        XCTAssertEqual(try XCTUnwrap(s.meanLogitsMAE), 0.002, accuracy: 1e-7)
    }

    func testAggregateCountsOnlyComparableLogitsForMAE() {
        // A sample with nil MAE (mismatched logits widths) is a LABEL datapoint but NOT an MAE datapoint.
        let s = BASCoreAIShadowComparison.aggregate([
            result(agree: true, mae: 0.01), result(agree: false, mae: nil), result(agree: true, mae: 0.03)])
        XCTAssertEqual(s.sampleCount, 3)
        XCTAssertEqual(s.labelsAgreeCount, 2)
        XCTAssertEqual(s.labelAgreementRate, 2.0 / 3.0, accuracy: 1e-9)
        XCTAssertEqual(s.maeSampleCount, 2, "the nil-MAE sample contributes no MAE datapoint")
        XCTAssertEqual(try XCTUnwrap(s.maxLogitsMAE), 0.03, accuracy: 1e-7)
    }

    func testAggregateForcesNonFiniteMAEToNaNMax() {
        // A corrupted (NaN) MAE in a NON-first position would be silently dropped by Array.max() (it uses `<`),
        // returning a finite max that could pass parity. aggregate must force a non-finite MAX instead.
        let s = BASCoreAIShadowComparison.aggregate([
            result(agree: true, mae: 0.001),
            result(agree: true, mae: Float.nan),     // middle position — max() would drop this
            result(agree: true, mae: 0.002)])
        XCTAssertEqual(s.maeSampleCount, 3, "the NaN is still a non-nil MAE datapoint")
        XCTAssertTrue(try XCTUnwrap(s.maxLogitsMAE).isNaN,
            "any non-finite MAE must surface as a NaN max, never be dropped by Array.max()")
        // +Inf is likewise non-finite and must surface as NaN (uniform corruption signal).
        let sInf = BASCoreAIShadowComparison.aggregate([
            result(agree: true, mae: 0.001), result(agree: true, mae: Float.infinity)])
        XCTAssertTrue(try XCTUnwrap(sInf.maxLogitsMAE).isNaN)
    }

    func testNaNCorruptedLogitsFailParityNeverMigrate() {
        // A candidate emitting NaN-corrupted logits must FAIL parity (doNotMigrate), never slip through as
        // PARITY_MET via the IEEE-754 `NaN > ε == false` hole. This is the critical-finding regression guard.
        let e = BASCoreAIMigrationVerdict.Evidence(
            parity: parity(n: 60, agree: 60, mae: Float.nan),
            candidateMeanLatencyMillis: 8, incumbentMeanLatencyMillis: 10,
            candidatePeakMemoryBytes: 800, incumbentPeakMemoryBytes: 1000, distinctDeviceCount: 2)
        let v = BASCoreAIMigrationVerdict.decide(evidence: e)
        XCTAssertEqual(v.recommendation, .doNotMigrate,
            "NaN-corrupted logits must be rejected, not certified as a parity win")
        XCTAssertTrue(v.reasonCodes.contains("PARITY_FAILED_MAE"))
        XCTAssertFalse(v.reasonCodes.contains("PARITY_MET"))
    }

    // MARK: - 2. The today's-reality canary (the whole point)

    func testTodayEvidenceForcesInsufficientEvidence() {
        // Exactly what the iPhone Air run produced: 4/4 label parity, MAE ~1e-6, ONLY candidate latency
        // captured (no incumbent baseline), no memory comparison, ONE device. The gate MUST refuse to migrate.
        let e = BASCoreAIMigrationVerdict.Evidence(
            parity: parity(n: 4, agree: 4, mae: 1e-6), distinctDeviceCount: 1)
        let v = BASCoreAIMigrationVerdict.decide(evidence: e)
        XCTAssertEqual(v.recommendation, .insufficientEvidence,
            "matched ≠ won — today's n=1 single-device parity-only evidence cannot retire CoreML")
        XCTAssertEqual(v.reasonCodes, [
            "DEVICES_BELOW_MIN", "LATENCY_NO_EVIDENCE", "MEMORY_NO_EVIDENCE",
            "PARITY_MET", "SAMPLES_BELOW_MIN"])
    }

    // MARK: - 3. The only path to .migrate

    func testFullWinAcrossAllDimensionsMigrates() {
        let e = BASCoreAIMigrationVerdict.Evidence(
            parity: parity(n: 60, agree: 60, mae: 1e-5),
            candidateMeanLatencyMillis: 8, incumbentMeanLatencyMillis: 10,   // 8 <= 9.5 ⇒ win
            candidatePeakMemoryBytes: 800, incumbentPeakMemoryBytes: 1000,   // 800 <= 950 ⇒ win
            distinctDeviceCount: 2)
        let v = BASCoreAIMigrationVerdict.decide(evidence: e)
        XCTAssertEqual(v.recommendation, .migrate)
        XCTAssertEqual(v.reasonCodes, ["LATENCY_WIN", "MEMORY_WIN", "PARITY_MET"])
    }

    // MARK: - 4. Any single missing/short dimension blocks .migrate

    func testMissingLatencyAloneBlocksMigrate() {
        let e = BASCoreAIMigrationVerdict.Evidence(
            parity: parity(n: 60, agree: 60, mae: 1e-5),
            candidatePeakMemoryBytes: 800, incumbentPeakMemoryBytes: 1000, distinctDeviceCount: 2)
        let v = BASCoreAIMigrationVerdict.decide(evidence: e)
        XCTAssertEqual(v.recommendation, .insufficientEvidence)
        XCTAssertTrue(v.reasonCodes.contains("LATENCY_NO_EVIDENCE"))
        XCTAssertFalse(v.reasonCodes.contains("LATENCY_WIN"))
    }

    func testSingleDeviceBlocksMigrateEvenOnFullWin() {
        let e = BASCoreAIMigrationVerdict.Evidence(
            parity: parity(n: 60, agree: 60, mae: 1e-5),
            candidateMeanLatencyMillis: 8, incumbentMeanLatencyMillis: 10,
            candidatePeakMemoryBytes: 800, incumbentPeakMemoryBytes: 1000,
            distinctDeviceCount: 1)   // <2
        let v = BASCoreAIMigrationVerdict.decide(evidence: e)
        XCTAssertEqual(v.recommendation, .insufficientEvidence)
        XCTAssertTrue(v.reasonCodes.contains("DEVICES_BELOW_MIN"))
    }

    func testFewSamplesBlockMigrateEvenOnFullWin() {
        let e = BASCoreAIMigrationVerdict.Evidence(
            parity: parity(n: 10, agree: 10, mae: 1e-5),   // <50
            candidateMeanLatencyMillis: 8, incumbentMeanLatencyMillis: 10,
            candidatePeakMemoryBytes: 800, incumbentPeakMemoryBytes: 1000, distinctDeviceCount: 2)
        let v = BASCoreAIMigrationVerdict.decide(evidence: e)
        XCTAssertEqual(v.recommendation, .insufficientEvidence)
        XCTAssertTrue(v.reasonCodes.contains("SAMPLES_BELOW_MIN"))
    }

    // MARK: - 5. A proven LOSS (regression) ⇒ doNotMigrate — decisive

    func testLatencyRegressionDoesNotMigrate() {
        let e = BASCoreAIMigrationVerdict.Evidence(
            parity: parity(n: 60, agree: 60, mae: 1e-5),
            candidateMeanLatencyMillis: 12, incumbentMeanLatencyMillis: 10,   // 12 > 10 ⇒ loss
            candidatePeakMemoryBytes: 800, incumbentPeakMemoryBytes: 1000, distinctDeviceCount: 2)
        let v = BASCoreAIMigrationVerdict.decide(evidence: e)
        XCTAssertEqual(v.recommendation, .doNotMigrate)
        XCTAssertTrue(v.reasonCodes.contains("LATENCY_LOSS"))
    }

    func testMemoryRegressionDoesNotMigrate() {
        let e = BASCoreAIMigrationVerdict.Evidence(
            parity: parity(n: 60, agree: 60, mae: 1e-5),
            candidateMeanLatencyMillis: 8, incumbentMeanLatencyMillis: 10,
            candidatePeakMemoryBytes: 1100, incumbentPeakMemoryBytes: 1000,   // 1100 > 1000 ⇒ loss
            distinctDeviceCount: 2)
        let v = BASCoreAIMigrationVerdict.decide(evidence: e)
        XCTAssertEqual(v.recommendation, .doNotMigrate)
        XCTAssertTrue(v.reasonCodes.contains("MEMORY_LOSS"))
    }

    func testParityLabelFailureDoesNotMigrate() {
        let e = BASCoreAIMigrationVerdict.Evidence(
            parity: parity(n: 60, agree: 59, mae: 1e-5),   // 59/60 < 100%
            candidateMeanLatencyMillis: 8, incumbentMeanLatencyMillis: 10,
            candidatePeakMemoryBytes: 800, incumbentPeakMemoryBytes: 1000, distinctDeviceCount: 2)
        let v = BASCoreAIMigrationVerdict.decide(evidence: e)
        XCTAssertEqual(v.recommendation, .doNotMigrate)
        XCTAssertTrue(v.reasonCodes.contains("PARITY_FAILED_LABEL"))
    }

    func testParityMAEFailureDoesNotMigrate() {
        let e = BASCoreAIMigrationVerdict.Evidence(
            parity: parity(n: 60, agree: 60, mae: 0.5),   // MAE 0.5 >> 1e-3
            candidateMeanLatencyMillis: 8, incumbentMeanLatencyMillis: 10,
            candidatePeakMemoryBytes: 800, incumbentPeakMemoryBytes: 1000, distinctDeviceCount: 2)
        let v = BASCoreAIMigrationVerdict.decide(evidence: e)
        XCTAssertEqual(v.recommendation, .doNotMigrate)
        XCTAssertTrue(v.reasonCodes.contains("PARITY_FAILED_MAE"))
    }

    // MARK: - 6. Full evidence, no loss, but no benefit (a tie) ⇒ doNotMigrate (don't churn)

    func testMeasuredTieDoesNotMigrate() {
        let e = BASCoreAIMigrationVerdict.Evidence(
            parity: parity(n: 60, agree: 60, mae: 1e-5),
            candidateMeanLatencyMillis: 9.7, incumbentMeanLatencyMillis: 10,   // within 5% band ⇒ tie
            candidatePeakMemoryBytes: 800, incumbentPeakMemoryBytes: 1000,     // win
            distinctDeviceCount: 2)
        let v = BASCoreAIMigrationVerdict.decide(evidence: e)
        XCTAssertEqual(v.recommendation, .doNotMigrate,
            "a measured no-net-benefit tie must NOT trigger migration churn (亏的不要)")
        XCTAssertTrue(v.reasonCodes.contains("LATENCY_TIE"))
    }

    // MARK: - 7. Priority: a LOSS outranks insufficiency

    func testLossOutranksMissingEvidence() {
        // Latency regresses AND memory is unmeasured AND samples are short — the regression is decisive.
        let e = BASCoreAIMigrationVerdict.Evidence(
            parity: parity(n: 5, agree: 5, mae: 1e-5),
            candidateMeanLatencyMillis: 20, incumbentMeanLatencyMillis: 10,   // loss
            distinctDeviceCount: 1)
        let v = BASCoreAIMigrationVerdict.decide(evidence: e)
        XCTAssertEqual(v.recommendation, .doNotMigrate, "a known regression decides it, gaps notwithstanding")
        XCTAssertTrue(v.reasonCodes.contains("LATENCY_LOSS"))
    }

    // MARK: - 8. Parity with no comparable logits ⇒ never migrate

    func testParityWithoutComparableLogitsIsNoEvidence() {
        let e = BASCoreAIMigrationVerdict.Evidence(
            parity: parity(n: 60, agree: 60, mae: nil),   // labels seen, but zero comparable logits
            candidateMeanLatencyMillis: 8, incumbentMeanLatencyMillis: 10,
            candidatePeakMemoryBytes: 800, incumbentPeakMemoryBytes: 1000, distinctDeviceCount: 2)
        let v = BASCoreAIMigrationVerdict.decide(evidence: e)
        XCTAssertEqual(v.recommendation, .insufficientEvidence)
        XCTAssertTrue(v.reasonCodes.contains("PARITY_NO_EVIDENCE"))
        XCTAssertFalse(v.reasonCodes.contains("PARITY_MET"))
    }

    // MARK: - 9. Determinism + sortedness

    func testVerdictIsDeterministicAndReasonsSorted() {
        let e = BASCoreAIMigrationVerdict.Evidence(
            parity: parity(n: 4, agree: 4, mae: 1e-6), distinctDeviceCount: 1)
        let a = BASCoreAIMigrationVerdict.decide(evidence: e)
        let b = BASCoreAIMigrationVerdict.decide(evidence: e)
        XCTAssertEqual(a, b, "pure ⇒ identical verdict")
        XCTAssertEqual(a.reasonCodes, a.reasonCodes.sorted(), "reason codes must be deterministically sorted")
    }
}
