import Foundation
import BASRuntimeCore
import BASMemory
import BASSovereign

/// Wires the leaf `BASShadowTrialLedger` protocol (defined in
/// `BASMemory`) to the real append-only audit ledger (`BASSovereignAuditLedger`
/// in `BASSovereign`). Lives in `BASOrchestration` because that is
/// the first module in the dependency graph that can see both:
///
///   BASMemory  (leaf on BASRuntimeCore)
///   BASSovereign (leaf on BASRuntimeCore)
///   BASOrchestration (depends on both)
///
/// Keeping the conformance here means neither leaf module has to take
/// on an extra dependency to get the integration. Memory-only unit
/// tests can still use `BASInMemoryShadowTrialLedger`; integration
/// tests import this bridge and hand the coordinator a real sovereign
/// ledger so the shadow-trial chain and the sovereign verdict chain
/// share the same hash chain.
///
/// ## Field mapping
///
/// `BASShadowTrialLedgerEntry` is neutral; `BASSovereignAuditEntry`
/// is the sovereign-specific schema. The mapping is 1:1 across every
/// scalar. One deliberate asymmetry: `signature: ""` is passed so the
/// sovereign ledger computes the HMAC-SHA256 signature itself. The
/// coordinator's `signaturePayload` is the content-addressed string
/// used for seal.signature on the `BASEvolutionSeal` side (a plain
/// schema field, not a ledger signature); the ledger's signature is
/// derived from the canonical entry bytes + prior-hash chain so it's
/// dependent on chain position, which is exactly the guarantee we
/// want for tamper detection.
///
/// The bridge never reinterprets fields or adds fields of its own.
/// If the coordinator hands in an entry, every scalar field reaches
/// the ledger verbatim; if the ledger rejects it (bad chain, invalid
/// entry, tamper), the coordinator sees the throw and rolls back.
extension BASSovereignAuditLedger: BASShadowTrialLedger {
    public func appendShadowTrialEvent(
        _ entry: BASShadowTrialLedgerEntry
    ) async throws -> String {
        // chapter 九百九十六.5 Round-15 CRITICAL-2:hardened
        // canonical-bytes — Shadow trial bridge re-wraps caller-
        // supplied opaque ruleIDs/signalRefs/actionRefs which IS
        // the exact comma-collision attack surface ch 993 patched
        let draft = BASSovereignAuditEntry(
            // ch 1011 / M3770 — Round-21 HIGH-1: shared constant
            schemaVersion: BASSovereignAuditEntry
                .hardenedSchemaVersion,
            auditID: entry.auditID,
            sessionID: entry.sessionID,
            turnID: entry.turnID,
            verdictRef: entry.verdictRef,
            ruleIDs: entry.ruleIDs,
            signalRefs: entry.signalRefs,
            actionRefs: entry.actionRefs,
            snapshotRef: entry.snapshotRef,
            actor: .system,
            signature: "",
            appendedAt: entry.appendedAt)
        let appended = try append(draft)
        return appended.entry.auditID
    }
}
