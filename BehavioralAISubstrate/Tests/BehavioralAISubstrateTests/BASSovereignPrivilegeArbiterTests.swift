import XCTest
@testable import BASRuntimeCore
@testable import BASSovereign

/// Tests for `BR-02` PrivilegeArbiter.
///
/// Arbiter bookkeeping is simple but every edge matters — a bug in
/// revocation scope lets a revoked permission sneak back in, which
/// silently breaks BR-003..BR-005 / BR-011. These tests lock down
/// each scope precedence rule.
final class BASSovereignPrivilegeArbiterTests: XCTestCase {
    func testDefaultAllowsWhenNothingRevoked() async {
        let arb = BASSovereignPrivilegeArbiter()
        let ok = await arb.isAllowed(.toolWrite, session: "S1", turn: "T1")
        XCTAssertTrue(ok)
    }

    func testTurnRevocationBlocksCurrentTurnOnly() async {
        let arb = BASSovereignPrivilegeArbiter()
        await arb.revoke(.toolWrite, session: "S1", turn: "T1", reasonCode: "BR-003")

        let t1 = await arb.isAllowed(.toolWrite, session: "S1", turn: "T1")
        XCTAssertFalse(t1)

        let t2 = await arb.isAllowed(.toolWrite, session: "S1", turn: "T2")
        XCTAssertTrue(t2, "turn revocation must not leak into a different turn")
    }

    func testSessionRevocationBlocksAllTurnsOfSession() async {
        let arb = BASSovereignPrivilegeArbiter()
        await arb.revoke(.hostMutation, session: "S1", reasonCode: "BR-005")

        let t1 = await arb.isAllowed(.hostMutation, session: "S1", turn: "T1")
        let t2 = await arb.isAllowed(.hostMutation, session: "S1", turn: "T99")
        XCTAssertFalse(t1)
        XCTAssertFalse(t2)

        // Other sessions unaffected.
        let other = await arb.isAllowed(.hostMutation, session: "S2", turn: "T1")
        XCTAssertTrue(other)
    }

    func testDomainRevocationBlocksAcrossSessions() async {
        let arb = BASSovereignPrivilegeArbiter()
        await arb.revoke(.externalActuation, session: "S1", featureDomain: "network", reasonCode: "BR-008")

        let s1 = await arb.isAllowed(.externalActuation, session: "S1", turn: "T1", featureDomain: "network")
        let s2 = await arb.isAllowed(.externalActuation, session: "S2", turn: "T1", featureDomain: "network")
        XCTAssertFalse(s1)
        XCTAssertFalse(s2)

        let other = await arb.isAllowed(.externalActuation, session: "S2", turn: "T1", featureDomain: "fs")
        XCTAssertTrue(other, "different domain must not inherit revocation")
    }

    func testDomainSealCannotBeBypassedByOmittingDomain() async {
        // blindspot HIGH: a domain seal must not be dodgeable by simply
        // not naming the domain in the query. The old code only checked
        // domainRevocations[featureDomain], so a nil-domain query fell
        // through to session/turn scope and returned true — silently
        // bypassing the widest-scope seal ("no external actuation ...").
        let arb = BASSovereignPrivilegeArbiter()
        await arb.revoke(.externalActuation, session: "S1", featureDomain: "network", reasonCode: "BR-008")

        // Query for the SAME permission omitting featureDomain entirely
        // (and even for a different session/turn) must fail CLOSED.
        let nilDomainSameSession = await arb.isAllowed(.externalActuation, session: "S1", turn: "T1")
        let nilDomainOtherSession = await arb.isAllowed(.externalActuation, session: "S9", turn: "T7")
        XCTAssertFalse(nilDomainSameSession,
            "a domain-omitting query must not bypass the domain seal")
        XCTAssertFalse(nilDomainOtherSession,
            "the domain seal is cross-session; omitting the domain cannot dodge it")

        // A DIFFERENT permission with no seal is still allowed — the
        // backstop is permission-specific, not a blanket deny.
        let unrelated = await arb.isAllowed(.toolWrite, session: "S1", turn: "T1")
        XCTAssertTrue(unrelated, "unsealed permissions remain allowed")
    }

    func testApplyVerdictCopiesEveryRevokedPermission() async {
        let arb = BASSovereignPrivilegeArbiter()
        let verdict = BASSovereignVerdict(
            verdictID: "v1",
            verdictLevel: .deadStop,
            latched: true,
            reasonCodes: ["BR-001"],
            revokedPermissions: [.toolWrite, .externalActuation, .hostMutation],
            policyHash: BASSovereignTrustConstants.builtInPolicyHash
        )
        await arb.apply(verdict: verdict, session: "S1")

        for perm in verdict.revokedPermissions {
            let allowed = await arb.isAllowed(perm, session: "S1", turn: "T1")
            XCTAssertFalse(allowed, "\(perm) must be denied after apply(verdict:)")
        }
    }

    func testEndOfTurnLiftsTurnRevocationButNotSession() async {
        let arb = BASSovereignPrivilegeArbiter()
        await arb.revoke(.toolWrite, session: "S1", turn: "T1", reasonCode: "BR-003")
        await arb.revoke(.hostMutation, session: "S1", reasonCode: "BR-005")

        await arb.endOfTurn(session: "S1", turn: "T1")

        let writeOK = await arb.isAllowed(.toolWrite, session: "S1", turn: "T1")
        XCTAssertTrue(writeOK, "turn revocation must be lifted")

        let hostOK = await arb.isAllowed(.hostMutation, session: "S1", turn: "T2")
        XCTAssertFalse(hostOK, "session revocation must persist across end-of-turn")
    }

    func testExplainDenialReportsRevocationScope() async {
        let arb = BASSovereignPrivilegeArbiter()
        await arb.revoke(.externalActuation, session: "S1", featureDomain: "network", reasonCode: "BR-008")
        let why = await arb.explainDenial(.externalActuation, session: "S1", turn: "T1", featureDomain: "network")
        XCTAssertNotNil(why)
        XCTAssertTrue(why!.contains("domain(network)"))
        XCTAssertTrue(why!.contains("BR-008"))
    }

    func testDomainOutranksSessionWhichOutranksTurnInExplain() async {
        let arb = BASSovereignPrivilegeArbiter()
        await arb.revoke(.toolWrite, session: "S1", turn: "T1", reasonCode: "TURN")
        await arb.revoke(.toolWrite, session: "S1", reasonCode: "SESSION")
        await arb.revoke(.toolWrite, session: "S1", featureDomain: "fs", reasonCode: "DOMAIN")

        let why = await arb.explainDenial(.toolWrite, session: "S1", turn: "T1", featureDomain: "fs")
        XCTAssertTrue(why!.contains("DOMAIN"), "domain scope should be reported first when present")
    }
}
