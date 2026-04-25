import Foundation
import BASRuntimeCore
import BASLeaseLife
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import QinaoSovereign

extension QinaoRuntime {

    /// M152 — one value-typed argument that replaces the legacy
    /// 22 positional parameters of `sendSession`. Fields are
    /// grouped by semantic intent; defaults preserve backward-
    /// compat behavior so callers only set what they need.
    ///
    /// Construction patterns:
    ///
    ///     // 1. Minimal (just identity)
    ///     let inputs = QinaoRuntime.TurnInputs(
    ///         observations: obs,
    ///         coordinatorSeverity: .pass)
    ///
    ///     // 2. Mutating (set fields after construction)
    ///     var inputs = QinaoRuntime.TurnInputs(...)
    ///     inputs.thoughtFrame = tf
    ///     inputs.memoryBundle = mb
    ///
    ///     // 3. Fluent (single expression)
    ///     let outcome = try await runtime.sendSession(
    ///         .init(observations: obs,
    ///               coordinatorSeverity: .pass)
    ///             .with { $0.thoughtFrame = tf })
    public struct TurnInputs: Sendable {
        // MARK: Identity
        /// Required — the completed-turn observations the
        /// coordinator sealed.
        public var observations:
            QinaoSovereignControlPlane.TurnObservations
        /// Optional — the coordinator's own severity estimate,
        /// used to compute parity against the independent audit.
        public var coordinatorSeverity:
            QinaoSovereignControlPlane.AuditSeverity?

        // MARK: Per-turn layer inputs (gated by non-nil)
        /// L6 source (presenceEye).
        public var contextFrame: BASContextFrame?
        /// L7 source (mirrorBlade).
        public var decomposeFrame: BASDecomposeFrame?
        /// L8 source (hippocampalWell).
        public var memoryBundle: BASMemoryBundle?
        /// L4 + L10 + L11 source (worldPrior + tribunal + risk).
        public var thoughtFrame: BASThoughtFrame?
        /// L13 source (evolutionFurnace shadow tickets).
        public var updateTickets: [BASUpdateTicket] = []
        /// L2 source (neuralOrgan).
        public var neuralOrganMap: BASNeuralOrganMap?
        /// L12 source (gentleHand — needs thoughtFrame too).
        public var renderedOutput: BASRenderedOutput?
        /// L9 source (dreamLoop).
        public var candidateFrontier: BASCandidateFrontier?

        // MARK: Sovereign frame extra refs (L14 §5.1 aggregator)
        public var jurisdictionMap: BASJurisdictionMap?
        public var contaminationLineages:
            [BASContaminationLineage] = []
        public var timeLockRef: String?
        public var pendingActionDigest: String?
        public var pendingMutationDigest: String?
        public var pendingMemoryDigest: String?

        // MARK: Budget & coverage
        public var coverageBudgetCeiling: Double = 1.0
        public var expectedCoverageLayerIDs: [String] = ["L14"]
        public var plannedBudget: BASBudgetFrame?
        public var turnDurationSeconds: Double?
        public var additionalCoverageSummaries:
            [BASObservationCoverageSummary]?
        public var surfaceRetryPolicy: SurfaceRetryPolicy =
            .default

        public init(
            observations:
                QinaoSovereignControlPlane.TurnObservations,
            coordinatorSeverity:
                QinaoSovereignControlPlane.AuditSeverity?
        ) {
            self.observations = observations
            self.coordinatorSeverity = coordinatorSeverity
        }

        /// Fluent builder — returns a copy with the closure
        /// applied.
        public func with(
            _ configure: (inout Self) -> Void
        ) -> Self {
            var copy = self
            configure(&copy)
            return copy
        }
    }
}
