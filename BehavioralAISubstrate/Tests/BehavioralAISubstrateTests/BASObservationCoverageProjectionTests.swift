import XCTest
import BASRuntimeCore
@testable import BASWorldPrior
@testable import BASPolicy
@testable import BASMemory
@testable import BASOrchestration

final class BASObservationCoverageProjectionTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 0)

    // MARK: - L4 world prior

    func testWorldPriorProjectionCarriesLayerAndFields() {
        let bundle = BASWorldPriorObservationBundle(
            turnID: "t-1",
            sessionID: "s-1",
            observations: [
                BASWorldPriorObservation(
                    kind: .templateMatched,
                    templateID: "a",
                    evidenceLevel: .wellSupported,
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASWorldPriorObservation(
                    kind: .counterfactualSeeded,
                    templateID: "a",
                    evidenceLevel: .plausible,
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASWorldPriorObservation(
                    kind: .templateMatched,
                    templateID: "b",
                    evidenceLevel: .plausible,
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0)
            ],
            emittedAt: t0)
        let s = bundle.coverageSummary
        XCTAssertEqual(s.layer, .worldPrior)
        XCTAssertEqual(s.turnID, "t-1")
        XCTAssertEqual(s.sessionID, "s-1")
        XCTAssertEqual(s.totalObservations, 3)
        XCTAssertEqual(s.distinctSubjectCount, 2)
        XCTAssertTrue(s.hasCoreSignalCoverage)
        XCTAssertEqual(
            s.budgetTotalCost,
            0.10 + 0.30 + 0.10,
            accuracy: 1e-9)
    }

    // MARK: - L6 presence (channel-addressed)

    func testPresenceProjectionMapsDistinctChannels() {
        let obs: (BASPresenceChannel) -> BASPresenceObservation = {
            BASPresenceObservation(
                channel: $0,
                salience: 0.5, confidence: 0.5,
                content: "x", observedAt: self.t0)
        }
        let bundle = BASPresenceObservationBundle(
            turnID: "t-2",
            sessionID: "s-2",
            observations: [
                obs(.task), obs(.risk), obs(.manipulation),
                obs(.task)
            ],
            emittedAt: t0)
        let s = bundle.coverageSummary
        XCTAssertEqual(s.layer, .presenceEye)
        XCTAssertEqual(s.totalObservations, 4)
        XCTAssertEqual(s.distinctSubjectCount, 3)
        XCTAssertTrue(s.hasCoreSignalCoverage)
    }

    // MARK: - L7 mirror blade (kind-addressed)

    func testDecompositionProjectionMapsDistinctKinds() {
        let obs: (BASDecompositionSignalKind) -> BASDecompositionObservation = {
            BASDecompositionObservation(
                kind: $0,
                salience: 0.5, confidence: 0.5,
                content: "x", observedAt: self.t0)
        }
        let bundle = BASDecompositionObservationBundle(
            turnID: "t-3",
            sessionID: "s-3",
            observations: [
                obs(.factShard), obs(.contradiction),
                obs(.mirrorDraft), obs(.factShard)
            ],
            emittedAt: t0)
        let s = bundle.coverageSummary
        XCTAssertEqual(s.layer, .mirrorBlade)
        XCTAssertEqual(s.totalObservations, 4)
        XCTAssertEqual(s.distinctSubjectCount, 3)
        XCTAssertTrue(s.hasCoreSignalCoverage)
    }

    // MARK: - L9 dream loop

    func testCandidateProjectionMapsCandidateIDs() {
        let obs: (BASCandidateSignalKind, String) -> BASCandidateObservation = {
            BASCandidateObservation(
                kind: $0,
                candidateID: $1,
                salience: 0.5, confidence: 0.5,
                content: "x", observedAt: self.t0)
        }
        let bundle = BASCandidateObservationBundle(
            turnID: "t-4",
            sessionID: "s-4",
            observations: [
                obs(.candidate, "a"),
                obs(.reversibilitySignal, "a"),
                obs(.guardianBranch, "a"),
                obs(.candidate, "b")
            ],
            emittedAt: t0)
        let s = bundle.coverageSummary
        XCTAssertEqual(s.layer, .dreamLoop)
        XCTAssertEqual(s.distinctSubjectCount, 2)
        XCTAssertTrue(s.hasCoreSignalCoverage)
    }

    // MARK: - L10 tribunal

    func testTribunalProjectionMapsSubjectIDs() {
        let vote: (BASTribunalVoice, BASTribunalDisposition, String) -> BASTribunalObservation = {
            BASTribunalObservation(
                kind: .vote,
                voice: $0,
                disposition: $1,
                subjectID: $2,
                salience: 0.5, confidence: 0.5,
                content: "x", observedAt: self.t0)
        }
        let bundle = BASTribunalObservationBundle(
            turnID: "t-5",
            sessionID: "s-5",
            observations: [
                vote(.baseSelf, .affirm, "sub-a"),
                vote(.ruleSelf, .affirm, "sub-a"),
                vote(.aspireSelf, .affirm, "sub-a"),
                BASTribunalObservation(
                    kind: .convergence,
                    voice: nil,
                    disposition: nil,
                    subjectID: "sub-a",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0)
            ],
            emittedAt: t0)
        let s = bundle.coverageSummary
        XCTAssertEqual(s.layer, .triSelfTribunal)
        XCTAssertEqual(s.distinctSubjectCount, 1)
        XCTAssertTrue(s.hasCoreSignalCoverage)
    }

    // MARK: - L11 risk

    func testRiskProjectionMapsIntentIDs() {
        let obs: (BASRiskSignalKind, String) -> BASRiskObservation = {
            BASRiskObservation(
                kind: $0,
                intentID: $1,
                salience: 0.5, confidence: 0.5,
                content: "x", observedAt: self.t0)
        }
        let bundle = BASRiskObservationBundle(
            turnID: "t-6",
            sessionID: "s-6",
            observations: [
                obs(.hazardReading, "i-a"),
                obs(.irreversibilityReading, "i-a"),
                obs(.harmPotentialReading, "i-a"),
                obs(.hazardReading, "i-b")
            ],
            emittedAt: t0)
        let s = bundle.coverageSummary
        XCTAssertEqual(s.layer, .riskClimate)
        XCTAssertEqual(s.distinctSubjectCount, 2)
        XCTAssertTrue(s.hasCoreSignalCoverage)
    }

    // MARK: - L12 soft hand

    func testSoftHandProjectionMapsSubjectIDs() {
        let obs: (BASSoftHandSignalKind, BASSoftHandMode, String) -> BASSoftHandObservation = {
            BASSoftHandObservation(
                kind: $0, mode: $1,
                subjectID: $2,
                salience: 0.5, confidence: 0.5,
                content: "x", observedAt: self.t0)
        }
        let bundle = BASSoftHandObservationBundle(
            turnID: "t-7",
            sessionID: "s-7",
            observations: [
                obs(.selection, .compare, "sub-a"),
                obs(.render, .compare, "sub-a"),
                obs(.selection, .draft, "sub-b")
            ],
            emittedAt: t0)
        let s = bundle.coverageSummary
        XCTAssertEqual(s.layer, .gentleHand)
        XCTAssertEqual(s.distinctSubjectCount, 2)
        XCTAssertTrue(s.hasCoreSignalCoverage)
    }

    // MARK: - L13 shadow trial

    func testShadowTrialProjectionMapsTicketIDs() {
        let obs: (BASShadowTrialSignalKind, String) -> BASShadowTrialObservation = {
            BASShadowTrialObservation(
                kind: $0,
                ticketID: $1,
                salience: 0.5, confidence: 0.5,
                content: "x", observedAt: self.t0)
        }
        let bundle = BASShadowTrialObservationBundle(
            turnID: "t-8",
            sessionID: "s-8",
            observations: [
                obs(.ticketIssued, "tk-a"),
                obs(.trialRun, "tk-a"),
                obs(.parityVerified, "tk-a"),
                obs(.ticketIssued, "tk-b")
            ],
            emittedAt: t0)
        let s = bundle.coverageSummary
        XCTAssertEqual(s.layer, .evolutionFurnace)
        XCTAssertEqual(s.distinctSubjectCount, 2)
        XCTAssertTrue(s.hasCoreSignalCoverage)
    }

    // MARK: - L8 hippocampal well (M37)

    private func tieringProfile(
        id: String,
        tier: BASMemoryTier,
        recency: Double = 0.5,
        frequency: Double = 0.5,
        sensitivity: Double = 0.0,
        staleness: Double = 0.0
    ) -> BASMemoryTieringProfile {
        BASMemoryTieringProfile(
            atomID: id,
            currentTier: tier,
            recencyScore: recency,
            accessFrequency: frequency,
            sensitivityDrift: sensitivity,
            worldContextStaleness: staleness,
            observedAt: t0)
    }

    private func makeTieringReconciler(
        at timestamp: TimeInterval = 1_000
    ) -> (BASMemoryTieringReconciler, BASMemoryTierTransitionLog) {
        let log = BASMemoryTierTransitionLog(capacity: 64)
        let reconciler = BASMemoryTieringReconciler(
            log: log,
            clock: { Date(timeIntervalSince1970: timestamp) })
        return (reconciler, log)
    }

    func testTieringProjectionMapsAtomIDsAndBudget() async {
        let (reconciler, _) = makeTieringReconciler()
        let outcome = await reconciler.reconcile(profiles: [
            // hold (warm, neutral bands)
            tieringProfile(id: "atom-a", tier: .warm),
            // promote (cold → warm, heat 0.445)
            tieringProfile(
                id: "atom-b", tier: .cold,
                recency: 0.8, frequency: 0.3),
            // evictSuggest (cold, zero recency/frequency)
            tieringProfile(
                id: "atom-c", tier: .cold,
                recency: 0.0, frequency: 0.0),
            // duplicate atom-a, should collapse in distinctCount
            tieringProfile(id: "atom-a", tier: .warm)
        ])
        let s = outcome.coverageSummary(
            turnID: "t-l8", sessionID: "s-l8")

        XCTAssertEqual(s.layer, .hippocampalWell)
        XCTAssertEqual(s.turnID, "t-l8")
        XCTAssertEqual(s.sessionID, "s-l8")
        XCTAssertEqual(s.totalObservations, 4)
        XCTAssertEqual(s.distinctSubjectCount, 3)
        XCTAssertTrue(s.hasCoreSignalCoverage)

        // Two holds (0.02 each), one promote (0.08), one evict
        // suggest (0.10) — 0.22 total, clamped stays the same.
        XCTAssertEqual(
            s.budgetTotalCost,
            0.02 + 0.08 + 0.10 + 0.02,
            accuracy: 1e-9)
    }

    func testTieringProjectionEmptySweepReportsNoCoreCoverage() async {
        let (reconciler, _) = makeTieringReconciler()
        let outcome = await reconciler.reconcile(profiles: [])
        let s = outcome.coverageSummary(
            turnID: "t-l8-empty", sessionID: "s-l8")
        XCTAssertEqual(s.layer, .hippocampalWell)
        XCTAssertEqual(s.totalObservations, 0)
        XCTAssertEqual(s.distinctSubjectCount, 0)
        XCTAssertFalse(
            s.hasCoreSignalCoverage,
            "an empty sweep is silent — no audit signal")
        XCTAssertEqual(s.budgetTotalCost, 0.0, accuracy: 1e-12)
    }

    func testTieringProjectionBudgetClampsAtOne() async {
        // Fire enough high-cost decisions that the raw sum would
        // overflow the [0, 1] budget window. The projection clamps.
        // Quarantine is the heaviest branch at 0.15 per decision;
        // 10 quarantines = 1.5 raw, must clamp to 1.0.
        let sensitive = (0..<10).map {
            tieringProfile(
                id: "sens-\($0)", tier: .warm,
                sensitivity: 0.9)
        }
        let (reconciler, _) = makeTieringReconciler()
        let outcome = await reconciler.reconcile(
            profiles: sensitive)
        let s = outcome.coverageSummary(
            turnID: "t-l8-clamp", sessionID: "s-l8")
        XCTAssertEqual(s.budgetTotalCost, 1.0, accuracy: 1e-12)
        XCTAssertEqual(s.distinctSubjectCount, 10)
        XCTAssertEqual(s.totalObservations, 10)
    }

    func testTieringProjectionFeedsCrossLayerReportAsNinthLayer() async {
        let (reconciler, _) = makeTieringReconciler()
        let outcome = await reconciler.reconcile(profiles: [
            tieringProfile(id: "atom-x", tier: .warm)
        ])
        let summary = outcome.coverageSummary(
            turnID: "t", sessionID: "s")
        let report = BASObservationReconciliationReport(
            turnID: "t", sessionID: "s",
            summaries: [summary])
        XCTAssertEqual(report.coveredLayers, [.hippocampalWell])
        XCTAssertTrue(
            report.isFullyObserved(expected: [.hippocampalWell]))
    }

    // MARK: - Cross-layer reconciliation

    func testEightLayerReconciliationAssemblesFullReport() {
        // Build one minimally-compliant bundle per layer and feed
        // each coverage summary into a reconciliation report.
        let wp = BASWorldPriorObservationBundle(
            turnID: "t", sessionID: "s",
            observations: [
                BASWorldPriorObservation(
                    kind: .templateMatched, templateID: "a",
                    evidenceLevel: .plausible,
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASWorldPriorObservation(
                    kind: .counterfactualSeeded, templateID: "a",
                    evidenceLevel: .plausible,
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0)
            ],
            emittedAt: t0)
        let presence = BASPresenceObservationBundle(
            turnID: "t", sessionID: "s",
            observations: [
                BASPresenceObservation(
                    channel: .task, salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASPresenceObservation(
                    channel: .risk, salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASPresenceObservation(
                    channel: .manipulation, salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0)
            ],
            emittedAt: t0)
        let decomp = BASDecompositionObservationBundle(
            turnID: "t", sessionID: "s",
            observations: [
                BASDecompositionObservation(
                    kind: .factShard, salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASDecompositionObservation(
                    kind: .contradiction, salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASDecompositionObservation(
                    kind: .mirrorDraft, salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0)
            ],
            emittedAt: t0)
        let cand = BASCandidateObservationBundle(
            turnID: "t", sessionID: "s",
            observations: [
                BASCandidateObservation(
                    kind: .candidate, candidateID: "c-a",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASCandidateObservation(
                    kind: .reversibilitySignal, candidateID: "c-a",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASCandidateObservation(
                    kind: .guardianBranch, candidateID: "c-a",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0)
            ],
            emittedAt: t0)
        let tri = BASTribunalObservationBundle(
            turnID: "t", sessionID: "s",
            observations: [
                BASTribunalObservation(
                    kind: .vote, voice: .baseSelf,
                    disposition: .affirm, subjectID: "sub",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASTribunalObservation(
                    kind: .vote, voice: .ruleSelf,
                    disposition: .affirm, subjectID: "sub",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASTribunalObservation(
                    kind: .vote, voice: .aspireSelf,
                    disposition: .affirm, subjectID: "sub",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASTribunalObservation(
                    kind: .convergence, voice: nil,
                    disposition: nil, subjectID: "sub",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0)
            ],
            emittedAt: t0)
        let risk = BASRiskObservationBundle(
            turnID: "t", sessionID: "s",
            observations: [
                BASRiskObservation(
                    kind: .hazardReading, intentID: "i",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASRiskObservation(
                    kind: .irreversibilityReading, intentID: "i",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASRiskObservation(
                    kind: .harmPotentialReading, intentID: "i",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0)
            ],
            emittedAt: t0)
        let hand = BASSoftHandObservationBundle(
            turnID: "t", sessionID: "s",
            observations: [
                BASSoftHandObservation(
                    kind: .selection, mode: .compare,
                    subjectID: "sub",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASSoftHandObservation(
                    kind: .render, mode: .compare,
                    subjectID: "sub",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0)
            ],
            emittedAt: t0)
        let shadow = BASShadowTrialObservationBundle(
            turnID: "t", sessionID: "s",
            observations: [
                BASShadowTrialObservation(
                    kind: .ticketIssued, ticketID: "tk",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASShadowTrialObservation(
                    kind: .trialRun, ticketID: "tk",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0),
                BASShadowTrialObservation(
                    kind: .parityVerified, ticketID: "tk",
                    salience: 0.5, confidence: 0.5,
                    content: "x", observedAt: t0)
            ],
            emittedAt: t0)

        let expected: [BASCognitiveLayer] = [
            .worldPrior, .presenceEye, .mirrorBlade,
            .dreamLoop, .triSelfTribunal, .riskClimate,
            .gentleHand, .evolutionFurnace
        ]
        var report = BASObservationReconciliationReport(
            turnID: "t", sessionID: "s")
        for summary in [
            wp.coverageSummary,
            presence.coverageSummary,
            decomp.coverageSummary,
            cand.coverageSummary,
            tri.coverageSummary,
            risk.coverageSummary,
            hand.coverageSummary,
            shadow.coverageSummary
        ] {
            report = report.appending(summary)
        }

        XCTAssertEqual(report.coveredLayers, expected)
        XCTAssertTrue(report.missingLayers(expected: expected).isEmpty)
        XCTAssertTrue(report.layersWithoutCoreCoverage.isEmpty)
        XCTAssertTrue(report.isFullyObserved(expected: expected))
    }
}
