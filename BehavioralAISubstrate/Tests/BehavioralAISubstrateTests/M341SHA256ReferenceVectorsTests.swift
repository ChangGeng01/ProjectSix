import XCTest
@testable import BASMemory

/// M341 deep-review (chapter 八十一) — verify the pure-Swift SHA-256
/// implementation in `BASEvolutionLifecycleStructuralFingerprintHasher`
/// against the NIST FIPS 180-4 published test vectors AND against
/// Python's `hashlib.sha256` for additional inputs.
///
/// ## Why this exists
///
/// M341 ships `BASEvolutionLifecycleStructuralFingerprint` whose
/// load-bearing field is a SHA-256 hash. The hash is the canonical
/// drift detector — if the hash value drifts, the L13 lifecycle has
/// regressed. But that ONLY works if the hash function actually IS
/// SHA-256 and not something subtly different (a one-bit-off
/// implementation produces deterministic hashes that pass all
/// self-consistency tests but are not actually SHA-256, and the
/// canonical hash baked into the library is wrong).
///
/// This is the same pattern that bit M306 with `String.hashValue`:
/// internal-consistent but not what the audit chain actually needs.
///
/// `M341EvolutionLifecycleFingerprintTests` verifies that
/// `current() == canonical` (self-consistency); this file verifies
/// that the canonical hash equals what `python3 -c "import hashlib;
/// print(hashlib.sha256(b'...').hexdigest())"` would produce. Without
/// this test, a subtle SHA-256 bug could hide indefinitely.
final class M341SHA256ReferenceVectorsTests: XCTestCase {

    private func sha256Hex(_ input: String) -> String {
        BASEvolutionLifecycleStructuralFingerprintHasher
            .sha256Hex(encoding: input)
    }

    /// NIST FIPS 180-4 §B.1 — empty string vector.
    func testEmptyString() {
        XCTAssertEqual(
            sha256Hex(""),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    /// NIST FIPS 180-4 §B.1 — "abc" vector.
    func testAbc() {
        XCTAssertEqual(
            sha256Hex("abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    /// NIST FIPS 180-4 §B.2 — 56-byte boundary vector.
    /// "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
    /// is exactly 56 bytes, which is the SHA-256 padding boundary
    /// (msg.count % 64 == 56 means no extra block needed).
    func testBoundary56Byte() {
        XCTAssertEqual(
            sha256Hex("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
            "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
    }

    /// Single-byte vector — "a" (1 byte). Pads to 64 bytes.
    func testSingleByte() {
        XCTAssertEqual(
            sha256Hex("a"),
            "ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb")
    }

    /// Multi-block vector — 1000-char string. Forces multi-block
    /// processing path.
    func testMultiBlock1000Chars() {
        let input = String(repeating: "a", count: 1000)
        // python3 -c "import hashlib; print(hashlib.sha256(b'a'*1000).hexdigest())"
        XCTAssertEqual(
            sha256Hex(input),
            "41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3")
    }

    /// Boundary vector — exactly 64 bytes (one block). Pads to
    /// 128 bytes.
    func testExactly64Bytes() {
        let input = String(repeating: "x", count: 64)
        // python3 -c "import hashlib; print(hashlib.sha256(b'x'*64).hexdigest())"
        XCTAssertEqual(
            sha256Hex(input),
            "7ce100971f64e7001e8fe5a51973ecdfe1ced42befe7ee8d5fd6219506b5393c")
    }

    /// Boundary vector — exactly 55 bytes (one byte short of the
    /// 56-byte fast-path boundary). Pads to exactly 64 bytes.
    func testExactly55Bytes() {
        let input = String(repeating: "y", count: 55)
        // python3 -c "import hashlib; print(hashlib.sha256(b'y'*55).hexdigest())"
        XCTAssertEqual(
            sha256Hex(input),
            "fb66d40c3bfff05b0d5af8612d0abfbfacc6f5f26c330bc7ad634f1f44bc20ad")
    }

    /// Verify the L13 canonical hash baked into
    /// `BASEvolutionLifecycleStructuralFingerprint.canonical` is
    /// what NIST SHA-256 would produce for the canonical encoding.
    func testL13CanonicalHashMatchesReference() {
        let canonical = BASEvolutionLifecycleStructuralFingerprint
            .canonical
        let encoding = BASEvolutionLifecycleStructuralFingerprint
            .canonicalEncoding(matrix: canonical.transitionMatrix)
        let computed = sha256Hex(encoding)
        XCTAssertEqual(
            computed, canonical.matrixHash,
            "canonical hash baked into BASEvolutionLifecycle" +
            "StructuralFingerprint must equal what the live " +
            "SHA-256 impl computes for the canonical encoding. " +
            "If this fails, either the canonical hash is wrong " +
            "or the SHA-256 impl drifted.")
        // And cross-check: the canonical hash matches what Python
        // hashlib.sha256 produces for the same encoding (verified
        // out-of-band; this is the value committed in M341):
        XCTAssertEqual(
            canonical.matrixHash,
            "9e15d296c25c5b28da42eb5d5ca7d89bf768f407a49cbad21ed0b735eec114f5",
            "canonical hash literal must match what Python " +
            "hashlib.sha256 produced for the canonical encoding " +
            "out-of-band. If this fails, the canonical literal " +
            "drifted from the reference SHA-256.")
    }
}
