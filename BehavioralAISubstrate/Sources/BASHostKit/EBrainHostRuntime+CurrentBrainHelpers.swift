import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

// MARK: - M72 split — BASHostCurrentBrain helper extension extracted from the
// 5039-line EBrainHostRuntimeSynthesis.swift.  Previously file-scope `private
// extension`, now default-internal so every sibling service file in BASHostKit
// (PowerClock/HostConstitution/HostProfile/Context/Decompose/Memory/NeuralCore/
// Loop/TriSelf/Risk/Action/Evolution and the reduced main orchestrator) can
// reuse these derivations.  None of these members surface through the Qinao
// public API.

extension BASHostCurrentBrain {
    func applyingControlPlaneDisposition(
        _ disposition: BASHostConfiguration.ControlPlaneExecutionDisposition,
        reasonCodes: [String]
    ) -> BASHostCurrentBrain {
        guard disposition != .normal else {
            return self
        }

        func orderedUnique(_ values: [String]) -> [String] {
            var seen = Set<String>()
            return values.filter { seen.insert($0).inserted }
        }

        var updated = self
        let laneConstraint = disposition == .quarantine
            ? "brain-bootstrap-quarantine"
            : "brain-bootstrap-recovery"
        let laneTag = disposition == .quarantine ? "quarantine" : "recovery"
        let annotatedReasons = reasonCodes.map { "\($0)" }

        updated.activeConstraints = orderedUnique(
            updated.activeConstraints
                + [laneConstraint]
                + annotatedReasons
        )
        updated.retrievalTags = orderedUnique(
            updated.retrievalTags
                + [laneTag]
                + annotatedReasons
        )
        if updated.verificationSummary.isEmpty {
            updated.verificationSummary = "control-plane:\(laneTag)"
        } else if !updated.verificationSummary.contains("control-plane:\(laneTag)") {
            updated.verificationSummary += " | control-plane:\(laneTag)"
        }

        return updated
    }

    var hasEvidenceCaveatLoad: Bool {
        riskFlags.contains(.evidenceCaveatLoad) || retrievalTags.contains("evidence_caveat")
    }

    var hasProtectiveBoundary: Bool {
        boundaryMode == .localOnlyProtective
    }

    var requiresRecovery: Bool {
        activeConstraints.contains("brain-bootstrap-recovery") || retrievalTags.contains("recovery")
    }

    var requiresQuarantine: Bool {
        activeConstraints.contains("brain-bootstrap-quarantine") || retrievalTags.contains("quarantine")
    }

    var isCalibrationUnstable: Bool {
        calibrationStatus == .watch || calibrationStatus == .drifting
    }

    var hasTrustDriftSignals: Bool {
        riskFlags.contains(.lowTrustLoad) ||
            riskFlags.contains(.retrievalInstability) ||
            riskFlags.contains(.externalRefreshGuardTriggered) ||
            riskFlags.contains(.observationOnlyQuarantine) ||
            hasEvidenceCaveatLoad
    }

    func hostGuardrailPressure(
        using tuning: BASEBrainRuntimeSynthesisPolicy
    ) -> Double {
        let pressureTuning = tuning.guardrailPressure
        var pressure = 0.0
        if hasProtectiveBoundary { pressure += pressureTuning.protectiveBoundaryIncrement }
        if calibrationStatus == .watch { pressure += pressureTuning.calibrationWatchIncrement }
        if calibrationStatus == .drifting { pressure += pressureTuning.calibrationDriftingIncrement }
        pressure += min(
            pressureTuning.boundaryConstraintCap,
            Double(boundaryConstraints.count) * pressureTuning.boundaryConstraintUnit
        )
        pressure += min(
            pressureTuning.calibrationAlertCap,
            Double(calibrationAlerts.count) * pressureTuning.calibrationAlertUnit
        )
        pressure += min(
            pressureTuning.failureGuardCap,
            Double(failureGuardCount) * pressureTuning.failureGuardUnit
        )
        pressure += min(
            pressureTuning.riskFlagCap,
            Double(riskFlags.count) * pressureTuning.riskFlagUnit
        )
        return min(pressureTuning.maximumPressure, pressure)
    }
}
