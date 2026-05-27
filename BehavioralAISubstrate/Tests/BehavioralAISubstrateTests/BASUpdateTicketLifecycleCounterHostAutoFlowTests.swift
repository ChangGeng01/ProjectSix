import XCTest
@testable import BASHostKit
@testable import BASObservability
@testable import BASMemory

/// chapter 二百五十四 / M741 —
/// `BASUpdateTicketLifecycleCoordinator
///     .approveForDistillationResolvingCounterHost(...)`
/// resolver convenience coverage.
///
/// 附录 V Stage 2 Step 1 of 2. The plan flagged Counter-Host gate
/// as "schema-wired / 0 production callers". chapter 二百五十四
/// adds the resolver convenience — hosts wire one closure and
/// every promotion runs through the gate. This suite verifies:
///
///   1. Resolver returns nil → gate passes through
///   2. Resolver returns `.genuineHostPattern` → gate passes
///   3. Resolver returns `.systemInducedDrift` + non-empty
///      verdictRef → passedWithSovereignOverride
///   4. Resolver returns `.systemInducedDrift` + empty verdictRef
///      → blocked + ticket marked rejected
///   5. Unknown ticketID throws LifecycleError.unknownTicket
#if !os(iOS)  // ch 1022 source-gate
final class BASUpdateTicketLifecycleCounterHostAutoFlowTests:
    XCTestCase
{
    // MARK: - Fixtures

    private func makeTicket(id: String) -> BASUpdateTicket {
        BASUpdateTicket(
            ticketID: id,
            sessionRef: "sess-\(id)",
            summary: "test ticket \(id)",
            confidence: 0.7)
    }

    private func makeCoordinatorAndAdvanceToTrialPassed(
        ticketID: String
    ) async throws -> BASUpdateTicketLifecycleCoordinator {
        let coord = BASUpdateTicketLifecycleCoordinator()
        _ = try await coord.submit(makeTicket(id: ticketID))
        try await coord.startTrial(
            ticketID: ticketID, trialRecordRef: "tr-\(ticketID)")
        try await coord.markTrialOutcome(
            ticketID: ticketID,
            outcome: .passed(reasonCodes: ["clean"]))
        return coord
    }

    /// Static so closures can reference without `self` capture.
    private static let genuinePatternCheck = BASCounterHostCheck(
        checkID: "chc-genuine",
        candidateRef: "cand-genuine",
        hostBaselineRef: "host-1",
        observedDelta: 0.05,
        inducedRiskScore: 0.1,
        outcome: .genuineHostPattern,
        reasonCodes: ["matches-baseline"])

    private static let systemInducedDriftCheck =
        BASCounterHostCheck(
            checkID: "chc-drift",
            candidateRef: "cand-drift",
            hostBaselineRef: "host-1",
            observedDelta: 0.6,
            inducedRiskScore: 0.85,
            outcome: .systemInducedDrift,
            reasonCodes: ["self-confirmation-loop"])

    // MARK: - 1. nil resolver → passes through

    func testNilResolverReturnsPassed() async throws {
        let coord =
            try await makeCoordinatorAndAdvanceToTrialPassed(
                ticketID: "t-1")
        let outcome = try await coord
            .approveForDistillationResolvingCounterHost(
                ticketID: "t-1",
                sovereignVerdictRef: "vr-1") { _ in nil }
        XCTAssertEqual(outcome, .passed)
        let entry = await coord.entry(ticketID: "t-1")
        XCTAssertEqual(entry?.state, .queuedForDistillation)
    }

    // MARK: - 2. .genuineHostPattern → passes

    func testGenuinePatternReturnsPassed() async throws {
        let coord =
            try await makeCoordinatorAndAdvanceToTrialPassed(
                ticketID: "t-2")
        let outcome = try await coord
            .approveForDistillationResolvingCounterHost(
                ticketID: "t-2",
                sovereignVerdictRef: "vr-2") { _ in
                    Self.genuinePatternCheck
                }
        XCTAssertEqual(outcome, .passed)
        let entry = await coord.entry(ticketID: "t-2")
        XCTAssertEqual(entry?.state, .queuedForDistillation)
    }

    // MARK: - 3. .systemInducedDrift + non-empty verdictRef →
    //              passedWithSovereignOverride

    func testSystemInducedDriftWithVerdictRefOverridesAndPasses()
        async throws
    {
        let coord =
            try await makeCoordinatorAndAdvanceToTrialPassed(
                ticketID: "t-3")
        let outcome = try await coord
            .approveForDistillationResolvingCounterHost(
                ticketID: "t-3",
                sovereignVerdictRef: "vr-3-override") { _ in
                    Self.systemInducedDriftCheck
                }
        XCTAssertEqual(
            outcome, .passedWithSovereignOverride)
        let entry = await coord.entry(ticketID: "t-3")
        XCTAssertEqual(entry?.state, .queuedForDistillation)
    }

    // MARK: - 4. .systemInducedDrift + empty verdictRef → blocked

    func testSystemInducedDriftWithEmptyVerdictRefBlocked()
        async throws
    {
        let coord =
            try await makeCoordinatorAndAdvanceToTrialPassed(
                ticketID: "t-4")
        let outcome = try await coord
            .approveForDistillationResolvingCounterHost(
                ticketID: "t-4",
                sovereignVerdictRef: "") { _ in
                    Self.systemInducedDriftCheck
                }
        XCTAssertEqual(outcome, .blocked)
        let entry = await coord.entry(ticketID: "t-4")
        XCTAssertEqual(entry?.state, .rejected)
        // Verify Counter-Host reason codes appear in the
        // rejection transition.
        let lastTransition = entry?.history.last
        let codes = lastTransition?.reasonCodes ?? []
        XCTAssertTrue(
            codes.contains(
                "counter-host-gate:blocked-no-sovereign-override"
            ),
            "expected blocked reason code; got \(codes)")
    }

    // MARK: - 5. Unknown ticketID throws unknownTicket

    func testUnknownTicketIDThrows() async throws {
        let coord = BASUpdateTicketLifecycleCoordinator()
        do {
            _ = try await coord
                .approveForDistillationResolvingCounterHost(
                    ticketID: "no-such-ticket",
                    sovereignVerdictRef: "vr") { _ in nil }
            XCTFail("expected unknownTicket")
        } catch
            BASUpdateTicketLifecycleCoordinator
                .LifecycleError.unknownTicket(let id)
        {
            XCTAssertEqual(id, "no-such-ticket")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - 6. Resolver receives the actual entry

    func testResolverReceivesEntry() async throws {
        let coord =
            try await makeCoordinatorAndAdvanceToTrialPassed(
                ticketID: "t-6")
        var observedEntryID: String? = nil
        let observed = LockedRef<String?>()
        let outcome = try await coord
            .approveForDistillationResolvingCounterHost(
                ticketID: "t-6",
                sovereignVerdictRef: "vr-6") { entry in
                    await observed.set(entry.ticket.ticketID)
                    return nil
                }
        observedEntryID = await observed.get()
        XCTAssertEqual(outcome, .passed)
        XCTAssertEqual(observedEntryID, "t-6")
    }
}

// MARK: - Test helper: tiny actor for capturing values from
//                       Sendable closures

private actor LockedRef<Value: Sendable> {
    private var stored: Value
    init() where Value == String? { self.stored = nil }
    init(_ initial: Value) { self.stored = initial }
    func set(_ value: Value) { self.stored = value }
    func get() -> Value { stored }
}
#endif
