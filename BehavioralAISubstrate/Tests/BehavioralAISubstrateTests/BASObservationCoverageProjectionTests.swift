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
