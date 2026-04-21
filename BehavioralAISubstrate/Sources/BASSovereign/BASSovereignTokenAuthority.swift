import Foundation
import CryptoKit
import BASRuntimeCore

/// `BR-06` TokenAuthority — issues and verifies the two L14 credentials
/// that gate every irreversible operation:
///
/// - `BASSovereignCommitToken` — the "second key" of the double-key
///   submission protocol (§10 of the Black Ring spec). Bound to
///   `session_id + turn_id + action_digest + snapshot_ref` and signed by
///   the sovereign keyring.
/// - `BASSovereignWarrant` — the extended-scope, jurisdiction-bound
///   authorization that survives a single turn (used by host mutation,
///   memory promotion, rule promotion).
///
/// ## Why in-memory + actor?
///
/// The TokenAuthority must be the single source of truth about
/// "nonce X has been seen" and "token Y has been burned." An actor
/// serializes issuance/verification so those invariants are race-free.
/// Persistence to the keychain or a signed journal is a later concern
/// (M3 Snapshot Ark); for v1 we hold nonces and spent tokens in memory.
///
/// ## Signing
///
/// v1 uses Ed25519 (CryptoKit `Curve25519.Signing`) — on-device only,
/// no network. The authority owns the private key; verification can be
/// done by anyone holding the public key. Tests use a deterministic
/// seed so signatures are reproducible.
public actor BASSovereignTokenAuthority {
    public enum AuthorityError: Error, Equatable, Sendable {
        case invalidIntent(String)
        case expired(tokenID: String)
        case alreadyUsed(tokenID: String)
        case unknownToken(tokenID: String)
        case signatureInvalid(tokenID: String)
        case scopeMismatch(expected: BASSovereignCommitScope, got: BASSovereignCommitScope)
        case actionDigestMismatch(tokenID: String)
        case policyHashMismatch(tokenID: String)
    }

    /// Materialized intent — everything the authority needs to mint a
    /// token. The intent itself is NOT signed; the minted token is.
    public struct CommitIntent: Sendable, Equatable {
        public let sessionID: String
        public let turnID: String
        public let scope: BASSovereignCommitScope
        public let allowedTargets: [String]
        public let actionDigest: String
        public let snapshotRef: String
        public let ttlMs: Int
        public let policyHash: String

        public init(
            sessionID: String,
            turnID: String,
            scope: BASSovereignCommitScope,
            allowedTargets: [String],
            actionDigest: String,
            snapshotRef: String,
            ttlMs: Int = BASSovereignTrustConstants.defaultCommitTokenTTLMs,
            policyHash: String = BASSovereignTrustConstants.builtInPolicyHash
        ) {
            self.sessionID = sessionID
            self.turnID = turnID
            self.scope = scope
            self.allowedTargets = allowedTargets
            self.actionDigest = actionDigest
            self.snapshotRef = snapshotRef
            self.ttlMs = ttlMs
            self.policyHash = policyHash
        }
    }

    /// Warrant intent — like CommitIntent but wider in scope and time.
    public struct WarrantIntent: Sendable, Equatable {
        public let scope: BASSovereignCommitScope
        public let actionDigest: String
        public let jurisdictionRef: String
        public let snapshotRef: String
        public let timeLockRef: String
        public let ttlMs: Int
        public let witnessRefs: [String]
        public let policyHash: String

        public init(
            scope: BASSovereignCommitScope,
            actionDigest: String,
            jurisdictionRef: String,
            snapshotRef: String,
            timeLockRef: String,
            ttlMs: Int = BASSovereignTrustConstants.defaultCommitTokenTTLMs,
            witnessRefs: [String] = [],
            policyHash: String = BASSovereignTrustConstants.builtInPolicyHash
        ) {
            self.scope = scope
            self.actionDigest = actionDigest
            self.jurisdictionRef = jurisdictionRef
            self.snapshotRef = snapshotRef
            self.timeLockRef = timeLockRef
            self.ttlMs = ttlMs
            self.witnessRefs = witnessRefs
            self.policyHash = policyHash
        }
    }

    private struct MintedTokenRecord {
        let issuedAt: Date
        let ttlMs: Int
        let actionDigest: String
        let scope: BASSovereignCommitScope
        let policyHash: String
        var redeemed: Bool
    }

    private struct MintedWarrantRecord {
        let issuedAt: Date
        let ttlMs: Int
        let scope: BASSovereignCommitScope
        let actionDigest: String
        let policyHash: String
        var redeemed: Bool
    }

    private let signingKey: Curve25519.Signing.PrivateKey
    private let now: @Sendable () -> Date

    /// `tokenID` → record.
    private var mintedTokens: [String: MintedTokenRecord] = [:]
    /// `warrantID` → record.
    private var mintedWarrants: [String: MintedWarrantRecord] = [:]
    /// Set of nonces ever emitted; prevents replay even across expiry.
    private var seenNonces: Set<String> = []

    public init(
        signingKey: Curve25519.Signing.PrivateKey = Curve25519.Signing.PrivateKey(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.signingKey = signingKey
        self.now = now
    }

    /// Public key exported so verifiers in other processes (tests,
    /// replay, governance) can validate signatures without holding the
    /// private half.
    public nonisolated var publicKey: Curve25519.Signing.PublicKey {
        signingKey.publicKey
    }

    // MARK: - Commit tokens

    public func issueCommitToken(for intent: CommitIntent) throws -> BASSovereignCommitToken {
        guard !intent.sessionID.isEmpty, !intent.turnID.isEmpty else {
            throw AuthorityError.invalidIntent("session/turn must be non-empty")
        }
        guard !intent.actionDigest.isEmpty else {
            throw AuthorityError.invalidIntent("actionDigest must be non-empty")
        }
        guard intent.ttlMs > 0 else {
            throw AuthorityError.invalidIntent("ttlMs must be positive")
        }

        let tokenID = "sct-\(UUID().uuidString)"
        let nonce = makeFreshNonce()
        let issuedAt = now()

        let canonical = canonicalCommitBytes(
            tokenID: tokenID,
            sessionID: intent.sessionID,
            turnID: intent.turnID,
            scope: intent.scope,
            allowedTargets: intent.allowedTargets,
            actionDigest: intent.actionDigest,
            snapshotRef: intent.snapshotRef,
            policyHash: intent.policyHash,
            ttlMs: intent.ttlMs,
            nonce: nonce,
            issuedAtEpochMs: Int(issuedAt.timeIntervalSince1970 * 1000)
        )
        let signature = try signingKey.signature(for: canonical).base64EncodedString()

        mintedTokens[tokenID] = MintedTokenRecord(
            issuedAt: issuedAt,
            ttlMs: intent.ttlMs,
            actionDigest: intent.actionDigest,
            scope: intent.scope,
            policyHash: intent.policyHash,
            redeemed: false
        )

        return BASSovereignCommitToken(
            tokenID: tokenID,
            sessionID: intent.sessionID,
            turnID: intent.turnID,
            scope: intent.scope,
            allowedTargets: intent.allowedTargets,
            actionDigest: intent.actionDigest,
            snapshotRef: intent.snapshotRef,
            policyHash: intent.policyHash,
            ttlMs: intent.ttlMs,
            nonce: nonce,
            singleUse: true,
            signature: signature
        )
    }

    /// Verify a commit token against the authority.
    ///
    /// `redeem: true` — mark the token as spent; subsequent verifications
    /// will throw `alreadyUsed`. This is the call made at the final
    /// pre-commit gate. Read-only verifications (e.g. `Intra-Turn Watch`)
    /// should pass `redeem: false`.
    public func verifyCommitToken(
        _ token: BASSovereignCommitToken,
        expectedScope: BASSovereignCommitScope,
        expectedActionDigest: String,
        expectedPolicyHash: String = BASSovereignTrustConstants.builtInPolicyHash,
        redeem: Bool
    ) throws {
        guard var record = mintedTokens[token.tokenID] else {
            throw AuthorityError.unknownToken(tokenID: token.tokenID)
        }
        guard token.scope == expectedScope else {
            throw AuthorityError.scopeMismatch(expected: expectedScope, got: token.scope)
        }
        guard token.actionDigest == expectedActionDigest else {
            throw AuthorityError.actionDigestMismatch(tokenID: token.tokenID)
        }
        guard token.policyHash == expectedPolicyHash else {
            throw AuthorityError.policyHashMismatch(tokenID: token.tokenID)
        }
        if record.redeemed && token.singleUse {
            throw AuthorityError.alreadyUsed(tokenID: token.tokenID)
        }

        // Expiry check.
        let currentTime = now()
        let ageMs = Int(currentTime.timeIntervalSince(record.issuedAt) * 1000)
        if ageMs > record.ttlMs {
            throw AuthorityError.expired(tokenID: token.tokenID)
        }

        // Signature check.
        let canonical = canonicalCommitBytes(
            tokenID: token.tokenID,
            sessionID: token.sessionID,
            turnID: token.turnID,
            scope: token.scope,
            allowedTargets: token.allowedTargets,
            actionDigest: token.actionDigest,
            snapshotRef: token.snapshotRef,
            policyHash: token.policyHash,
            ttlMs: token.ttlMs,
            nonce: token.nonce,
            issuedAtEpochMs: Int(record.issuedAt.timeIntervalSince1970 * 1000)
        )
        guard let sigData = Data(base64Encoded: token.signature),
              signingKey.publicKey.isValidSignature(sigData, for: canonical)
        else {
            throw AuthorityError.signatureInvalid(tokenID: token.tokenID)
        }

        if redeem {
            record.redeemed = true
            mintedTokens[token.tokenID] = record
        }
    }

    /// Revoke every un-redeemed token for a session. Called when L14
    /// escalates to `ROLLBACK` or `DEAD_STOP` per §8.2 and §10.3.
    public func revokeAllTokens(forSession sessionID: String) {
        // We don't store sessionID in the record (it's in the token
        // itself, which lives outside the actor). A real implementation
        // persists session refs; for v1 we provide the hook as a
        // broadcast-all nuke when the caller cannot enumerate.
        //
        // Callers that track which tokens belong to which session can
        // instead call `revoke(tokenID:)` for precision.
        _ = sessionID
        for (id, var record) in mintedTokens where !record.redeemed {
            record.redeemed = true
            mintedTokens[id] = record
        }
    }

    public func revoke(tokenID: String) {
        if var record = mintedTokens[tokenID] {
            record.redeemed = true
            mintedTokens[tokenID] = record
        }
    }

    // MARK: - Warrants

    public func issueWarrant(for intent: WarrantIntent) throws -> BASSovereignWarrant {
        guard !intent.actionDigest.isEmpty else {
            throw AuthorityError.invalidIntent("actionDigest must be non-empty")
        }
        guard !intent.jurisdictionRef.isEmpty else {
            throw AuthorityError.invalidIntent("jurisdictionRef must be non-empty")
        }
        guard intent.ttlMs > 0 else {
            throw AuthorityError.invalidIntent("ttlMs must be positive")
        }

        let warrantID = "swt-\(UUID().uuidString)"
        let issuedAt = now()
        let expiresAt = issuedAt.addingTimeInterval(TimeInterval(intent.ttlMs) / 1000.0)

        let canonical = canonicalWarrantBytes(
            warrantID: warrantID,
            scope: intent.scope,
            actionDigest: intent.actionDigest,
            jurisdictionRef: intent.jurisdictionRef,
            snapshotRef: intent.snapshotRef,
            timeLockRef: intent.timeLockRef,
            policyHash: intent.policyHash,
            issuedAtEpochMs: Int(issuedAt.timeIntervalSince1970 * 1000),
            expiresAtEpochMs: Int(expiresAt.timeIntervalSince1970 * 1000),
            witnessRefs: intent.witnessRefs
        )
        let signature = try signingKey.signature(for: canonical).base64EncodedString()

        mintedWarrants[warrantID] = MintedWarrantRecord(
            issuedAt: issuedAt,
            ttlMs: intent.ttlMs,
            scope: intent.scope,
            actionDigest: intent.actionDigest,
            policyHash: intent.policyHash,
            redeemed: false
        )

        return BASSovereignWarrant(
            warrantID: warrantID,
            scope: intent.scope,
            actionDigest: intent.actionDigest,
            commitTokenRef: nil,
            jurisdictionRef: intent.jurisdictionRef,
            snapshotRef: intent.snapshotRef,
            timeLockRef: intent.timeLockRef,
            policyHash: intent.policyHash,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            witnessRefs: intent.witnessRefs,
            singleUse: true,
            signature: signature
        )
    }

    public func verifyWarrant(
        _ warrant: BASSovereignWarrant,
        expectedScope: BASSovereignCommitScope,
        expectedActionDigest: String,
        expectedPolicyHash: String = BASSovereignTrustConstants.builtInPolicyHash,
        redeem: Bool
    ) throws {
        guard var record = mintedWarrants[warrant.warrantID] else {
            throw AuthorityError.unknownToken(tokenID: warrant.warrantID)
        }
        guard warrant.scope == expectedScope else {
            throw AuthorityError.scopeMismatch(expected: expectedScope, got: warrant.scope)
        }
        guard warrant.actionDigest == expectedActionDigest else {
            throw AuthorityError.actionDigestMismatch(tokenID: warrant.warrantID)
        }
        guard warrant.policyHash == expectedPolicyHash else {
            throw AuthorityError.policyHashMismatch(tokenID: warrant.warrantID)
        }
        if record.redeemed && warrant.singleUse {
            throw AuthorityError.alreadyUsed(tokenID: warrant.warrantID)
        }
        if let expiresAt = warrant.expiresAt, now() > expiresAt {
            throw AuthorityError.expired(tokenID: warrant.warrantID)
        }

        let canonical = canonicalWarrantBytes(
            warrantID: warrant.warrantID,
            scope: warrant.scope,
            actionDigest: warrant.actionDigest,
            jurisdictionRef: warrant.jurisdictionRef,
            snapshotRef: warrant.snapshotRef,
            timeLockRef: warrant.timeLockRef,
            policyHash: warrant.policyHash,
            issuedAtEpochMs: Int(record.issuedAt.timeIntervalSince1970 * 1000),
            expiresAtEpochMs: Int((warrant.expiresAt ?? record.issuedAt).timeIntervalSince1970 * 1000),
            witnessRefs: warrant.witnessRefs
        )
        guard let sigData = Data(base64Encoded: warrant.signature),
              signingKey.publicKey.isValidSignature(sigData, for: canonical)
        else {
            throw AuthorityError.signatureInvalid(tokenID: warrant.warrantID)
        }

        if redeem {
            record.redeemed = true
            mintedWarrants[warrant.warrantID] = record
        }
    }

    // MARK: - Diagnostics

    public func issuedTokenCount() -> Int { mintedTokens.count }
    public func activeTokenCount() -> Int { mintedTokens.values.filter { !$0.redeemed }.count }
    public func issuedWarrantCount() -> Int { mintedWarrants.count }

    // MARK: - Canonical bytes

    private func canonicalCommitBytes(
        tokenID: String,
        sessionID: String,
        turnID: String,
        scope: BASSovereignCommitScope,
        allowedTargets: [String],
        actionDigest: String,
        snapshotRef: String,
        policyHash: String,
        ttlMs: Int,
        nonce: String,
        issuedAtEpochMs: Int
    ) -> Data {
        let fields: [String] = [
            "COMMIT",
            tokenID,
            sessionID,
            turnID,
            scope.rawValue,
            allowedTargets.joined(separator: ","),
            actionDigest,
            snapshotRef,
            policyHash,
            String(ttlMs),
            nonce,
            String(issuedAtEpochMs),
            BASSovereignTrustConstants.signingNamespace
        ]
        return Data(fields.joined(separator: "|").utf8)
    }

    private func canonicalWarrantBytes(
        warrantID: String,
        scope: BASSovereignCommitScope,
        actionDigest: String,
        jurisdictionRef: String,
        snapshotRef: String,
        timeLockRef: String,
        policyHash: String,
        issuedAtEpochMs: Int,
        expiresAtEpochMs: Int,
        witnessRefs: [String]
    ) -> Data {
        let fields: [String] = [
            "WARRANT",
            warrantID,
            scope.rawValue,
            actionDigest,
            jurisdictionRef,
            snapshotRef,
            timeLockRef,
            policyHash,
            String(issuedAtEpochMs),
            String(expiresAtEpochMs),
            witnessRefs.joined(separator: ","),
            BASSovereignTrustConstants.signingNamespace
        ]
        return Data(fields.joined(separator: "|").utf8)
    }

    private func makeFreshNonce() -> String {
        // UUID gives us ~122 bits of entropy per nonce. Dedup-set check
        // is retained anyway as a belt-and-braces guarantee: no nonce
        // ever leaves this authority twice.
        while true {
            let candidate = UUID().uuidString
            if seenNonces.insert(candidate).inserted {
                return candidate
            }
        }
    }
}
