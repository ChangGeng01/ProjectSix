// ch1045 / v1.0 — BASTranscriptView (L12, outline §8.2): the 压榨成果展示器.
//
// Renders a set of `BASProcessTrace` entries into a structured, redacted view under a chosen mode.
// Core principle: 展示过程结构,不裸露隐藏内脏 — show PROCESS STRUCTURE, never raw prompts/responses
// or hidden reasoning. This is structurally guaranteed here: `BASProcessTrace` carries no body, so
// there is nothing for the view to leak; the view only surfaces governance fields (purpose, refs,
// contract digest, token counts, verdict), filtered by mode.
//
// Scope: this increment renders the call-process view from ProcessTrace. The richer view that also
// folds in CanonicalCognitiveFrame (局势摘要), ActionPermit (风险许可), and AgencyReservation
// (主体性保留), plus per-call redaction driven by the contract's `transcriptVisibility`, is a noted
// follow-on.

import Foundation

/// Transcript display modes (outline §8.2). `off` shows nothing; the others trade detail for
/// breadth. None expose raw reasoning.
public enum BASTranscriptMode: String, Sendable, Equatable, Codable, CaseIterable {
    case off
    case summary
    case compare
    case structuredTrace
    case agentTrace
    case auditLite
}

public struct BASTranscriptView: Sendable, Equatable, Codable {
    public let mode: BASTranscriptMode
    public let lines: [String]
    public let callCount: Int
    public let acceptedCount: Int
    public let rejectedCount: Int
    public let totalOutputTokens: Int

    public init(
        mode: BASTranscriptMode, lines: [String], callCount: Int,
        acceptedCount: Int, rejectedCount: Int, totalOutputTokens: Int
    ) {
        self.mode = mode
        self.lines = lines
        self.callCount = callCount
        self.acceptedCount = acceptedCount
        self.rejectedCount = rejectedCount
        self.totalOutputTokens = totalOutputTokens
    }

    private static func verdictLabel(_ v: BASProcessTraceVerdict) -> String {
        switch v {
        case .accepted: return "accepted"
        case .rejected(let reason): return "rejected(\(reason))"
        }
    }

    private static func isAccepted(_ v: BASProcessTraceVerdict) -> Bool {
        if case .accepted = v { return true }
        return false
    }

    /// Render a view from process traces under `mode`. Pure function; emits only structured,
    /// redacted lines — never a raw body (there is none on `BASProcessTrace`).
    public static func render(
        traces: [BASProcessTrace], mode: BASTranscriptMode
    ) -> BASTranscriptView {
        let accepted = traces.filter { isAccepted($0.verdict) }.count
        let rejected = traces.count - accepted
        let totalOut = traces.reduce(0) { $0 + $1.outputTokens }

        var lines: [String] = []
        switch mode {
        case .off:
            lines = []
        case .summary:
            let byPurpose = Dictionary(grouping: traces, by: { $0.purpose })
                .map { "\($0.key.rawValue)=\($0.value.count)" }
                .sorted()
            lines = [
                "calls=\(traces.count) accepted=\(accepted) rejected=\(rejected) out_tokens=\(totalOut)",
                "by_purpose: " + byPurpose.joined(separator: " ")
            ]
        case .compare:
            lines = traces.map {
                "\($0.callID) purpose=\($0.purpose.rawValue) "
                + "verdict=\(verdictLabel($0.verdict)) out=\($0.outputTokens)"
            }
        case .structuredTrace:
            lines = traces.map { t in
                "call=\(t.callID) purpose=\(t.purpose.rawValue) "
                + "agent=\(t.agentRef ?? "-") verifier=\(t.verifierRef ?? "-") "
                + "inputs=[\(t.inputRefs.joined(separator: ","))] "
                + "contract=\(String(t.contractDigestHex.prefix(12))) "
                + "provider=\(t.providerID) in=\(t.inputTokens) out=\(t.outputTokens) "
                + "verdict=\(verdictLabel(t.verdict))"
            }
        case .agentTrace:
            let byAgent = Dictionary(grouping: traces, by: { $0.agentRef ?? "<none>" })
            lines = byAgent.keys.sorted().map { agent in
                let ts = byAgent[agent] ?? []
                let out = ts.reduce(0) { $0 + $1.outputTokens }
                let purposes = Set(ts.map { $0.purpose.rawValue }).sorted().joined(separator: ",")
                return "agent=\(agent) calls=\(ts.count) out=\(out) purposes=[\(purposes)]"
            }
        case .auditLite:
            lines = traces.map {
                "\($0.callID) purpose=\($0.purpose.rawValue) "
                + "contract=\($0.contractDigestHex) verdict=\(verdictLabel($0.verdict))"
            }
        }

        return BASTranscriptView(
            mode: mode, lines: lines, callCount: traces.count,
            acceptedCount: accepted, rejectedCount: rejected, totalOutputTokens: totalOut)
    }
}
