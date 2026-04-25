import Foundation
import BASRuntimeCore
import BASOrchestration
import BASSovereign

extension QinaoSovereignControlPlane {

    /// Per-turn residue snapshot: coverage + observation bundle +
    /// sovereign frame + render frame. All four reads happen on
    /// the same actor hop for a coherent view.
    public func turnResidue(
        sessionID: String,
        turnID: String
    ) async -> TurnResidue {
        let cov = await coverageReading(
            sessionID: sessionID, turnID: turnID)
        let bundle = await auditLedger.observationBundle(
            forSession: sessionID, turn: turnID)
        let frame = await auditLedger.sovereignFrame(
            forSession: sessionID, turn: turnID)
        let rframe = renderFrameEntries.first {
            $0.sessionID == sessionID && $0.turnID == turnID
        }?.frame
        return TurnResidue(
            sessionID: sessionID,
            turnID: turnID,
            coverageReading: cov,
            observationBundle: bundle,
            sovereignFrame: frame,
            renderFrame: rframe)
    }

    /// Pure cross-surface integrity check; pass a value
    /// previously fetched via `turnResidue(sessionID:turnID:)`.
    public nonisolated func verifyTurnResidue(
        _ residue: TurnResidue
    ) -> TurnResidueVerification {
        var findings:
            [TurnResidueVerification.Finding] = []

        if residue.coverageReading == nil {
            findings.append(.missingCoverage)
        }
        if residue.observationBundle == nil {
            findings.append(.missingObservationBundle)
        }
        if residue.sovereignFrame == nil {
            findings.append(.missingSovereignFrame)
        }

        if let bundle = residue.observationBundle {
            let hasL14 = bundle.summaries.contains {
                $0.layer == .sovereign
            }
            if !hasL14 {
                findings.append(.missingL14InBundle)
            }
        }

        if let bundle = residue.observationBundle,
           let frame = residue.sovereignFrame
        {
            if bundle.sessionID != frame.sessionID {
                findings.append(.sessionIDMismatch(
                    bundle: bundle.sessionID,
                    frame: frame.sessionID))
            }
            if bundle.turnID != frame.turnID {
                findings.append(.turnIDMismatch(
                    bundle: bundle.turnID,
                    frame: frame.turnID))
            }
        }

        if let frame = residue.sovereignFrame {
            let expectedFrameID = Self.syntheticRef(
                prefix: "frame",
                sessionID: frame.sessionID,
                turnID: frame.turnID)
            if frame.frameID != expectedFrameID {
                findings.append(
                    .frameIDConventionMismatch(
                        expected: expectedFrameID,
                        got: frame.frameID))
            }
            let expectedFoldRef = Self.syntheticRef(
                prefix: "fold",
                sessionID: frame.sessionID,
                turnID: frame.turnID)
            if let ref = frame.thoughtFoldRef,
               ref != expectedFoldRef
            {
                findings.append(
                    .thoughtFoldRefConventionMismatch(
                        expected: expectedFoldRef,
                        got: ref))
            }
        }

        // Render-frame checks fire only when the residue has a
        // sovereign frame; without one the render frame's absence
        // is the expected halt-path behavior.
        if residue.sovereignFrame != nil
           && residue.renderFrame == nil
        {
            findings.append(.missingRenderFrame)
        }
        if let rframe = residue.renderFrame {
            let expectedRenderFrameID = Self.syntheticRef(
                prefix: "render",
                sessionID: residue.sessionID,
                turnID: residue.turnID)
            if rframe.frameID != expectedRenderFrameID {
                findings.append(
                    .renderFrameIDConventionMismatch(
                        expected: expectedRenderFrameID,
                        got: rframe.frameID))
            }
            let expectedMergedChoiceRef = Self.syntheticRef(
                prefix: "fold",
                sessionID: residue.sessionID,
                turnID: residue.turnID)
            if let ref = rframe.mergedChoiceRef,
               ref != expectedMergedChoiceRef
            {
                findings.append(
                    .renderMergedChoiceRefConventionMismatch(
                        expected: expectedMergedChoiceRef,
                        got: ref))
            }
            if let sframe = residue.sovereignFrame,
               rframe.sovereignSurfaceRef != sframe.frameID
            {
                findings.append(
                    .renderSovereignBackRefBroken(
                        renderSurfaceRef:
                            rframe.sovereignSurfaceRef,
                        sovereignFrameID: sframe.frameID))
            }
        }

        return TurnResidueVerification(findings: findings)
    }
}

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
