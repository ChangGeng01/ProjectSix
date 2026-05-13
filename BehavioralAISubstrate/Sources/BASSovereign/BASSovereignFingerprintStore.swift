import Foundation
import CryptoKit

/// M93b — Trust-anchor fingerprint store for the sovereign subsystem.
///
/// ## Why this exists
///
/// Cross-process audit verifiers (M87 static verify + M91 SQLite
/// persistence) need to know **which public keys to trust**.
/// Hard-coding a single pubkey into every verifier is brittle: key
/// rotation, multi-signer deployments, revocation — all impossible.
///
/// The whitepaper's solution is a **fingerprint manifest** — a
/// signed JSON document listing pinned Ed25519 public keys plus
/// metadata (label, issuedAt, notAfter, role). The manifest itself
/// is signed by a root key whose pubkey is compiled into the
/// verifier binary. Hosts load the manifest, verify its root
/// signature, then use the inner list as the trust anchor for
/// ledger entry verification.
///
/// `BASSovereignFingerprintStore` is the Swift side of that
/// protocol: load manifest from disk, verify the outer signature
/// against a supplied root public key, expose the inner
/// `trustedFingerprints[]` for downstream callers.
///
/// ## Manifest format (v1)
///
/// ```json
/// {
///   "schemaVersion": "BASSovereignFingerprintManifest.v1",
///   "issuedAt": 1729801200000,
///   "notAfter": 1761337200000,
///   "fingerprints": [
///     {
///       "label": "qinao-sovereign-primary",
///       "publicKeyRaw": "<base64 32 bytes>",
///       "role": "audit-ledger-signer",
///       "issuedAt": 1729801200000,
///       "notAfter": 1761337200000
///     }
///   ],
///   "signature": "<base64 Ed25519 signature over canonical payload>"
/// }
/// ```
///
/// The `signature` field covers every other field of the manifest
/// encoded in canonical byte form (see
/// `canonicalManifestBytes(for:)` below). Any single-byte tamper
/// to any field invalidates the signature. That's the integrity
/// guarantee this store ships.
///
/// ## Non-Darwin
///
/// This file uses only Foundation + CryptoKit. It works identically
/// on Darwin (iOS / macOS) and Linux SPM builds. No platform guard
/// needed.

// MARK: - Manifest schema

/// One entry in the fingerprint manifest. Represents one trusted
/// public key for a specified role.
public struct BASSovereignTrustedFingerprint:
    Sendable, Equatable, Codable, Hashable {
    public let label: String
    /// Raw 32-byte Ed25519 public key, base64-encoded for JSON
    /// portability. Decoded back to `Curve25519.Signing.PublicKey`
    /// via `publicKey()` below.
    public let publicKeyRaw: String
    /// Role tag — e.g. `"audit-ledger-signer"`,
    /// `"warrant-authority"`. Hosts key enforcement policy on this.
    public let role: String
    public let issuedAt: Date
    public let notAfter: Date

    public init(
        label: String,
        publicKeyRaw: String,
        role: String,
        issuedAt: Date,
        notAfter: Date
    ) {
        self.label = label
        self.publicKeyRaw = publicKeyRaw
        self.role = role
        self.issuedAt = issuedAt
        self.notAfter = notAfter
    }

    /// Decode the stored base64 bytes back into a CryptoKit
    /// `PublicKey`. Returns nil when the base64 is malformed or the
    /// resulting bytes are not a valid Ed25519 public key (wrong
    /// length or rejected by CryptoKit).
    public func publicKey() -> Curve25519.Signing.PublicKey? {
        guard let data = Data(base64Encoded: publicKeyRaw) else {
            return nil
        }
        return try? Curve25519.Signing.PublicKey(
            rawRepresentation: data)
    }
}

/// Full fingerprint manifest.
///
/// The `signature` field is a base64 Ed25519 signature over the
/// canonical bytes of the manifest payload (every field EXCEPT
/// `signature` itself, encoded in the canonical byte layout
/// documented in `BASSovereignFingerprintStore.canonicalManifestBytes`).
public struct BASSovereignFingerprintManifest:
    Sendable, Equatable, Codable {
    public static let currentSchemaVersion =
        "BASSovereignFingerprintManifest.v1"

    public let schemaVersion: String
    public let issuedAt: Date
    public let notAfter: Date
    public let fingerprints: [BASSovereignTrustedFingerprint]
    public let signature: String

    public init(
        schemaVersion: String = currentSchemaVersion,
        issuedAt: Date,
        notAfter: Date,
        fingerprints: [BASSovereignTrustedFingerprint],
        signature: String
    ) {
        self.schemaVersion = schemaVersion
        self.issuedAt = issuedAt
        self.notAfter = notAfter
        self.fingerprints = fingerprints
        self.signature = signature
    }
}

// MARK: - Store

/// Loads and verifies a fingerprint manifest. Once verified,
/// exposes the inner `trustedFingerprints[]` as a value-type
/// snapshot for downstream trust checks.
public struct BASSovereignFingerprintStore: Sendable {

    public enum StoreError:
        Error, Equatable, Sendable, Codable
    {
        /// File at the given path could not be read.
        case fileUnreadable(path: String, underlying: String)
        /// JSON at the path decoded but is not a valid
        /// `BASSovereignFingerprintManifest` (schema mismatch).
        case manifestMalformed(reason: String)
        /// Manifest schemaVersion does not match what this build
        /// knows how to verify.
        case schemaVersionMismatch(found: String, expected: String)
        /// Signature on the manifest did not verify under the
        /// supplied root public key. The critical trust failure:
        /// reject the whole manifest.
        case rootSignatureInvalid
        /// Manifest is expired (now > notAfter).
        case expired(notAfter: Date, now: Date)
        /// Manifest is not yet valid (now < issuedAt).
        case notYetValid(issuedAt: Date, now: Date)
    }

    public let manifest: BASSovereignFingerprintManifest
    public let rootPublicKey: Curve25519.Signing.PublicKey

    /// Direct initializer — use when the manifest is already in
    /// memory and already verified. Most call sites should use
    /// `load(from:rootPublicKey:now:)` instead.
    public init(
        manifest: BASSovereignFingerprintManifest,
        rootPublicKey: Curve25519.Signing.PublicKey
    ) {
        self.manifest = manifest
        self.rootPublicKey = rootPublicKey
    }

    /// Load + verify a fingerprint manifest from disk.
    ///
    /// Steps:
    /// 1. Read bytes from `path`.
    /// 2. Decode JSON → `BASSovereignFingerprintManifest`.
    /// 3. Verify `schemaVersion` matches current.
    /// 4. Compute canonical bytes + verify signature under
    ///    `rootPublicKey`.
    /// 5. Check `issuedAt <= now <= notAfter`.
    /// 6. Return an initialized store.
    ///
    /// `now` defaults to current wall-clock; override for tests.
    public static func load(
        from path: String,
        rootPublicKey: Curve25519.Signing.PublicKey,
        now: Date = Date()
    ) throws -> BASSovereignFingerprintStore {
        let url = URL(fileURLWithPath: path)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw StoreError.fileUnreadable(
                path: path,
                underlying: "\(error)")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let manifest: BASSovereignFingerprintManifest
        do {
            manifest = try decoder.decode(
                BASSovereignFingerprintManifest.self,
                from: data)
        } catch {
            throw StoreError.manifestMalformed(
                reason: "\(error)")
        }

        guard manifest.schemaVersion
            == BASSovereignFingerprintManifest.currentSchemaVersion
        else {
            throw StoreError.schemaVersionMismatch(
                found: manifest.schemaVersion,
                expected: BASSovereignFingerprintManifest
                    .currentSchemaVersion)
        }

        // Verify root signature.
        guard let sigBytes = Data(
            base64Encoded: manifest.signature)
        else {
            throw StoreError.rootSignatureInvalid
        }
        let canonical = canonicalManifestBytes(for: manifest)
        guard rootPublicKey.isValidSignature(
            sigBytes, for: canonical)
        else {
            throw StoreError.rootSignatureInvalid
        }

        // Validity window.
        if now < manifest.issuedAt {
            throw StoreError.notYetValid(
                issuedAt: manifest.issuedAt, now: now)
        }
        if now > manifest.notAfter {
            throw StoreError.expired(
                notAfter: manifest.notAfter, now: now)
        }

        return BASSovereignFingerprintStore(
            manifest: manifest,
            rootPublicKey: rootPublicKey)
    }

    // MARK: - Query

    /// Every trusted fingerprint the manifest carries.
    public var trustedFingerprints:
        [BASSovereignTrustedFingerprint]
    { manifest.fingerprints }

    /// Look up a fingerprint by its `label`. Returns nil when no
    /// fingerprint with that label exists in the manifest.
    public func fingerprint(
        label: String
    ) -> BASSovereignTrustedFingerprint? {
        manifest.fingerprints.first { $0.label == label }
    }

    /// Return every fingerprint whose `role` matches. Empty array
    /// when no fingerprint carries that role.
    public func fingerprints(
        role: String
    ) -> [BASSovereignTrustedFingerprint] {
        manifest.fingerprints.filter { $0.role == role }
    }

    /// True when the manifest carries a fingerprint whose
    /// `publicKeyRaw` decodes to bytes byte-equal to `publicKey`'s
    /// raw representation. This is the "should I trust this ledger
    /// signer?" query.
    public func trusts(
        _ publicKey: Curve25519.Signing.PublicKey
    ) -> Bool {
        let target = publicKey.rawRepresentation
        for fp in manifest.fingerprints {
            guard let candidate = Data(
                base64Encoded: fp.publicKeyRaw)
            else { continue }
            if candidate == target { return true }
        }
        return false
    }

    // MARK: - Canonical bytes + root-signature helper

    /// Canonical byte layout for manifest signing. Any change is a
    /// breaking schema-version bump.
    ///
    /// Fields included (in order):
    ///   - schemaVersion
    ///   - issuedAt (ms since epoch)
    ///   - notAfter (ms since epoch)
    ///   - for each fingerprint, sorted by label:
    ///     label | publicKeyRaw | role | issuedAt_ms | notAfter_ms
    ///
    /// All joined by `|`. Utf-8 encoded.
    public static func canonicalManifestBytes(
        for manifest: BASSovereignFingerprintManifest
    ) -> Data {
        var parts: [String] = [
            manifest.schemaVersion,
            String(Int(
                manifest.issuedAt.timeIntervalSince1970 * 1000)),
            String(Int(
                manifest.notAfter.timeIntervalSince1970 * 1000))
        ]
        let sortedFingerprints = manifest.fingerprints
            .sorted { $0.label < $1.label }
        for fp in sortedFingerprints {
            parts.append(fp.label)
            parts.append(fp.publicKeyRaw)
            parts.append(fp.role)
            parts.append(String(Int(
                fp.issuedAt.timeIntervalSince1970 * 1000)))
            parts.append(String(Int(
                fp.notAfter.timeIntervalSince1970 * 1000)))
        }
        return Data(parts.joined(separator: "|").utf8)
    }

    /// Convenience builder: given a set of fingerprints + a root
    /// signing key, produce a fully-signed manifest.
    /// Intended for tests + host-side provisioning tooling;
    /// production manifests should be signed offline.
    public static func signed(
        schemaVersion: String
            = BASSovereignFingerprintManifest.currentSchemaVersion,
        issuedAt: Date,
        notAfter: Date,
        fingerprints: [BASSovereignTrustedFingerprint],
        rootSigningKey: Curve25519.Signing.PrivateKey
    ) throws -> BASSovereignFingerprintManifest {
        let provisional = BASSovereignFingerprintManifest(
            schemaVersion: schemaVersion,
            issuedAt: issuedAt,
            notAfter: notAfter,
            fingerprints: fingerprints,
            signature: "")
        let canonical = canonicalManifestBytes(for: provisional)
        let sig = try rootSigningKey.signature(for: canonical)
        return BASSovereignFingerprintManifest(
            schemaVersion: schemaVersion,
            issuedAt: issuedAt,
            notAfter: notAfter,
            fingerprints: fingerprints,
            signature: sig.base64EncodedString())
    }
}
