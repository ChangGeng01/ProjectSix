import XCTest
import CryptoKit
@testable import BASSovereign

/// M296.2.x — high-consequence intent gate contract tests.
///
/// Doctrine pinned:
/// - Routine intents always pass — no commit required, even nil
/// - High-consequence + nil commit → false
/// - High-consequence + valid commit + matching digest → true
/// - High-consequence + commit with mismatched digest → false
/// - High-consequence + tampered commit → false (verifier
///   delegated to)
final class BASSovereignHighConsequenceGateTests: XCTestCase {

    // MARK: - Fixtures

    private func makeGate() -> (
        gate: BASSovereignHighConsequenceGate,
        primary: BASSovereignEd25519KeyPair,
        secondary: BASSovereignEd25519KeyPair
    ) {
        let primary = try! BASSovereignEd25519KeyPair
            .fromSeed("hcg-primary-seed")
        let secondary = try! BASSovereignEd25519KeyPair
            .fromSeed("hcg-secondary-seed")
        let verifier = BASSovereignDualKeyVerifier(
            primaryKeyID: "p",
            primaryPublicKey: primary.publicKey,
            secondaryKeyID: "s",
            secondaryPublicKey: secondary.publicKey)
        return (
            BASSovereignHighConsequenceGate(verifier: verifier),
            primary,
            secondary)
    }

    private func makeDigest(
        _ payload: String = "delete-host-version-7"
    ) -> Data {
        Data(SHA256.hash(data: Data(payload.utf8)))
    }

    // MARK: - Routine path

    func test_routineIntent_alwaysPassesNoCommitNeeded() {
        let (gate, _, _) = makeGate()
        XCTAssertTrue(gate.authorize(
            intentClass: .routine,
            intentDigest: makeDigest(),
            commit: nil))
    }

    func test_routineIntent_passesEvenWithIrrelevantCommit()
        throws
    {
        let (gate, primary, secondary) = makeGate()
        let commit = try BASSovereignDualKeySigning.makeCommit(
            intentDigest: makeDigest("anything"),
            primary: primary,
            primaryKeyID: "p",
            secondary: secondary,
            secondaryKeyID: "s")
        // Routine: commit is ignored.
        XCTAssertTrue(gate.authorize(
            intentClass: .routine,
            intentDigest: makeDigest("different"),
            commit: commit))
    }

    // MARK: - High-consequence: missing commit

    func test_highConsequence_nilCommitFails() {
        let (gate, _, _) = makeGate()
        XCTAssertFalse(gate.authorize(
            intentClass: .highConsequence,
            intentDigest: makeDigest(),
            commit: nil))
    }

    // MARK: - High-consequence: digest mismatch

    func test_highConsequence_digestMismatchFails() throws {
        let (gate, primary, secondary) = makeGate()
        let signedDigest = makeDigest("signed-for-this")
        let commit = try BASSovereignDualKeySigning.makeCommit(
            intentDigest: signedDigest,
            primary: primary,
            primaryKeyID: "p",
            secondary: secondary,
            secondaryKeyID: "s")
        // Caller asks gate to authorize a different intent digest.
        XCTAssertFalse(gate.authorize(
            intentClass: .highConsequence,
            intentDigest: makeDigest("a-different-intent"),
            commit: commit))
    }

    // MARK: - High-consequence: happy path

    func test_highConsequence_validCommitPasses() throws {
        let (gate, primary, secondary) = makeGate()
        let digest = makeDigest("ok-intent")
        let commit = try BASSovereignDualKeySigning.makeCommit(
            intentDigest: digest,
            primary: primary,
            primaryKeyID: "p",
            secondary: secondary,
            secondaryKeyID: "s")
        XCTAssertTrue(gate.authorize(
            intentClass: .highConsequence,
            intentDigest: digest,
            commit: commit))
    }

    // MARK: - High-consequence: tampered commit

    func test_highConsequence_tamperedCommitFails() throws {
        let (gate, primary, secondary) = makeGate()
        let digest = makeDigest("ok-intent")
        let validCommit =
            try BASSovereignDualKeySigning.makeCommit(
                intentDigest: digest,
                primary: primary,
                primaryKeyID: "p",
                secondary: secondary,
                secondaryKeyID: "s")
        var badSig = validCommit.primarySignature
        badSig[0] ^= 0xFF
        let tampered = BASSovereignDualKeyCommit(
            intentDigest: validCommit.intentDigest,
            primaryKeyID: validCommit.primaryKeyID,
            primarySignature: badSig,
            secondaryKeyID: validCommit.secondaryKeyID,
            secondarySignature: validCommit.secondarySignature)
        XCTAssertFalse(gate.authorize(
            intentClass: .highConsequence,
            intentDigest: digest,
            commit: tampered))
    }
}
