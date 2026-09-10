// ADR-032 — single source of truth for a commit token's per-scope action-digest PARTS.
//
// `buildSovereignCommitTokens` (the EMITTER) and `BASSovereignGatedTurn` (the host-side
// GATE) must derive the SAME `actionDigestParts` for a given scope, or the gate's
// recomputed digest will never match the emitted token's signed digest and the gate
// would deny every op. Rather than duplicate the per-scope formula in both places (a
// silent-drift footgun in a SOVEREIGN gate), both go through THIS pure function.
//
// The parts are the "approved artifact": the exact content the host is about to act on.
// If the host's artifact differs from what the brain emitted (tamper between
// authorization and execution), the recomputed parts differ → digest mismatch → deny.

import Foundation
import BASRuntimeCore
import BASOrchestration

public enum BASSovereignTurnArtifactParts {

    /// PRIMITIVE core (testable without the heavy domain structs): the canonical
    /// `actionDigestParts` for `scope`. Returns `nil` for a scope this turn does not
    /// model (the caller fails closed). MUST stay identical between the emitter and the
    /// gate — that is the whole point of centralizing it here.
    public static func parts(
        scope: BASSovereignCommitScope,
        foldID: String,
        renderMode: String,
        renderHeadline: String,
        renderBody: String,
        ticketActionDigestParts: [[String]],
        ticketCount: Int
    ) -> [String]? {
        switch scope {
        case .checkpointCommit:
            return ["checkpoint", foldID, renderMode, String(ticketCount)]
        case .memoryWrite:
            return ticketActionDigestParts.flatMap { $0 }
        case .renderHighRisk:
            return [renderMode, renderHeadline, renderBody]
        default:
            return nil
        }
    }

    /// Object convenience for the emitter (which holds the domain structs). Forwards to
    /// the primitive core so there is ONE formula.
    public static func parts(
        scope: BASSovereignCommitScope,
        thoughtFold: BASThoughtFold,
        renderedOutput: BASRenderedOutput,
        updateTickets: [BASUpdateTicket]
    ) -> [String]? {
        parts(
            scope: scope,
            foldID: thoughtFold.foldID,
            renderMode: renderedOutput.mode.rawValue,
            renderHeadline: renderedOutput.headline,
            renderBody: renderedOutput.body,
            ticketActionDigestParts: updateTickets.map(\.actionDigestParts),
            ticketCount: updateTickets.count)
    }
}
