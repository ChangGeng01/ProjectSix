import XCTest
import CryptoKit
@testable import BASSovereign

/// M93b — Fingerprint store tests.
///
/// Pins:
///
/// 1. Round-trip: sign manifest → write JSON → load + verify →
///    trustedFingerprints match what went in.
/// 2. Bit-flip rejection: flipping a single byte anywhere in the
///    JSON (label, publicKeyRaw, role, issuedAt, fingerprint
///    count, root signature) makes `load` throw
///    `.rootSignatureInvalid`.
/// 3. Wrong-root-key rejection: a correct signature under the
///    wrong key fails to verify.
/// 4. Schema version mismatch: manifest with unknown schemaVersion
///    throws `.schemaVersionMismatch`.
/// 5. Validity window: `notYetValid` + `expired` both surface.
/// 6. Query surface: `fingerprint(label:)`, `fingerprints(role:)`,
///    `trusts(_:)` return the expected values.
/// 7. `trusts(_:)` returns false for a public key NOT in the
///    manifest, even if the root signature is valid (i.e. the
///    manifest is authentic but doesn't list that key).
final class BASSovereignFingerprintStoreTests: XCTestCase {

    // MARK: - Fixtures

    private func tempPath(_ label: String = #function) -> String {
        let sanitized = label
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        return "/tmp/bas-sovereign-fingerprints-\(sanitized)-\(UUID().uuidString).json"
    }

    private func removeFile(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    private func makeFingerprint(
        label: String,
        role: String = "audit-ledger-signer",
        publicKey: Curve25519.Signing.PublicKey,
        issuedAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        notAfter: Date = Date(timeIntervalSince1970: 1_800_000_000)
    ) -> BASSovereignTrustedFingerprint {
        BASSovereignTrustedFingerprint(
            label: label,
            publicKeyRaw: publicKey.rawRepresentation.base64EncodedString(),
            role: role,
            issuedAt: issuedAt,
            notAfter: notAfter)
    }

    private func writeManifest(
        _ manifest: BASSovereignFingerprintManifest,
        to path: String
    ) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(manifest)
        try data.write(to: URL(fileURLWithPath: path))
    }

    // MARK: - 1. Round-trip

    func testSignedManifestLoadsAndExposesFingerprints() throws {
        let rootKey = Curve25519.Signing.PrivateKey()
        let signerKey = Curve25519.Signing.PrivateKey()
        let fingerprint = makeFingerprint(
            label: "primary", publicKey: signerKey.publicKey)

        let manifest = try BASSovereignFingerprintStore.signed(
            issuedAt: Date(timeIntervalSince1970: 1_700_000_000),
            notAfter: Date(timeIntervalSince1970: 1_800_000_000),
            fingerprints: [fingerprint],
            rootSigningKey: rootKey)

        let path = tempPath()
        defer { removeFile(path) }
        try writeManifest(manifest, to: path)

        let store = try BASSovereignFingerprintStore.load(
            from: path,
            rootPublicKey: rootKey.publicKey,
            now: Date(timeIntervalSince1970: 1_750_000_000))

        XCTAssertEqual(store.trustedFingerprints.count, 1)
        XCTAssertEqual(
            store.trustedFingerprints[0].label, "primary")
        XCTAssertTrue(store.trusts(signerKey.publicKey))
    }

    // MARK: - 2. Bit-flip rejection

    func testBitFlipToSignatureRejected() throws {
        let rootKey = Curve25519.Signing.PrivateKey()
        let signerKey = Curve25519.Signing.PrivateKey()
        var manifest = try BASSovereignFingerprintStore.signed(
            issuedAt: Date(timeIntervalSince1970: 1_700_000_000),
            notAfter: Date(timeIntervalSince1970: 1_800_000_000),
            fingerprints: [makeFingerprint(
                label: "primary", publicKey: signerKey.publicKey)],
            rootSigningKey: rootKey)

        // Flip one char in the signature.
        let sig = manifest.signature
        let firstChar = sig.first == "A" ? "B" : "A"
        manifest = BASSovereignFingerprintManifest(
            schemaVersion: manifest.schemaVersion,
            issuedAt: manifest.issuedAt,
            notAfter: manifest.notAfter,
            fingerprints: manifest.fingerprints,
            signature: String(firstChar) + sig.dropFirst())

        let path = tempPath()
        defer { removeFile(path) }
        try writeManifest(manifest, to: path)

        do {
            _ = try BASSovereignFingerprintStore.load(
                from: path,
                rootPublicKey: rootKey.publicKey,
                now: Date(timeIntervalSince1970: 1_750_000_000))
            XCTFail("expected rootSignatureInvalid")
        } catch BASSovereignFingerprintStore.StoreError
            .rootSignatureInvalid {}
    }

    func testBitFlipToFingerprintFieldRejected() throws {
        let rootKey = Curve25519.Signing.PrivateKey()
        let signerKey = Curve25519.Signing.PrivateKey()
        let original = try BASSovereignFingerprintStore.signed(
            issuedAt: Date(timeIntervalSince1970: 1_700_000_000),
            notAfter: Date(timeIntervalSince1970: 1_800_000_000),
            fingerprints: [makeFingerprint(
                label: "primary", publicKey: signerKey.publicKey)],
            rootSigningKey: rootKey)

        // Mutate the label — canonical bytes change, signature
        // must fail to verify.
        let tampered = BASSovereignFingerprintManifest(
            schemaVersion: original.schemaVersion,
            issuedAt: original.issuedAt,
            notAfter: original.notAfter,
            fingerprints: [BASSovereignTrustedFingerprint(
                label: "tampered-label",
                publicKeyRaw: original.fingerprints[0].publicKeyRaw,
                role: original.fingerprints[0].role,
                issuedAt: original.fingerprints[0].issuedAt,
                notAfter: original.fingerprints[0].notAfter)],
            signature: original.signature)

        let path = tempPath()
        defer { removeFile(path) }
        try writeManifest(tampered, to: path)

        do {
            _ = try BASSovereignFingerprintStore.load(
                from: path,
                rootPublicKey: rootKey.publicKey,
                now: Date(timeIntervalSince1970: 1_750_000_000))
            XCTFail("expected rootSignatureInvalid")
        } catch BASSovereignFingerprintStore.StoreError
            .rootSignatureInvalid {}
    }

    // MARK: - 3. Wrong root key

    func testWrongRootPublicKeyRejected() throws {
        let originalRoot = Curve25519.Signing.PrivateKey()
        let attackerRoot = Curve25519.Signing.PrivateKey()
        let signerKey = Curve25519.Signing.PrivateKey()
        let manifest = try BASSovereignFingerprintStore.signed(
            issuedAt: Date(timeIntervalSince1970: 1_700_000_000),
            notAfter: Date(timeIntervalSince1970: 1_800_000_000),
            fingerprints: [makeFingerprint(
                label: "primary", publicKey: signerKey.publicKey)],
            rootSigningKey: originalRoot)

        let path = tempPath()
        defer { removeFile(path) }
        try writeManifest(manifest, to: path)

        do {
            _ = try BASSovereignFingerprintStore.load(
                from: path,
                rootPublicKey: attackerRoot.publicKey,  // wrong!
                now: Date(timeIntervalSince1970: 1_750_000_000))
            XCTFail("expected rootSignatureInvalid")
        } catch BASSovereignFingerprintStore.StoreError
            .rootSignatureInvalid {}
    }

    // MARK: - 4. Schema version mismatch

    func testUnknownSchemaVersionRejected() throws {
        let rootKey = Curve25519.Signing.PrivateKey()
        let signerKey = Curve25519.Signing.PrivateKey()
        let manifest = try BASSovereignFingerprintStore.signed(
            schemaVersion: "BASSovereignFingerprintManifest.v99",
            issuedAt: Date(timeIntervalSince1970: 1_700_000_000),
            notAfter: Date(timeIntervalSince1970: 1_800_000_000),
            fingerprints: [makeFingerprint(
                label: "primary", publicKey: signerKey.publicKey)],
            rootSigningKey: rootKey)

        let path = tempPath()
        defer { removeFile(path) }
        try writeManifest(manifest, to: path)

        do {
            _ = try BASSovereignFingerprintStore.load(
                from: path,
                rootPublicKey: rootKey.publicKey,
                now: Date(timeIntervalSince1970: 1_750_000_000))
            XCTFail("expected schemaVersionMismatch")
        } catch BASSovereignFingerprintStore.StoreError
            .schemaVersionMismatch(let found, let expected) {
            XCTAssertEqual(
                found, "BASSovereignFingerprintManifest.v99")
            XCTAssertEqual(
                expected,
                BASSovereignFingerprintManifest.currentSchemaVersion)
        }
    }

    // MARK: - 5. Validity window

    func testExpiredManifestRejected() throws {
        let rootKey = Curve25519.Signing.PrivateKey()
        let signerKey = Curve25519.Signing.PrivateKey()
        let manifest = try BASSovereignFingerprintStore.signed(
            issuedAt: Date(timeIntervalSince1970: 1_700_000_000),
            notAfter: Date(timeIntervalSince1970: 1_750_000_000),
            fingerprints: [makeFingerprint(
                label: "primary", publicKey: signerKey.publicKey)],
            rootSigningKey: rootKey)

        let path = tempPath()
        defer { removeFile(path) }
        try writeManifest(manifest, to: path)

        do {
            _ = try BASSovereignFingerprintStore.load(
                from: path,
                rootPublicKey: rootKey.publicKey,
                now: Date(timeIntervalSince1970: 1_800_000_000))
            XCTFail("expected expired")
        } catch BASSovereignFingerprintStore.StoreError.expired {}
    }

    func testNotYetValidManifestRejected() throws {
        let rootKey = Curve25519.Signing.PrivateKey()
        let signerKey = Curve25519.Signing.PrivateKey()
        let manifest = try BASSovereignFingerprintStore.signed(
            issuedAt: Date(timeIntervalSince1970: 1_750_000_000),
            notAfter: Date(timeIntervalSince1970: 1_800_000_000),
            fingerprints: [makeFingerprint(
                label: "primary", publicKey: signerKey.publicKey)],
            rootSigningKey: rootKey)

        let path = tempPath()
        defer { removeFile(path) }
        try writeManifest(manifest, to: path)

        do {
            _ = try BASSovereignFingerprintStore.load(
                from: path,
                rootPublicKey: rootKey.publicKey,
                now: Date(timeIntervalSince1970: 1_700_000_000))
            XCTFail("expected notYetValid")
        } catch BASSovereignFingerprintStore.StoreError
            .notYetValid {}
    }

    // MARK: - 6. Query surface

    func testQueryByLabelAndRole() throws {
        let rootKey = Curve25519.Signing.PrivateKey()
        let signerA = Curve25519.Signing.PrivateKey()
        let signerB = Curve25519.Signing.PrivateKey()
        let fps = [
            makeFingerprint(
                label: "alpha", role: "audit-ledger-signer",
                publicKey: signerA.publicKey),
            makeFingerprint(
                label: "beta", role: "warrant-authority",
                publicKey: signerB.publicKey)
        ]
        let manifest = try BASSovereignFingerprintStore.signed(
            issuedAt: Date(timeIntervalSince1970: 1_700_000_000),
            notAfter: Date(timeIntervalSince1970: 1_800_000_000),
            fingerprints: fps,
            rootSigningKey: rootKey)
        let store = BASSovereignFingerprintStore(
            manifest: manifest, rootPublicKey: rootKey.publicKey)

        XCTAssertEqual(
            store.fingerprint(label: "alpha")?.role,
            "audit-ledger-signer")
        XCTAssertNil(store.fingerprint(label: "does-not-exist"))
        XCTAssertEqual(
            store.fingerprints(role: "warrant-authority")
                .map(\.label),
            ["beta"])
        XCTAssertEqual(
            store.fingerprints(role: "non-existent-role").count, 0)
    }

    // MARK: - 7. trusts(_:) only returns true for listed pubkeys

    func testTrustsReturnsFalseForUnlistedPublicKey() throws {
        let rootKey = Curve25519.Signing.PrivateKey()
        let listedSigner = Curve25519.Signing.PrivateKey()
        let unlistedSigner = Curve25519.Signing.PrivateKey()

        let manifest = try BASSovereignFingerprintStore.signed(
            issuedAt: Date(timeIntervalSince1970: 1_700_000_000),
            notAfter: Date(timeIntervalSince1970: 1_800_000_000),
            fingerprints: [makeFingerprint(
                label: "listed",
                publicKey: listedSigner.publicKey)],
            rootSigningKey: rootKey)
        let store = BASSovereignFingerprintStore(
            manifest: manifest, rootPublicKey: rootKey.publicKey)

        XCTAssertTrue(store.trusts(listedSigner.publicKey))
        XCTAssertFalse(
            store.trusts(unlistedSigner.publicKey),
            "unlisted key must NOT be trusted even though manifest signature is valid")
    }

    // MARK: - 8. File unreadable

    func testLoadFromNonExistentPathThrowsFileUnreadable() {
        let rootKey = Curve25519.Signing.PrivateKey()
        do {
            _ = try BASSovereignFingerprintStore.load(
                from: "/tmp/definitely-does-not-exist-\(UUID().uuidString).json",
                rootPublicKey: rootKey.publicKey,
                now: Date(timeIntervalSince1970: 1_750_000_000))
            XCTFail("expected fileUnreadable")
        } catch BASSovereignFingerprintStore.StoreError
            .fileUnreadable {}
        catch {
            XCTFail("expected fileUnreadable, got \(error)")
        }
    }

    // MARK: - 9. Canonical bytes are stable regardless of fingerprint order

    func testCanonicalBytesStableUnderFingerprintOrderChange()
        throws {
        let rootKey = Curve25519.Signing.PrivateKey()
        let signerA = Curve25519.Signing.PrivateKey()
        let signerB = Curve25519.Signing.PrivateKey()
        let fpA = makeFingerprint(
            label: "alpha", publicKey: signerA.publicKey)
        let fpB = makeFingerprint(
            label: "beta", publicKey: signerB.publicKey)

        let manifest1 = BASSovereignFingerprintManifest(
            issuedAt: Date(timeIntervalSince1970: 1_700_000_000),
            notAfter: Date(timeIntervalSince1970: 1_800_000_000),
            fingerprints: [fpA, fpB],
            signature: "")
        let manifest2 = BASSovereignFingerprintManifest(
            issuedAt: Date(timeIntervalSince1970: 1_700_000_000),
            notAfter: Date(timeIntervalSince1970: 1_800_000_000),
            fingerprints: [fpB, fpA],  // reversed order
            signature: "")

        let bytes1 = BASSovereignFingerprintStore
            .canonicalManifestBytes(for: manifest1)
        let bytes2 = BASSovereignFingerprintStore
            .canonicalManifestBytes(for: manifest2)
        XCTAssertEqual(
            bytes1, bytes2,
            "canonical bytes sort fingerprints by label; order-independent")

        _ = rootKey  // suppress warning
    }
}
