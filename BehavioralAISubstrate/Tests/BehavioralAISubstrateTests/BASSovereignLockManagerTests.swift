import XCTest
@testable import BASRuntimeCore
@testable import BASSovereign

/// Tests for `BR-08` SovereignLockManager.
///
/// The lock manager encodes "which mode is this scope currently in?"
/// A bug lets a released lock keep blocking (false positive, denies
/// legitimate work) or lets an active lock get ignored (false
/// negative, lets dangerous work through). Tests cover both edges,
/// plus the verdict-derived engage and level precedence.
final class BASSovereignLockManagerTests: XCTestCase {
    private typealias LM = BASSovereignLockManager

    func testPassWhenNoLocksEngaged() async {
        let lm = LM()
        let level = await lm.highestActiveLevel(session: "S1")
        XCTAssertEqual(level, .pass)
    }

    func testEngageAndQueryHighestLevel() async {
        let lm = LM()
        _ = await lm.engage(
            lockID: "L1",
            scope: .session("S1"),
            level: .toolCut,
            releaseCondition: "manual"
        )
        let level = await lm.highestActiveLevel(session: "S1")
        XCTAssertEqual(level, .toolCut)
    }

    func testHigherLockSubsumesLowerAcrossScopes() async {
        let lm = LM()
        _ = await lm.engage(
            lockID: "L-turn",
            scope: .turn(session: "S1", turn: "T1"),
            level: .shadowLock,
            releaseCondition: "endOfTurn"
        )
        _ = await lm.engage(
            lockID: "L-session",
            scope: .session("S1"),
            level: .memoryFreeze,
            releaseCondition: "maintenance"
        )
        let level = await lm.highestActiveLevel(session: "S1", turn: "T1")
        XCTAssertEqual(level, .memoryFreeze,
                       "session-scope memoryFreeze must outrank turn-scope shadowLock")
    }

    func testReleaseDropsActive() async {
        let lm = LM()
        _ = await lm.engage(
            lockID: "L1",
            scope: .session("S1"),
            level: .toolCut,
            releaseCondition: "manual"
        )
        await lm.release(lockID: "L1")
        let level = await lm.highestActiveLevel(session: "S1")
        XCTAssertEqual(level, .pass)

        let total = await lm.totalLockCount()
        XCTAssertEqual(total, 1, "released locks are kept for audit, not deleted")
    }

    func testReleaseIsIdempotentAndSafe() async {
        let lm = LM()
        _ = await lm.engage(
            lockID: "L1",
            scope: .session("S1"),
            level: .toolCut,
            releaseCondition: "manual"
        )
        await lm.release(lockID: "L1")
        await lm.release(lockID: "L1")          // no-op
        await lm.release(lockID: "nonexistent") // no-op
        let count = await lm.activeLockCount()
        XCTAssertEqual(count, 0)
    }

    func testReleaseAllInScopeClearsThatScopeOnly() async {
        let lm = LM()
        _ = await lm.engage(lockID: "Lt1", scope: .turn(session: "S1", turn: "T1"), level: .shadowLock, releaseCondition: "endOfTurn")
        _ = await lm.engage(lockID: "Lt2", scope: .turn(session: "S1", turn: "T1"), level: .toolCut, releaseCondition: "endOfTurn")
        _ = await lm.engage(lockID: "Ls",  scope: .session("S1"), level: .memoryFreeze, releaseCondition: "maintenance")

        await lm.releaseAll(in: .turn(session: "S1", turn: "T1"))

        let turnLevel = await lm.highestActiveLevel(session: "S1", turn: "T1")
        XCTAssertEqual(turnLevel, .memoryFreeze,
                       "session lock must survive a turn-scope releaseAll")
    }

    func testDomainScopeAppliesOnlyWhenQueried() async {
        let lm = LM()
        _ = await lm.engage(
            lockID: "Ld",
            scope: .featureDomain("network"),
            level: .toolCut,
            releaseCondition: "maintenance"
        )
        let withDomain = await lm.highestActiveLevel(session: "S1", featureDomain: "network")
        let withoutDomain = await lm.highestActiveLevel(session: "S1")
        let otherDomain = await lm.highestActiveLevel(session: "S1", featureDomain: "fs")

        XCTAssertEqual(withDomain, .toolCut)
        XCTAssertEqual(withoutDomain, .pass)
        XCTAssertEqual(otherDomain, .pass)
    }

    func testApplyVerdictEngagesLockForShadowLockAndHigher() async {
        let lm = LM()
        let verdict = BASSovereignVerdict(
            verdictID: "v-tc",
            verdictLevel: .toolCut,
            latched: true,
            reasonCodes: ["BR-003"],
            revokedPermissions: [.toolWrite],
            policyHash: BASSovereignTrustConstants.builtInPolicyHash
        )
        let lock = await lm.apply(verdict: verdict, scope: .session("S1"))
        XCTAssertNotNil(lock)
        XCTAssertEqual(lock?.lockLevel, .toolCut)

        let level = await lm.highestActiveLevel(session: "S1")
        XCTAssertEqual(level, .toolCut)
    }

    func testApplyVerdictIgnoresPassAndThrottle() async {
        let lm = LM()
        let pass = BASSovereignVerdict(
            verdictID: "v-pass",
            verdictLevel: .pass,
            latched: false,
            reasonCodes: [],
            revokedPermissions: [],
            policyHash: BASSovereignTrustConstants.builtInPolicyHash
        )
        let throttle = BASSovereignVerdict(
            verdictID: "v-thr",
            verdictLevel: .throttle,
            latched: false,
            reasonCodes: ["THR"],
            revokedPermissions: [],
            policyHash: BASSovereignTrustConstants.builtInPolicyHash
        )
        let a = await lm.apply(verdict: pass, scope: .session("S1"))
        let b = await lm.apply(verdict: throttle, scope: .session("S1"))
        XCTAssertNil(a)
        XCTAssertNil(b)
        let count = await lm.activeLockCount()
        XCTAssertEqual(count, 0)
    }

    func testIsOperationAllowedRespectsToleration() async {
        let lm = LM()
        _ = await lm.engage(
            lockID: "L",
            scope: .session("S1"),
            level: .shadowLock,
            releaseCondition: "m"
        )
        let toolWriteOK = await lm.isOperationAllowed(
            maxTolerated: .throttle,
            session: "S1"
        )
        let readOK = await lm.isOperationAllowed(
            maxTolerated: .shadowLock,
            session: "S1"
        )
        XCTAssertFalse(toolWriteOK, "shadowLock > throttle → tool write denied")
        XCTAssertTrue(readOK, "shadowLock == max tolerated → read OK")
    }

    func testDiagnosticsActiveVsTotal() async {
        let lm = LM()
        _ = await lm.engage(lockID: "A", scope: .session("S"), level: .shadowLock, releaseCondition: "m")
        _ = await lm.engage(lockID: "B", scope: .session("S"), level: .toolCut, releaseCondition: "m")
        await lm.release(lockID: "A")

        let active = await lm.activeLockCount()
        let total = await lm.totalLockCount()
        XCTAssertEqual(active, 1)
        XCTAssertEqual(total, 2)
    }
}
