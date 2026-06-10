import XCTest
@testable import BASAppleAdapters
@testable import BASMemory

/// K2 — the evidence composer that wires the shadow-trial ledger into the CoreML→CoreAI migration gate.
/// PURE (framework-free): ledger records → parse → aggregate → Evidence → decide → render. The gate previously
/// had no production caller; these tests pin the wiring end-to-end, including the paired-only latency honesty
/// rule and the today's-reality outcome (insufficientEvidence).
final class BASCoreAIVerdictEvidenceComposerTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let t1 = Date(timeIntervalSince1970: 1_700_000_001)

    private func recordedLedger(
        _ comparisons: [BASCoreAIShadowComparison.Result]
    ) -> [BASShadowTrialRecord] {
        var ledger = BASShadowTrialFeedbackLedger()
        for (i, comparison) in comparisons.enumerated() {
            ledger = BASCoreAIShadowComparison.record(
                into: ledger, trialID: "t-\(i)", inputLength: 10 + i,
                comparison: comparison, startAt: t0, endAt: t1)
        }
        return ledger.pendingTrials
    }

    private func result(
        agree: Bool = true, mae: Float? = 1e-6,
        candMs: Double = 1.0, incMs: Double? = nil
    ) -> BASCoreAIShadowComparison.Result {
        .init(incumbentLabel: "task", candidateLabel: agree ? "task" : "chat",
              labelsAgree: agree, logitsMAE: mae,
              candidateLatencyMillis: candMs, incumbentLatencyMillis: incMs)
    }

    // MARK: - 1. Parse round-trip (record → parse → identical Result)

    func testParseRoundTripsARecordedComparison() throws {
        let original = result(agree: true, mae: 0.000123, candMs: 4.25, incMs: 6.5)
        let records = recordedLedger([original])
        let parsed = try XCTUnwrap(BASCoreAIVerdictEvidenceComposer.parse(record: records[0]))
        XCTAssertEqual(parsed.incumbentLabel, "task")
        XCTAssertEqual(parsed.candidateLabel, "task")
        XCTAssertTrue(parsed.labelsAgree)
        XCTAssertEqual(try XCTUnwrap(parsed.logitsMAE), 0.000123, accuracy: 1e-9)
        XCTAssertEqual(parsed.candidateLatencyMillis, 4.25)
        XCTAssertEqual(try XCTUnwrap(parsed.incumbentLatencyMillis), 6.5)
    }

    func testParseRoundTripsUnpairedAndNAMae() throws {
        // Pre-pairing record shape: no incumbent_latency_ms line; "n/a" MAE (mismatched logits spaces).
        let records = recordedLedger([result(agree: false, mae: nil, candMs: 2.0, incMs: nil)])
        let parsed = try XCTUnwrap(BASCoreAIVerdictEvidenceComposer.parse(record: records[0]))
        XCTAssertFalse(parsed.labelsAgree)
        XCTAssertNil(parsed.logitsMAE, "'logits_mae: n/a' must parse back to nil")
        XCTAssertNil(parsed.incumbentLatencyMillis, "absent line must parse to nil (unpaired)")
    }

    // MARK: - 2. Parse rejects foreign / malformed records (never guesses)

    func testParseRejectsForeignScopeAndMalformedRecords() {
        let foreign = BASShadowTrialRecord(
            trialID: "x", candidateRef: "other.candidate", trialScope: "some-other-scope",
            startAt: t0, endAt: t1,
            observedEffects: ["incumbent_label: task", "candidate_label: task",
                              "labels_agree: true", "candidate_latency_ms: 1.0"],
            failConditions: [], completionState: "observing")
        XCTAssertNil(BASCoreAIVerdictEvidenceComposer.parse(record: foreign),
            "foreign trialScope must be skipped, not interpreted")

        let missingRequired = BASShadowTrialRecord(
            trialID: "y", candidateRef: "coreai.context-classifier.v1",
            trialScope: "coreai-classifier", startAt: t0, endAt: t1,
            observedEffects: ["incumbent_label: task"],   // no candidate/agree/latency
            failConditions: [], completionState: "observing")
        XCTAssertNil(BASCoreAIVerdictEvidenceComposer.parse(record: missingRequired))

        let malformedMAE = BASShadowTrialRecord(
            trialID: "z", candidateRef: "coreai.context-classifier.v1",
            trialScope: "coreai-classifier", startAt: t0, endAt: t1,
            observedEffects: ["incumbent_label: task", "candidate_label: task",
                              "labels_agree: true", "logits_mae: garbage",
                              "candidate_latency_ms: 1.0"],
            failConditions: [], completionState: "observing")
        XCTAssertNil(BASCoreAIVerdictEvidenceComposer.parse(record: malformedMAE),
            "present-but-malformed MAE must reject the record (never guessed)")
    }

    // MARK: - 3. Paired-only latency means

    func testComposeUsesPairedOnlyLatencyMeans() {
        let records = recordedLedger([
            result(candMs: 1.0, incMs: 3.0),    // paired
            result(candMs: 2.0, incMs: 5.0),    // paired
            result(candMs: 100.0, incMs: nil),  // UNPAIRED — must not pollute the means
        ])
        let c = BASCoreAIVerdictEvidenceComposer.compose(records: records, distinctDeviceCount: 1)
        XCTAssertEqual(c.parsedRecordCount, 3)
        XCTAssertEqual(c.pairedLatencySampleCount, 2)
        XCTAssertEqual(c.evidence.parity.sampleCount, 3, "unpaired records still contribute parity")
        XCTAssertEqual(c.evidence.candidateMeanLatencyMillis, 1.5)
        XCTAssertEqual(c.evidence.incumbentMeanLatencyMillis, 4.0)
    }

    func testComposeNoPairedRecordsYieldsNilMeansAndLatencyNoEvidence() {
        let records = recordedLedger([result(incMs: nil), result(incMs: nil)])
        let (verdict, composition) = BASCoreAIVerdictEvidenceComposer.decide(
            records: records, distinctDeviceCount: 1)
        XCTAssertNil(composition.evidence.candidateMeanLatencyMillis,
            "unpaired-only ledger ⇒ NO latency means (a candidate-only mean would be uncomparable)")
        XCTAssertNil(composition.evidence.incumbentMeanLatencyMillis)
        XCTAssertTrue(verdict.reasonCodes.contains("LATENCY_NO_EVIDENCE"))
    }

    // MARK: - 4. Today's reality: the probe's actual ledger shape → insufficientEvidence

    func testTodayRealityProbeLedgerYieldsInsufficientEvidence() {
        // Exactly what the iPhone Air probe records per run (now WITH paired latency): 4 agreeing trials,
        // tiny MAE, 1 device, no memory comparison. Candidate FASTER here (a latency win) so the verdict
        // isolates the COVERAGE gaps — note: if the candidate were SLOWER, the gate would say doNotMigrate
        // (loss is decisive), which testLatencyRegression… in the gate suite already pins.
        let records = recordedLedger((0..<4).map { _ in
            result(agree: true, mae: 1e-6, candMs: 0.7, incMs: 0.9)
        })
        let (verdict, _) = BASCoreAIVerdictEvidenceComposer.decide(
            records: records, distinctDeviceCount: 1)
        XCTAssertEqual(verdict.recommendation, .insufficientEvidence,
            "n=4 / 1 device / no memory evidence must NOT migrate (亏的不要)")
        XCTAssertTrue(verdict.reasonCodes.contains("SAMPLES_BELOW_MIN"))
        XCTAssertTrue(verdict.reasonCodes.contains("DEVICES_BELOW_MIN"))
        XCTAssertTrue(verdict.reasonCodes.contains("MEMORY_NO_EVIDENCE"))
    }

    // MARK: - 5. Full-win ledger end-to-end → migrate (the only green path)

    func testFullWinLedgerEndToEndMigrates() {
        let records = recordedLedger((0..<60).map { _ in
            result(agree: true, mae: 1e-5, candMs: 8.0, incMs: 10.0)
        })
        let (verdict, composition) = BASCoreAIVerdictEvidenceComposer.decide(
            records: records, distinctDeviceCount: 2,
            candidatePeakMemoryBytes: 800, incumbentPeakMemoryBytes: 1000)
        XCTAssertEqual(composition.pairedLatencySampleCount, 60)
        XCTAssertEqual(verdict.recommendation, .migrate,
            "60 samples, 2 devices, parity met, latency+memory wins ⇒ the gate's one green path")
        XCTAssertEqual(verdict.reasonCodes, ["LATENCY_WIN", "MEMORY_WIN", "PARITY_MET"])
    }

    // MARK: - 6. Render + determinism

    func testRenderIsDeterministicAndCarriesRecommendation() {
        let records = recordedLedger([result(incMs: 2.0)])   // candidate 1.0 vs incumbent 2.0 — no latency loss
        let (verdict, composition) = BASCoreAIVerdictEvidenceComposer.decide(
            records: records, distinctDeviceCount: 1)
        let a = BASCoreAIVerdictEvidenceComposer.render(verdict: verdict, composition: composition)
        let b = BASCoreAIVerdictEvidenceComposer.render(verdict: verdict, composition: composition)
        XCTAssertEqual(a, b, "pure ⇒ byte-identical render")
        XCTAssertTrue(a.contains("recommendation=insufficientEvidence"))
        XCTAssertTrue(a.contains("never auto-promotes"))
        XCTAssertTrue(a.contains("paired n=1"))
    }

    func testSkippedRecordsAreCounted() {
        var records = recordedLedger([result()])
        records.append(BASShadowTrialRecord(
            trialID: "bad", candidateRef: "coreai.context-classifier.v1",
            trialScope: "coreai-classifier", startAt: t0, endAt: t1,
            observedEffects: ["nonsense"], failConditions: [], completionState: "observing"))
        let c = BASCoreAIVerdictEvidenceComposer.compose(records: records, distinctDeviceCount: 1)
        XCTAssertEqual(c.parsedRecordCount, 1)
        XCTAssertEqual(c.skippedRecordCount, 1, "malformed records must be visibly counted, not silently dropped")
    }
}
