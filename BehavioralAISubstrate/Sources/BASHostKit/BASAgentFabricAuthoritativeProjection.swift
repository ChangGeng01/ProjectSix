// MARK: - BASAgentFabricAuthoritativeProjection — Step 5 (Agent Fabric authoritative, host feed-forward)
//
// Makes `BASAgentFabricMode.authoritative` actually DO something — safely. Until now the mode was
// inert scaffold (the substrate branched on it nowhere; both modes produced byte-identical output).
//
// ## The design (given the ch883 sync/async boundary)
//
// The fabric runs HOST-SIDE (async: `runAgentFabricObservation` / `BASAgentFabricHostPipeline`) and
// returns a `BASAgentTurnResult` for turn N. The synchronous `runTurn` cannot `await` it, so the
// authoritative path is a HOST-SIDE FEED-FORWARD: this projection turns turn N's merged (accepted)
// agent deltas into a typed `BASAgentFabricAuthoritativeInput`, and the host folds it into turn
// N+1's `userInput` as a clearly-labeled context block. The brain then processes it through the
// SAME gated cascade — the sovereign verdict + single-commit gate remain the SOLE authority
// (红线 7: the deltas are INPUT, not a decision; 不变量 #2: 神经不掌权; 单提交口 不变).
//
// ## Why this is safe (R1 / ADR-014)
//
// - **Mode-gated**: `project(...)` returns `nil` unless `mode == .authoritative` (and unless there
//   are accepted deltas). `.observationOnly` ⇒ nil ⇒ no feed-forward.
// - **Additive-only**: this touches NO coordinator / `runTurn` / verdict code. The only behavioral
//   change is that the host MAY enrich `userInput`; if it does not (or the projection is nil), every
//   turn is byte-identical to before. byte-equal-off is by construction.
// - **Input-class**: the fabric's conclusions enter as ordinary input text the cascade already
//   processes; the sovereign verdict gates the result exactly as it gates any turn.
//
// The single-writer-per-domain invariant (`BASSharedStateGraph`) already guarantees the merged
// deltas are conflict-resolved and authored only by registered agents, so they are safe to surface.

import Foundation
import CryptoKit
import BASRuntimeCore
import BASMemory

/// Typed, host-held projection of a fabric turn's ACCEPTED (merge-won) agent deltas into a
/// feed-forward input for a subsequent turn. Codable provenance; `contextBlock` is the labeled text
/// the host folds into the next `userInput`.
public struct BASAgentFabricAuthoritativeInput:
    Codable, Sendable, Equatable, Hashable
{
    /// One merge-accepted delta's conclusion, flattened for the host + audit.
    public struct Conclusion: Codable, Sendable, Equatable, Hashable {
        public let deltaID: String
        public let domain: String          // `<domain>` prefix of the delta's targetObjectRef
        public let deltaType: String       // BASAgentDeltaType raw value
        public let confidence: Double
        public let summary: String         // (bounded) patch payload
        public let reasonCodes: [String]

        public init(
            deltaID: String, domain: String, deltaType: String,
            confidence: Double, summary: String, reasonCodes: [String]
        ) {
            self.deltaID = deltaID
            self.domain = domain
            self.deltaType = deltaType
            self.confidence = confidence
            self.summary = summary
            self.reasonCodes = reasonCodes
        }
    }

    public let sourceTurnID: String
    public let acceptedDeltaIDs: [String]
    public let conclusions: [Conclusion]
    public let contextBlock: String
    /// Stable hash of the conclusions (provenance / replay identity).
    public let digest: String

    public init(
        sourceTurnID: String,
        acceptedDeltaIDs: [String],
        conclusions: [Conclusion],
        contextBlock: String,
        digest: String
    ) {
        self.sourceTurnID = sourceTurnID
        self.acceptedDeltaIDs = acceptedDeltaIDs
        self.conclusions = conclusions
        self.contextBlock = contextBlock
        self.digest = digest
    }
}

public enum BASAgentFabricAuthoritativeProjection {

    /// chapter 一百八十五 — bound each conclusion summary so the folded block stays compact.
    public static let maxSummaryChars: Int = 240

    /// Project a fabric turn's merge-accepted deltas into an authoritative feed-forward input —
    /// ONLY when `mode == .authoritative` and at least one delta was accepted. Returns `nil`
    /// otherwise (the byte-equal-off path). Pure + deterministic.
    public static func project(
        fabricResult: BASAgentTurnResult,
        mode: BASAgentFabricMode,
        sourceTurnID: String
    ) -> BASAgentFabricAuthoritativeInput? {
        guard mode == .authoritative else { return nil }

        // The merge reports accepted IDs in the dependency-REF format `delta:<deltaID>` (ch956.5), so
        // normalize to the raw deltaID to match `emittedDeltas[*].deltaID`. WITHOUT this, the filter
        // below never matched the real fabric's accepted IDs ⇒ the projection always returned nil ⇒ the
        // authoritative feed-forward was dead end-to-end (the stub tests masked it by using bare IDs).
        // A bare `<deltaID>` (no prefix) is matched as-is, so stub/legacy callers are unaffected.
        let acceptedIDs = Set(fabricResult.mergeResult.acceptedDeltaIDs.map { id in
            id.hasPrefix("delta:") ? String(id.dropFirst("delta:".count)) : id
        })
        guard !acceptedIDs.isEmpty else { return nil }

        // Preserve emit order; keep only the deltas the merge accepted.
        let accepted = fabricResult.emittedDeltas.filter { acceptedIDs.contains($0.deltaID) }
        guard !accepted.isEmpty else { return nil }

        let conclusions = accepted.map { delta in
            BASAgentFabricAuthoritativeInput.Conclusion(
                deltaID: delta.deltaID,
                domain: Self.domain(of: delta.targetObjectRef),
                deltaType: delta.deltaType.rawValue,
                confidence: delta.confidence,
                summary: Self.boundedSummary(delta.patchJson),
                reasonCodes: delta.reasonCodes)
        }

        return BASAgentFabricAuthoritativeInput(
            sourceTurnID: sourceTurnID,
            acceptedDeltaIDs: accepted.map(\.deltaID),
            conclusions: conclusions,
            contextBlock: Self.contextBlock(sourceTurnID: sourceTurnID, conclusions: conclusions),
            digest: Self.digest(of: conclusions))
    }

    /// Fold an authoritative input into a request by appending its labeled context block to
    /// `userInput`. Returns a NEW request (value copy; the input request is not mutated). The host
    /// calls this for turn N+1; the existing cascade then processes the enriched input, gated by the
    /// sovereign verdict as always.
    public static func enrichedRequest(
        _ request: BASEBrainTurnRequest,
        with input: BASAgentFabricAuthoritativeInput
    ) -> BASEBrainTurnRequest {
        var out = request
        let base = request.userInput
        out.userInput = base.isEmpty
            ? input.contextBlock
            : base + "\n\n" + input.contextBlock
        return out
    }

    // MARK: - helpers

    static func domain(of targetObjectRef: String) -> String {
        // Format: `<domain>#<objectID>` — take the domain prefix.
        if let hash = targetObjectRef.firstIndex(of: "#") {
            return String(targetObjectRef[..<hash])
        }
        return targetObjectRef
    }

    static func boundedSummary(_ patchJson: String) -> String {
        guard patchJson.count > maxSummaryChars else { return patchJson }
        return String(patchJson.prefix(maxSummaryChars)) + "…"
    }

    static func contextBlock(
        sourceTurnID: String,
        conclusions: [BASAgentFabricAuthoritativeInput.Conclusion]
    ) -> String {
        var lines: [String] = [
            "[fabric-authoritative · turn \(sourceTurnID) · \(conclusions.count) accepted delta(s)]"
        ]
        for c in conclusions {
            let conf = String(format: "%.2f", c.confidence)
            lines.append("- \(c.domain) (\(c.deltaType), conf \(conf)): \(c.summary)")
        }
        return lines.joined(separator: "\n")
    }

    static func digest(
        of conclusions: [BASAgentFabricAuthoritativeInput.Conclusion]
    ) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(conclusions) else { return "" }
        let hash = SHA256.hash(data: data)
        return BASAutoRouteRanker.bytesToHexLower(Array(hash))
    }
}
