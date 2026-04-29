import Foundation
import BASObservability

/// M267 — single-call auto-flow from `BASEBrainTurnResult` into
/// `BASUpdateTicketLifecycleCoordinator`.
///
/// ## Why this lives in BASHostKit
///
/// The lifecycle coordinator is in `BASObservability`. The turn
/// result is in `BASHostKit`. BASHostKit already imports
/// BASObservability (for `BASUpdateTicket` and other observation
/// types), but BASObservability cannot import BASHostKit without
/// creating a cycle. So the extension that bridges the two lives
/// here.
///
/// ## Usage
///
/// Hosts construct the lifecycle coordinator at runtime startup
/// (with optional audit sink wiring per M265), then call this
/// helper after each turn:
///
/// ```swift
/// let coord = BASUpdateTicketLifecycleCoordinator(
///     auditSink: { try await ledger.append($0) })
///
/// // ... per turn:
/// let turn = try await runtime.makeEBrainTurn(...)
/// await coord.ingestTurnResult(turn)
/// // ... existing per-turn handling
/// ```
///
/// One line per turn, no manual iteration over
/// `turn.updateTickets`. Duplicates are silently skipped (so
/// re-presenting an old turn result is idempotent), and any
/// errors during ingestion are absorbed (auto-flow path must
/// never crash a host runtime).
public extension BASUpdateTicketLifecycleCoordinator {
    /// Ingest every `BASUpdateTicket` from the turn result.
    /// Returns the count of newly-registered tickets so hosts
    /// can surface the metric for observability.
    @discardableResult
    func ingestTurnResult(
        _ turn: BASEBrainTurnResult
    ) -> Int {
        ingestTurn(turn.updateTickets)
    }
}
