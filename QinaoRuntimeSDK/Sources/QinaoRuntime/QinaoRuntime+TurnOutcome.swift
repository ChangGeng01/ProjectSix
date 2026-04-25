import Foundation
import BASRuntimeCore
import BASLeaseLife
import BASOrchestration
import QinaoSovereign

extension QinaoRuntime {

    /// Outcome of a successful or auto-halted `sendSession` turn.
    ///
    /// Returned (rather than thrown) on:
    ///   * healthy `.pass` audits
    ///   * controlled rollback / deadStop auto-halts
    ///     (`sessionHalted == true`)
    ///
    /// Throwing terminations (`auditParityFailure`, `coverageHalt`,
    /// pre-flight rejections) raise `TurnError` instead.
    public struct TurnOutcome: Sendable, Equatable {
        public let audit: QinaoSovereignControlPlane.AuditReport
        /// Cross-layer M45 coverage verdict. `.halt` triggers a
        /// fail-closed halt (which throws `coverageHalt` rather
        /// than reaching this struct).
        public let coverage:
            QinaoSovereignControlPlane.CoverageReading
        public let sessionHalted: Bool
        /// M70 — lifecycle-routed budget actually used for this
        /// turn. `nil` if the caller did not pass `plannedBudget`
        /// or if the runtime has no attached `QinaoLifecycle`.
        public let routedBudget: BASBudgetFrame?
        /// M70 — lifecycle turn record produced AFTER healthy
        /// completion. `nil` for halted turns (halted turns must
        /// not advance lung accumulator / thermal twin) or when
        /// caller did not pass `turnDurationSeconds`.
        public let turnRecorded:
            BASLeaseLifeCoordinator.TurnRecorded?
        /// M125 / M145 — L12 surface decision derived from the
        /// turn's audit + coverage severity. Always populated on
        /// any return path; halt branches that throw never reach
        /// here.
        public let surfaceDecision: BASSurfaceDecision
        /// M128 — per-turn residue (observation bundle, sovereign
        /// frame, render frame). Optional: host-written fixtures
        /// can build a TurnOutcome by hand and leave this nil;
        /// every `sendSession` return path populates it.
        public let residue:
            QinaoSovereignControlPlane.TurnResidue?

        public init(
            audit: QinaoSovereignControlPlane.AuditReport,
            coverage:
                QinaoSovereignControlPlane.CoverageReading,
            sessionHalted: Bool,
            routedBudget: BASBudgetFrame? = nil,
            turnRecorded:
                BASLeaseLifeCoordinator.TurnRecorded? = nil,
            surfaceDecision: BASSurfaceDecision,
            residue:
                QinaoSovereignControlPlane.TurnResidue? = nil
        ) {
            self.audit = audit
            self.coverage = coverage
            self.sessionHalted = sessionHalted
            self.routedBudget = routedBudget
            self.turnRecorded = turnRecorded
            self.surfaceDecision = surfaceDecision
            self.residue = residue
        }
    }
}
