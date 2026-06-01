// ch1044 A3(b) — dual-key gate on boundary-WEAKENING constitution approvals. Opt-in /
// byte-equal-off per ADR-014.
//
// ## The risk
//
// A constitution approval that SHRINKS the block-list — removes an entry from
// `boundaryVeil.hardNoGo` or `boundaryVeil.confirmRequired` — weakens a sovereign safety
// boundary. Single-actor approval means a single compromised principal can quietly disable
// a red line. Routine approvals (adding boundaries, editing non-boundary fields) carry no
// such risk and must stay frictionless.
//
// ## The gate
//
// `BASConstitutionApprovalGate` classifies an approval (before → after vault) and, for the
// high-consequence (shrinking) case, requires a valid `BASSovereignDualKeyCommit` — two
// independent principals' signatures over a digest that binds the EXACT transition — via
// the existing `BASSovereignHighConsequenceGate`. It does not classify or gate anything
// the caller hasn't opted into: a host that never constructs a gate and never calls
// `requireAuthorized` sees the current single-actor behavior unchanged (byte-equal-off).
//
// Like the vault seal (ADR-027) this lives in BASHostKit — the only layer that sees both
// the BASMemory vault type and the BASSovereign dual-key primitives. The two approver keys
// come from the host's keyring (`BASSovereignKeychainBinding`), NOT per-process random keys.
//
// ## Honest scope (A1 pattern)
//
// The gate + the transition digest exist and are tested. The per-host wiring — calling
// `requireAuthorized` at the constitution approval site (`approve(candidate:on:)`, today a
// pure value transform with no key) before persisting the new version — is the operator's
// opt-in step, and is deferred with the rest of the host integration (ADR-027 §5).

import Foundation
import CryptoKit
import BASMemory
import BASRuntimeCore
import BASSovereign

public enum BASConstitutionApprovalGate {

    /// Domain-separation tag for the approval intent digest.
    public static let intentDomain = "bas.constitution.approval/1.0.0"

    /// Thrown by `requireAuthorized` when a shrinking approval lacks a valid dual-key commit.
    public enum ApprovalError: Error, Equatable, Sendable {
        case dualKeyRequired(hostID: String)
    }

    // MARK: - Classification

    /// `true` when the approval removes ≥1 entry from `hardNoGo` or `confirmRequired` — the
    /// boundary-weakening directions that require dual-key. Adding entries, reordering, or
    /// editing non-boundary fields is NOT high-consequence.
    public static func isHighConsequence(
        vaultBefore: BASHostConstitutionVault?,
        vaultAfter: BASHostConstitutionVault
    ) -> Bool {
        shrinks(\.hardNoGo, vaultBefore, vaultAfter)
            || shrinks(\.confirmRequired, vaultBefore, vaultAfter)
    }

    /// Map the approval to a sovereign intent class for `BASSovereignHighConsequenceGate`.
    public static func classify(
        vaultBefore: BASHostConstitutionVault?,
        vaultAfter: BASHostConstitutionVault
    ) -> BASSovereignIntentClass {
        isHighConsequence(vaultBefore: vaultBefore, vaultAfter: vaultAfter)
            ? .highConsequence : .routine
    }

    private static func shrinks(
        _ keyPath: KeyPath<BASBoundaryVeil, [String]>,
        _ before: BASHostConstitutionVault?,
        _ after: BASHostConstitutionVault
    ) -> Bool {
        let beforeSet = Set(
            before?.constitutionSnapshot.boundaryVeil[keyPath: keyPath] ?? [])
        let afterSet = Set(after.constitutionSnapshot.boundaryVeil[keyPath: keyPath])
        return !beforeSet.subtracting(afterSet).isEmpty
    }

    // MARK: - Transition digest

    /// A 32-byte digest binding the EXACT approval transition: host, from/to version, and
    /// the full before+after `hardNoGo` + `confirmRequired` sets, encoded injectively (so a
    /// dual-key commit cannot be replayed onto a different transition). The two approvers
    /// sign this digest; the gate checks `commit.intentDigest == this`.
    public static func intentDigest(
        vaultBefore: BASHostConstitutionVault?,
        vaultAfter: BASHostConstitutionVault
    ) -> Data {
        let before = vaultBefore?.constitutionSnapshot
        let after = vaultAfter.constitutionSnapshot
        var parts: [String] = [
            intentDomain,
            after.hostID,
            before?.activeVersion ?? "<none>",
            after.activeVersion
        ]
        parts += BASSovereignCanonicalBytes.list(before?.boundaryVeil.hardNoGo ?? [])
        parts += BASSovereignCanonicalBytes.list(after.boundaryVeil.hardNoGo)
        parts += BASSovereignCanonicalBytes.list(before?.boundaryVeil.confirmRequired ?? [])
        parts += BASSovereignCanonicalBytes.list(after.boundaryVeil.confirmRequired)
        return Data(SHA256.hash(data: BASSovereignCanonicalBytes.lengthPrefixed(parts)))
    }

    // MARK: - Authorization

    /// `true` if the approval is permitted: routine approvals always pass; a shrinking
    /// (high-consequence) approval passes only with a `commit` whose `intentDigest` equals
    /// `intentDigest(before, after)` and whose two signatures both verify under the gate's
    /// verifier.
    public static func authorize(
        vaultBefore: BASHostConstitutionVault?,
        vaultAfter: BASHostConstitutionVault,
        gate: BASSovereignHighConsequenceGate,
        commit: BASSovereignDualKeyCommit?
    ) -> Bool {
        gate.authorize(
            intentClass: classify(vaultBefore: vaultBefore, vaultAfter: vaultAfter),
            intentDigest: intentDigest(vaultBefore: vaultBefore, vaultAfter: vaultAfter),
            commit: commit)
    }

    /// Fail-closed wrapper: throws `dualKeyRequired` when a shrinking approval is not
    /// authorized. A host calls this at the approval site before persisting the new version.
    public static func requireAuthorized(
        vaultBefore: BASHostConstitutionVault?,
        vaultAfter: BASHostConstitutionVault,
        gate: BASSovereignHighConsequenceGate,
        commit: BASSovereignDualKeyCommit?
    ) throws {
        guard authorize(
            vaultBefore: vaultBefore, vaultAfter: vaultAfter,
            gate: gate, commit: commit)
        else {
            throw ApprovalError.dualKeyRequired(
                hostID: vaultAfter.constitutionSnapshot.hostID)
        }
    }
}
