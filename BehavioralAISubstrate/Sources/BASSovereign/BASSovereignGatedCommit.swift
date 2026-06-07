// ADR-025 option B + ADR-026 — the host-callable GATED-EXECUTION seam.
//
// The substrate already ships the sovereign commit-gate PRIMITIVES: the deterministic
// Ed25519 mint (`BASSovereignTokenAuthority.issueDeterministicCommitToken`), the
// single-source-of-truth action digest (`BASSovereignActionDigest.compute`), and the
// production enforcer (`BASSovereignCommitEnforcer`: register → authorize). What was
// MISSING is the one-call composition that ties them into a foot-gun-free
// gated-execution call — so a host cannot (a) recompute the action digest incorrectly,
// (b) read the digest off the token instead of from the approved artifact, or
// (c) execute the irreversible op after a FAILED authorization. This struct is that
// glue: it makes ADR-025 option B FUNCTIONAL end-to-end (the way ADR-034 made the
// agent-fabric feed-forward functional end-to-end), not just a set of primitives.
//
// OPT-IN / byte-equal-off (红线 7): nothing constructs a `BASSovereignGatedCommit` by
// default. If a host never builds one (and the enforcer + keyring-backed authority it
// wraps), the substrate is byte-equal — this adds NO behavior to the turn path. When
// the operator wires it, every gated op is cryptographically authenticated against an
// INDEPENDENTLY-recomputed action digest, and the op runs ONLY on a clean authorization.

import Foundation
import BASRuntimeCore

public struct BASSovereignGatedCommit: Sendable {

    private let enforcer: BASSovereignCommitEnforcer

    public init(enforcer: BASSovereignCommitEnforcer) {
        self.enforcer = enforcer
    }

    /// Register a brain-emitted commit token with the authority (mint the authoritative
    /// Ed25519 token + single-use ledger entry) and return the registered token the host
    /// holds for the later `executeGated`. Call once per emitted token, at emission time.
    /// Identity (tokenID / nonce / scope / actionDigest / allowedTargets / …) is preserved
    /// from the brain token; only a real keyed signature + ledger tracking are added.
    @discardableResult
    public func register(
        _ brainToken: BASSovereignCommitToken,
        issuedAt: Date? = nil
    ) async throws -> BASSovereignCommitToken {
        try await enforcer.register(brainToken, issuedAt: issuedAt)
    }

    /// Authorize AND execute an irreversible op in one foot-gun-free call.
    ///
    /// The `expectedActionDigest` is recomputed HERE from the caller-supplied
    /// `approvedArtifactParts` (the EXACT artifact the host is about to act on) via the
    /// single-source-of-truth `BASSovereignActionDigest.compute` — never read off the
    /// token — so a body tampered between authorization and execution fails the digest
    /// check. The `op` closure is invoked ONLY if `authorize` does not throw; on ANY gate
    /// failure (aliased target / tampered digest / replay / TTL / scope / policy / invalid
    /// signature) the error propagates and `op` is NEVER run.
    ///
    /// - Returns: the op's result on a clean authorization.
    /// - Throws: the enforcer/authority error on any gate failure (op not invoked).
    public func executeGated<T: Sendable>(
        token: BASSovereignCommitToken,
        scope: BASSovereignCommitScope,
        target: String,
        approvedArtifactParts: [String],
        sessionID: String,
        turnID: String,
        snapshotRef: String,
        policyHash: String,
        op: @Sendable () async throws -> T
    ) async throws -> T {
        let expectedActionDigest = BASSovereignActionDigest.compute(
            scope: scope,
            actionDigestParts: approvedArtifactParts,
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: snapshotRef,
            policyHash: policyHash)
        try await enforcer.authorize(
            token,
            scope: scope,
            target: target,
            expectedActionDigest: expectedActionDigest,
            expectedPolicyHash: policyHash)
        // Reached ONLY if `authorize` did not throw → safe to perform the irreversible op.
        return try await op()
    }
}
