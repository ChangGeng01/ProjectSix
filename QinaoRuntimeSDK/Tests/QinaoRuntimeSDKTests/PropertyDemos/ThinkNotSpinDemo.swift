import XCTest
@testable import QinaoLoop

/// Property 3 · 会想不自转 — Think, not spin.
///
/// **What this demo proves:** when the host submits multiple
/// candidates, the loop does three things *deterministically*:
///
/// 1. produces a composite-scored frontier so a reproducible
///    top choice exists;
/// 2. renders a side-by-side compare panel with stable labels;
/// 3. fires a guardian branch — a dissenting alternative — when
///    any candidate crosses the critique threshold.
///
/// "Not spin" means: the same inputs always produce the same
/// ordering, the same labels, and the same guardian pick. There
/// is no hidden randomness, no wall-clock dependency.
final class ThinkNotSpinDemo: XCTestCase {

    private let sessionID = "sess.think"

    private func submit(
        _ fx: PropertyDemoFixture.Runtime,
        _ candidates: [QinaoLoop.CandidateInput]
    ) async throws {
        try await fx.loop.submit(
            sessionID: sessionID, candidates: candidates)
    }

    func testLoopProducesFrontierCompareAndGuardianBranch() async throws {
        let fx = PropertyDemoFixture.makeRuntime()

        // Three candidates:
        //   A — high-benefit, reversible, low-critique    → winner
        //   B — mid-benefit, mid-cost, neutral critique   → middle
        //   C — mid-benefit, HIGH manipulation risk       → guardian trigger
        try await submit(fx, [
            .init(candidateID: "A",
                  title: "Take a short walk",
                  actionSummary: "step outside for 10 min",
                  expectedBenefit: 0.85, expectedCost: 0.10,
                  reversibility: 0.95, confidence: 0.80),
            .init(candidateID: "B",
                  title: "Schedule the call for tomorrow",
                  actionSummary: "push call to tomorrow 10am",
                  expectedBenefit: 0.60, expectedCost: 0.30,
                  reversibility: 0.80, confidence: 0.65),
            .init(candidateID: "C",
                  title: "Respond to the pressured email now",
                  actionSummary: "reply yes immediately",
                  expectedBenefit: 0.65, expectedCost: 0.40,
                  reversibility: 0.15, confidence: 0.55,
                  manipulationRisk: 1.0,
                  emotionalBias: 0.8,
                  boundaryConflict: 0.9)
        ])

        // 1 — Frontier: A leads, then B, then C. The formula is
        // documented on `candidateFrontier` — a regression here
        // would show up as a reordering.
        let frontier = try await fx.loop.candidateFrontier(
            sessionID: sessionID, topK: 3)
        XCTAssertEqual(frontier.map(\.candidateID), ["A", "B", "C"])

        // 2 — Compare panel: same order, stable label tokens.
        // Host UI keys copy on these strings, so they must not
        // drift across runs.
        let panel = try await fx.loop.comparePanel(sessionID: sessionID)
        XCTAssertEqual(panel.map(\.candidateID), ["A", "B", "C"])

        // A is clearly beneficial and reversible.
        let aRow = panel[0]
        XCTAssertTrue(aRow.pros.contains("high-benefit"))
        XCTAssertTrue(aRow.pros.contains("reversible"))
        XCTAssertTrue(aRow.pros.contains("high-confidence"))

        // C's risks expose manipulation + boundary concerns and
        // the low-reversibility con — the guardian's cue.
        let cRow = panel[2]
        XCTAssertTrue(cRow.risks.contains("manipulation-risk"))
        XCTAssertTrue(cRow.risks.contains("boundary-conflict"))
        XCTAssertTrue(cRow.cons.contains("low-reversibility"))

        // 3 — Guardian branch: fires on C (critique crossed 0.7),
        // proposes the lowest-critique substitute (A), and names
        // manipulation-risk as the dominant concern.
        let guardian = try await fx.loop.guardianBranch(
            sessionID: sessionID)
        XCTAssertNotNil(guardian)
        XCTAssertEqual(guardian?.candidateID, "C")
        XCTAssertEqual(guardian?.alternative, "A")
        XCTAssertEqual(guardian?.dissent, "manipulation-risk")
    }

    /// Clean batch (no candidate crosses the 0.7 critique line)
    /// produces a frontier but no guardian branch. The brain
    /// doesn't invent dissent when there is none — that is the
    /// "not spin" half of the property.
    func testCleanBatchHasNoGuardianBranch() async throws {
        let fx = PropertyDemoFixture.makeRuntime()
        try await submit(fx, [
            .init(candidateID: "x",
                  title: "Drink water",
                  actionSummary: "a glass of water",
                  expectedBenefit: 0.70, expectedCost: 0.05,
                  reversibility: 0.99, confidence: 0.80),
            .init(candidateID: "y",
                  title: "Stretch for 5 minutes",
                  actionSummary: "light stretching",
                  expectedBenefit: 0.65, expectedCost: 0.10,
                  reversibility: 0.95, confidence: 0.75)
        ])
        let guardian = try await fx.loop.guardianBranch(
            sessionID: sessionID)
        XCTAssertNil(guardian)
    }
}
