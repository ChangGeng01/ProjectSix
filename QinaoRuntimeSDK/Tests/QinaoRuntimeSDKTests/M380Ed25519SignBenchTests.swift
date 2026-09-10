import XCTest
import CryptoKit
@testable import BASSovereign

/// M380 — pin substrate contracts that
/// `QinaoSampleHost --ed25519-sign-bench` relies on.
///
/// The bench is a diagnostic for chapter 八十四.6 Open Opportunity
/// C (audit-ledger outlier rate investigation). Sample-host
/// benches are not directly importable, so this file pins the
/// substrate primitives the bench composes:
///
///   1. `BASSovereignEd25519KeyPair.fromSeed(_:)` produces a
///      working key pair from a deterministic seed.
///   2. `keyPair.privateKey.signature(for:)` produces a non-empty
///      signature.
///   3. The same seed produces the same private key (deterministic).
///   4. Different inputs produce different signatures.
///   5. CryptoKit's `isValidSignature(_:for:)` accepts our own
///      output (round-trip integrity).
final class M380Ed25519SignBenchTests: XCTestCase {

    func testFromSeedProducesWorkingKeyPair() throws {
        let keyPair = try BASSovereignEd25519KeyPair
            .fromSeed("m380-test-seed")
        let payload = Data("test payload".utf8)
        let signature = try keyPair.privateKey
            .signature(for: payload)
        XCTAssertGreaterThan(signature.count, 0)
    }

    func testSameSeedProducesSamePrivateKey() throws {
        let kp1 = try BASSovereignEd25519KeyPair
            .fromSeed("deterministic-seed")
        let kp2 = try BASSovereignEd25519KeyPair
            .fromSeed("deterministic-seed")
        // Curve25519.Signing.PrivateKey raw representation
        // should be byte-equal for the same seed.
        XCTAssertEqual(
            kp1.privateKey.rawRepresentation,
            kp2.privateKey.rawRepresentation)
    }

    func testDifferentInputsProduceDifferentSignatures()
        throws
    {
        let keyPair = try BASSovereignEd25519KeyPair
            .fromSeed("m380-test-seed")
        let sig1 = try keyPair.privateKey
            .signature(for: Data("input-A".utf8))
        let sig2 = try keyPair.privateKey
            .signature(for: Data("input-B".utf8))
        XCTAssertNotEqual(sig1, sig2)
    }

    func testRoundTripVerificationAcceptsOwnSignature()
        throws
    {
        let keyPair = try BASSovereignEd25519KeyPair
            .fromSeed("m380-test-seed")
        let payload = Data("verify me".utf8)
        let signature = try keyPair.privateKey
            .signature(for: payload)
        XCTAssertTrue(
            keyPair.publicKey.isValidSignature(
                signature, for: payload),
            "Ed25519 signing should produce a signature " +
            "that the matching public key validates.")
    }
}
