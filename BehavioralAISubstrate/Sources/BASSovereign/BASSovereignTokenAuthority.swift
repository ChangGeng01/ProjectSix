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
    public enum AuthorityError:
        Error, Equatable, Sendable, Codable
    {
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
    public struct CommitIntent:
        Sendable, Equatable, Codable
    {
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
    public struct WarrantIntent:
        Sendable, Equatable, Codable
    {
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

    /// M93c — optional revocation broadcaster. When non-nil every
    /// `revoke(...)` / `revokeAllTokens(forSession:)` /
    /// `revokeWarrant(...)` call publishes a
    /// `BASSovereignRevocationEvent` to every subscriber. Nil
    /// preserves pre-M93 behaviour byte-for-byte so existing call
    /// sites are unaffected.
    private let revocationBroadcaster:
        BASSovereignRevocationBroadcaster?

    /// `tokenID` → record.
    private var mintedTokens: [String: MintedTokenRecord] = [:]
    /// `warrantID` → record.
    private var mintedWarrants: [String: MintedWarrantRecord] = [:]
    /// Set of nonces ever emitted; prevents replay even across expiry.
    private var seenNonces: Set<String> = []

    public init(
        signingKey: Curve25519.Signing.PrivateKey = Curve25519.Signing.PrivateKey(),
        now: @escaping @Sendable () -> Date = { Date() },
        revocationBroadcaster: BASSovereignRevocationBroadcaster? = nil
    ) {
        self.signingKey = signingKey
        self.now = now
        self.revocationBroadcaster = revocationBroadcaster
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

    /// Deterministic-IDENTITY variant of `issueCommitToken` (ch1044 #2 / DEFER-1).
    /// The caller supplies `tokenID` / `nonce` / `issuedAt` instead of the
    /// authority generating a random UUID + fresh nonce + `now()`, so the token's
    /// IDENTITY is reproducible. It produces a real Ed25519-signed, single-use
    /// token that `verifyCommitToken` validates exactly like a randomly-minted one.
    ///
    /// ⚠️ FINDING (ch1044): CryptoKit's `Curve25519.Signing` is a RANDOMIZED
    /// (hedged) Ed25519 — the SIGNATURE is NOT bit-reproducible even for the same
    /// key + message. So full-token byte-determinism INCLUDING the signature (the
    /// HIGH-1 replay contract) is NOT achievable with CryptoKit Ed25519.
    /// Reconciling that is the #2 wiring's key design decision (ADR-025): relax
    /// replay-determinism to exclude the signature, carry a DUAL signature
    /// (deterministic SHA256 tag + Ed25519), or use a deterministic Ed25519 impl.
    /// Additive — production `makeCommitToken` is untouched, so this is byte-equal
    /// until a host opts in.
    public func issueDeterministicCommitToken(
        for intent: CommitIntent,
        tokenID: String,
        nonce: String,
        issuedAt: Date
    ) throws -> BASSovereignCommitToken {
        guard !intent.sessionID.isEmpty, !intent.turnID.isEmpty else {
            throw AuthorityError.invalidIntent("session/turn must be non-empty")
        }
        guard !intent.actionDigest.isEmpty else {
            throw AuthorityError.invalidIntent("actionDigest must be non-empty")
        }
        guard intent.ttlMs > 0 else {
            throw AuthorityError.invalidIntent("ttlMs must be positive")
        }
        guard !tokenID.isEmpty, !nonce.isEmpty else {
            throw AuthorityError.invalidIntent("tokenID/nonce must be non-empty")
        }
        // ch1044 audit fix (FINDING 4): a deterministic mint must NOT silently
        // overwrite an existing ledger record — that would reset a redeemed token's
        // `redeemed:true -> false` and defeat single-use (a double-spend). A tokenID
        // and a nonce are each one-shot here, exactly as in the random-mint path.
        // (Re-deriving a token to VERIFY it uses `verifyCommitToken`, never a re-mint.)
        guard mintedTokens[tokenID] == nil else {
            throw AuthorityError.alreadyUsed(tokenID: tokenID)
        }
        guard seenNonces.insert(nonce).inserted else {
            throw AuthorityError.alreadyUsed(tokenID: tokenID)
        }

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
        // ch1044 深入 audit fix (CRITICAL replay bypass): enforce single-use from the
        // SERVER record, NOT the token-carried `singleUse` flag. `singleUse` is an
        // attacker-mutable Codable field NOT covered by `canonicalCommitBytes`, so an
        // attacker could flip it to false and replay a redeemed token (the Ed25519 sig
        // still verifies — the byte isn't signed). The authority only mints single-use
        // tokens (the `redeemed` flag IS the mechanism), so a redeemed record is spent
        // regardless of the token's claimed flag.
        if record.redeemed {
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
    ///
    /// M93c — when a `revocationBroadcaster` is wired, publishes one
    /// `BASSovereignRevocationEvent` per newly-revoked token with
    /// `reasonCode: "session-revoked-all"`.
    public func revokeAllTokens(forSession sessionID: String) async {
        // We don't store sessionID in the record (it's in the token
        // itself, which lives outside the actor). A real implementation
        // persists session refs; for v1 we provide the hook as a
        // broadcast-all nuke when the caller cannot enumerate.
        //
        // Callers that track which tokens belong to which session can
        // instead call `revoke(tokenID:)` for precision.
        _ = sessionID
        var revokedIDs: [String] = []
        for (id, var record) in mintedTokens where !record.redeemed {
            record.redeemed = true
            mintedTokens[id] = record
            revokedIDs.append(id)
        }
        if let broadcaster = revocationBroadcaster {
            for id in revokedIDs {
                await broadcaster.publish(
                    BASSovereignRevocationEvent(
                        kind: .commitToken,
                        subjectID: id,
                        reasonCode: "session-revoked-all",
                        publishedAt: now()))
            }
        }
    }

    /// Revoke a single token by ID.
    ///
    /// M93c — when a `revocationBroadcaster` is wired AND the token
    /// was previously un-revoked, publishes one
    /// `BASSovereignRevocationEvent` with `reasonCode: "host-requested"`.
    /// Revoking an already-revoked token is a no-op that does NOT
    /// re-broadcast (idempotent).
    public func revoke(tokenID: String) async {
        guard var record = mintedTokens[tokenID] else { return }
        let wasRevoked = record.redeemed
        record.redeemed = true
        mintedTokens[tokenID] = record
        if !wasRevoked, let broadcaster = revocationBroadcaster {
            await broadcaster.publish(
                BASSovereignRevocationEvent(
                    kind: .commitToken,
                    subjectID: tokenID,
                    reasonCode: "host-requested",
                    publishedAt: now()))
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
        // ch1044 深入 audit fix (CRITICAL replay bypass): enforce single-use from the
        // SERVER record, not the attacker-mutable, unsigned `warrant.singleUse` flag.
        if record.redeemed {
            throw AuthorityError.alreadyUsed(tokenID: warrant.warrantID)
        }
        // Audit fix: SERVER-AUTHORITATIVE expiry (mirrors verifyCommitToken:345-350 + the ch1044 singleUse
        // doctrine). The client-carried `warrant.expiresAt` is advisory only — a nil no longer means "never";
        // the authority computes age from the server record's issuedAt + ttlMs. Fail-closed.
        let ageMs = Int(now().timeIntervalSince(record.issuedAt) * 1000)
        if ageMs > record.ttlMs {
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
            // Server-authoritative: reproduce the mint-time expiry (issuedAt + ttlMs) from the RECORD so the
            // canonical never trusts the client-carried `expiresAt`; byte-matches the value signed at mint.
            expiresAtEpochMs: Int(record.issuedAt.addingTimeInterval(
                TimeInterval(record.ttlMs) / 1000.0).timeIntervalSince1970 * 1000),
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
        // ch1044 audit fix — INJECTIVE length-prefixed encoding. Was a `,`-join on
        // allowedTargets inside a `|`-join: an in-band `,` or `|` in any field could
        // forge a different field set into byte-identical signed bytes. Each target
        // is now its own length-prefixed element behind a count marker; no in-band
        // separator can shift a boundary.
        BASSovereignCanonicalBytes.lengthPrefixed(
            ["COMMIT", tokenID, sessionID, turnID, scope.rawValue]
            + BASSovereignCanonicalBytes.list(allowedTargets)
            + [actionDigest, snapshotRef, policyHash,
               String(ttlMs), nonce, String(issuedAtEpochMs),
               BASSovereignTrustConstants.signingNamespace]
        )
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
        // ch1044 全面 audit fix — INJECTIVE length-prefixed encoding (was a `,`-join
        // on witnessRefs inside a `|`-join; same forgery class as canonicalCommitBytes,
        // missed in the first pass). witnessRefs become count-prefixed length-delimited
        // elements so no in-band separator can shift a boundary. (issueWarrant is
        // dormant — no persisted warrants — so the layout change is byte-safe.)
        return BASSovereignCanonicalBytes.lengthPrefixed(
            ["WARRANT", warrantID, scope.rawValue, actionDigest, jurisdictionRef,
             snapshotRef, timeLockRef, policyHash,
             String(issuedAtEpochMs), String(expiresAtEpochMs)]
            + BASSovereignCanonicalBytes.list(witnessRefs)
            + [BASSovereignTrustConstants.signingNamespace]
        )
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
