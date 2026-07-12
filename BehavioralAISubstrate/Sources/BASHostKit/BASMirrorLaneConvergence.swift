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
// turn one into a `BASConvergedProposalEnvelope`, and only by stamping TRUSTED values
// (policy hash from the gate's policy, timestamp from the gate's clock) — claimed
// values are checked, never copied through on trust (mirrors BASSovereignGatedTurn's
// recompute-don't-trust posture).
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
        modelID: String,
        promptDigest: String,
        claimedPolicyHash: String,
        provenance: String
    ) {
        self.claimedKind = claimedKind
        self.content = content
        self.evidenceIDs = evidenceIDs.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
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
    public static let signingNamespace = "qinao.mirror.envelope.v1"

    public let envelopeID: String
    public let kind: BASMirrorLaneKind
    public let content: String
    public let contentDigest: String
    public let evidenceIDs: [String]
    public let modelID: String
    public let promptDigest: String
    /// TRUSTED policy hash stamped by the disposer — never the candidate's claim.
    public let policyHash: String
    public let producedAtMs: Int64
    public let provenance: String
    /// HMAC-SHA256 (hex) over `canonicalBytes()`. Empty until `signed(with:)`.
    public let signature: String

    public init(
        envelopeID: String,
        kind: BASMirrorLaneKind,
        content: String,
        contentDigest: String,
        evidenceIDs: [String],
        modelID: String,
        promptDigest: String,
        policyHash: String,
        producedAtMs: Int64,
        provenance: String,
        signature: String
    ) {
        self.envelopeID = envelopeID
        self.kind = kind
        self.content = content
        self.contentDigest = contentDigest
        self.evidenceIDs = evidenceIDs
        self.modelID = modelID
        self.promptDigest = promptDigest
        self.policyHash = policyHash
        self.producedAtMs = producedAtMs
        self.provenance = provenance
        self.signature = signature
    }

    /// Injective canonical payload (signature field excluded by construction).
    /// Arrays enter through `BASSovereignCanonicalBytes.list` so arity is signed;
    /// the namespace is the final field (house domain-separation convention).
    public func canonicalBytes() -> Data {
        var fields = [envelopeID, kind.rawValue, contentDigest]
        fields.append(contentsOf: BASSovereignCanonicalBytes.list(evidenceIDs))
        fields.append(contentsOf: [
            modelID, promptDigest, policyHash,
            String(producedAtMs), provenance,
            Self.signingNamespace,
        ])
        return BASSovereignCanonicalBytes.lengthPrefixed(fields)
    }

    /// Immutable-update: a copy carrying the HMAC tag over the canonical bytes.
    public func signed(with key: SymmetricKey) -> BASConvergedProposalEnvelope {
        let tag = HMAC<SHA256>.authenticationCode(
            for: canonicalBytes(), using: key)
        return BASConvergedProposalEnvelope(
            envelopeID: envelopeID, kind: kind, content: content,
            contentDigest: contentDigest, evidenceIDs: evidenceIDs,
            modelID: modelID, promptDigest: promptDigest,
            policyHash: policyHash, producedAtMs: producedAtMs,
            provenance: provenance,
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

    public enum RejectReason: String, Sendable, Equatable, Codable {
        case emptyContent = "empty-content"
        case contentTooLong = "content-too-long"
        case missingModelID = "missing-model-id"
        case missingPromptDigest = "missing-prompt-digest"
        case policyHashMismatch = "policy-hash-mismatch"
        case kindNotAllowed = "kind-not-allowed"
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
        // Recompute-don't-trust: the claim must MATCH the trusted hash; empty or
        // divergent claims fail closed. The envelope carries the TRUSTED hash.
        guard candidate.claimedPolicyHash == policy.trustedPolicyHash else {
            return .rejected(.policyHashMismatch)
        }
        guard policy.allowedKinds.contains(candidate.claimedKind) else {
            return .rejected(.kindNotAllowed)
        }

        // Evidence rule: a proposal or warrant-request with NO evidence is an opinion —
        // it may annotate, it may not propose. Deterministic demotion, explicit in the
        // disposition so telemetry can see every reduction.
        let effectiveKind: BASMirrorLaneKind
        let droppedKind: BASMirrorLaneKind?
        if candidate.claimedKind != .annotation && candidate.evidenceIDs.isEmpty {
            effectiveKind = .annotation
            droppedKind = candidate.claimedKind
        } else {
            effectiveKind = candidate.claimedKind
            droppedKind = nil
        }

        let envelope = BASConvergedProposalEnvelope(
            envelopeID: envelopeID,
            kind: effectiveKind,
            content: content,
            contentDigest: BASConvergedProposalEnvelope.sha256Hex(content),
            evidenceIDs: candidate.evidenceIDs,
            modelID: candidate.modelID,
            promptDigest: candidate.promptDigest,
            policyHash: policy.trustedPolicyHash,
            producedAtMs: Int64(now.timeIntervalSince1970 * 1000),
            provenance: candidate.provenance,
            signature: "")
            .signed(with: key)

        if let dropped = droppedKind {
            return .reduced(envelope, droppedKind: dropped)
        }
        return .accepted(envelope)
    }
}
