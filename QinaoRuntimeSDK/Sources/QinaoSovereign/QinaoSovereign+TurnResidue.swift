import Foundation
import BASRuntimeCore
import BASOrchestration
import BASSovereign

extension QinaoSovereignControlPlane {

    /// M124 + M131 — per-turn residue bundle. Snapshot of the
    /// four parallel storages keyed on `(sessionID, turnID)`:
    ///   * `coverageReading` — M45 cross-layer verdict
    ///   * `observationBundle` — M90 per-turn layer summaries
    ///   * `sovereignFrame` — M123 L14 §5.1 aggregator
    ///   * `renderFrame` — M127 L12 surface aggregator
    ///
    /// All components are optional because production ledgers
    /// can have partial turns (halt paths, pre-halted sessions,
    /// direct-constructed fixtures).
    public struct TurnResidue: Sendable, Equatable {
        public let sessionID: String
        public let turnID: String
        public let coverageReading: CoverageReading?
        public let observationBundle:
            BASObservationReconciliationReport?
        public let sovereignFrame: BASSovereignFrame?
        /// M131 — the L12 render-frame recorded on the control
        /// plane's parallel storage (M127). `nil` for halt paths,
        /// direct-constructed fixtures, and pre-M127 call sites.
        public let renderFrame: BASRenderFrame?

        public init(
            sessionID: String,
            turnID: String,
            coverageReading: CoverageReading?,
            observationBundle:
                BASObservationReconciliationReport?,
            sovereignFrame: BASSovereignFrame?,
            renderFrame: BASRenderFrame? = nil
        ) {
            self.sessionID = sessionID
            self.turnID = turnID
            self.coverageReading = coverageReading
            self.observationBundle = observationBundle
            self.sovereignFrame = sovereignFrame
            self.renderFrame = renderFrame
        }

        /// `true` when all four residue components are present.
        public var isComplete: Bool {
            coverageReading != nil
                && observationBundle != nil
                && sovereignFrame != nil
                && renderFrame != nil
        }
    }

    /// M124 — diagnostic for a `TurnResidue` integrity check.
    /// Empty `findings` ⇒ the three surfaces are mutually
    /// coherent.
    public struct TurnResidueVerification:
        Sendable, Equatable
    {
        public let findings: [Finding]

        public init(findings: [Finding]) {
            self.findings = findings
        }

        public var isValid: Bool { findings.isEmpty }

        public enum Finding: Sendable, Equatable {
            case missingCoverage
            case missingObservationBundle
            case missingSovereignFrame
            /// Bundle and frame disagree on sessionID.
            case sessionIDMismatch(bundle: String, frame: String)
            /// Bundle and frame disagree on turnID.
            case turnIDMismatch(bundle: String, frame: String)
            /// Sovereign frame's `frameID` does not follow the
            /// M163 percent-escaped convention.
            case frameIDConventionMismatch(
                expected: String, got: String)
            /// Sovereign frame's `thoughtFoldRef` does not follow
            /// the M163 convention.
            case thoughtFoldRefConventionMismatch(
                expected: String, got: String)
            /// Observation bundle missing the always-present L14
            /// (sovereign) summary.
            case missingL14InBundle
            /// M129 — the audit ledger's hash chain failed
            /// `verifyChainIntegrity()`. Fires only on the
            /// async `verifyTurnResidueStrong` variant.
            case chainIntegrityBroken(lastVerifiedAuditID: String?)
            /// M131 — residue lacks the L12 render frame.
            case missingRenderFrame
            /// M131 — render frame's `frameID` does not follow
            /// the M163 convention.
            case renderFrameIDConventionMismatch(
                expected: String, got: String)
            /// M131 — render frame's `sovereignSurfaceRef` does
            /// not back-reference the sovereign frame's frameID.
            case renderSovereignBackRefBroken(
                renderSurfaceRef: String?,
                sovereignFrameID: String?)
            /// M131 — render frame's `mergedChoiceRef` does not
            /// follow the L3 fold M163 convention.
            case renderMergedChoiceRefConventionMismatch(
                expected: String, got: String)
        }
    }
}
