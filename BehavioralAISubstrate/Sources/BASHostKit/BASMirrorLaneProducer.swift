// MARK: - BASMirrorLaneProducer — ruling ① completion (2026-07-12)
//
// "BASHostKit 负责模型调用、候选汇合、证据绑定" — the producer ORCHESTRATION (prompt
// construction, model invocation through the protocol seam, evidence binding, candidate
// assembly) is HostKit property. The CONCRETE adapter is still constructed by the edge
// and injected (the model itself stays outside the core umbrella — charter T4); this
// type only ever sees `any BASOrganAdapter`.
//
// Evidence binding (ruling ③): every source's content is SHA-256 digested here, at the
// moment it is read, and the digests travel with the candidate into the signed envelope
// — a landed annotation is attributable to the exact evidence bytes it reflected on.

import Foundation
import CryptoKit
import BASOrgan

public enum BASMirrorLaneProducer {

    /// One evidence source the mirror reflects on (id + the content that was read).
    public struct Source: Sendable, Equatable {
        public let id: String
        public let content: String
        public init(id: String, content: String) {
            self.id = id
            self.content = content
        }
    }

    /// The mirror doctrine prompt — a MIRROR, never an oracle.
    public static let mirrorInstruction = """
        You are a MIRROR for a private decision journal — never an oracle. In at most \
        three sentences, reflect one honest observation about the recent entries below: \
        a pattern, a tension, or a question worth sitting with. Do not advise, do not \
        flatter, do not invent facts.
        """

    /// Invoke the injected adapter over the sources and assemble the UNTRUSTED candidate.
    /// Deterministic except for the model call itself: prompt digest and per-source
    /// evidence digests are computed here; the candidate claims `.annotation` (a mirror
    /// comments, it does not propose) and carries the trusted policy hash the CALLER
    /// says this lane runs under (the disposer still verifies it).
    public static func produceCandidate(
        adapter: any BASOrganAdapter,
        sources: [Source],
        trustedPolicyHash: String,
        provenance: String,
        requestID: String,
        maxOutputTokens: Int = 220
    ) async throws -> BASMirrorLaneCandidate {
        let context = sources.map { "- \($0.content)" }.joined(separator: "\n")
        let draft = try await adapter.draft(BASOrganRequest(
            requestID: requestID,
            role: .scout,
            preset: .scout,
            instruction: Self.mirrorInstruction,
            context: [context],
            maxOutputTokens: maxOutputTokens,
            stopSequences: []))

        return BASMirrorLaneCandidate(
            claimedKind: .annotation,
            content: draft.body,
            evidenceIDs: sources.map(\.id),
            evidenceDigests: sources.map { sha256Hex($0.content) },
            modelID: adapter.descriptor.providerID,
            promptDigest: sha256Hex(Self.mirrorInstruction + "\n" + context),
            claimedPolicyHash: trustedPolicyHash,
            provenance: provenance)
    }

    static func sha256Hex(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8))
            .map { String(format: "%02x", $0) }.joined()
    }
}
