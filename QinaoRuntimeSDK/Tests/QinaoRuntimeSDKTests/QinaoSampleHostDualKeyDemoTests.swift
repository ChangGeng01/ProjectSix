import XCTest
import CryptoKit
@testable import BASSovereign

/// M328 — pin substrate contracts that
/// `QinaoSampleHost --dual-key-demo` relies on. Demo lives in
/// the executable target so XCTest can't import it directly;
/// these tests pin the BASSovereign primitives the demo
/// composes, so any breaking change in the gate / verifier /
/// signing helpers surfaces here as a Qinao-side test failure.
///
/// What this file pins:
///
///   1. `BASSovereignIntentClass` exposes the two cases the
///      demo uses (`.routine` / `.highConsequence`) with
///      stable raw values.
///   2. `BASSovereignHighConsequenceGate.authorize(...)`
///      satisfies the 5 scenarios the demo asserts:
///        - routine + nil commit → true
///        - high-conseq + nil commit → false
///        - high-conseq + valid commit → true
///        - high-conseq + wrong-digest commit → false
///        - high-conseq + tampered signature → false
///   3. `BASSovereignDualKeySigning.makeCommit(...)` rejects
///      same-key-ID for both slots (the *identity* check
///      beyond crypto verification).
final class QinaoSampleHostDualKeyDemoTests: XCTestCase {

    // MARK: - 1. Intent class enum

    func testIntentClassExposesTwoStableCases() {
        let routine: BASSovereignIntentClass = .routine
        let highConseq: BASSovereignIntentClass =
            .highConsequence
        XCTAssertNotEqual(routine, highConseq)
        // Demo banner uses raw values; pin them.
        XCTAssertEqual(routine.rawValue, "routine")
        XCTAssertEqual(
            highConseq.rawValue, "highConsequence")
    }

    // MARK: - Fixture helper

    private func makeFixture() -> (
        primary: BASSovereignEd25519KeyPair,
        secondary: BASSovereignEd25519KeyPair,
        verifier: BASSovereignDualKeyVerifier,
        gate: BASSovereignHighConsequenceGate
    ) {
        let primary = BASSovereignEd25519KeyPair.generate()
        let secondary = BASSovereignEd25519KeyPair.generate()
        let verifier = BASSovereignDualKeyVerifier(
            primaryKeyID: "test-primary",
            primaryPublicKey: primary.publicKey,
            secondaryKeyID: "test-secondary",
            secondaryPublicKey: secondary.publicKey)
        let gate = BASSovereignHighConsequenceGate(
            verifier: verifier)
        return (primary, secondary, verifier, gate)
    }

    private func digest(_ s: String) -> Data {
        Data(SHA256.hash(data: Data(s.utf8)))
    }

    // MARK: - 2a. Routine + nil commit → pass

    func testRoutineWithNilCommitPasses() {
        let f = makeFixture()
        let result = f.gate.authorize(
            intentClass: .routine,
            intentDigest: digest("routine"),
            commit: nil)
        XCTAssertTrue(result)
    }

    // MARK: - 2b. High-conseq + nil commit → fail

    func testHighConseqWithNilCommitFails() {
        let f = makeFixture()
        let result = f.gate.authorize(
            intentClass: .highConsequence,
            intentDigest: digest("rotate-key"),
            commit: nil)
        XCTAssertFalse(result)
    }

    // MARK: - 2c. High-conseq + valid commit → pass

    func testHighConseqWithValidCommitPasses() throws {
        let f = makeFixture()
        let intentDigest = digest("rotate-key")
        let commit = try BASSovereignDualKeySigning
            .makeCommit(
                intentDigest: intentDigest,
                primary: f.primary,
                primaryKeyID: "test-primary",
                secondary: f.secondary,
                secondaryKeyID: "test-secondary")
        let result = f.gate.authorize(
            intentClass: .highConsequence,
            intentDigest: intentDigest,
            commit: commit)
        XCTAssertTrue(result)
    }

    // MARK: - 2d. High-conseq + wrong-digest commit → fail

    func testHighConseqWithWrongDigestFails() throws {
        let f = makeFixture()
        let intentA = digest("rotate-key")
        let intentB = digest("bake-cake")
        // commit covers intentB but gate is asked about intentA
        let commit = try BASSovereignDualKeySigning
            .makeCommit(
                intentDigest: intentB,
                primary: f.primary,
                primaryKeyID: "test-primary",
                secondary: f.secondary,
                secondaryKeyID: "test-secondary")
        let result = f.gate.authorize(
            intentClass: .highConsequence,
            intentDigest: intentA,
            commit: commit)
        XCTAssertFalse(result)
    }

    // MARK: - 2e. High-conseq + tampered signature → fail

    func testHighConseqWithTamperedSignatureFails()
        throws
    {
        let f = makeFixture()
        let intent = digest("rotate-key")
        let valid = try BASSovereignDualKeySigning
            .makeCommit(
                intentDigest: intent,
                primary: f.primary,
                primaryKeyID: "test-primary",
                secondary: f.secondary,
                secondaryKeyID: "test-secondary")
        var tamperedSig = valid.primarySignature
        let lastIdx = tamperedSig.count - 1
        tamperedSig[lastIdx] ^= 0xFF
        let tampered = BASSovereignDualKeyCommit(
            intentDigest: intent,
            primaryKeyID: "test-primary",
            primarySignature: tamperedSig,
            secondaryKeyID: "test-secondary",
            secondarySignature: valid.secondarySignature)
        let result = f.gate.authorize(
            intentClass: .highConsequence,
            intentDigest: intent,
            commit: tampered)
        XCTAssertFalse(result)
    }

    // MARK: - 3. SameKeyID check

    func testMakeCommitThrowsOnSameKeyIDForBothSlots() {
        let kp = BASSovereignEd25519KeyPair.generate()
        XCTAssertThrowsError(
            try BASSovereignDualKeySigning.makeCommit(
                intentDigest: digest("test"),
                primary: kp,
                primaryKeyID: "same-id",
                secondary: kp,
                secondaryKeyID: "same-id"))
        { error in
            XCTAssertEqual(
                error
                    as? BASSovereignDualKeySigning
                        .SigningError,
                .sameKeyIDForBothSlots("same-id"))
        }
    }
}
