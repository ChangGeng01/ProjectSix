// MARK: - QinaoKeyDomainSeparationTests — deep-audit P1-6
//
// The token HMAC keys (permit / warrant / proof) must be cryptographically separated from the raw
// ledger secret AND from each other, so a single-secret host (tokenSigningKey nil ⇒ fallback to the
// ledger secret) cannot have a tag minted in one domain replay in another. HKDF-SHA256 with a
// distinct `info` label per domain gives that separation deterministically.

import XCTest
import CryptoKit
@testable import QinaoSovereign

final class QinaoKeyDomainSeparationTests: XCTestCase {

    private let secret = Data("a-single-host-secret-shared-by-ledger-and-tokens".utf8)

    private func raw(_ d: SymmetricKey) -> Data {
        d.withUnsafeBytes { Data($0) }
    }

    func testEachDomainKeyDiffersFromTheRawSecretAndEachOther() {
        let ledgerRaw = SymmetricKey(data: secret)            // the ledger key = raw (unchanged)
        let permit = QinaoSovereignControlPlane.deriveDomainKey(secret, domain: "qinao.permit.v1")
        let token = QinaoSovereignControlPlane.deriveDomainKey(secret, domain: "qinao.token.v1")

        XCTAssertNotEqual(raw(permit), secret,
            "the permit key must NOT be the raw ledger secret (no cross-domain reuse)")
        XCTAssertNotEqual(raw(token), secret,
            "the warrant/proof key must NOT be the raw ledger secret")
        XCTAssertNotEqual(raw(permit), raw(token),
            "permit and warrant/proof keys must be cryptographically separated")
        XCTAssertNotEqual(raw(permit), raw(ledgerRaw))
        XCTAssertEqual(permit.bitCount, 256, "HKDF-SHA256 → 32-byte key")
    }

    /// Cross-domain forgery is blocked: a tag computed under the permit-domain key does NOT verify
    /// under the warrant-domain key or the raw ledger secret. Reverting derivation to a shared
    /// SymmetricKey(data:) would make all three verify identically — this reds then.
    func testTagUnderOneDomainDoesNotVerifyUnderAnother() {
        let payload = Data("permitID|digest|session|allow|issued|expires".utf8)
        let permitKey = QinaoSovereignControlPlane.deriveDomainKey(secret, domain: "qinao.permit.v1")
        let tokenKey = QinaoSovereignControlPlane.deriveDomainKey(secret, domain: "qinao.token.v1")
        let ledgerKey = SymmetricKey(data: secret)

        let tag = HMAC<SHA256>.authenticationCode(for: payload, using: permitKey)

        XCTAssertTrue(
            HMAC<SHA256>.isValidAuthenticationCode(tag, authenticating: payload, using: permitKey),
            "a permit tag must verify under its own domain key")
        XCTAssertFalse(
            HMAC<SHA256>.isValidAuthenticationCode(tag, authenticating: payload, using: tokenKey),
            "a permit tag must NOT verify under the warrant/proof domain key (domain forgery blocked)")
        XCTAssertFalse(
            HMAC<SHA256>.isValidAuthenticationCode(tag, authenticating: payload, using: ledgerKey),
            "a permit tag must NOT verify under the raw ledger secret")
    }

    func testDerivationIsDeterministicForCrossProcessGates() {
        // Two gates sharing the secret must derive the identical key (permit minted on one verifies
        // on the other) — the property the assembly comment relies on.
        let a = QinaoSovereignControlPlane.deriveDomainKey(secret, domain: "qinao.permit.v1")
        let b = QinaoSovereignControlPlane.deriveDomainKey(secret, domain: "qinao.permit.v1")
        XCTAssertEqual(raw(a), raw(b))
    }
}
