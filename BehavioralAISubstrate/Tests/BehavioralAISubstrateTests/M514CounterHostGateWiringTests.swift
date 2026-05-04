import XCTest
@testable import BASAdmin
@testable import BASHostKit
import BASMemory
import BASObservability
import BASRuntimeCore

/// M514 (chapter 一百三十一) — pin Counter-Host Gate L13 promotion
/// path. Verifies the chapter-一百三十 doctrine invariant:
/// when `BASCounterHostCheck.outcome == .systemInducedDrift`,
/// promotion MUST require explicit L14 sovereign override
/// (non-empty verdict ref).
final class M514CounterHostGateWiringTests: XCTestCase {

    // Helper — clean ledger (no audit emission required for
    // these gate-logic tests).
    private func makeCoordinator(
    ) -> BASUpdateTicketLifecycleCoordinator {
        BASUpdateTicketLifecycleCoordinator(
            clock: { Date() },
            auditSink: nil,
            storage: nil)
    }

    // Helper — submit a ticket and walk it to .trialPassed so
    // approveForDistillation is reachable.
    private func walkToTrialPassed(
        coordinator: BASUpdateTicketLifecycleCoordinator,
        ticketID: String
    ) async throws {
        let ticket = BASUpdateTicket(
            ticketID: ticketID,
            sessionRef: "session:\(ticketID)",
            summary: "summary for \(ticketID)",
            confidence: 0.5)
        _ = try await coordinator.submit(ticket)
        try await coordinator.startTrial(
            ticketID: ticketID,
            trialRecordRef: "trial:\(ticketID)")
        try await coordinator.markTrialOutcome(
            ticketID: ticketID,
            outcome: .passed(reasonCodes: []))
    }

    // MARK: - 1. nil counterHostCheck → passed

    func testNilCounterHostCheckPassesNormally() async throws {
        let coord = makeCoordinator()
        try await walkToTrialPassed(
            coordinator: coord, ticketID: "t1")
        let outcome = try await coord
            .approveForDistillationWithCounterHostCheck(
                ticketID: "t1",
                sovereignVerdictRef: "verdict:v1",
                counterHostCheck: nil)
        XCTAssertEqual(outcome, .passed,
            "nil Counter-Host Check → normal pass")
    }

    // MARK: - 2. .genuineHostPattern → passed

    func testGenuineHostPatternPasses() async throws {
        let coord = makeCoordinator()
        try await walkToTrialPassed(
            coordinator: coord, ticketID: "t2")
        let check = BASCounterHostCheck(
            checkID: "check:t2",
            candidateRef: "t2",
            hostBaselineRef: "host-baseline:v1",
            observedDelta: 0.05,
            inducedRiskScore: 0.1,
            outcome: .genuineHostPattern,
            reasonCodes: [])
        let outcome = try await coord
            .approveForDistillationWithCounterHostCheck(
                ticketID: "t2",
                sovereignVerdictRef: "verdict:v1",
                counterHostCheck: check)
        XCTAssertEqual(outcome, .passed,
            "genuineHostPattern → normal pass (no override needed)")
    }

    // MARK: - 3. .systemInducedDrift + empty verdict → blocked

    func testSystemInducedDriftWithoutOverrideBlocked() async throws {
        let coord = makeCoordinator()
        try await walkToTrialPassed(
            coordinator: coord, ticketID: "t3")
        let check = BASCounterHostCheck(
            checkID: "check:t3",
            candidateRef: "t3",
            hostBaselineRef: "host-baseline:v1",
            observedDelta: 0.5,
            inducedRiskScore: 0.8,  // above 0.6 threshold
            outcome: .systemInducedDrift,
            reasonCodes: ["counter-host:risk:0.800"])
        let outcome = try await coord
            .approveForDistillationWithCounterHostCheck(
                ticketID: "t3",
                sovereignVerdictRef: "",  // empty → blocked
                counterHostCheck: check)
        XCTAssertEqual(outcome, .blocked,
            "systemInducedDrift + empty verdict → BLOCKED (audit Point 8 doctrine)")
    }

    // MARK: - 4. .systemInducedDrift + sovereign override → passed

    func testSystemInducedDriftWithOverridePasses() async throws {
        let coord = makeCoordinator()
        try await walkToTrialPassed(
            coordinator: coord, ticketID: "t4")
        let check = BASCounterHostCheck(
            checkID: "check:t4",
            candidateRef: "t4",
            hostBaselineRef: "host-baseline:v1",
            observedDelta: 0.5,
            inducedRiskScore: 0.9,
            outcome: .systemInducedDrift,
            reasonCodes: [
                "counter-host:requires-sovereign-override"])
        let outcome = try await coord
            .approveForDistillationWithCounterHostCheck(
                ticketID: "t4",
                sovereignVerdictRef: "verdict:explicit-override",
                counterHostCheck: check)
        XCTAssertEqual(
            outcome, .passedWithSovereignOverride,
            "systemInducedDrift + non-empty verdict → passed-with-override")
    }

    // MARK: - 5. .insufficientEvidence → passed

    func testInsufficientEvidencePasses() async throws {
        let coord = makeCoordinator()
        try await walkToTrialPassed(
            coordinator: coord, ticketID: "t5")
        let check = BASCounterHostCheck(
            checkID: "check:t5",
            candidateRef: "t5",
            hostBaselineRef: "",
            observedDelta: 0.3,
            inducedRiskScore: 0.4,
            outcome: .insufficientEvidence,
            reasonCodes: [])
        let outcome = try await coord
            .approveForDistillationWithCounterHostCheck(
                ticketID: "t5",
                sovereignVerdictRef: "verdict:v1",
                counterHostCheck: check)
        XCTAssertEqual(outcome, .passed,
            "insufficientEvidence → pass (defer, not block)")
    }

    // MARK: - 6. .notApplicable → passed

    func testNotApplicablePasses() async throws {
        let coord = makeCoordinator()
        try await walkToTrialPassed(
            coordinator: coord, ticketID: "t6")
        let check = BASCounterHostCheck(
            checkID: "check:t6",
            candidateRef: "t6",
            hostBaselineRef: "",
            observedDelta: 0.0,
            inducedRiskScore: 0.0,
            outcome: .notApplicable,
            reasonCodes: [])
        let outcome = try await coord
            .approveForDistillationWithCounterHostCheck(
                ticketID: "t6",
                sovereignVerdictRef: "",
                counterHostCheck: check)
        XCTAssertEqual(outcome, .passed,
            "notApplicable → pass (non-host candidate skips gate)")
    }

    // MARK: - 7. Outcome enum cardinality

    func testGateOutcomeCardinality() {
        XCTAssertEqual(
            BASCounterHostGateOutcome.allCases.count, 3,
            "exactly 3 gate outcomes per audit Point 8")
        let rawValues = Set(
            BASCounterHostGateOutcome.allCases.map(\.rawValue))
        XCTAssertEqual(
            rawValues,
            ["passed", "passed-with-sovereign-override",
             "blocked"],
            "stable kebab-case raw values")
    }
}
