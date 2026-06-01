// ch1044 A1 — the production enforcement seam for sovereign commit tokens.
//
// THE GAP (deep-audit dataflow finding): the substrate emits commit tokens whose
// `signature` is a KEYLESS SHA256 tag (a checksum anyone can recompute, not an
// authenticator), and NO production code verifies a token before it could authorize an
// irreversible op. The real verifier (`BASSovereignTokenAuthority`) was test-only.
//
// THIS is the real (non-test) seam. A host holds an enforcer built with its sovereign
// keyring, and MUST call `authorize(...)` before executing any irreversible operation.
// It is OPT-IN: if a host never constructs an enforcer, the substrate is byte-equal
// (this file adds no behavior to the turn path). When the operator wires it, every
// gated op is cryptographically authenticated against an INDEPENDENTLY-recomputed
// action digest.

import Foundation
import CryptoKit
import BASRuntimeCore

public actor BASSovereignCommitEnforcer {

    private let authority: BASSovereignTokenAuthority
    private let now: @Sendable () -> Date

    public enum EnforcementError: Error, Sendable, Equatable {
        /// The requested target is not in the token's SIGNED `allowedTargets` — an
        /// aliased-target attempt (a token minted for target A used to authorize B).
        /// `verifyCommitToken` does NOT check target membership (a deep-audit gap), so
        /// the enforcer enforces it here.
        case targetNotAllowed(tokenID: String, target: String)
    }

    public init(
        authority: BASSovereignTokenAuthority,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.authority = authority
        self.now = now
    }

    /// Mint the AUTHORITATIVE Ed25519 token for a brain-emitted commit token and register
    /// it in the authority's single-use ledger. Call once per emitted token (at emission
    /// time, from the host). The returned token carries the authority's Ed25519 signature
    /// — the host stores it and passes it to `authorize` before the op. Identity
    /// (tokenID/nonce/scope/actionDigest/allowedTargets/...) is preserved from the brain
    /// token; only a real keyed signature + ledger tracking are added. `issuedAt`
    /// defaults to now (the TTL origin); pass the turn's recordedAt for turn-accurate TTL.
    @discardableResult
    public func register(
        _ brainToken: BASSovereignCommitToken,
        issuedAt: Date? = nil
    ) async throws -> BASSovereignCommitToken {
        let intent = BASSovereignTokenAuthority.CommitIntent(
            sessionID: brainToken.sessionID,
            turnID: brainToken.turnID,
            scope: brainToken.scope,
            allowedTargets: brainToken.allowedTargets,
            actionDigest: brainToken.actionDigest,
            snapshotRef: brainToken.snapshotRef,
            ttlMs: brainToken.ttlMs,
            policyHash: brainToken.policyHash)
        return try await authority.issueDeterministicCommitToken(
            for: intent,
            tokenID: brainToken.tokenID,
            nonce: brainToken.nonce,
            issuedAt: issuedAt ?? now())
    }

    /// Authorize an irreversible op BEFORE the host executes it. THROWS on ANY failure —
    /// the host MUST NOT execute on a throw. Checks, in order:
    ///   1. `target` ∈ `token.allowedTargets` (signed) — rejects an aliased target.
    ///   2. the authority verify: Ed25519 signature, single-use BURN (replay), TTL,
    ///      scope, policyHash, AND `token.actionDigest == expectedActionDigest`.
    ///
    /// `expectedActionDigest` MUST be recomputed by the caller — via
    /// `BASSovereignActionDigest.compute(...)` from the ACTUALLY-APPROVED artifact (the
    /// exact render body / ticket set / fold the host is about to act on), NEVER read off
    /// the token. That is what makes a tampered-between-authorization-and-execution body
    /// fail: the recomputed digest won't match the token's signed `actionDigest`.
    public func authorize(
        _ token: BASSovereignCommitToken,
        scope: BASSovereignCommitScope,
        target: String,
        expectedActionDigest: String,
        expectedPolicyHash: String
    ) async throws {
        guard token.allowedTargets.contains(target) else {
            throw EnforcementError.targetNotAllowed(
                tokenID: token.tokenID, target: target)
        }
        try await authority.verifyCommitToken(
            token,
            expectedScope: scope,
            expectedActionDigest: expectedActionDigest,
            expectedPolicyHash: expectedPolicyHash,
            redeem: true)
    }
}
