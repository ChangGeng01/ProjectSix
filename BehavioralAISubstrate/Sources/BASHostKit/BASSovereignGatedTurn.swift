// ADR-032 — the host-side LIVE crypto commit-gate over a completed turn.
//
// `runTurn` is a PURE emit-only function: it COMPUTES + EMITS the sovereign commit
// tokens (keyless SHA256) in the result; the HOST executes the irreversible ops (persist
// the fold, apply update tickets, render). So the crypto gate is HOST-SIDE *by
// architecture* — there is no in-process op inside `runTurn` to gate (a gate there is
// structurally impossible). This is that host-side gate: given the turn's emitted commit
// tokens + the settled artifact + a keyring-backed enforcer, it authorizes the token for
// a scope against the ACTUAL artifact (recomputed via the shared
// `BASSovereignTurnArtifactParts`), then runs the host's irreversible op ONLY on success.
//
// Fail-closed (mirrors lineage-fail-closed): no emitted token for the scope (the brain
// did NOT authorize it — e.g. verdict >= quarantine, or the permission was revoked), an
// unsupported scope, OR any authorization failure (aliased target / tampered artifact /
// replay / TTL / invalid signature) → throws, and the op is NEVER run.
//
// OPT-IN / byte-equal-off (红线 7): a host that never calls this is byte-identical — the
// coordinator / `runTurn` is untouched; this runs only when a host opts into the keyring.

import Foundation
import BASRuntimeCore
import BASSovereign

public enum BASSovereignGatedTurn {

    public enum GateError: Error, Sendable, Equatable {
        /// The turn emitted NO commit token for this scope — the brain did not authorize
        /// the op (verdict >= quarantine, or the permission was revoked). Fail-closed.
        case noCommitTokenForScope(BASSovereignCommitScope)
        /// The scope has no modeled artifact formula → the digest cannot be recomputed.
        case unsupportedScope(BASSovereignCommitScope)
    }

    /// PRIMITIVE core (testable without the heavy turn-result struct). Authorize the
    /// emitted commit token for `scope` against the ACTUAL artifact primitives, then run
    /// `op` ONLY on a clean authorization.
    ///
    /// The expected action digest is recomputed HERE from the artifact primitives (via the
    /// shared `BASSovereignTurnArtifactParts`) — NEVER read off the token — so a tampered
    /// artifact fails. The token's signature-protected identity fields
    /// (sessionID/turnID/snapshotRef/policyHash) are taken from the token: a forged change
    /// to any of them breaks the Ed25519 signature the enforcer verifies.
    ///
    /// `target` MUST be in the token's signed `allowedTargets` (the enforcer rejects an
    /// aliased target). `register` stamps the TTL origin at call time, so the token's TTL
    /// bounds the gate→execute window — gate promptly after the turn.
    ///
    /// - Throws: `GateError` (no token / unsupported scope) or the enforcer/authority
    ///   error on any gate failure — in EVERY failure case `op` is NOT invoked.
    @discardableResult
    public static func gate<T: Sendable>(
        commitTokens: [BASSovereignCommitToken],
        scope: BASSovereignCommitScope,
        target: String,
        foldID: String,
        renderMode: String,
        renderHeadline: String,
        renderBody: String,
        ticketActionDigestParts: [[String]],
        ticketCount: Int,
        enforcer: BASSovereignCommitEnforcer,
        op: @Sendable () async throws -> T
    ) async throws -> T {
        guard let token = commitTokens.first(where: { $0.scope == scope }) else {
            throw GateError.noCommitTokenForScope(scope)
        }
        guard let parts = BASSovereignTurnArtifactParts.parts(
            scope: scope,
            foldID: foldID,
            renderMode: renderMode,
            renderHeadline: renderHeadline,
            renderBody: renderBody,
            ticketActionDigestParts: ticketActionDigestParts,
            ticketCount: ticketCount) else {
            throw GateError.unsupportedScope(scope)
        }
        let registered = try await enforcer.register(token)
        let gated = BASSovereignGatedCommit(enforcer: enforcer)
        return try await gated.executeGated(
            token: registered,
            scope: scope,
            target: target,
            approvedArtifactParts: parts,
            sessionID: token.sessionID,
            turnID: token.turnID,
            snapshotRef: token.snapshotRef,
            policyHash: token.policyHash,
            op: op)
    }

    /// Host convenience — extracts the pieces the gate needs from a completed turn result
    /// and forwards to the primitive core. This is the one call a host turn loop makes to
    /// gate an irreversible op (e.g. `gate(result:, scope: .checkpointCommit, target:
    /// result.thoughtFold.foldID, enforcer:) { persistFold() }`).
    @discardableResult
    public static func gate<T: Sendable>(
        result: BASEBrainTurnResult,
        scope: BASSovereignCommitScope,
        target: String,
        enforcer: BASSovereignCommitEnforcer,
        op: @Sendable () async throws -> T
    ) async throws -> T {
        try await gate(
            commitTokens: result.sovereignCommitTokens,
            scope: scope,
            target: target,
            foldID: result.thoughtFold.foldID,
            renderMode: result.renderedOutput.mode.rawValue,
            renderHeadline: result.renderedOutput.headline,
            renderBody: result.renderedOutput.body,
            ticketActionDigestParts: result.updateTickets.map(\.actionDigestParts),
            ticketCount: result.updateTickets.count,
            enforcer: enforcer,
            op: op)
    }
}
