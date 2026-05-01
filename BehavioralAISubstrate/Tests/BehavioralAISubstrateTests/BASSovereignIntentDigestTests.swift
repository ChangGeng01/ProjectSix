import XCTest
import CryptoKit
@testable import BASSovereign

/// M296.2.z — intent digest helper contract tests.
///
/// Doctrine pinned:
/// - SHA-256 size = 32 bytes
/// - Same input → same digest (deterministic)
/// - Different payload → different digest
/// - Different intent name → different digest (with same payload)
/// - Bare and name-bound digests are different (canonical
///   separator means they can't collide)
/// - Convenience overloads agree with their primitive forms
final class BASSovereignIntentDigestTests: XCTestCase {

    // MARK: - SHA-256 sanity

    func test_bareDigestIs32Bytes() {
        let digest = BASSovereignIntentDigest.compute(
            payload: Data("hello".utf8))
        XCTAssertEqual(digest.count, 32)
    }

    func test_nameBoundDigestIs32Bytes() {
        let digest = BASSovereignIntentDigest.compute(
            intentName: "delete-host-version-7",
            payload: Data("payload".utf8))
        XCTAssertEqual(digest.count, 32)
    }

    // MARK: - Determinism

    func test_bareDigestDeterministic() {
        let a = BASSovereignIntentDigest.compute(
            payload: Data("x".utf8))
        let b = BASSovereignIntentDigest.compute(
            payload: Data("x".utf8))
        XCTAssertEqual(a, b)
    }

    func test_nameBoundDigestDeterministic() {
        let a = BASSovereignIntentDigest.compute(
            intentName: "act",
            payload: Data("p".utf8))
        let b = BASSovereignIntentDigest.compute(
            intentName: "act",
            payload: Data("p".utf8))
        XCTAssertEqual(a, b)
    }

    // MARK: - Distinguishing properties

    func test_differentPayloadYieldsDifferentDigest() {
        let a = BASSovereignIntentDigest.compute(
            payload: Data("a".utf8))
        let b = BASSovereignIntentDigest.compute(
            payload: Data("b".utf8))
        XCTAssertNotEqual(a, b)
    }

    func test_differentIntentNameYieldsDifferentDigest() {
        let payload = Data("same-payload".utf8)
        let a = BASSovereignIntentDigest.compute(
            intentName: "delete-host-version",
            payload: payload)
        let b = BASSovereignIntentDigest.compute(
            intentName: "freeze-sovereign-policy",
            payload: payload)
        XCTAssertNotEqual(a, b)
    }

    func test_bareAndNameBoundDigestsAreDifferent() {
        // Even when caller might think they overlap, the 0x00
        // separator + name prefix guarantees different bytes
        // get hashed.
        let payload = Data("payload".utf8)
        let bare = BASSovereignIntentDigest.compute(
            payload: payload)
        let nameBound = BASSovereignIntentDigest.compute(
            intentName: "",
            payload: payload)
        XCTAssertNotEqual(bare, nameBound)
    }

    // MARK: - Convenience overloads

    func test_stringPayloadConvenienceMatchesData() {
        let viaString = BASSovereignIntentDigest.compute(
            payload: "abc")
        let viaData = BASSovereignIntentDigest.compute(
            payload: Data("abc".utf8))
        XCTAssertEqual(viaString, viaData)
    }

    func test_stringPayloadNameBoundConvenienceMatchesData() {
        let viaString = BASSovereignIntentDigest.compute(
            intentName: "act",
            payload: "abc")
        let viaData = BASSovereignIntentDigest.compute(
            intentName: "act",
            payload: Data("abc".utf8))
        XCTAssertEqual(viaString, viaData)
    }

    // MARK: - Round-trip with dual-key sign + verify

    func test_digestUsableForDualKeyCommit() throws {
        let primary = try BASSovereignEd25519KeyPair.fromSeed(
            "ix-primary")
        let secondary = try BASSovereignEd25519KeyPair.fromSeed(
            "ix-secondary")
        let digest = BASSovereignIntentDigest.compute(
            intentName: "delete-host-version",
            payload: "host-7")
        let commit = try BASSovereignDualKeySigning.makeCommit(
            intentDigest: digest,
            primary: primary,
            primaryKeyID: "p",
            secondary: secondary,
            secondaryKeyID: "s")
        let verifier = BASSovereignDualKeyVerifier(
            primaryKeyID: "p",
            primaryPublicKey: primary.publicKey,
            secondaryKeyID: "s",
            secondaryPublicKey: secondary.publicKey)
        XCTAssertTrue(verifier.verify(commit))
    }
}
