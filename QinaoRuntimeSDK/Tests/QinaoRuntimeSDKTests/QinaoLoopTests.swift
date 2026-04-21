import XCTest
@testable import QinaoLoop

/// M7.5 — QinaoLoop façade over L9 dream-loop + L10 tribunal.
///
/// The façade composes `BASCandidatePath` + `BASCritiqueBundle`
/// from host-supplied `CandidateInput`s, then produces three
/// readouts:
///
/// 1. `candidateFrontier(topK:)` — ranked composite score
/// 2. `comparePanel()` — stable pros / cons / risks strings
/// 3. `guardianBranch()` — dissent + alternative when the tribunal
///    sees a candidate cross a severity threshold
///
/// These tests prove each readout is deterministic, the public
/// surface never drifts to substrate types, and the per-session
/// state is real (submit → clear → sessionUnknown).
final class QinaoLoopTests: XCTestCase {

    private func makeInput(
        _ id: String,
        benefit: Double = 0.5,
        cost: Double = 0.2,
        reversibility: Double = 0.5,
        confidence: Double = 0.5,
        evidenceGap: Double = 0,
        manipulation: Double = 0,
        emotional: Double = 0,
        boundary: Double = 0
    ) -> QinaoLoop.CandidateInput {
        QinaoLoop.CandidateInput(
            candidateID: id,
            title: "title-\(id)",
            actionSummary: "summary-\(id)",
            expectedBenefit: benefit,
            expectedCost: cost,
            reversibility: reversibility,
            confidence: confidence,
            evidenceGap: evidenceGap,
            manipulationRisk: manipulation,
            emotionalBias: emotional,
            boundaryConflict: boundary)
    }

    // MARK: - Intake

    func testSubmitEmptyBatchThrowsInvalidCandidate() async throws {
        let loop = QinaoLoop()
        do {
            try await loop.submit(sessionID: "s1", candidates: [])
            XCTFail("empty batch must throw")
        } catch QinaoLoop.LoopError.invalidCandidate(let reason) {
            XCTAssertEqual(reason, "empty-submission")
        }
    }

    func testSubmitDuplicateIDThrowsInvalidCandidate() async throws {
        let loop = QinaoLoop()
        do {
            try await loop.submit(
                sessionID: "s1",
                candidates: [makeInput("c1"), makeInput("c1")])
            XCTFail("duplicate candidate ID must throw")
        } catch QinaoLoop.LoopError.invalidCandidate(let reason) {
            XCTAssertTrue(reason.hasPrefix("duplicate-candidate-id:"))
        }
    }

    func testSubmitEmptyIDThrowsInvalidCandidate() async throws {
        let loop = QinaoLoop()
        do {
            try await loop.submit(
                sessionID: "s1",
                candidates: [makeInput("   ")])
            XCTFail("empty ID must throw")
        } catch QinaoLoop.LoopError.invalidCandidate(let reason) {
            XCTAssertEqual(reason, "empty-candidate-id")
        }
    }

    // MARK: - Frontier ranking

    func testCandidateFrontierOrdersByCompositeScore() async throws {
        let loop = QinaoLoop()
        // Expected ranking derivation (by formula):
        //   0.4*B - 0.3*C - 0.3*cstr + 0.15*R + 0.15*Conf
        // c-hi: B=0.9 C=0.1 R=0.8 Conf=0.9 cstr≈0 → 0.36-0.03+0.12+0.135 = 0.585
        // c-md: B=0.5 C=0.3 R=0.5 Conf=0.5 cstr≈0 → 0.2-0.09+0.075+0.075 = 0.26
        // c-lo: B=0.2 C=0.2 R=0.3 Conf=0.2 cstr≈0 → 0.08-0.06+0.045+0.03 = 0.095
        try await loop.submit(sessionID: "s1", candidates: [
            makeInput("c-md", benefit: 0.5, cost: 0.3, reversibility: 0.5, confidence: 0.5),
            makeInput("c-lo", benefit: 0.2, cost: 0.2, reversibility: 0.3, confidence: 0.2),
            makeInput("c-hi", benefit: 0.9, cost: 0.1, reversibility: 0.8, confidence: 0.9),
        ])
        let frontier = try await loop.candidateFrontier(sessionID: "s1")
        XCTAssertEqual(frontier.map(\.candidateID),
                       ["c-hi", "c-md", "c-lo"])
        XCTAssertGreaterThan(frontier[0].score, frontier[1].score)
        XCTAssertGreaterThan(frontier[1].score, frontier[2].score)
    }

    func testCandidateFrontierTieBreaksOnIDAscending() async throws {
        let loop = QinaoLoop()
        // Two candidates with identical shape → same score.
        // Tiebreaker: candidateID ascending.
        try await loop.submit(sessionID: "s1", candidates: [
            makeInput("b-same", benefit: 0.5, cost: 0.2,
                      reversibility: 0.5, confidence: 0.5),
            makeInput("a-same", benefit: 0.5, cost: 0.2,
                      reversibility: 0.5, confidence: 0.5),
        ])
        let frontier = try await loop.candidateFrontier(sessionID: "s1")
        XCTAssertEqual(frontier.map(\.candidateID),
                       ["a-same", "b-same"])
    }

    func testCandidateFrontierHonoursTopK() async throws {
        let loop = QinaoLoop()
        try await loop.submit(sessionID: "s1", candidates: [
            makeInput("c1", benefit: 0.9),
            makeInput("c2", benefit: 0.5),
            makeInput("c3", benefit: 0.1),
        ])
        let frontier = try await loop.candidateFrontier(
            sessionID: "s1", topK: 1)
        XCTAssertEqual(frontier.count, 1)
        XCTAssertEqual(frontier[0].candidateID, "c1")
    }

    func testCritiqueLowersScore() async throws {
        let loop = QinaoLoop()
        // Two identical candidates except one has high manipulation
        // risk; the clean one must outrank the pressured one.
        try await loop.submit(sessionID: "s1", candidates: [
            makeInput("clean", benefit: 0.8, cost: 0.2, manipulation: 0.0),
            makeInput("pressured", benefit: 0.8, cost: 0.2, manipulation: 0.9),
        ])
        let frontier = try await loop.candidateFrontier(sessionID: "s1")
        XCTAssertEqual(frontier[0].candidateID, "clean")
        XCTAssertGreaterThan(
            frontier[0].score, frontier[1].score + 0.05)
    }

    // MARK: - Compare panel

    func testComparePanelEmitsStableProsConsRisks() async throws {
        let loop = QinaoLoop()
        try await loop.submit(sessionID: "s1", candidates: [
            makeInput("c1",
                      benefit: 0.9, cost: 0.1,
                      reversibility: 0.9, confidence: 0.9,
                      evidenceGap: 0.7, manipulation: 0.8)
        ])
        let rows = try await loop.comparePanel(sessionID: "s1")
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(Set(rows[0].pros),
                       ["high-benefit", "reversible", "high-confidence"])
        XCTAssertTrue(rows[0].cons.isEmpty)
        XCTAssertEqual(Set(rows[0].risks),
                       ["evidence-gap", "manipulation-risk"])
    }

    func testComparePanelOrdersMatchFrontier() async throws {
        let loop = QinaoLoop()
        try await loop.submit(sessionID: "s1", candidates: [
            makeInput("c-md", benefit: 0.5, cost: 0.3),
            makeInput("c-lo", benefit: 0.2, cost: 0.5),
            makeInput("c-hi", benefit: 0.9, cost: 0.1),
        ])
        let frontier = try await loop.candidateFrontier(
            sessionID: "s1", topK: Int.max)
        let panel = try await loop.comparePanel(sessionID: "s1")
        XCTAssertEqual(
            frontier.map(\.candidateID),
            panel.map(\.candidateID),
            "compare panel must reflect same ordering as frontier")
    }

    // MARK: - Guardian branch

    func testGuardianBranchNilWhenNoCandidateTriggers() async throws {
        let loop = QinaoLoop()
        try await loop.submit(sessionID: "s1", candidates: [
            makeInput("clean", manipulation: 0.1, boundary: 0.1)
        ])
        let branch = try await loop.guardianBranch(sessionID: "s1")
        XCTAssertNil(branch)
    }

    func testGuardianBranchFiresOnHighCritique() async throws {
        let loop = QinaoLoop()
        try await loop.submit(sessionID: "s1", candidates: [
            // Critique strength weighting:
            //   0.35*manip + 0.30*bound + 0.20*emo + 0.15*evgap
            // high-risk: manip=1.0, boundary=1.0 → 0.35+0.30 = 0.65
            //            need bound higher — make it all 1.0:
            makeInput("high-risk",
                      evidenceGap: 1.0, manipulation: 1.0,
                      emotional: 1.0, boundary: 1.0),
            makeInput("safe-alt",
                      reversibility: 0.95, confidence: 0.9,
                      manipulation: 0.0)
        ])
        let branch = try await loop.guardianBranch(sessionID: "s1")
        XCTAssertNotNil(branch)
        XCTAssertEqual(branch?.candidateID, "high-risk")
        XCTAssertEqual(branch?.alternative, "safe-alt")
        // Dominant concern is manipulation (weight 1.0 tied with
        // boundary at 1.0 — our tiebreaker is first-listed which
        // is manipulation-risk).
        XCTAssertEqual(branch?.dissent, "manipulation-risk")
    }

    func testGuardianBranchAlternativeIsLowestCritique() async throws {
        let loop = QinaoLoop()
        try await loop.submit(sessionID: "s1", candidates: [
            makeInput("trig",
                      evidenceGap: 1.0, manipulation: 1.0,
                      emotional: 1.0, boundary: 1.0),
            makeInput("medium-risk", manipulation: 0.4),
            makeInput("safest",
                      reversibility: 0.9, confidence: 0.7,
                      manipulation: 0.0),
        ])
        let branch = try await loop.guardianBranch(sessionID: "s1")
        XCTAssertEqual(branch?.alternative, "safest")
    }

    // MARK: - Session lifecycle

    func testUnknownSessionSurfacesTypedError() async throws {
        let loop = QinaoLoop()
        do {
            _ = try await loop.candidateFrontier(sessionID: "ghost")
            XCTFail("unknown session must throw")
        } catch QinaoLoop.LoopError.sessionUnknown(let id) {
            XCTAssertEqual(id, "ghost")
        }
    }

    func testClearDropsSessionState() async throws {
        let loop = QinaoLoop()
        try await loop.submit(sessionID: "s1", candidates: [makeInput("c1")])
        await loop.clear(sessionID: "s1")
        do {
            _ = try await loop.candidateFrontier(sessionID: "s1")
            XCTFail("cleared session must behave as unknown")
        } catch QinaoLoop.LoopError.sessionUnknown(let id) {
            XCTAssertEqual(id, "s1")
        }
    }

    func testSubmitReplacesPriorSessionState() async throws {
        let loop = QinaoLoop()
        try await loop.submit(sessionID: "s1",
                              candidates: [makeInput("old")])
        try await loop.submit(sessionID: "s1",
                              candidates: [makeInput("new")])
        let frontier = try await loop.candidateFrontier(sessionID: "s1")
        XCTAssertEqual(frontier.map(\.candidateID), ["new"])
    }
}
