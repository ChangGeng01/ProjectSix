// MARK: - BASMirrorLaneLedgerIngest — mirror-lane charter M3 (2026-07-12)
//
// Operator ruling ③ (Docs/MIRROR_LANE_CHARTER_2026-07-12.md): the Ledger accepts ONLY
// signed canonical proposal envelopes; unsigned / schema-invalid are rejected outright
// — typed reason, ZERO partial writes. Pipeline order is fixed:
// validate → canonicalize → sign (BASMirrorLaneDisposer) → THIS GATE (verify) → append.
//
// The gate verifies the envelope's HMAC tag and schema BEFORE anything touches the
// sovereign audit chain; on success it appends a digest-bearing audit entry (the
// Ledger stores contentDigest as snapshotRef — digest-not-content doctrine; the raw
// text stays with the host / content sidecar). The append itself is sealed by the
// audit ledger's OWN key (Ed25519/HMAC per its configuration) — the envelope tag and
// the chain seal are two separate signatures with two separate jobs: the tag proves
// the envelope came through the deterministic disposer; the seal proves the chain.
//
// Hot-path convention: non-throwing outcome struct with honest reason — errors are
// surfaced, not swallowed (BASSovereignLedgerHostSink precedent).

import Foundation
import CryptoKit
import BASRuntimeCore
import BASSovereign

public enum BASMirrorLaneIngestGate {

    public enum RejectReason: String, Sendable, Equatable, Codable {
        case badSignature = "bad-signature"
        case contentDigestMismatch = "content-digest-mismatch"
        case emptyModelID = "empty-model-id"
        case emptyPromptDigest = "empty-prompt-digest"
        case emptyPolicyHash = "empty-policy-hash"
        /// ruling ③ hardening: same envelope presented twice — typed, on ANY storage
        /// (was an untyped append failure, and only SQLite's PRIMARY KEY caught it).
        case replayed = "replayed"
        /// ruling ③ hardening: evidence IDs/digests unpaired at the gate.
        case evidenceDigestMismatch = "evidence-digest-mismatch"
        case appendFailed = "append-failed"
    }

    /// Honest outcome: `appended == false` always carries a reason.
    public struct IngestOutcome: Sendable, Equatable {
        public let appended: Bool
        public let auditID: String?
        public let reason: RejectReason?

        public init(appended: Bool, auditID: String?, reason: RejectReason?) {
            self.appended = appended
            self.auditID = auditID
            self.reason = reason
        }
    }

    /// Verify-then-append. Any failure returns a typed rejection BEFORE the ledger is
    /// touched — there is no partial write to roll back.
    @discardableResult
    public static func ingest(
        _ envelope: BASConvergedProposalEnvelope,
        key: SymmetricKey,
        ledger: BASSovereignAuditLedger,
        sessionID: String,
        turnID: String,
        now: Date = Date()
    ) async -> IngestOutcome {
        // 1. Signature FIRST (fail closed — an unsigned or tampered envelope never
        //    reaches schema inspection, let alone the chain).
        guard envelope.verifySignature(with: key) else {
            return IngestOutcome(appended: false, auditID: nil, reason: .badSignature)
        }
        // 2. Schema: the ruling-③ provenance fields must be present, and the content
        //    must still match its signed digest (a post-signing content swap dies here).
        guard envelope.contentDigest
            == BASConvergedProposalEnvelope.sha256Hex(envelope.content) else {
            return IngestOutcome(
                appended: false, auditID: nil, reason: .contentDigestMismatch)
        }
        guard !envelope.modelID.isEmpty else {
            return IngestOutcome(appended: false, auditID: nil, reason: .emptyModelID)
        }
        guard !envelope.promptDigest.isEmpty else {
            return IngestOutcome(
                appended: false, auditID: nil, reason: .emptyPromptDigest)
        }
        guard !envelope.policyHash.isEmpty else {
            return IngestOutcome(appended: false, auditID: nil, reason: .emptyPolicyHash)
        }
        guard envelope.evidenceIDs.count == envelope.evidenceDigests.count else {
            return IngestOutcome(
                appended: false, auditID: nil, reason: .evidenceDigestMismatch)
        }

        // 2b. Replay: the envelopeID is the signed nonce; its derived auditID must be NEW
        //     on this chain. Typed reject, zero writes. HONEST SCOPE (deep-audit L-3,
        //     2026-07-13): this hasEntry→append pair is race-free under SEQUENTIAL ingest
        //     on any backend, and additionally CONCURRENT-safe on persistent storage where
        //     `audit_id PRIMARY KEY` is the authoritative backstop (both production callers
        //     wire SQLite single-shot). On the in-memory null-storage ledger (test/
        //     ephemeral), two truly-concurrent ingests of the same envelope could both pass
        //     this check before either appends — a non-production race, not covered here.
        let auditID = "mirror-\(envelope.envelopeID)"
        if await ledger.hasEntry(auditID: auditID) {
            return IngestOutcome(appended: false, auditID: nil, reason: .replayed)
        }

        // 3. Append a digest-bearing audit entry. verdictRef encodes the lane + kind
        //    (mirror lane never mutates existing entries — this is an append-only
        //    annotation of the chain); signalRefs carry the full signed provenance so
        //    the landed row is attributable without the raw content.
        let draft = BASSovereignAuditEntry(
            // Hardened injective canonical form — REQUIRED: floored ledgers (e.g. the
            // journal's makeLedger sets minimumSchemaVersion 1.2.0) reject sub-hardened
            // drafts, and a security lane has no business emitting the non-injective form.
            schemaVersion: BASSovereignAuditEntry.hardenedSchemaVersion,
            auditID: auditID,
            sessionID: sessionID,
            turnID: turnID,
            verdictRef: "mirror.ingest|kind:\(envelope.kind.rawValue)",
            ruleIDs: ["mirror.lane.v1"],
            signalRefs: [
                "model:\(envelope.modelID)",
                "prompt:\(envelope.promptDigest)",
                "policy:\(envelope.policyHash)",
                "reducer:\(envelope.reducerVersion)",
                "producedAtMs:\(envelope.producedAtMs)",
                "provenance:\(envelope.provenance)",
                "signerKey:\(envelope.signerKeyID)",
                "envelopeTag:\(envelope.signature)",
            ] + zip(envelope.evidenceIDs, envelope.evidenceDigests)
                .map { "evidence:\($0.0)#\($0.1)" },
            actionRefs: [],
            snapshotRef: envelope.contentDigest,
            actor: .system,
            signature: "",
            appendedAt: now)
        do {
            let appended = try await ledger.append(draft)
            return IngestOutcome(
                appended: true, auditID: appended.entry.auditID, reason: nil)
        } catch {
            return IngestOutcome(appended: false, auditID: nil, reason: .appendFailed)
        }
    }
}
