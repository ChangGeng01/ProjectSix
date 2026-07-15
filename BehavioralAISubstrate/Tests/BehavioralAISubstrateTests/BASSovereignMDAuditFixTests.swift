import XCTest
import CryptoKit
import BASRuntimeCore
@testable import BASSovereign

/// audit M-d cluster (sovereign ledger / token authority) fixes.
final class BASSovereignMDAuditFixTests: XCTestCase {

    private func makeAuthority() -> BASSovereignTokenAuthority {
        BASSovereignTokenAuthority(signingKey: Curve25519.Signing.PrivateKey())
    }
    private func intent(_ session: String, _ turn: String)
        -> BASSovereignTokenAuthority.CommitIntent {
        BASSovereignTokenAuthority.CommitIntent(
            sessionID: session, turnID: turn,
            scope: BASSovereignCommitScope.allCases.first!,
            allowedTargets: ["answer"],
            actionDigest: "ad-\(session)-\(turn)",
            snapshotRef: "snap")
    }

    /// M-d MED-6: `revokeAllTokens(forSession:)` must burn ONLY the named session's un-redeemed
    /// tokens. Previously it ignored the sessionID (`_ = sessionID`) and nuked EVERY session's
    /// tokens — an L14 ROLLBACK on session A would silently invalidate B/C/…
    func testRevokeAllTokensIsSessionScoped() async throws {
        let authority = makeAuthority()
        _ = try await authority.issueCommitToken(for: intent("A", "t1"))
        _ = try await authority.issueCommitToken(for: intent("A", "t2"))
        _ = try await authority.issueCommitToken(for: intent("B", "t1"))
        let before = await authority.activeTokenCount()
        XCTAssertEqual(before, 3, "three un-redeemed tokens minted")

        await authority.revokeAllTokens(forSession: "A")

        let after = await authority.activeTokenCount()
        XCTAssertEqual(after, 1,
            "revokeAllTokens(forSession: A) must burn only A's 2 tokens, leaving B's 1 active (M-d MED-6)")
    }

    /// M-d MED-3: the injective canonical form is gated on schemaRank >= (1,2,0), so a future
    /// schema above 1.2.0 stays injective instead of falling into the ambiguous delimiter-join.
    /// Byte-equal for existing versions: 1.0.0/1.1.0 rank below 1.2.0, 1.2.0 at it.
    func testSchemaRankGatesInjectiveCanonicalForm() {
        XCTAssertTrue(BASSovereignAuditLedger.schemaRank("1.2.0") >= BASSovereignAuditLedger.schemaRank("1.2.0"))
        XCTAssertTrue(BASSovereignAuditLedger.schemaRank("1.3.0") >= BASSovereignAuditLedger.schemaRank("1.2.0"),
            "a future >1.2.0 schema must select the injective form")
        XCTAssertFalse(BASSovereignAuditLedger.schemaRank("1.1.0") >= BASSovereignAuditLedger.schemaRank("1.2.0"),
            "1.1.0 stays on its legacy form (byte-equal)")
        XCTAssertFalse(BASSovereignAuditLedger.schemaRank("1.0.0") >= BASSovereignAuditLedger.schemaRank("1.2.0"))
    }
}
