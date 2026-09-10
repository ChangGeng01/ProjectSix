import XCTest
@testable import BASAppleAdapters
@testable import BASMemory

/// C4 — the observation-only Core-AI-vs-CoreML shadow comparison. PURE (framework-free), so it runs under the
/// default Xcode 26.5 toolchain with a DETERMINISTIC fake candidate (the real Core AI candidate runs on iOS 27).
/// Proves: the parity summary is correct; the trial is recorded as PENDING ("observing", never auto-promoted);
/// and the incumbent ledger is never mutated (immutability — 红线 4).
final class BASCoreAIShadowComparisonTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let t1 = Date(timeIntervalSince1970: 1_700_000_001)

    // MARK: - logitsMAE

    func testLogitsMAEIsZeroForIdenticalVectors() {
        XCTAssertEqual(BASCoreAIShadowComparison.logitsMAE([0.1, 0.2, 0.7], [0.1, 0.2, 0.7]), 0)
    }

    func testLogitsMAEIsMeanAbsoluteDifference() {
        // |0-1| + |1-0| = 2, /2 = 1.0
        XCTAssertEqual(BASCoreAIShadowComparison.logitsMAE([0, 1], [1, 0]), 1.0)
    }

    func testLogitsMAEIsNilForMismatchedLengthOrEmpty() {
        XCTAssertNil(BASCoreAIShadowComparison.logitsMAE([1, 2, 3], [1, 2]))
        XCTAssertNil(BASCoreAIShadowComparison.logitsMAE([], []))
    }

    // MARK: - compare

    func testCompareReportsAgreementAndMAE() throws {
        let r = BASCoreAIShadowComparison.compare(
            incumbentLabel: "task", incumbentLogits: [0, 1, 0],
            candidateLabel: "task", candidateLogits: [0.1, 0.9, 0.0],
            candidateLatencyMillis: 4.2)
        XCTAssertTrue(r.labelsAgree)
        XCTAssertEqual(r.incumbentLabel, "task")
        XCTAssertEqual(r.candidateLabel, "task")
        XCTAssertEqual(try XCTUnwrap(r.logitsMAE), (0.1 + 0.1 + 0.0) / 3, accuracy: 1e-6)
        XCTAssertEqual(r.candidateLatencyMillis, 4.2)
    }

    func testCompareWithMismatchedLogitsRecordsMAEAsUnavailable() {
        // The full compare()→record() path with logits of DIFFERENT lengths (e.g. a future model revision):
        // MAE must be nil (not a bogus number) and the record must carry "logits_mae: n/a" honestly.
        let r = BASCoreAIShadowComparison.compare(
            incumbentLabel: "task", incumbentLogits: [0, 1, 0],
            candidateLabel: "task", candidateLogits: [0, 1],
            candidateLatencyMillis: 1)
        XCTAssertNil(r.logitsMAE, "mismatched logits spaces must NOT produce a fake MAE")
        let updated = BASCoreAIShadowComparison.record(
            into: BASShadowTrialFeedbackLedger(), trialID: "t-mismatch", inputLength: 3,
            comparison: r, startAt: t0, endAt: t1)
        XCTAssertTrue(
            updated.pendingTrials.first?.observedEffects.contains("logits_mae: n/a") ?? false,
            "a nil MAE must be recorded as n/a (honest), never a number")
    }

    func testCompareReportsDisagreement() {
        let r = BASCoreAIShadowComparison.compare(
            incumbentLabel: "task", incumbentLogits: [0, 1],
            candidateLabel: "chat", candidateLogits: [1, 0],
            candidateLatencyMillis: 1)
        XCTAssertFalse(r.labelsAgree)
    }

    // MARK: - record (observation-only, immutable)

    func testRecordAppendsPendingTrialWithoutMutatingIncumbentLedger() throws {
        let incumbentLedger = BASShadowTrialFeedbackLedger()   // empty
        let comparison = BASCoreAIShadowComparison.compare(
            incumbentLabel: "manipulationRisk", incumbentLogits: [0, 0, 0, 0, 0, 1, 0],
            candidateLabel: "manipulationRisk", candidateLogits: [0, 0, 0, 0, 0, 0.95, 0.05],
            candidateLatencyMillis: 6.5)

        let updated = BASCoreAIShadowComparison.record(
            into: incumbentLedger,
            trialID: "trial-coreai-1",
            inputLength: 42,
            comparison: comparison,
            startAt: t0, endAt: t1)

        // Immutability: the receiver is untouched.
        XCTAssertEqual(incumbentLedger.pendingTrials.count, 0,
            "the incumbent ledger must NOT be mutated (immutability — 红线 4)")
        XCTAssertEqual(updated.pendingTrials.count, 1)

        // `try` (NOT `try?`) — a missing record must FAIL here with the unwrap message, not cascade nils.
        let record = try XCTUnwrap(updated.pendingTrials.first)
        XCTAssertEqual(record.trialID, "trial-coreai-1")
        XCTAssertEqual(record.candidateRef, "coreai.context-classifier.v1")
        XCTAssertEqual(record.trialScope, "coreai-classifier")
        XCTAssertEqual(record.completionState, "observing",
            "the trial must be PENDING — observation-only, never auto-promoted")
        // The parity summary is recorded; the input TEXT is not (length only — no PII into the ledger).
        let effects = record.observedEffects
        XCTAssertTrue(effects.contains("input_len: 42"))
        XCTAssertTrue(effects.contains("labels_agree: true"))
        XCTAssertTrue(effects.contains { $0.hasPrefix("logits_mae: ") })
        XCTAssertFalse(effects.contains { $0.contains("input_text") },
            "the raw input text must never be logged into the trial ledger")
    }

    func testRecordIsDeterministicForFixedTimestamps() {
        let ledger = BASShadowTrialFeedbackLedger()
        let comparison = BASCoreAIShadowComparison.compare(
            incumbentLabel: "chat", incumbentLogits: [1, 0],
            candidateLabel: "chat", candidateLogits: [1, 0],
            candidateLatencyMillis: 2)
        let a = BASCoreAIShadowComparison.record(
            into: ledger, trialID: "t", inputLength: 1, comparison: comparison, startAt: t0, endAt: t1)
        let b = BASCoreAIShadowComparison.record(
            into: ledger, trialID: "t", inputLength: 1, comparison: comparison, startAt: t0, endAt: t1)
        XCTAssertEqual(a.pendingTrials.first?.observedEffects, b.pendingTrials.first?.observedEffects,
            "pure + caller-supplied timestamps ⇒ byte-equal record")
    }

    // MARK: - The pure label math the Core AI adapter shares with the incumbent

    func testArgmaxSoftmaxPicksMaxLabelWithStableConfidence() {
        let labels = ["chat", "task", "choice"]
        let decided = BASCoreAIContextClassifierMath.argmaxSoftmax(labels: labels, logits: [0.1, 5.0, 0.2])
        XCTAssertEqual(decided.label, "task")
        XCTAssertGreaterThan(decided.confidence, 0.9, "a dominant logit ⇒ high softmax confidence")
        XCTAssertLessThanOrEqual(decided.confidence, 1.0)
    }

    func testArgmaxSoftmaxUniformLogitsGiveUniformConfidence() {
        let labels = ["a", "b", "c", "d"]
        let decided = BASCoreAIContextClassifierMath.argmaxSoftmax(labels: labels, logits: [1, 1, 1, 1])
        XCTAssertEqual(decided.confidence, 0.25, accuracy: 1e-6, "uniform logits ⇒ 1/N confidence")
    }
}
