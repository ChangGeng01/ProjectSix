import XCTest
import CryptoKit
@testable import BASSovereign

/// M296.2.y — typed gated-intent bundle contract tests.
///
/// Doctrine pinned:
/// - Routine intent → validator returns true regardless of commit
/// - High-consequence + valid commit → true
/// - High-consequence + nil commit → false
/// - High-consequence + tampered commit → false (delegates to gate)
/// - High-consequence + digest mismatch → false
/// - Codable round-trip preserves the bundle
final class BASSovereignGatedIntentTests: XCTestCase {

    private func makeValidator() -> (
        validator: BASSovereignGatedIntentValidator,
        primary: BASSovereignEd25519KeyPair,
        secondary: BASSovereignEd25519KeyPair
    ) {
        let primary = try! BASSovereignEd25519KeyPair
            .fromSeed("gi-primary")
        let secondary = try! BASSovereignEd25519KeyPair
            .fromSeed("gi-secondary")
        let verifier = BASSovereignDualKeyVerifier(
            primaryKeyID: "p",
            primaryPublicKey: primary.publicKey,
            secondaryKeyID: "s",
            secondaryPublicKey: secondary.publicKey)
        let gate = BASSovereignHighConsequenceGate(
            verifier: verifier)
        return (
            BASSovereignGatedIntentValidator(gate: gate),
            primary,
            secondary)
    }

    private func makeDigest(
        _ name: String, _ payload: String
    ) -> Data {
        BASSovereignIntentDigest.compute(
            intentName: name, payload: payload)
    }

    func test_routineIntent_passesEvenWithNilCommit() {
        let (v, _, _) = makeValidator()
        let intent = BASSovereignGatedIntent(
            intentName: "log-event",
            intentClass: .routine,
            intentDigest: makeDigest("log-event", "data"),
            dualKeyCommit: nil)
        XCTAssertTrue(v.authorize(intent))
    }

    func test_highConsequence_validCommitPasses() throws {
        let (v, primary, secondary) = makeValidator()
        let digest = makeDigest("delete-host-version", "h7")
        let commit = try BASSovereignDualKeySigning.makeCommit(
            intentDigest: digest,
            primary: primary,
            primaryKeyID: "p",
            secondary: secondary,
            secondaryKeyID: "s")
        let intent = BASSovereignGatedIntent(
            intentName: "delete-host-version",
            intentClass: .highConsequence,
            intentDigest: digest,
            dualKeyCommit: commit)
        XCTAssertTrue(v.authorize(intent))
    }

    func test_highConsequence_nilCommitFails() {
        let (v, _, _) = makeValidator()
        let intent = BASSovereignGatedIntent(
            intentName: "delete-host-version",
            intentClass: .highConsequence,
            intentDigest: makeDigest(
                "delete-host-version", "h7"),
            dualKeyCommit: nil)
        XCTAssertFalse(v.authorize(intent))
    }

    func test_highConsequence_digestMismatchFails() throws {
        let (v, primary, secondary) = makeValidator()
        let signedDigest = makeDigest(
            "delete-host-version", "h7")
        let commit = try BASSovereignDualKeySigning.makeCommit(
            intentDigest: signedDigest,
            primary: primary,
            primaryKeyID: "p",
            secondary: secondary,
            secondaryKeyID: "s")
        // Intent claims a different digest from what was signed.
        let intent = BASSovereignGatedIntent(
            intentName: "delete-host-version",
            intentClass: .highConsequence,
            intentDigest: makeDigest(
                "delete-host-version", "h99"),
            dualKeyCommit: commit)
        XCTAssertFalse(v.authorize(intent))
    }

    func test_highConsequence_tamperedCommitFails() throws {
        let (v, primary, secondary) = makeValidator()
        let digest = makeDigest("delete-host-version", "h7")
        let validCommit =
            try BASSovereignDualKeySigning.makeCommit(
                intentDigest: digest,
                primary: primary,
                primaryKeyID: "p",
                secondary: secondary,
                secondaryKeyID: "s")
        var bad = validCommit.primarySignature
        bad[0] ^= 0xFF
        let tampered = BASSovereignDualKeyCommit(
            intentDigest: validCommit.intentDigest,
            primaryKeyID: validCommit.primaryKeyID,
            primarySignature: bad,
            secondaryKeyID: validCommit.secondaryKeyID,
            secondarySignature: validCommit.secondarySignature)
        let intent = BASSovereignGatedIntent(
            intentName: "delete-host-version",
            intentClass: .highConsequence,
            intentDigest: digest,
            dualKeyCommit: tampered)
        XCTAssertFalse(v.authorize(intent))
    }

    func test_codableRoundTrip() throws {
        let (_, primary, secondary) = makeValidator()
        let digest = makeDigest("act", "p")
        let commit = try BASSovereignDualKeySigning.makeCommit(
            intentDigest: digest,
            primary: primary,
            primaryKeyID: "p",
            secondary: secondary,
            secondaryKeyID: "s")
        let original = BASSovereignGatedIntent(
            intentName: "act",
            intentClass: .highConsequence,
            intentDigest: digest,
            dualKeyCommit: commit)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASSovereignGatedIntent.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
