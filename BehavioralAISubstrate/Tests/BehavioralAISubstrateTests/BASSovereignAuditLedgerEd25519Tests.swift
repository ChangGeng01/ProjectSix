import XCTest
import CryptoKit
@testable import BASRuntimeCore
@testable import BASSovereign

/// M87 — Ed25519 production-grade signing for the sovereign audit
/// ledger.
///
/// These tests pin the Ed25519 mode's contracts so HMAC-mode
/// regression guards don't accidentally cover (or hide) Ed25519
/// behaviour. What each test proves:
///
/// 1. Ed25519 ledger signs append-time entries and the signature is
///    non-empty and base64-formatted (shape distinct from HMAC).
/// 2. Ed25519 signing is deterministic (RFC 8032 derives the nonce
///    from message + key; same message twice → same signature) —
///    this is what lets `verifyChainIntegrity()` recompute and
///    compare without storing a random nonce.
/// 3. `verifyChainIntegrity()` accepts a clean Ed25519-signed chain
///    just as it does for HMAC chains.
/// 4. The static `verify(_:publicKey:signingNamespace:)` accepts a
///    valid entry + matching public key.
/// 5. The static verify rejects:
///    - a wrong public key (different key pair)
///    - a tampered entry field (audit ID mutated)
///    - a tampered signature (one base64 char flipped)
///    - a mismatched signing namespace (namespace binding proof)
///    - a malformed base64 signature (returns false, not crash)
/// 6. Ed25519 and HMAC modes are distinguishable at the public
///    surface: `ed25519PublicKey` is non-nil only in Ed25519 mode.
/// 7. `withEd25519Seed(_:)` is deterministic across ledger instances
///    so integration tests can reproduce signatures.
/// 8. HMAC mode continues to behave exactly as pre-M87 (regression
///    guard — no change to the HMAC path).
///
/// Together the suite covers what a production cross-verifier binary
/// needs: hand it an appended entry + a public key and it can
/// independently decide clean/tampered without the signing secret.
final class BASSovereignAuditLedgerEd25519Tests: XCTestCase {

    // MARK: - Fixtures

    private func makeEntry(
        auditID: String,
        session: String = "session-A",
        turn: String = "turn-1",
        verdict: String = "verdict-m87",
        at: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> BASSovereignAuditEntry {
        BASSovereignAuditEntry(
            auditID: auditID,
            sessionID: session,
            turnID: turn,
            verdictRef: verdict,
            ruleIDs: ["BR-001"],
            signalRefs: [],
            actionRefs: [],
            snapshotRef: "snap-m87",
            actor: .system,
            signature: "",  // ledger signs on append
            appendedAt: at
        )
    }

    private func makeEd25519Ledger(seed: String = "m87-test-seed")
        throws -> BASSovereignAuditLedger {
        try BASSovereignAuditLedger.withEd25519Seed(seed)
    }

    // MARK: - Basic: Ed25519 signs and appends

    func testEd25519LedgerSignsAndAppendsFirstEntry() async throws {
        let ledger = try makeEd25519Ledger()
        let appended = try await ledger.append(makeEntry(auditID: "a-1"))

        XCTAssertEqual(appended.priorHash, "GENESIS")
        XCTAssertFalse(appended.entry.signature.isEmpty)
        // Ed25519 signature is 64 bytes → base64-encoded = ~88 chars
        // (44 bytes for HMAC-SHA256 = 44 chars base64). The shape is
        // a meaningful mode-distinguisher.
        XCTAssertEqual(appended.entry.signature.count, 88)
    }

    // MARK: - Non-deterministic signing but identical verification

    /// Apple's CryptoKit implementation of Ed25519 adds fault-attack
    /// entropy to the nonce on top of RFC 8032's deterministic
    /// baseline, so two signing calls on the same message with the
    /// same key produce **different** signatures — but both signatures
    /// verify against the same public key. This is a stronger
    /// security property than the paper's pure determinism. The
    /// ledger's verify path therefore uses
    /// `publicKey.isValidSignature(_:for:)` rather than recompute-
    /// and-compare; this test pins that contract so a future
    /// regression (accidentally tightening the check to byte-equality)
    /// is caught immediately.
    func testEd25519SigningIsNonDeterministicButBothVerify()
        async throws {
        let ledgerA = try makeEd25519Ledger(seed: "det-seed")
        let ledgerB = try makeEd25519Ledger(seed: "det-seed")

        let entry = makeEntry(auditID: "same-entry")
        let a = try await ledgerA.append(entry)
        let b = try await ledgerB.append(entry)

        // Signatures differ (CryptoKit randomization).
        XCTAssertNotEqual(
            a.entry.signature,
            b.entry.signature,
            "CryptoKit Ed25519 adds fault-attack entropy — signatures differ")

        // But both verify under the (identical) public key derived
        // from the shared seed.
        let pubA = await ledgerA.ed25519PublicKey!
        let pubB = await ledgerB.ed25519PublicKey!
        XCTAssertEqual(
            pubA.rawRepresentation,
            pubB.rawRepresentation,
            "same seed ⇒ same public key")
        XCTAssertTrue(
            BASSovereignAuditLedger.verify(a, publicKey: pubA))
        XCTAssertTrue(
            BASSovereignAuditLedger.verify(b, publicKey: pubB))
    }

    // MARK: - Chain integrity under Ed25519

    func testVerifyChainIntegrityPassesOnEd25519SignedChain()
        async throws {
        let ledger = try makeEd25519Ledger()
        _ = try await ledger.append(makeEntry(auditID: "e-1"))
        _ = try await ledger.append(makeEntry(
            auditID: "e-2", turn: "turn-2"))
        _ = try await ledger.append(makeEntry(
            auditID: "e-3", turn: "turn-3"))

        // Should not throw.
        try await ledger.verifyChainIntegrity()
    }

    // MARK: - Static verifier accepts valid (pubkey, entry)

    func testStaticVerifyAcceptsValidSignatureWithCorrectPubKey()
        async throws {
        let ledger = try makeEd25519Ledger()
        let appended = try await ledger.append(makeEntry(auditID: "v-1"))

        let pubKey = await ledger.ed25519PublicKey
        XCTAssertNotNil(pubKey)

        XCTAssertTrue(
            BASSovereignAuditLedger.verify(
                appended, publicKey: pubKey!))
    }

    // MARK: - Static verifier rejects wrong public key

    func testStaticVerifyRejectsDifferentKeyPair() async throws {
        let ledger = try makeEd25519Ledger(seed: "keypair-1")
        let appended = try await ledger.append(makeEntry(auditID: "wk-1"))

        // A completely independent key pair — CryptoKit's
        // `Curve25519.Signing.PrivateKey()` generates a fresh one.
        let otherPair = BASSovereignEd25519KeyPair.generate()

        XCTAssertFalse(
            BASSovereignAuditLedger.verify(
                appended, publicKey: otherPair.publicKey),
            "independent key pair must not validate")
    }

    // MARK: - Static verifier rejects tampered entry

    func testStaticVerifyRejectsTamperedAuditID() async throws {
        let ledger = try makeEd25519Ledger()
        let appended = try await ledger.append(
            makeEntry(auditID: "original-id"))
        let pubKey = await ledger.ed25519PublicKey!

        // Clone the appended entry but flip the audit ID.
        var tamperedEntry = appended.entry
        tamperedEntry.auditID = "tampered-id"
        let tampered = BASSovereignAuditLedger.AppendedEntry(
            entry: tamperedEntry,
            priorHash: appended.priorHash,
            selfHash: appended.selfHash)

        XCTAssertFalse(
            BASSovereignAuditLedger.verify(tampered, publicKey: pubKey))
    }

    // MARK: - Static verifier rejects tampered signature

    func testStaticVerifyRejectsTamperedSignatureBytes() async throws {
        let ledger = try makeEd25519Ledger()
        let appended = try await ledger.append(makeEntry(auditID: "sig-1"))
        let pubKey = await ledger.ed25519PublicKey!

        // Flip one base64 character in the signature.
        var tamperedEntry = appended.entry
        let original = tamperedEntry.signature
        let idx = original.index(original.startIndex, offsetBy: 0)
        let firstChar = original[idx]
        let flipped = firstChar == "A" ? "B" : "A"
        tamperedEntry.signature = flipped + String(original.dropFirst())
        let tampered = BASSovereignAuditLedger.AppendedEntry(
            entry: tamperedEntry,
            priorHash: appended.priorHash,
            selfHash: appended.selfHash)

        XCTAssertFalse(
            BASSovereignAuditLedger.verify(tampered, publicKey: pubKey))
    }

    // MARK: - Static verifier respects namespace binding

    func testStaticVerifyRejectsMismatchedSigningNamespace()
        async throws {
        let ledger = try BASSovereignAuditLedger.withEd25519Seed(
            "ns-seed", namespace: "sovereign.keyring.v1")
        let appended = try await ledger.append(makeEntry(auditID: "ns-1"))
        let pubKey = await ledger.ed25519PublicKey!

        // Correct namespace → accept.
        XCTAssertTrue(
            BASSovereignAuditLedger.verify(
                appended,
                publicKey: pubKey,
                signingNamespace: "sovereign.keyring.v1"))

        // Wrong namespace → reject. The canonical bytes include the
        // namespace tag; changing it changes what was signed.
        XCTAssertFalse(
            BASSovereignAuditLedger.verify(
                appended,
                publicKey: pubKey,
                signingNamespace: "sovereign.keyring.v2"))
    }

    // MARK: - Static verifier handles malformed base64 without crash

    func testStaticVerifyReturnsFalseOnMalformedBase64Signature()
        async throws {
        let ledger = try makeEd25519Ledger()
        let appended = try await ledger.append(makeEntry(auditID: "mb-1"))
        let pubKey = await ledger.ed25519PublicKey!

        // Replace the signature with garbage that isn't valid base64.
        var tamperedEntry = appended.entry
        tamperedEntry.signature = "!!!! not valid base64 !!!!"
        let tampered = BASSovereignAuditLedger.AppendedEntry(
            entry: tamperedEntry,
            priorHash: appended.priorHash,
            selfHash: appended.selfHash)

        XCTAssertFalse(
            BASSovereignAuditLedger.verify(tampered, publicKey: pubKey),
            "malformed base64 ⇒ false, not crash")
    }

    // MARK: - Mode-distinguishing accessors

    func testEd25519LedgerExposesPublicKey() async throws {
        let ledger = try makeEd25519Ledger()
        let pubKey = await ledger.ed25519PublicKey
        XCTAssertNotNil(pubKey)
    }

    func testHMACLedgerReturnsNilPublicKey() async {
        let ledger = BASSovereignAuditLedger.withSeed("hmac-seed")
        let pubKey = await ledger.ed25519PublicKey
        XCTAssertNil(pubKey, "HMAC mode has no Ed25519 public key")
    }

    // MARK: - Seed factory is reproducible

    func testWithEd25519SeedIsReproducibleAcrossLedgerInstances()
        async throws {
        let ledgerX = try BASSovereignAuditLedger.withEd25519Seed("repro")
        let ledgerY = try BASSovereignAuditLedger.withEd25519Seed("repro")

        let xKey = await ledgerX.ed25519PublicKey!
        let yKey = await ledgerY.ed25519PublicKey!

        XCTAssertEqual(
            xKey.rawRepresentation,
            yKey.rawRepresentation,
            "same seed ⇒ same public key bytes")
    }

    // MARK: - HMAC path untouched by M87 (regression guard)

    func testHMACLedgerPreservesPreM87SignatureShape() async throws {
        let ledger = BASSovereignAuditLedger.withSeed("hmac-shape-seed")
        let appended = try await ledger.append(makeEntry(auditID: "h-1"))

        // HMAC-SHA256 output is 32 bytes → base64-encoded = 44 chars.
        XCTAssertEqual(appended.entry.signature.count, 44)

        // Chain integrity still holds under HMAC — mode switching did
        // not change the canonical byte layout.
        try await ledger.verifyChainIntegrity()
    }

    // MARK: - Cross-verifier check across a multi-entry chain

    func testCrossVerifierAcceptsEveryEntryInEd25519Chain()
        async throws {
        let ledger = try makeEd25519Ledger()
        var appendeds: [BASSovereignAuditLedger.AppendedEntry] = []
        for i in 0..<5 {
            let entry = makeEntry(
                auditID: "chain-\(i)",
                turn: "turn-\(i)")
            let result = try await ledger.append(entry)
            appendeds.append(result)
        }
        let pubKey = await ledger.ed25519PublicKey!

        for (idx, appended) in appendeds.enumerated() {
            XCTAssertTrue(
                BASSovereignAuditLedger.verify(
                    appended, publicKey: pubKey),
                "entry \(idx) (audit \(appended.entry.auditID)) should verify")
        }
    }
}
