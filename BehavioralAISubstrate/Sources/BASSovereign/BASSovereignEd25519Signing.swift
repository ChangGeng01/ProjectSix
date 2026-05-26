import Foundation
import CryptoKit
import BASRuntimeCore

/// M87 — Ed25519 production-grade signing for the sovereign audit
/// ledger.
///
/// ## Why this exists
///
/// Before M87 `BASSovereignAuditLedger` signed every entry with
/// HMAC-SHA256 over a `SymmetricKey`. HMAC is a perfectly cryptographic
/// primitive for tamper detection, but it is a **shared-secret**
/// scheme: any process that wants to verify an entry's signature must
/// hold the same secret used to produce it. For in-process ledgers
/// that's fine; for the cross-process "second verifier" promise in
/// the L14 Black Ring spec (a separate audit verifier binary can
/// independently re-sign every entry and fail-closed if its
/// computation disagrees), sharing the signing secret to every
/// verifier collapses the integrity story to "whoever has the key
/// can also forge any entry".
///
/// Ed25519 is an **asymmetric** (public-key) signature scheme. The
/// ledger holds a private key to sign; any number of verifiers hold
/// only the matching public key to verify. A compromised verifier
/// cannot forge entries — it can only fail to catch a forgery. This
/// is what "production-grade sovereign audit" means in practice.
///
/// ## Properties this key pair gives the ledger
///
/// 1. **Deterministic signing** — Ed25519 (RFC 8032) derives the
///    signing nonce from the message + private key, so `sign(same
///    message)` twice yields byte-identical signatures. This matters
///    because `verifyChainIntegrity()` recomputes every signature
///    from scratch and compares; a non-deterministic scheme would
///    require storing and re-reading the random nonce.
/// 2. **Cross-verifier verification without secret sharing** — the
///    ledger exposes `BASSovereignAuditLedger.verify(_:publicKey:
///    signingNamespace:)` as a static pure function that takes an
///    appended entry and the public key alone. Cross-process
///    verifiers run this and do not need the private key.
/// 3. **Namespace binding preserved** — the canonical byte layout
///    (entry fields pipe-joined with the signing namespace tag as
///    the last field) is identical across HMAC and Ed25519 modes,
///    so swapping signing mode does NOT change the ledger-format
///    schema version.
///
/// ## What this explicitly does NOT do
///
/// - Key rotation — a given ledger is bound to one key pair for its
///   lifetime; rotation is the `TokenAuthority` keyring's concern
///   and will arrive as a separate milestone.
/// - Keychain storage — the `PrivateKey` is held in memory only; for
///   real deployment the host must materialise it from a
///   platform-specific keyring. Until that seam ships, tests and
///   bootstrap use `BASSovereignEd25519KeyPair.generate()` for fresh
///   pairs and `fromSeed(_:)` for deterministic test fixtures.
/// - BR-013+ integrity sentinel — M87 delivers the cryptographic
///   primitive; wiring it into a runtime sentinel that monitors and
///   halts on signature failures is a follow-up milestone.
public struct BASSovereignEd25519KeyPair: Sendable {

    public let privateKey: Curve25519.Signing.PrivateKey

    public var publicKey: Curve25519.Signing.PublicKey {
        privateKey.publicKey
    }

    public init(privateKey: Curve25519.Signing.PrivateKey) {
        self.privateKey = privateKey
    }

    /// Generate a fresh Ed25519 key pair with cryptographically
    /// secure random bytes. The only production-correct factory;
    /// `fromSeed(_:)` is test-only.
    public static func generate() -> BASSovereignEd25519KeyPair {
        BASSovereignEd25519KeyPair(
            privateKey: Curve25519.Signing.PrivateKey())
    }

    /// Derive a deterministic key pair from a UTF-8 seed string.
    ///
    /// Ed25519 requires a 32-byte seed; SHA-256 yields exactly 32
    /// bytes from any input so we hash the seed and use the digest.
    /// Deterministic = every caller supplying the same seed gets the
    /// same key pair, which makes integration tests reproducible.
    ///
    /// **Not for production** — the whole point of Ed25519 is to
    /// hold the private key in a keychain / HSM / enclave and never
    /// see the raw bytes again. Deriving a key from a low-entropy
    /// string exposes the ledger to offline attacks that guess the
    /// seed. Use this only for test fixtures.
    public static func fromSeed(_ seed: String) throws
        -> BASSovereignEd25519KeyPair {
        let digest = Data(SHA256.hash(data: Data(seed.utf8)))
        let privKey = try Curve25519.Signing.PrivateKey(
            rawRepresentation: digest)
        return BASSovereignEd25519KeyPair(privateKey: privKey)
    }
}

// MARK: - Canonical-byte helper shared with the ledger

/// Compute the canonical byte layout of a sovereign audit entry for
/// signing / verification. Kept `package`-visible so the ledger's
/// internal `sign(_:)` and the public static `verify(_:)` path
/// reference a single source of truth — a desync between them would
/// be a silent integrity hole.
///
/// chapter 九百九十三 / M3670 — cross-arc canonical-bytes separator
/// hardening (closes ch 982 Round-8 cross-arc concern):
/// The pre-1.1.0 format uses `","` as the inner array separator and
/// `"|"` as the outer field separator。 If any array entry CONTAINS
/// a `,` (legitimately,since they include caller-supplied opaque
/// strings like `agentExternal.proposal:<externalID>:...`),the
/// canonical bytes become ambiguous — two different signalRef lists
/// could yield the same canonical bytes,enabling signature
/// collision。 Same class as ch 981.9 C1 fix。
///
/// Schema-version-gated separator choice (additive,backward-compat):
///   - `"1.0.0"` (currentSchemaVersion as of ch 993):OLD format
///     (`,` inner / `|` outer) — preserved for in-memory + on-disk
///     ledger entries created before this chapter。 Vulnerable to
///     the collision class above。
///   - `"1.1.0"` (opt-in via explicit init):HARDENED format using
///     U+001F (unit separator) inner + U+001E (record separator)
///     outer。 Both are ASCII control chars forbidden in normal
///     string content per RFC discipline,so collision is
///     impossible regardless of caller-supplied content。
///
/// Callers wanting the hardened format MUST construct the entry
/// with `schemaVersion: "1.1.0"` explicitly。 ch 993 also updates
/// `BASSovereignWarrantAuditBridge.buildEntry(...)` to use the
/// hardened format by default since warrant entries are the
/// primary attack surface flagged by Round-8。
package func basSovereignAuditCanonicalBytes(
    for entry: BASSovereignAuditEntry,
    priorHash: String,
    signingNamespace: String
) -> Data {
    // Schema-version-gated separator choice。 Old format preserved
    // for backward compat;new format uses ASCII control-char
    // separators that cannot appear in user-supplied string content。
    let arraySep: String
    let fieldSep: String
    if entry.schemaVersion == "1.0.0" {
        arraySep = ","
        fieldSep = "|"
    } else {
        // chapter 九百九十三 / M3670 hardened format:U+001F inner,
        // U+001E outer。 Forbidden in legal user content。
        arraySep = "\u{001F}"
        fieldSep = "\u{001E}"
    }
    let fields: [String] = [
        entry.schemaVersion,
        entry.auditID,
        entry.sessionID,
        entry.turnID,
        entry.verdictRef,
        entry.ruleIDs.joined(separator: arraySep),
        entry.signalRefs.joined(separator: arraySep),
        entry.actionRefs.joined(separator: arraySep),
        entry.snapshotRef,
        entry.actor.rawValue,
        String(Int(entry.appendedAt.timeIntervalSince1970 * 1000)),
        priorHash,
        signingNamespace
    ]
    return Data(fields.joined(separator: fieldSep).utf8)
}

// MARK: - Static verifier for Ed25519-signed entries

public extension BASSovereignAuditLedger {

    /// Verify an `AppendedEntry`'s signature against a public key
    /// without needing the original signing secret. Intended for:
    ///
    /// - Cross-process verifier binaries that receive an exported
    ///   ledger + its public key and must independently re-check
    ///   every entry's signature.
    /// - In-process defensive reads where the caller wants belt-and-
    ///   braces verification on top of the ledger's own
    ///   `verifyChainIntegrity()`.
    ///
    /// Returns `true` if the signature validates under `publicKey` and
    /// the given `signingNamespace`; `false` otherwise. Does NOT
    /// throw — sentinel code must be able to branch on a plain Bool
    /// without catching, and any parse error (base64 malformed,
    /// wrong-size signature bytes) is an integrity failure equivalent
    /// to a bad signature.
    ///
    /// This method does NOT verify hash-chain continuity — it only
    /// checks "is this entry's signature valid under this public
    /// key". Callers that need chain integrity should additionally
    /// invoke `verifyChainIntegrity()` via the owning actor.
    static func verify(
        _ appended: AppendedEntry,
        publicKey: Curve25519.Signing.PublicKey,
        signingNamespace: String =
            BASSovereignTrustConstants.signingNamespace
    ) -> Bool {
        let canonical = basSovereignAuditCanonicalBytes(
            for: appended.entry,
            priorHash: appended.priorHash,
            signingNamespace: signingNamespace)
        guard let sigData = Data(
            base64Encoded: appended.entry.signature)
        else { return false }
        return publicKey.isValidSignature(sigData, for: canonical)
    }
}
