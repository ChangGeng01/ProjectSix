import XCTest
@testable import BASMemory

/// M364 — pin substrate contracts that
/// `QinaoSampleHost --sha256-bench` relies on.
///
/// Sample-host benches are not directly importable. This file
/// pins the substrate primitives the bench composes:
///
///   1. `BASEvolutionLifecycleStructuralFingerprint.sha256Hex(of:)`
///      is publicly available (M364 added it as passthrough to
///      the M341 internal hasher).
///   2. The hasher returns a 64-character lowercase hex string.
///   3. The hasher is deterministic (same input → same output
///      across calls).
///   4. The L13 canonical encoding hashes to the M341 pinned
///      value `9e15d2…`.
final class M364SHA256BenchTests: XCTestCase {

    private let canonicalInput =
        "candidateRegistered|startShadowTrial=" +
        "shadowTrialing;candidateRegistered|" +
        "withdraw=withdrawn;promoted|retract=retracted;" +
        "proposed|registerCandidate=candidateRegistered;" +
        "proposed|withdraw=withdrawn;rejected|" +
        "<terminal>;retracted|<terminal>;shadowTrialing|" +
        "fail=rejected;shadowTrialing|" +
        "finalizeTrial=trialFinalized;shadowTrialing|" +
        "withdraw=withdrawn;trialFinalized|" +
        "fail=rejected;trialFinalized|promote=promoted;" +
        "trialFinalized|withdraw=withdrawn;withdrawn|" +
        "<terminal>"

    func testSHA256HexPassthroughIsPubliclyCallable() {
        let hash = BASEvolutionLifecycleStructuralFingerprint
            .sha256Hex(of: "abc")
        XCTAssertEqual(
            hash,
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func testHashLengthIsSixtyFour() {
        let hash = BASEvolutionLifecycleStructuralFingerprint
            .sha256Hex(of: canonicalInput)
        XCTAssertEqual(hash.count, 64)
    }

    func testHashIsDeterministicAcrossCalls() {
        let a = BASEvolutionLifecycleStructuralFingerprint
            .sha256Hex(of: canonicalInput)
        let b = BASEvolutionLifecycleStructuralFingerprint
            .sha256Hex(of: canonicalInput)
        let c = BASEvolutionLifecycleStructuralFingerprint
            .sha256Hex(of: canonicalInput)
        XCTAssertEqual(a, b)
        XCTAssertEqual(b, c)
    }

    func testCanonicalInputHashesToM341PinnedValue() {
        let hash = BASEvolutionLifecycleStructuralFingerprint
            .sha256Hex(of: canonicalInput)
        XCTAssertEqual(
            hash,
            "9e15d296c25c5b28da42eb5d5ca7d89bf768f407a49cbad21ed0b735eec114f5")
    }
}
