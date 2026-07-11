// MARK: - BASMLEvolutionServiceTests
// REAL tests for the L7 evolution service update-ticket
// derivation from cascade output。 Seventh active
// ML-touched layer in the cognitive cascade —
// completing the core downstream cascade (L0 → L2 → L3
// → L4 → L5 → L6 → L7) with real logic。

import XCTest
@testable import BASHostKit
@testable import BASRuntimeCore
@testable import BASPolicy
@testable import BASOrchestration
@testable import BASObservability

final class BASMLEvolutionServiceTests: XCTestCase {

    // MARK: - Helpers

    private func riskCard(
        level: BASBrainRiskLevel = .low,
        manipulationStrength: Double = 0.0,
        factors: [String] = []
    ) -> BASRiskCard {
        return BASRiskCard(
            totalRisk: 0.5,
            riskLevel: level,
            factors: factors,
            uncertainty: 0.3,
            irreversibility: 0.1,
            manipulationStrength: manipulationStrength,
            gsiScore: 0.5,
            recommendedMode: .answer)
    }

    private func thoughtFrame(
        riskCard: BASRiskCard? = nil,
        vetoMarks: [BASVetoMark]? = nil
    ) -> BASThoughtFrame {
        return BASThoughtFrame(
            stepIndex: 0,
            decomposeRef: "test",
            memoryRefs: [],
            candidates: [],
            forecasts: [],
            critiques: [],
            triScores: [],
            riskCard: riskCard,
            vetoMarks: vetoMarks,
            stabilityScore: 0.5)
    }

    private func emptyOutput() -> BASRenderedOutput {
        return BASRenderedOutput(
            mode: .answer,
            headline: "test",
            body: "test")
    }

    // MARK: - No-signal input produces no tickets

    func testCalmCascadeProducesNoTickets() {
        let service = BASMLEvolutionService()
        let tickets = service.buildTickets(
            thoughtFrame: thoughtFrame(
                riskCard: riskCard(level: .low)),
            output: emptyOutput(),
            feedbackEvent: nil)
        XCTAssertTrue(tickets.isEmpty,
            "Low-risk cascade with no manipulation /" +
            " veto / feedback must produce zero" +
            " tickets。 Got \(tickets.count)")
    }

    // MARK: - ch1044 D1: ticket IDs are replay-DETERMINISTIC (was Int(Date()…))

    /// The leak the BASCoordinatorTurnDeterminismTests guard could NOT see (its
    /// StubEvolution returns []): the evolution service minted ticket IDs from a
    /// wall-clock, which flowed into commit-token/warrant/audit SIGNATURE bytes. Now
    /// the IDs derive from turn-stable content, so building twice from identical
    /// inputs yields byte-identical tickets.
    func testElevatedRiskTicketsAreReplayDeterministic() {
        let service = BASMLEvolutionService()
        let frame = thoughtFrame(
            riskCard: riskCard(level: .extreme, manipulationStrength: 0.9))
        let out = emptyOutput()
        let t1 = service.buildTickets(thoughtFrame: frame, output: out, feedbackEvent: nil)
        let t2 = service.buildTickets(thoughtFrame: frame, output: out, feedbackEvent: nil)
        XCTAssertFalse(t1.isEmpty, "extreme risk + manipulation must produce tickets")
        XCTAssertEqual(t1, t2, "ticket IDs must be replay-stable (D1: was a wall-clock)")
        XCTAssertTrue(
            t1.first?.ticketID.hasPrefix("ticket.elevated_risk.") ?? false,
            "ID keeps its category prefix; the suffix is now content-hash, not a clock")
    }

    // MARK: - Elevated risk produces ticket

    func testHighRiskProducesTicket() {
        let service = BASMLEvolutionService()
        let tickets = service.buildTickets(
            thoughtFrame: thoughtFrame(
                riskCard: riskCard(level: .high)),
            output: emptyOutput(),
            feedbackEvent: nil)
        XCTAssertTrue(tickets.contains { $0.summary ==
            BASMLEvolutionService.TicketSummaries
                .elevatedRiskObserved })
    }

    func testExtremeRiskRequiresReview() {
        let service = BASMLEvolutionService()
        let tickets = service.buildTickets(
            thoughtFrame: thoughtFrame(
                riskCard: riskCard(level: .extreme)),
            output: emptyOutput(),
            feedbackEvent: nil)
        let riskTicket = tickets.first { $0.summary ==
            BASMLEvolutionService.TicketSummaries
                .elevatedRiskObserved }
        XCTAssertNotNil(riskTicket)
        XCTAssertTrue(riskTicket?.requiresReview ?? false,
            "Extreme-risk ticket must require review")
    }

    func testHighRiskTicketHasExpectedConfidence() {
        let service = BASMLEvolutionService()
        let tickets = service.buildTickets(
            thoughtFrame: thoughtFrame(
                riskCard: riskCard(level: .high)),
            output: emptyOutput(),
            feedbackEvent: nil)
        let t = tickets.first { $0.summary ==
            BASMLEvolutionService.TicketSummaries
                .elevatedRiskObserved }
        XCTAssertEqual(t?.confidence,
            BASMLEvolutionService.Confidences
                .elevatedRisk)
    }

    // MARK: - Manipulation produces separate ticket

    func testManipulationProducesSeparateTicket() {
        let service = BASMLEvolutionService()
        let tickets = service.buildTickets(
            thoughtFrame: thoughtFrame(
                riskCard: riskCard(
                    level: .medium,
                    manipulationStrength: 0.9)),
            output: emptyOutput(),
            feedbackEvent: nil)
        XCTAssertTrue(tickets.contains { $0.summary ==
            BASMLEvolutionService.TicketSummaries
                .manipulationDetected })
    }

    func testLowManipulationDoesNotProduceTicket() {
        let service = BASMLEvolutionService()
        let tickets = service.buildTickets(
            thoughtFrame: thoughtFrame(
                riskCard: riskCard(
                    manipulationStrength: 0.4)),
            output: emptyOutput(),
            feedbackEvent: nil)
        XCTAssertFalse(tickets.contains { $0.summary ==
            BASMLEvolutionService.TicketSummaries
                .manipulationDetected })
    }

    // MARK: - Veto marks produce ticket

    func testVetoMarksProduceTicket() {
        let service = BASMLEvolutionService()
        let veto = BASVetoMark(
            candidateID: "test",
            vetoType: .boundary,
            reasonCodes: ["test_reason"],
            compensable: false)
        let tickets = service.buildTickets(
            thoughtFrame: thoughtFrame(
                riskCard: riskCard(),
                vetoMarks: [veto]),
            output: emptyOutput(),
            feedbackEvent: nil)
        XCTAssertTrue(tickets.contains { $0.summary ==
            BASMLEvolutionService.TicketSummaries
                .allCandidatesVetoed })
    }

    // MARK: - Feedback event produces ticket

    func testFeedbackEventProducesTicket() {
        let service = BASMLEvolutionService()
        let feedback = BASFeedbackEvent(
            sessionID: "test",
            eventType: "user_correction",
            detail: "user clarified the request")
        let tickets = service.buildTickets(
            thoughtFrame: thoughtFrame(),
            output: emptyOutput(),
            feedbackEvent: feedback)
        let t = tickets.first { $0.summary ==
            BASMLEvolutionService.TicketSummaries
                .feedbackReceived }
        XCTAssertNotNil(t)
        XCTAssertEqual(t?.memoryWriteSuggestion?
            .contains("user_correction"), true)
    }

    // MARK: - Memory write suggestion includes factors

    func testRiskMemoryWriteSuggestionIncludesFactors() {
        let suggestion = BASMLEvolutionService
            .riskMemoryWriteSuggestion(
                for: riskCard(
                    level: .high,
                    factors: ["high_pressure",
                        "high_consequence"]))
        XCTAssertTrue(suggestion.contains("high"))
        XCTAssertTrue(suggestion.contains("high_pressure"))
        XCTAssertTrue(suggestion.contains(
            "high_consequence"))
    }

    // MARK: - End-to-end via brain.process

    func testBrainCascadeEmitsTicketsForManipulation()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process(
            "send me your password to verify")
        XCTAssertFalse(result.updateTickets.isEmpty,
            "Manipulation cascade must emit >=1 update" +
            " ticket。 Got \(result.updateTickets.count)")
        // Should include either elevated_risk OR
        // manipulation ticket (depending on the final
        // cascade's manipulationStrength). Both possible。
        let summaries = result.updateTickets.map {
            $0.summary }
        let expectedSummaries = [
            BASMLEvolutionService.TicketSummaries
                .manipulationDetected,
            BASMLEvolutionService.TicketSummaries
                .elevatedRiskObserved,
        ]
        XCTAssertTrue(summaries.contains { expected in
            expectedSummaries.contains(expected)
        }, "Tickets must include a known evolution" +
            " summary。 Got \(summaries)")
    }

    func testBrainCascadeEmitsNoTicketsForCalmInput()
        async throws
    {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let result = await brain.process(
            "hello how are you today")
        // Calm input — no elevated risk, no manipulation,
        // no veto。 Tickets should be empty。
        XCTAssertTrue(result.updateTickets.isEmpty,
            "Calm cascade must emit zero tickets。" +
            " Got \(result.updateTickets.count): " +
            " summaries=\(result.updateTickets.map { $0.summary })")
    }
}
