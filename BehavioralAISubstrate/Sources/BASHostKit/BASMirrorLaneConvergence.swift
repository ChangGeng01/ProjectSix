// MARK: - BASMirrorLaneConvergence — mirror-lane charter M1+M2 (2026-07-12)
//
// Operator rulings ①② (Docs/MIRROR_LANE_CHARTER_2026-07-12.md):
//   ① Convergence lives in BASHostKit. QinaoRuntime only CONSUMES converged signed
//     proposal envelopes — no SDK-side convergence machinery.
//   ② The Ledger stays deterministic; the mirror lane's output universe is CLOSED
//     (proposal | warrant-request | annotation) and NOTHING here mutates the Ledger.
//     LLM output enters as an UNTRUSTED CANDIDATE and is disposed by a deterministic
//     accept / reject / reduce gate.
//
// Untrusted-ness is STRUCTURAL, not a Bool flag (house pattern — 红线 7 hint-only):
// `BASMirrorLaneCandidate` is a value type with zero authority. Only the disposer can
// turn one into a `BASConvergedProposalEnvelope`.
//
// deep-audit P1-11 (2026-07-13) — doc honesty. The prior header claimed "claimed values
// are checked, never copied through on trust". That overstated: the disposer treats the
// envelope's fields in TWO distinct ways, and most producer-supplied fields are bound
// AS CLAIMED (signed as-is), not recomputed:
//
//   STAMPED / recomputed (gate-authoritative, the producer cannot influence):
//     • policyHash     — recompute-checked: MUST equal the gate's trustedPolicyHash, then
//                        the TRUSTED hash is stamped (the claim is never copied through)
//     • producedAtMs   — from the gate's injected clock
//     • contentDigest  — recomputed here over the trimmed content
//     • kind           — the EFFECTIVE (post-demotion) kind, re-checked against policy
//     • reducerVersion, signerKeyID — stamped by the gate
//
//   BOUND AS CLAIMED (producer-supplied, signed as-is; only PRESENCE / PAIRING checked,
//   NOT validated against a source of truth):
//     • modelID, promptDigest — non-empty checked
//     • provenance            — non-empty checked (P1-11); still producer-attributed
//     • evidenceIDs / evidenceDigests — pairing + non-blank checked (P1-10); the referenced
//                        content is NOT re-hashed against a store at the dispose site
//
// This is safe at HEAD because the only untrusted producer (the LLM) controls just the
// `content` field (digest-bound at dispose AND ingest); the claimed-metadata fields come
// from trusted HostKit producer code. Hardening those to store-verified values is deferred
// to the future M4 / IPC seam (see P1-11), when an untrusted party could mint candidates.
//
// Signing (ruling ③): AFTER canonicalization, BEFORE ledger ingest. Canonical bytes
// via BASSovereignCanonicalBytes (injective netstrings + arity marker — never
// delimiter-join, ch1044). The signed payload binds envelopeID, kind, contentDigest,
// evidenceIDs (arity-guarded), modelID, promptDigest, policyHash, producedAtMs,
// provenance, and the domain namespace as the final field.

import Foundation
import CryptoKit
import BASRuntimeCore

/// The mirror lane's closed output universe (operator ruling ②). `warrantRequest` is
/// deliberately NOT `warrant`: the lane may REQUEST a warrant; minting stays sovereign.
public enum BASMirrorLaneKind: String, Sendable, Equatable, Codable, CaseIterable {
    case proposal
    case warrantRequest = "warrant-request"
    case annotation
}

/// UNTRUSTED input: what an LLM (or any fallible producer) claims. Zero authority —
/// nothing downstream accepts this type; it exists only to be disposed by
/// `BASMirrorLaneDisposer`. Claimed fields are validated against trusted values,
/// never trusted themselves.
public struct BASMirrorLaneCandidate: Sendable, Equatable, Codable {
    public let claimedKind: BASMirrorLaneKind
    public let content: String
    public let evidenceIDs: [String]
    /// ruling ③ hardening (2026-07-12): the CONTENT hash of each evidence item, paired
    /// 1:1 with `evidenceIDs`. Binding IDs alone let the referenced content be swapped
    /// after signing; the disposer rejects a count mismatch and the digests are signed.
    public let evidenceDigests: [String]
    public let modelID: String
    public let promptDigest: String
    /// The policy the producer CLAIMS it ran under — checked against the gate's
    /// trusted hash, never copied through.
    public let claimedPolicyHash: String
    public let provenance: String

    public init(
        claimedKind: BASMirrorLaneKind,
        content: String,
        evidenceIDs: [String],
        evidenceDigests: [String] = [],
        modelID: String,
        promptDigest: String,
        claimedPolicyHash: String,
        provenance: String
    ) {
        self.claimedKind = claimedKind
        self.content = content
        // deep-audit P1-10 (2026-07-13): TRIM per element but do NOT independently empty-filter
        // the two arrays. The old `.filter { !$0.isEmpty }` on each array separately dropped
        // blanks at different indices, silently shifting surviving IDs onto the wrong digests
        // while keeping counts equal. Lengths are preserved here; the disposer (the trust
        // boundary, and the only signed-envelope mint) fails closed on any empty-after-trim
        // entry — a rule Codable-decode cannot bypass because it skips this init entirely.
        self.evidenceIDs = evidenceIDs.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        self.evidenceDigests = evidenceDigests.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        self.modelID = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.promptDigest = promptDigest.trimmingCharacters(in: .whitespacesAndNewlines)
        self.claimedPolicyHash = claimedPolicyHash
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.provenance = provenance.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// The converged, signed, canonical proposal envelope (ruling ③). Every provenance
/// field the ruling names is a signed part of the canonical payload; `content` itself
/// is bound via `contentDigest` (digest-not-content doctrine — the Ledger never needs
/// the raw text to verify the envelope).
public struct BASConvergedProposalEnvelope: Sendable, Equatable, Codable {
    /// ruling ③ hardening (2026-07-12): v2 — the canonical payload gained
    /// evidenceDigests (content binding, not just IDs), reducerVersion (which
    /// accept/reject/reduce semantics produced this), and signerKeyID (which key signed
    /// it — rotation-attributable). v1 envelopes fail verification BY DESIGN: schema
    /// evolution of a signed format is explicit, never silent.
    public static let signingNamespace = "qinao.mirror.envelope.v2"

    public let envelopeID: String
    public let kind: BASMirrorLaneKind
    public let content: String
    public let contentDigest: String
    public let evidenceIDs: [String]
    /// Content hash per evidence item, index-paired with `evidenceIDs` (signed).
    public let evidenceDigests: [String]
    public let modelID: String
    public let promptDigest: String
    /// TRUSTED policy hash stamped by the disposer — never the candidate's claim.
    public let policyHash: String
    /// Version of the disposer semantics that produced this envelope (signed).
    public let reducerVersion: String
    public let producedAtMs: Int64
    public let provenance: String
    /// Fingerprint of the signing key (first 16 hex of SHA-256 over the key bytes) —
    /// signed, so a landed envelope is attributable to a key generation.
    public let signerKeyID: String
    /// HMAC-SHA256 (hex) over `canonicalBytes()`. Empty until `signed(with:)`.
    public let signature: String

    public init(
        envelopeID: String,
        kind: BASMirrorLaneKind,
        content: String,
        contentDigest: String,
        evidenceIDs: [String],
        evidenceDigests: [String],
        modelID: String,
        promptDigest: String,
        policyHash: String,
        reducerVersion: String,
        producedAtMs: Int64,
        provenance: String,
        signerKeyID: String,
        signature: String
    ) {
        self.envelopeID = envelopeID
        self.kind = kind
        self.content = content
        self.contentDigest = contentDigest
        self.evidenceIDs = evidenceIDs
        self.evidenceDigests = evidenceDigests
        self.modelID = modelID
        self.promptDigest = promptDigest
        self.policyHash = policyHash
        self.reducerVersion = reducerVersion
        self.producedAtMs = producedAtMs
        self.provenance = provenance
        self.signerKeyID = signerKeyID
        self.signature = signature
    }

    /// Injective canonical payload (signature field excluded by construction).
    /// Arrays enter through `BASSovereignCanonicalBytes.list` so arity is signed;
    /// the namespace is the final field (house domain-separation convention).
    public func canonicalBytes() -> Data {
        var fields = [envelopeID, kind.rawValue, contentDigest]
        fields.append(contentsOf: BASSovereignCanonicalBytes.list(evidenceIDs))
        fields.append(contentsOf: BASSovereignCanonicalBytes.list(evidenceDigests))
        fields.append(contentsOf: [
            modelID, promptDigest, policyHash, reducerVersion,
            String(producedAtMs), provenance, signerKeyID,
            Self.signingNamespace,
        ])
        return BASSovereignCanonicalBytes.lengthPrefixed(fields)
    }

    /// Fingerprint of an HMAC key: first 16 hex chars of SHA-256 over the raw key bytes.
    public static func keyID(of key: SymmetricKey) -> String {
        let digest = key.withUnsafeBytes { SHA256.hash(data: Data($0)) }
        return String(digest.map { String(format: "%02x", $0) }.joined().prefix(16))
    }

    /// Immutable-update: a copy carrying the HMAC tag over the canonical bytes.
    public func signed(with key: SymmetricKey) -> BASConvergedProposalEnvelope {
        let tag = HMAC<SHA256>.authenticationCode(
            for: canonicalBytes(), using: key)
        return BASConvergedProposalEnvelope(
            envelopeID: envelopeID, kind: kind, content: content,
            contentDigest: contentDigest, evidenceIDs: evidenceIDs,
            evidenceDigests: evidenceDigests,
            modelID: modelID, promptDigest: promptDigest,
            policyHash: policyHash, reducerVersion: reducerVersion,
            producedAtMs: producedAtMs,
            provenance: provenance, signerKeyID: signerKeyID,
            signature: Data(tag).map { String(format: "%02x", $0) }.joined())
    }

    /// Constant-time verification of the HMAC tag (non-throwing by house convention —
    /// parse failure == integrity failure == false).
    public func verifySignature(with key: SymmetricKey) -> Bool {
        guard signature.count == 64, signature.count % 2 == 0 else { return false }
        var raw = Data(capacity: 32)
        var index = signature.startIndex
        while index < signature.endIndex {
            let next = signature.index(index, offsetBy: 2)
            guard let byte = UInt8(signature[index..<next], radix: 16) else {
                return false
            }
            raw.append(byte)
            index = next
        }
        return HMAC<SHA256>.isValidAuthenticationCode(
            raw, authenticating: canonicalBytes(), using: key)
    }

    public static func sha256Hex(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8))
            .map { String(format: "%02x", $0) }.joined()
    }
}

/// Deterministic disposition policy. All thresholds explicit — no hidden magic numbers.
public struct BASMirrorLanePolicy: Sendable, Equatable {
    /// The TRUSTED policy hash the gate stamps into accepted envelopes. Candidates
    /// claiming a different (or empty) hash are rejected.
    public let trustedPolicyHash: String
    /// Hard cap on content length; beyond it the candidate is rejected (a mirror
    /// comment is a remark, not an essay).
    public let maxContentLength: Int
    public let allowedKinds: Set<BASMirrorLaneKind>

    public init(
        trustedPolicyHash: String,
        maxContentLength: Int = 4_000,
        allowedKinds: Set<BASMirrorLaneKind> = Set(BASMirrorLaneKind.allCases)
    ) {
        self.trustedPolicyHash = trustedPolicyHash
        self.maxContentLength = maxContentLength
        self.allowedKinds = allowedKinds
    }
}

/// The deterministic accept / reject / reduce gate (ruling ②). Pure function of
/// (candidate, policy, clock, key) — no LLM, no I/O, no hidden state.
public enum BASMirrorLaneDisposer {

    /// Version of THIS disposer's accept/reject/reduce semantics — stamped and SIGNED
    /// into every envelope so downstream can tell which rules produced it. Bump when
    /// the demotion/validation rules change meaning.
    public static let reducerVersion = "mirror-disposer.v1"

    public enum RejectReason: String, Sendable, Equatable, Codable {
        case emptyContent = "empty-content"
        case contentTooLong = "content-too-long"
        case missingModelID = "missing-model-id"
        case missingPromptDigest = "missing-prompt-digest"
        case policyHashMismatch = "policy-hash-mismatch"
        case kindNotAllowed = "kind-not-allowed"
        /// ruling ③ hardening: evidenceDigests must pair 1:1 with evidenceIDs —
        /// unpair-able evidence is unverifiable evidence.
        case evidenceDigestMismatch = "evidence-digest-mismatch"
        /// deep-audit P1-10 (2026-07-13): an empty-after-trim entry on EITHER evidence side.
        /// A blank ID or digest makes the index-pairing ambiguous — fail closed rather than
        /// drop-and-shift (which silently re-pairs surviving entries across the gap).
        case evidenceEntryEmpty = "evidence-entry-empty"
        /// deep-audit P1-11 (2026-07-13): provenance is a producer-CLAIMED field bound (signed)
        /// as-is — it is not recomputed against any source of truth. At minimum it must be
        /// PRESENT: an envelope that attributes itself to nothing is unattributable. Fail closed.
        case missingProvenance = "missing-provenance"
    }

    public enum Disposition: Sendable, Equatable {
        /// Candidate passed every deterministic check — canonicalized + signed.
        case accepted(BASConvergedProposalEnvelope)
        /// Candidate is unusable; nothing enters the lane. Typed reason, no partial output.
        case rejected(RejectReason)
        /// Candidate over-claimed (proposal/warrant-request without evidence) —
        /// REDUCED to the safe annotation subset, signed. The demotion is explicit.
        case reduced(BASConvergedProposalEnvelope, droppedKind: BASMirrorLaneKind)
    }

    /// Dispose one untrusted candidate. Order: schema checks (reject) → evidence rule
    /// (reduce) → canonicalize → sign. Trusted values are STAMPED: policyHash from the
    /// policy, producedAtMs from the injected clock, contentDigest recomputed here.
    public static func dispose(
        _ candidate: BASMirrorLaneCandidate,
        policy: BASMirrorLanePolicy,
        key: SymmetricKey,
        envelopeID: String,
        now: Date
    ) -> Disposition {
        let content = candidate.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return .rejected(.emptyContent) }
        guard content.count <= policy.maxContentLength else {
            return .rejected(.contentTooLong)
        }
        guard !candidate.modelID.isEmpty else { return .rejected(.missingModelID) }
        guard !candidate.promptDigest.isEmpty else {
            return .rejected(.missingPromptDigest)
        }
        // deep-audit P1-11 (2026-07-13): provenance is signed as-CLAIMED (never recomputed) —
        // enforce at least its PRESENCE so no signed envelope attributes itself to nothing.
        guard !candidate.provenance.isEmpty else {
            return .rejected(.missingProvenance)
        }
        // Recompute-don't-trust: the claim must MATCH the trusted hash; empty or
        // divergent claims fail closed. The envelope carries the TRUSTED hash.
        guard candidate.claimedPolicyHash == policy.trustedPolicyHash else {
            return .rejected(.policyHashMismatch)
        }
        guard policy.allowedKinds.contains(candidate.claimedKind) else {
            return .rejected(.kindNotAllowed)
        }
        // deep-audit P1-10 (2026-07-13): enforce evidence PAIRING at the trust boundary,
        // fail-closed. The candidate init no longer empty-FILTERS the two arrays independently
        // (that dropped blanks at different indices and silently shifted surviving IDs onto the
        // wrong digests while keeping counts equal). Here — the only path that can mint a signed
        // envelope, and the one Codable-decode CANNOT bypass — any empty-after-trim entry on
        // either side is rejected before the count check, so a surviving pair is always the
        // pair the producer actually stated at that index.
        let trimmedEvidenceIDs = candidate.evidenceIDs.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let trimmedEvidenceDigests = candidate.evidenceDigests.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !trimmedEvidenceIDs.contains(where: { $0.isEmpty }),
              !trimmedEvidenceDigests.contains(where: { $0.isEmpty }) else {
            return .rejected(.evidenceEntryEmpty)
        }
        // ruling ③ hardening: every evidence ID must carry its content digest (1:1) —
        // ID-only evidence lets the referenced content be swapped after signing.
        guard trimmedEvidenceIDs.count == trimmedEvidenceDigests.count else {
            return .rejected(.evidenceDigestMismatch)
        }

        // Evidence rule: a proposal or warrant-request with NO evidence is an opinion —
        // it may annotate, it may not propose. Deterministic demotion, explicit in the
        // disposition so telemetry can see every reduction.
        let effectiveKind: BASMirrorLaneKind
        let droppedKind: BASMirrorLaneKind?
        if candidate.claimedKind != .annotation && trimmedEvidenceIDs.isEmpty {
            effectiveKind = .annotation
            droppedKind = candidate.claimedKind
        } else {
            effectiveKind = candidate.claimedKind
            droppedKind = nil
        }
        // deep-audit L-6 (2026-07-13): re-validate the EFFECTIVE kind against the policy.
        // The claimed-kind check above runs before demotion; a policy that excludes
        // `.annotation` must still reject a demoted-to-annotation envelope rather than sign
        // and emit a kind the policy disallowed. (Filter-completeness — demotion is always
        // toward lowest authority, so this cannot escalate; it closes the exclusion gap.)
        guard policy.allowedKinds.contains(effectiveKind) else {
            return .rejected(.kindNotAllowed)
        }

        let envelope = BASConvergedProposalEnvelope(
            envelopeID: envelopeID,
            kind: effectiveKind,
            content: content,
            contentDigest: BASConvergedProposalEnvelope.sha256Hex(content),
            evidenceIDs: trimmedEvidenceIDs,
            evidenceDigests: trimmedEvidenceDigests,
            modelID: candidate.modelID,
            promptDigest: candidate.promptDigest,
            policyHash: policy.trustedPolicyHash,
            reducerVersion: Self.reducerVersion,
            producedAtMs: Int64(now.timeIntervalSince1970 * 1000),
            provenance: candidate.provenance,
            signerKeyID: BASConvergedProposalEnvelope.keyID(of: key),
            signature: "")
            .signed(with: key)

        if let dropped = droppedKind {
            return .reduced(envelope, droppedKind: dropped)
        }
        return .accepted(envelope)
    }
}
