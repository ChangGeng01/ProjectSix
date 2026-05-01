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
}
