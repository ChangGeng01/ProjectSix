import Foundation
import QinaoSovereign

extension QinaoRuntime {

    /// M160 — per-turn observability snapshot. One emitted at the
    /// end of every `sendSession` call (success, halt, OR error
    /// path). Carries enough fields for an OTel adapter to produce
    /// a span attribute set, a per-severity counter, a per-phase
    /// histogram bucket, and a halt-reason tag.
    public struct TurnMetric: Sendable, Equatable, Hashable {
        public let sessionID: String
        public let turnID: String
        /// Audit severity reached by this turn. `.pass` on a healthy
        /// return; the auto-halt severity on rollback/deadStop;
        /// the parity severity on `.auditParityFailure`. M165 —
        /// `.pass` is also the placeholder when the metric
        /// represents an error path that threw before audit ran;
        /// `errorTag` carries the discriminator in that case.
        public let auditSeverity:
            QinaoSovereignControlPlane.AuditSeverity
        /// Coverage severity from the M45 cross-layer reading.
        public let coverageSeverity:
            QinaoSovereignControlPlane.CoverageSeverity
        /// Number of L1..L13 observation summaries auto-streamed
        /// this turn (excludes the always-present L14).
        public let autoInjectedLayerCount: Int
        /// `true` whenever the turn ended in a halted state — both
        /// auto-halt outcome returns and error-path throws.
        public let halted: Bool
        /// When `halted == true`, a stable short reason tag.
        public let haltReason: String?
        /// Wall-clock emission timestamp. Useful for human-readable
        /// debugging; do NOT use for latency math — use
        /// `latencyMs` (monotonic) instead.
        public let emittedAt: Date
        /// M165 — turn duration in milliseconds, measured by
        /// `ContinuousClock` (monotonic, immune to wall-clock drift,
        /// NTP jumps, leap seconds).
        public let latencyMs: Double
        /// M165 — terminal phase (the phase the turn was in when
        /// it ended).
        public let phase: TurnPhase
        /// M165 — short stable error tag. `nil` on healthy returns.
        public let errorTag: String?
        /// M165 — `true` when the metric originates from a thrown
        /// error path. `false` on healthy returns AND on the
        /// controlled rollback/deadStop auto-halt path (which
        /// returns a `TurnOutcome` rather than throwing).
        public let isErrorPath: Bool

        public init(
            sessionID: String,
            turnID: String,
            auditSeverity:
                QinaoSovereignControlPlane.AuditSeverity,
            coverageSeverity:
                QinaoSovereignControlPlane.CoverageSeverity,
            autoInjectedLayerCount: Int,
            halted: Bool,
            haltReason: String?,
            emittedAt: Date,
            latencyMs: Double,
            phase: TurnPhase,
            errorTag: String?,
            isErrorPath: Bool
        ) {
            self.sessionID = sessionID
            self.turnID = turnID
            self.auditSeverity = auditSeverity
            self.coverageSeverity = coverageSeverity
            self.autoInjectedLayerCount = autoInjectedLayerCount
            self.halted = halted
            self.haltReason = haltReason
            self.emittedAt = emittedAt
            self.latencyMs = latencyMs
            self.phase = phase
            self.errorTag = errorTag
            self.isErrorPath = isErrorPath
        }
    }

    /// M165 — terminal phase of a `sendSession` invocation.
    public enum TurnPhase: String, Sendable, Equatable, Hashable,
        Codable
    {
        case preflightValidation
        case preflightHalt
        case preflightDuplicate
        case audit
        case coverage
        case parity
        case severity
        case healthy
        case unknown
    }

    /// M160 — host-supplied callback invoked once per `sendSession`
    /// turn with the final `TurnMetric`. `Sendable` because it runs
    /// from inside the runtime actor. Default `nil` = no-op.
    public typealias MetricsRecorder = @Sendable (
        TurnMetric
    ) -> Void
}
