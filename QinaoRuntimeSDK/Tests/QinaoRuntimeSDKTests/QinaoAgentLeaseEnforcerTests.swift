import XCTest
@testable import QinaoSeats

/// 六十五.1 — lease enforcer runtime tests.
final class QinaoAgentLeaseEnforcerTests: XCTestCase {

    /// Deterministic clock for tests.
    private final class Clock: @unchecked Sendable {
        var nowMs: Int = 0
    }

    private func makeEnforcer(
        clock: Clock
    ) -> QinaoAgentLeaseEnforcer {
        QinaoAgentLeaseEnforcer(
            now: { clock.nowMs })
    }

    private func makeLease(
        agent: QinaoSeat = .planner,
        maxMs: Int = 1000,
        maxLoops: Int = 5,
        maxWrites: Int = 3,
        scope: Set<QinaoSeatDomain> = [
            .candidateFrontier,
        ]
    ) -> QinaoAgentLease {
        QinaoAgentLease(
            agent: agent,
            maxMs: maxMs,
            maxLoops: maxLoops,
            maxWrites: maxWrites,
            scope: scope)
    }

    func test_freshLeaseIsValid() async {
        let clock = Clock()
        let enf = makeEnforcer(clock: clock)
        let ref = await enf.issue(makeLease())
        let valid = await enf.isValid(leaseRef: ref)
        XCTAssertTrue(valid)
    }

    func test_unknownLeaseInvalid() async {
        let clock = Clock()
        let enf = makeEnforcer(clock: clock)
        let report = await enf.validity(
            leaseRef: "ghost")
        XCTAssertTrue(
            report.reasons.contains(.unknownLease))
    }

    func test_expiredLeaseInvalid() async {
        let clock = Clock()
        let enf = makeEnforcer(clock: clock)
        let ref = await enf.issue(
            makeLease(maxMs: 100))
        clock.nowMs = 200
        let report = await enf.validity(
            leaseRef: ref)
        XCTAssertFalse(report.isValid)
        let isExpired = report.reasons.contains {
            if case .expired = $0 { return true }
            return false
        }
        XCTAssertTrue(isExpired)
    }

    func test_writesExhausted() async {
        let clock = Clock()
        let enf = makeEnforcer(clock: clock)
        let ref = await enf.issue(
            makeLease(maxWrites: 2))
        await enf.recordWrite(leaseRef: ref)
        await enf.recordWrite(leaseRef: ref)
        let report = await enf.validity(
            leaseRef: ref)
        let exhausted = report.reasons.contains {
            if case .writesExhausted = $0 { return true }
            return false
        }
        XCTAssertTrue(exhausted)
    }

    func test_loopsExhausted() async {
        let clock = Clock()
        let enf = makeEnforcer(clock: clock)
        let ref = await enf.issue(
            makeLease(maxLoops: 1))
        await enf.recordLoop(leaseRef: ref)
        let report = await enf.validity(
            leaseRef: ref)
        let exhausted = report.reasons.contains {
            if case .loopsExhausted = $0 { return true }
            return false
        }
        XCTAssertTrue(exhausted)
    }

    func test_targetOutsideScope() async {
        let clock = Clock()
        let enf = makeEnforcer(clock: clock)
        let ref = await enf.issue(
            makeLease(
                scope: [.candidateFrontier]))
        // Check against a target NOT in scope.
        let valid = await enf.isValid(
            leaseRef: ref,
            target: .actionPermit)
        XCTAssertFalse(valid)
    }

    func test_revokedLeaseInvalid() async {
        let clock = Clock()
        let enf = makeEnforcer(clock: clock)
        let ref = await enf.issue(makeLease())
        await enf.revoke(leaseRef: ref)
        let report = await enf.validity(
            leaseRef: ref)
        XCTAssertTrue(
            report.reasons.contains(.revoked))
    }

    func test_issuedRefMonotonic() async {
        let clock = Clock()
        let enf = makeEnforcer(clock: clock)
        let r1 = await enf.issue(makeLease())
        let r2 = await enf.issue(makeLease())
        XCTAssertNotEqual(r1, r2)
        let count = await enf.issuedCount()
        XCTAssertEqual(count, 2)
    }

    func test_usageInspection() async {
        let clock = Clock()
        let enf = makeEnforcer(clock: clock)
        let ref = await enf.issue(makeLease())
        await enf.recordWrite(leaseRef: ref)
        await enf.recordWrite(leaseRef: ref)
        await enf.recordLoop(leaseRef: ref)
        let usage = await enf.usage(leaseRef: ref)
        XCTAssertEqual(usage?.writesUsed, 2)
        XCTAssertEqual(usage?.loopsUsed, 1)
        XCTAssertEqual(usage?.revoked, false)
    }

    func test_validityReportCodable() throws {
        let report = QinaoAgentLeaseValidityReport(
            leaseRef: "lease-1",
            reasons: [
                .expired(elapsedMs: 200, maxMs: 100),
                .revoked,
            ])
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(
            QinaoAgentLeaseValidityReport.self,
            from: data)
        XCTAssertEqual(decoded, report)
    }

    // MARK: - deep-audit P1-8 (2026-07-13): lease is bound to its issued agent.

    /// A lease issued to `.planner`, presented by `.risk`, must fail closed with
    /// `.leaseAgentMismatch` — a seat cannot spend another agent's lease budget/scope even
    /// when every other invariant (unexpired, budget, scope) holds. Dropping the
    /// `entry.lease.agent != agent` compare (the pre-P1-8 state) flips this GREEN → the tooth.
    func test_leasePresentedByWrongAgentFailsClosed() async {
        let clock = Clock()
        let enf = makeEnforcer(clock: clock)
        let ref = await enf.issue(makeLease(agent: .planner))

        // Same lease, presented by the ISSUED agent → valid.
        let ownReport = await enf.validity(leaseRef: ref, agent: .planner)
        XCTAssertTrue(ownReport.isValid,
            "the lease's own agent must pass every invariant")

        // Presented by a DIFFERENT seat → mismatch, fail closed.
        let report = await enf.validity(leaseRef: ref, agent: .risk)
        XCTAssertFalse(report.isValid,
            "a seat presenting another agent's lease must fail closed")
        let mismatched = report.reasons.contains {
            if case .leaseAgentMismatch(let issuedTo, let presentedBy) = $0 {
                return issuedTo == .planner && presentedBy == .risk
            }
            return false
        }
        XCTAssertTrue(mismatched,
            "the typed reason must name both the issued and presenting seats")
    }

    /// Back-compat: the agent-less validity() call keeps its exact pre-P1-8 semantics — no
    /// mismatch reason can appear when no presenting agent is supplied.
    func test_agentlessValidityUnchanged() async {
        let clock = Clock()
        let enf = makeEnforcer(clock: clock)
        let ref = await enf.issue(makeLease(agent: .planner))
        let report = await enf.validity(leaseRef: ref)  // no agent
        XCTAssertTrue(report.isValid)
        let anyMismatch = report.reasons.contains {
            if case .leaseAgentMismatch = $0 { return true }
            return false
        }
        XCTAssertFalse(anyMismatch, "no agent supplied → no mismatch check")
    }
}
