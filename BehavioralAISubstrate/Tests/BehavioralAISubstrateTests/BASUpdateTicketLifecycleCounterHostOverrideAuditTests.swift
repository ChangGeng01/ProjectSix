import XCTest
@testable import BASHostKit
@testable import BASObservability
@testable import BASMemory

/// chapter 二百五十五 / M742 — sovereign-override audit-code
/// emission coverage.
///
/// 附录 V Stage 2 Step 2 of 2. Pre-chapter 二百五十五 the
/// chapter 一百三十一 gate's override path emitted only the
/// standard `sovereign-verdict:<ref>` reason code — audit
/// walkers couldn't distinguish "promoted because Counter-Host
/// check passed naturally" from "promoted because sovereign
/// authorized counter-host-drift". chapter 二百五十五 fixes that
/// by:
///
///   1. Extending `approveForDistillation` to accept optional
///      `extraReasonCodes: [String] = []` (additive — default
///      preserves pre-chapter-二百五十五 behaviour byte-for-byte).
///   2. The chapter 一百三十一 gate's override branch passes
///      `["counter-host-gate:passed-with-sovereign-override"]`
///      plus the Counter-Host check's reasonCodes.
///
/// Audit walkers can now grep:
///   - `counter-host-gate:blocked-no-sovereign-override`
///     (block path — already shipped chapter 一百三十一)
///   - `counter-host-gate:passed-with-sovereign-override`
///     (override path — chapter 二百五十五, this commit)
///
/// Both load-bearing for "did doctrine fire?" forensic queries.
final class BASUpdateTicketLifecycleCounterHostOverrideAuditTests:
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

    private func makeCoordAndAdvanceToTrialPassed(
        ticketID: String
    ) async throws -> BASUpdateTicketLifecycleCoordinator {
        let coord = BASUpdateTicketLifecycleCoordinator()
        _ = try await coord.submit(makeTicket(id: ticketID))
        try await coord.startTrial(
            ticketID: ticketID,
            trialRecordRef: "tr-\(ticketID)")
        try await coord.markTrialOutcome(
            ticketID: ticketID,
            outcome: .passed(reasonCodes: []))
        return coord
    }

    // MARK: - 1. extraReasonCodes default-empty preserves
    //              pre-chapter-二百五十五 behaviour

    func testApproveForDistillationDefaultArgUnchanged()
        async throws
    {
        let coord =
            try await makeCoordAndAdvanceToTrialPassed(
                ticketID: "t-1")
        try await coord.approveForDistillation(
            ticketID: "t-1",
            sovereignVerdictRef: "vr-1")
        let entry = await coord.entry(ticketID: "t-1")
        let lastTransition = entry?.history.last
        XCTAssertEqual(
            lastTransition?.reasonCodes,
            ["sovereign-verdict:vr-1"])
    }

    // MARK: - 2. extraReasonCodes append in order

    func testExtraReasonCodesAppendInOrder() async throws {
        let coord =
            try await makeCoordAndAdvanceToTrialPassed(
                ticketID: "t-2")
        try await coord.approveForDistillation(
            ticketID: "t-2",
            sovereignVerdictRef: "vr-2",
            extraReasonCodes: ["custom:a", "custom:b"])
        let entry = await coord.entry(ticketID: "t-2")
        let lastTransition = entry?.history.last
        XCTAssertEqual(
            lastTransition?.reasonCodes,
            ["sovereign-verdict:vr-2", "custom:a", "custom:b"])
    }

    // MARK: - 3. Override path emits new typed audit code

    /// THE KEY TEST — when the gate's `.systemInducedDrift` +
    /// non-empty verdictRef path fires, the lifecycle entry's
    /// transition record now contains the chapter 二百五十五
    /// audit code in addition to the existing
    /// `sovereign-verdict:<ref>` code.
    func testOverrideBranchEmitsAuditCode() async throws {
        let coord =
            try await makeCoordAndAdvanceToTrialPassed(
                ticketID: "t-3")
        let driftCheck = BASCounterHostCheck(
            checkID: "chc-3",
            candidateRef: "cand-3",
            hostBaselineRef: "host-3",
            observedDelta: 0.7,
            inducedRiskScore: 0.9,
            outcome: .systemInducedDrift,
            reasonCodes: ["self-confirmation-loop"])
        let outcome = try await coord
            .approveForDistillationWithCounterHostCheck(
                ticketID: "t-3",
                sovereignVerdictRef: "vr-3-override",
                counterHostCheck: driftCheck)
        XCTAssertEqual(
            outcome, .passedWithSovereignOverride)

        let entry = await coord.entry(ticketID: "t-3")
        let lastTransition = entry?.history.last
        let codes = lastTransition?.reasonCodes ?? []
        XCTAssertTrue(
            codes.contains(
                "counter-host-gate:passed-with-sovereign-override"
            ),
            "expected override audit code; got \(codes)")
        XCTAssertTrue(
            codes.contains("sovereign-verdict:vr-3-override"))
        // Counter-Host check's own reason codes carried forward
        // so the audit trail explains WHY.
        XCTAssertTrue(
            codes.contains("self-confirmation-loop"),
            "expected check's reason code in audit trail")
    }

    // MARK: - 4. Natural-pass branch does NOT emit override code

    /// When the gate passes naturally (Counter-Host check is nil
    /// or `.genuineHostPattern` etc.), the `passed-with-sovereign
    /// -override` code MUST NOT appear — that's how audit walkers
    /// distinguish the two cases.
    func testNaturalPassBranchDoesNotEmitOverrideCode()
        async throws
    {
        let coord =
            try await makeCoordAndAdvanceToTrialPassed(
                ticketID: "t-4")
        let genuineCheck = BASCounterHostCheck(
            checkID: "chc-4",
            candidateRef: "cand-4",
            hostBaselineRef: "host-4",
            observedDelta: 0.05,
            inducedRiskScore: 0.1,
            outcome: .genuineHostPattern,
            reasonCodes: ["matches-baseline"])
        let outcome = try await coord
            .approveForDistillationWithCounterHostCheck(
                ticketID: "t-4",
                sovereignVerdictRef: "vr-4",
                counterHostCheck: genuineCheck)
        XCTAssertEqual(outcome, .passed)

        let entry = await coord.entry(ticketID: "t-4")
        let codes = entry?.history.last?.reasonCodes ?? []
        XCTAssertFalse(
            codes.contains(
                "counter-host-gate:passed-with-sovereign-override"
            ),
            "natural-pass branch must NOT emit override code; got \(codes)")
        XCTAssertTrue(
            codes.contains("sovereign-verdict:vr-4"))
    }

    // MARK: - 5. Block branch's existing audit code unchanged

    /// chapter 一百三十一's block path already emits
    /// `counter-host-gate:blocked-no-sovereign-override`. chapter
    /// 二百五十五 doesn't touch that branch — verify it still
    /// works.
    func testBlockBranchRetainsExistingAuditCode() async throws {
        let coord =
            try await makeCoordAndAdvanceToTrialPassed(
                ticketID: "t-5")
        let driftCheck = BASCounterHostCheck(
            checkID: "chc-5",
            candidateRef: "cand-5",
            hostBaselineRef: "host-5",
            observedDelta: 0.7,
            inducedRiskScore: 0.9,
            outcome: .systemInducedDrift,
            reasonCodes: ["self-confirmation-loop"])
        let outcome = try await coord
            .approveForDistillationWithCounterHostCheck(
                ticketID: "t-5",
                sovereignVerdictRef: "",
                counterHostCheck: driftCheck)
        XCTAssertEqual(outcome, .blocked)
        let entry = await coord.entry(ticketID: "t-5")
        let codes = entry?.history.last?.reasonCodes ?? []
        XCTAssertTrue(
            codes.contains(
                "counter-host-gate:blocked-no-sovereign-override"
            ))
    }
}
