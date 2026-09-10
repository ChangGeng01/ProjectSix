import Foundation
import QinaoSovereign

extension QinaoRuntime {

    /// Errors that can be thrown from `sendSession(_ inputs:)`.
    ///
    /// Categories:
    ///   * Phase 0 pre-flight: `invalidInput`, `sessionAlreadyHalted`,
    ///     `duplicateTurnAlreadyProcessed`, `duplicateTurnInFlight`.
    ///   * Phase 2 audit: `auditParityFailure` (coordinator missed
    ///     what the engine caught).
    ///   * Phase 8 coverage: `coverageHalt` (M45 cross-layer breach).
    public enum TurnError: Error, Equatable, Sendable {
        /// The session was already halted before this turn started.
        /// Hosts must release the halt before sending new turns.
        case sessionAlreadyHalted(id: String)
        /// The turn audit came back with `parity == .coordinatorLaxer`
        /// — the coordinator missed something the independent engine
        /// caught. Fail-closed: the runtime has halted the session;
        /// the host must not accept any further turns until explicit
        /// release.
        case auditParityFailure(
            sessionID: String,
            severity: QinaoSovereignControlPlane.AuditSeverity,
            auditRef: String)
        /// The M45 cross-layer coverage verdict returned `.halt`
        /// severity — typically because total clamped per-turn
        /// budget exceeded the ceiling. Fail-closed: the session is
        /// halted before the caller sees the turn result.
        case coverageHalt(
            sessionID: String,
            turnID: String,
            findings: [QinaoSovereignControlPlane.CoverageFinding])
        /// M159 — input validation rejection at Phase 0. The runtime
        /// refuses any malformed `sessionID` / `turnID` (empty,
        /// whitespace-only, byte length over `maxIdentifierByteLength`,
        /// disallowed control characters) before any state mutation.
        case invalidInput(field: String, reason: String)
        /// M161 — the same `(sessionID, turnID)` was already processed
        /// and finalized by a previous `sendSession`. Hosts MUST NOT
        /// retry the same turnID on this case — the work happened,
        /// retry is meaningless. Use a fresh turnID.
        case duplicateTurnAlreadyProcessed(
            sessionID: String, turnID: String)
        /// M165 — the same `(sessionID, turnID)` is currently
        /// in-flight: another `sendSession` task already passed claim
        /// and is mid-Phase-2. Hosts MAY retry after a short backoff;
        /// the in-flight task could finalize OR release.
        case duplicateTurnInFlight(
            sessionID: String, turnID: String)

        /// M165 — back-compat helper. The pre-M165 single
        /// `duplicateTurnSubmission` case was split into
        /// `duplicateTurnAlreadyProcessed` and `duplicateTurnInFlight`.
        /// Callers that only need the "either kind of duplicate"
        /// answer can use this static helper.
        public static func isDuplicateTurnSubmission(
            _ error: any Error
        ) -> Bool {
            guard let e = error as? TurnError else { return false }
            switch e {
            case .duplicateTurnAlreadyProcessed,
                 .duplicateTurnInFlight:
                return true
            default:
                return false
            }
        }
    }
}
