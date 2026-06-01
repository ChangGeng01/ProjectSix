// ch1044 A3(a)+(c) — a real Ed25519 authenticator + verifier for the host constitution
// vault, plus the approval audit-entry builder. Opt-in / byte-equal-off per ADR-014.
//
// ## The gap this closes
//
// `BASHostConstitutionVault.versionSignature` is `basStableSignature` — an UNKEYED,
// 64-bit-truncated SHA256 over a `joined("|")`/`joined("::")` material. Three weaknesses:
//   1. Unkeyed → it is a CHECKSUM anyone recomputes, not an authenticator. A tamperer who
//      edits the persisted vault (e.g. SHRINKS `boundaryVeil.hardNoGo` to disable a block)
//      simply recomputes `versionSignature`; nothing detects it.
//   2. Truncated to 16 hex chars (64 bits) → collision-weak even as a checksum.
//   3. The material delimiter-joins arrays (`hardNoGo.joined("|")`) → the same forgery
//      class fixed everywhere else this chapter: `["a","b"]` and `["a|b"]` collide.
//
// This component is the real fix: an Ed25519 signature (a true authenticator — unforgeable
// without the private key) over the INJECTIVE canonical bytes of the vault's safety-
// critical material (closing weakness 3), full-length (closing 2), keyed (closing 1).
//
// ## Why this is in BASHostKit (and what is honestly deferred)
//
// The vault type lives in BASMemory; Ed25519 lives in BASSovereign; the two are sibling
// modules (neither imports the other). Only BASHostKit sees both, so the bridge lives
// here. Two integration pieces are deliberately NOT done in this pass (亏的不要上 / 小心翼翼 —
// do not rush a persisted-format migration or invent a key-management scheme on a hunch):
//   - **Key provenance.** `seal`/`verify` take the keypair / public key as a parameter
//     (dependency-injected). A host supplies a `BASSovereignEd25519KeyPair` from its
//     keyring — NOT a per-process random key, NOT `fromSeed("constant")` (test-only). This
//     component does not fabricate the sovereign key-management design.
//   - **Persist + verify-on-load.** The seal is DETACHED (returned as hex). Persisting it
//     alongside the vault (a nullable `sovereign_seal` SQLite column so legacy rows decode
//     to nil and still load) and calling `verify` in the storage load path is the host's
//     opt-in step. Until a host does so, the vault is byte-identical to today
//     (`versionSignature` unchanged) — 红线 7 / byte-equal-off holds.
//
// So, like A1 (ADR-026): the cryptographic core + verifier exist and are tested here; the
// per-host wiring is a bounded, documented integration, not a from-scratch build.

import Foundation
import CryptoKit
import BASMemory
import BASRuntimeCore
import BASSovereign

public enum BASHostConstitutionVaultSovereignSeal {

    /// Domain-separation tag prefixed into the signed material. Prevents a vault seal from
    /// ever being mistaken for (or replayed as) a signature over any other artifact that
    /// happens to share the same field values. Versioned so the layout can evolve.
    public static let sealDomain = "bas.host.constitution.vault.seal/1.0.0"

    // MARK: - Canonical bytes (injective — closes the delimiter-join forgery)

    /// The schema-versioned, INJECTIVE canonical byte layout of the vault's safety-critical
    /// material. Every array is length-counted via `BASSovereignCanonicalBytes.list` and
    /// the whole record is netstring-framed via `.lengthPrefixed`, so no in-band byte (a
    /// `|`, a `,`, a control char inside any caller-supplied ref) can shift a field
    /// boundary and collide two distinct vaults onto one signed pre-image.
    ///
    /// Authenticates the FULL boundary veil (hardNoGo / softCaution / confirmRequired /
    /// restricted{Memory,Tool}Domains) — strictly more than the legacy checksum (which
    /// covered only hardNoGo) — so SHRINKING any boundary list changes the bytes and breaks
    /// the seal. Also covers identity, goals, rollback/export lineage, deletion + sync
    /// revocation refs, device-consistency state, and the migration contract.
    public static func canonicalBytes(
        for vault: BASHostConstitutionVault
    ) -> Data {
        let constitution = vault.constitutionSnapshot
        let veil = constitution.boundaryVeil
        let deletion = vault.deletionManifest
        let migration = vault.migrationContract

        var parts: [String] = [
            sealDomain,
            vault.vaultID,
            vault.constitutionID,
            constitution.hostID,
            constitution.constitutionID,
            constitution.activeVersion
        ]
        parts += BASSovereignCanonicalBytes.list(constitution.goalSpine.goals)
        parts += BASSovereignCanonicalBytes.list(veil.hardNoGo)
        parts += BASSovereignCanonicalBytes.list(veil.softCaution)
        parts += BASSovereignCanonicalBytes.list(veil.confirmRequired)
        parts += BASSovereignCanonicalBytes.list(veil.restrictedMemoryDomains)
        parts += BASSovereignCanonicalBytes.list(veil.restrictedToolDomains)
        parts += BASSovereignCanonicalBytes.list(vault.rollbackLineage)
        parts += BASSovereignCanonicalBytes.list(vault.exportInvalidationManifest)
        parts.append(deletion?.requestID ?? "")
        parts += BASSovereignCanonicalBytes.list(deletion?.targetRefs ?? [])
        parts += BASSovereignCanonicalBytes.list(vault.syncRevocationLedger.revokedRequestIDs)
        parts += BASSovereignCanonicalBytes.list(vault.syncRevocationLedger.revokedExportRefs)
        parts += [
            vault.deviceConsistencyReport.consistencyState,
            migration?.sourceDeviceID ?? "",
            migration?.targetDeviceID ?? "",
            migration?.rollbackVersionID ?? ""
        ]
        return BASSovereignCanonicalBytes.lengthPrefixed(parts)
    }

    // MARK: - Sign / verify

    /// Produce a detached Ed25519 seal (lowercase hex) over the vault's canonical bytes.
    ///
    /// CryptoKit's Ed25519 signing is hedged/randomized (ADR-025), so the seal is NOT
    /// deterministic across calls — that is fine: a seal is signed once at write time,
    /// stored, and later verified. Verification (`isValidSignature`) is stable.
    public static func seal(
        _ vault: BASHostConstitutionVault,
        with keyPair: BASSovereignEd25519KeyPair
    ) throws -> String {
        let signature = try keyPair.privateKey.signature(
            for: canonicalBytes(for: vault))
        return BASAutoRouteRanker.dataToHexLower(signature)
    }

    /// Fail-closed verification: returns `true` ONLY when `sealHex` is a well-formed hex
    /// Ed25519 signature that validates against the vault's recomputed canonical bytes
    /// under `publicKey`. A malformed hex string, a tampered vault field (a shrunk
    /// hardNoGo, an aliased identity), or a wrong key all return `false`.
    public static func verify(
        _ vault: BASHostConstitutionVault,
        sealHex: String,
        publicKey: Curve25519.Signing.PublicKey
    ) -> Bool {
        guard let signature = BASAutoRouteRanker.hexToData(sealHex) else {
            return false
        }
        return publicKey.isValidSignature(
            signature, for: canonicalBytes(for: vault))
    }

    // MARK: - (c) Approval audit entry

    /// Build the hardened (`1.2.0`, injective) audit entry recording a constitution
    /// approval, capturing the `hardNoGo` diff so a SHRINK (the dangerous direction) is
    /// permanently attested in the hash-chained ledger. The returned entry is UNSIGNED
    /// (`signature: ""`); the `BASSovereignAuditLedger` signs + hash-chains it on `append`.
    ///
    /// `signalRefs` carry the diff as `hardNoGo.removed:<entry>` / `hardNoGo.added:<entry>`
    /// codes (sorted, deduped). Removed entries weaken the boundary, so they are the audit
    /// signal that matters most for after-the-fact review.
    public static func approvalAuditEntry(
        vaultBefore: BASHostConstitutionVault?,
        vaultAfter: BASHostConstitutionVault,
        auditID: String,
        sessionID: String,
        turnID: String,
        appendedAt: Date,
        actor: BASSovereignAuditActor = .system
    ) -> BASSovereignAuditEntry {
        let before = Set(vaultBefore?.constitutionSnapshot.boundaryVeil.hardNoGo ?? [])
        let after = Set(vaultAfter.constitutionSnapshot.boundaryVeil.hardNoGo)
        let removed = before.subtracting(after).sorted()
        let added = after.subtracting(before).sorted()
        let signalRefs =
            removed.map { "hardNoGo.removed:\($0)" }
            + added.map { "hardNoGo.added:\($0)" }

        let fromVersion = vaultBefore?.constitutionSnapshot.activeVersion ?? "<none>"
        let toVersion = vaultAfter.constitutionSnapshot.activeVersion

        return BASSovereignAuditEntry(
            schemaVersion: BASSovereignAuditEntry.hardenedSchemaVersion,
            auditID: auditID,
            sessionID: sessionID,
            turnID: turnID,
            verdictRef: "constitution.approval:\(fromVersion)->\(toVersion)",
            ruleIDs: ["BR-CONSTITUTION-APPROVAL"],
            signalRefs: signalRefs,
            actionRefs: ["constitution.vault:\(vaultAfter.vaultID)"],
            snapshotRef: vaultAfter.versionSignature,
            actor: actor,
            signature: "",
            appendedAt: appendedAt)
    }

    /// Convenience: `true` when the approval SHRINKS the hardNoGo set (removes ≥1 entry).
    /// The host uses this to decide whether the high-consequence (dual-key) path is
    /// required — A3(b), deferred to its own session, but the predicate is defined here so
    /// the policy is single-sourced when that wiring lands.
    public static func shrinksHardNoGo(
        vaultBefore: BASHostConstitutionVault?,
        vaultAfter: BASHostConstitutionVault
    ) -> Bool {
        let before = Set(vaultBefore?.constitutionSnapshot.boundaryVeil.hardNoGo ?? [])
        let after = Set(vaultAfter.constitutionSnapshot.boundaryVeil.hardNoGo)
        return !before.subtracting(after).isEmpty
    }
}
