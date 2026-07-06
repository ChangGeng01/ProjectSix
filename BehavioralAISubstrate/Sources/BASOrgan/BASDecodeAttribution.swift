import Foundation

/// 可解释性章程① (2026-07-06) — THE turn line's carrier: one additive, optional, Codable record
/// per turn that says WHY the turn ran the way it did. The audit's core finding was that every
/// piece of this is already COMPUTED and then dropped at a module boundary (ctx discarded,
/// trace-exit printed-and-lost, B2 silent-when-agreeing, fail-close visible only in a console
/// error line). This struct carries them to two named consumers and NO further:
///   • the operator's log stream (`summaryLine` behind BAS_DECODE_CTX=1 — one line per turn), and
///   • probes/tests asserting on `draft.decodeAttribution`.
/// Deliberately NOT persisted anywhere (charter: no receipts-about-the-owner on disk until the
/// owner opts in; a JSONL sink waits for a real past-turn question to go unanswered twice).
public struct BASDecodeAttribution: Sendable, Equatable, Codable {

    /// B2 difficulty-probe tri-state — the audit's exact complaint was that "armed and agreed"
    /// was indistinguishable from "never armed".
    public enum DiffProbeState: Sendable, Equatable, Codable {
        /// Kill-switched, weights unresolved, not armed for this turn, or deliberately not
        /// consulted (thermal fallback).
        case off
        /// Armed and evaluated: p_success + planned→refined budget (planned == refined ⇒ agreed).
        case armed(pSuccess: Double, planned: Int, refined: Int)
    }

    public let requestID: String
    /// The 案5 per-turn fact snapshot (nil on the session path, which has its own lane story).
    public let context: BASDecodeContext?
    /// What the decider elected (planner lane, or the session-lane election).
    public let plannedLane: String
    /// What actually ran. != plannedLane ⇒ a fail-close or an in-turn fallback fired.
    public let executedLane: String
    /// Populated iff executedLane diverged (error description / "thermal" / …).
    public let failCloseReason: String?
    /// B3 trace-exit: reason + think-token count when the stop rule fired this turn.
    public let traceExitReason: String?
    public let traceThinkTokens: Int?
    public let diffProbe: DiffProbeState

    public init(requestID: String, context: BASDecodeContext?, plannedLane: String,
                executedLane: String, failCloseReason: String? = nil,
                traceExitReason: String? = nil, traceThinkTokens: Int? = nil,
                diffProbe: DiffProbeState = .off) {
        self.requestID = requestID
        self.context = context
        self.plannedLane = plannedLane
        self.executedLane = executedLane
        self.failCloseReason = failCloseReason
        self.traceExitReason = traceExitReason
        self.traceThinkTokens = traceThinkTokens
        self.diffProbe = diffProbe
    }

    /// THE turn line — the whole story, one grep-friendly line, requestID-attributable.
    public var summaryLine: String {
        let lane = plannedLane == executedLane
            ? plannedLane
            : "\(plannedLane)→\(executedLane)(\(failCloseReason ?? "?"))"
        let b2: String
        switch diffProbe {
        case .off: b2 = "off"
        case .armed(let p, let planned, let refined):
            b2 = planned == refined
                ? String(format: "agreed(p=%.2f)", p)
                : String(format: "p=%.2f:%d→%d", p, planned, refined)
        }
        let trace = traceExitReason.map { "\($0):think=\(traceThinkTokens ?? 0)" } ?? "-"
        let ctx = context.map { c in
            let mem = c.memoryHeadroomBytes.map { "\($0 / (1024 * 1024))MB" } ?? "n/a"
            return "temp=\(c.temperature) cap=\(c.maxOutputTokens.map(String.init) ?? "∞") "
                + "thermal=\(c.thermalThrottled ? "THROTTLED" : "ok") mem=\(mem)"
        } ?? "-"
        return "📊 turn id=\(requestID) lane=\(lane) b2=\(b2) trace=\(trace) ctx[\(ctx)]"
    }
}
