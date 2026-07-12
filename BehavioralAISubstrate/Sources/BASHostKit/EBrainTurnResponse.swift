import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// Context-IR step 2 (2026-07-12) — the TurnRecord / TurnResponse split.
//
// The 53-field turn result serves FOUR consumers with different needs: host UI reads ~8
// fields, the SDK bridge projects 18, audit observation consumes nearly all, Codable replay
// needs all. Naming the roles ends the everyone-eats-at-one-table coupling:
//
//   BASTurnRecord   — the full accretion record (audit / replay / bridge projections).
//   BASTurnResponse — the slim host-facing contract: what a production host needs to ACT
//                     (permit, risk), SHOW (rendered output), CARRY (fold), and FILE
//                     (tickets, audit receipt).
//
// `record.response` is THE host-response projection point; hosts that only act/display
// consume the response and stop coupling to the other 45 fields. HONEST SCOPING (audit
// 2026-07-12): this is the single point for the HOST RESPONSE — the SDK's sovereign-
// artifacts bridge is a separate, DECLARED audit-class projection seam, and inspection
// surfaces (the 13-layer detail view) read the record by design. The boundary is
// mechanically enforced: host-surface files reading the raw record must carry the
// `BASTurnRecord-consumer: audit-class` marker (BASTurnResponseTests
// .testHostRecordReadersDeclareAuditClass); ACT/SHOW consumers use the response. Slimness
// pinned by testResponseSurfaceStaysSlim (cap 10 — widening requires a caller census).

/// The audit/replay accretion record — the role name for what flows out of runTurn whole.
public typealias BASTurnRecord = BASEBrainTurnResult

/// The slim host-facing turn contract. Fields chosen from the measured production-host read
/// surface (SampleHost bench + detail-action paths); everything else stays on the record.
public struct BASTurnResponse: Codable, Equatable, Sendable {
    /// What to show — the rendered answer/action surface.
    public let renderedOutput: BASRenderedOutput
    /// What the host may do — the L11-bound action permit.
    public let actionPermit: BASActionPermit
    /// Why — the risk summary backing the permit.
    public let riskCard: BASRiskCard
    /// What to carry forward — the compact per-turn fold (restore pointer + slots).
    public let thoughtFold: BASThoughtFold
    /// What to file — host-side follow-up tickets.
    public let updateTickets: [BASUpdateTicket]
    /// The sovereign receipt for this turn, when one was written.
    public let sovereignAuditEntry: BASSovereignAuditEntry?
    /// The applied host-gate value (L12 render gate).
    public let hostGateValue: Double
}

extension BASEBrainTurnResult {
    /// THE record→response projection point (context-IR step 2). Add fields here only after
    /// a caller census — the response is a contract, not a convenience bag.
    public var response: BASTurnResponse {
        BASTurnResponse(
            renderedOutput: renderedOutput,
            actionPermit: actionPermit,
            riskCard: riskCard,
            thoughtFold: thoughtFold,
            updateTickets: updateTickets,
            sovereignAuditEntry: sovereignAuditEntry,
            hostGateValue: hostGateValue)
    }
}

extension BASHostSessionResult {
    /// Production hosts consume the response; the record stays available for
    /// inspection/audit consumers (`eBrainTurn`).
    public var turnResponse: BASTurnResponse? { eBrainTurn?.response }
}
