import XCTest
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASWorldPrior

/// M385 — pin the contract that an active `BASUnknownReserve` caps
/// the `BASActionPermit.assertionCeiling` field.
///
/// What this file pins:
///
///   1. The strictness ranking (unrestricted < provisional <
///      qualified < metaOnly < none) is total + ordered correctly.
///   2. nil reserve / closed reserve (empty unknownRefs OR ceiling
///      == .unrestricted) is no-op.
///   3. Active reserve narrows the permit's assertionCeiling field
///      to the reserve's ceiling raw value.
///   4. Already-stricter permit ceiling is preserved (monotonic
///      narrowing only).
///   5. Reason code format is stable
///      (`permit.assertion-ceiling:capped-from:<from>:to:<to>`).
///   6. The cap never changes `permit.mode` or any other field
///      besides `assertionCeiling` and `reasonCodes`.
final class M385AssertionCeilingGateTests: XCTestCase {

    // MARK: - Fixture helpers

    private func basePermit(
        ceiling: String = "guarded",
        mode: BASActionPermitMode = .answer
    ) -> BASActionPermit {
        BASActionPermit(
            mode: mode,
            assertionCeiling: ceiling)
    }

    private func reserve(
        ceiling: BASUnknownAssertionCeiling,
        refs: [String] = ["unknown-1"]
    ) -> BASUnknownReserve {
        BASUnknownReserve(
            reserveID: "r-test",
            unknownRefs: refs,
            whyUnresolved: "test",
            forbiddenInferences: [],
            evidenceNeeded: [],
            assertionCeiling: ceiling)
    }

    // MARK: - 1. Strictness ranking is total + ordered

    func testStrictnessRankingIsTotalAndOrdered() {
        let ranks = BASUnknownAssertionCeiling.allCases.map {
            ($0, BASAssertionCeilingGate.strictnessRank(for: $0))
        }
        // Each case has a unique rank.
        XCTAssertEqual(
            Set(ranks.map(\.1)).count,
            BASUnknownAssertionCeiling.allCases.count)
        // Ordering: unrestricted is least strict; none is most.
        XCTAssertLessThan(
            BASAssertionCeilingGate.strictnessRank(for: .unrestricted),
            BASAssertionCeilingGate.strictnessRank(for: .provisional))
        XCTAssertLessThan(
            BASAssertionCeilingGate.strictnessRank(for: .provisional),
            BASAssertionCeilingGate.strictnessRank(for: .qualified))
        XCTAssertLessThan(
            BASAssertionCeilingGate.strictnessRank(for: .qualified),
            BASAssertionCeilingGate.strictnessRank(for: .metaOnly))
        XCTAssertLessThan(
            BASAssertionCeilingGate.strictnessRank(for: .metaOnly),
            BASAssertionCeilingGate.strictnessRank(for: .none))
    }

    // MARK: - 1b. BAS permit-string ranking covers canonical strings

    func testBASPermitStringRankingCoversCanonicalStrings() {
        // Canonical BAS permit strings + reserve raw values share
        // the ordering. Pin the exact rank values for each.
        XCTAssertEqual(
            BASAssertionCeilingGate.strictnessRank(forPermitString: "default"), 0)
        XCTAssertEqual(
            BASAssertionCeilingGate.strictnessRank(forPermitString: "unrestricted"), 0)
        XCTAssertEqual(
            BASAssertionCeilingGate.strictnessRank(forPermitString: "standard"), 1)
        XCTAssertEqual(
            BASAssertionCeilingGate.strictnessRank(forPermitString: "provisional"), 1)
        XCTAssertEqual(
            BASAssertionCeilingGate.strictnessRank(forPermitString: "guarded"), 2)
        XCTAssertEqual(
            BASAssertionCeilingGate.strictnessRank(forPermitString: "qualified"), 2)
        XCTAssertEqual(
            BASAssertionCeilingGate.strictnessRank(forPermitString: "meta-only"), 3)
        XCTAssertEqual(
            BASAssertionCeilingGate.strictnessRank(forPermitString: "minimal"), 4)
        XCTAssertEqual(
            BASAssertionCeilingGate.strictnessRank(forPermitString: "none"), 4)
        // Unrecognised strings rank -1 so reserve cap can still
        // narrow them.
        XCTAssertEqual(
            BASAssertionCeilingGate.strictnessRank(forPermitString: "host-defined-x"), -1)
    }

    // MARK: - 2. nil reserve no-op

    func testNilReserveNoOp() {
        let permit = basePermit()
        let decision = BASAssertionCeilingGate.cap(
            permit: permit,
            reserve: nil)
        XCTAssertFalse(decision.capped)
        XCTAssertEqual(decision.reasonCodes, [])
        XCTAssertEqual(decision.permit, permit)
    }

    // MARK: - 3. Closed reserve (empty refs) no-op

    func testClosedReserveEmptyRefsNoOp() {
        let permit = basePermit()
        let r = reserve(ceiling: .qualified, refs: [])
        let decision = BASAssertionCeilingGate.cap(
            permit: permit,
            reserve: r)
        XCTAssertFalse(decision.capped)
        XCTAssertEqual(decision.permit, permit)
    }

    // MARK: - 4. Closed reserve (unrestricted ceiling) no-op

    func testClosedReserveUnrestrictedNoOp() {
        let permit = basePermit()
        let r = reserve(ceiling: .unrestricted)
        let decision = BASAssertionCeilingGate.cap(
            permit: permit,
            reserve: r)
        XCTAssertFalse(decision.capped)
        XCTAssertEqual(decision.permit, permit)
    }

    // MARK: - 5. Active reserve caps a less-strict permit ceiling

    func testActiveReserveCapsLessStrictPermitCeiling() {
        // "default" (rank 0) is less strict than .qualified (rank
        // 2). Cap should fire.
        let permit = basePermit(ceiling: "default")
        let r = reserve(ceiling: .qualified)
        let decision = BASAssertionCeilingGate.cap(
            permit: permit,
            reserve: r)
        XCTAssertTrue(decision.capped)
        XCTAssertEqual(decision.permit.assertionCeiling, "qualified")
        XCTAssertEqual(decision.reasonCodes, [
            "permit.assertion-ceiling:capped-from:default:to:qualified"
        ])
    }

    // MARK: - 6. Active reserve at most-strict caps "guarded" to "none"

    func testMostStrictReserveCapsGuardedToNone() {
        // "guarded" (rank 2) cannot beat .none (rank 4). Cap fires.
        let permit = basePermit(ceiling: "guarded")
        let r = reserve(ceiling: .none)
        let decision = BASAssertionCeilingGate.cap(
            permit: permit,
            reserve: r)
        XCTAssertTrue(decision.capped)
        XCTAssertEqual(decision.permit.assertionCeiling, "none")
        XCTAssertEqual(decision.reasonCodes, [
            "permit.assertion-ceiling:capped-from:guarded:to:none"
        ])
    }

    // MARK: - 7. Stricter permit preserved (monotonic narrowing)

    func testStricterPermitCeilingPreserved() {
        // "minimal" (rank 4, most strict) → reserve at .qualified
        // (rank 2) must not widen.
        let permit = basePermit(ceiling: "minimal")
        let r = reserve(ceiling: .qualified)
        let decision = BASAssertionCeilingGate.cap(
            permit: permit,
            reserve: r)
        XCTAssertFalse(decision.capped)
        XCTAssertEqual(decision.reasonCodes, [])
        XCTAssertEqual(decision.permit, permit)
    }

    // MARK: - 8. Equal strictness preserved (no spurious cap)

    func testEqualStrictnessPreserved() {
        // "guarded" (rank 2) and .qualified (rank 2) — equal, no
        // cap. This is the contract that lets pre-existing BAS
        // permits with "guarded" string survive an active reserve
        // at .qualified without churn.
        let permit = basePermit(ceiling: "guarded")
        let r = reserve(ceiling: .qualified)
        let decision = BASAssertionCeilingGate.cap(
            permit: permit,
            reserve: r)
        XCTAssertFalse(decision.capped)
        XCTAssertEqual(decision.permit, permit)
    }

    // MARK: - 9. Cap leaves all other permit fields untouched

    func testCapLeavesOtherFieldsUntouched() {
        let permit = BASActionPermit(
            mode: .answer,
            stackedModes: [.compare],
            reasonCodes: ["existing"],
            allowedDomains: ["fact"],
            blockedDomains: ["medical"],
            assertionCeiling: "default",
            toolScope: "broad",
            memoryScope: "broad",
            requireMirror: true,
            requireCompare: true,
            requireSecondCheck: true,
            outputLengthCap: 1000,
            tonePolicy: "soft",
            templatePolicy: "free",
            delayWindow: "30s",
            substituteRequired: false,
            escalationHintRef: "hint-1")
        let r = reserve(ceiling: .qualified)
        let decision = BASAssertionCeilingGate.cap(
            permit: permit,
            reserve: r)
        XCTAssertTrue(decision.capped)
        let p = decision.permit
        XCTAssertEqual(p.mode, .answer)
        XCTAssertEqual(p.stackedModes, [.compare])
        XCTAssertEqual(p.allowedDomains, ["fact"])
        XCTAssertEqual(p.blockedDomains, ["medical"])
        XCTAssertEqual(p.assertionCeiling, "qualified")
        XCTAssertEqual(p.toolScope, "broad")
        XCTAssertEqual(p.memoryScope, "broad")
        XCTAssertTrue(p.requireMirror)
        XCTAssertTrue(p.requireCompare)
        XCTAssertTrue(p.requireSecondCheck)
        XCTAssertEqual(p.outputLengthCap, 1000)
        XCTAssertEqual(p.tonePolicy, "soft")
        XCTAssertEqual(p.templatePolicy, "free")
        XCTAssertEqual(p.delayWindow, "30s")
        XCTAssertFalse(p.substituteRequired)
        XCTAssertEqual(p.escalationHintRef, "hint-1")
        // reasonCodes additive — existing preserved + new appended.
        XCTAssertEqual(p.reasonCodes, [
            "existing",
            "permit.assertion-ceiling:capped-from:default:to:qualified",
        ])
    }

    // MARK: - 10. canonicalString returns raw value

    func testCanonicalStringReturnsRawValue() {
        for c in BASUnknownAssertionCeiling.allCases {
            XCTAssertEqual(
                BASAssertionCeilingGate.canonicalString(for: c),
                c.rawValue)
        }
    }
}
