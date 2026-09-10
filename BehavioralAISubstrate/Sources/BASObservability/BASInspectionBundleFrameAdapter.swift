// MARK: - BASInspectionBundleFrameAdapter
// chapter 五百九 / M1414 — typed pure-function adapter
// from existing BASInspectionBundle (BASObservability)
// to the chapter 507 M1406 BASInspectionFrame<Body>
// Tier C primitive
//
// Maps the existing 7-field BASInspectionBundle onto the
// 7-field BASInspectionFrame:
//
//   BASInspectionBundle field   → BASInspectionFrame field
//   ──────────────────────────    ─────────────────────────
//   generatedAt                 → inspectedAtMs
//   trace                       → body.trace
//   replayFingerprint           → body.replayFingerprint
//   replayDisposition           → body.replayDisposition
//   releaseDecision             → body.releaseDecision
//   anomalySignals              → diagnostics + body.anomaly
//                                 Signals
//   calibration                 → body.calibration
//
// The Frame fields:
//   inspectionID:composed from trace + generatedAt
//   inspectorRefs:["substrate"] default (substrate is
//                  the inspector for this bundle's purpose)
//   inspectedRefs:trace.toolsCalled + trace
//                  .memoriesRecalled (what was inspected)
//   inspectionPolicy:"observability-core"
//
// HONEST SCOPE — chapter 五百九:
// =============================================================
// Pure-function adapter — does NOT modify existing
// BASInspectionBundle。 ADR-014 OPT-IN preserved。 V1
// byte-equality untouched (adapter is opt-in only)。

import Foundation
import BASRuntimeCore

/// Typed body for the Tier C-frame form of
/// BASInspectionBundle。 Carries summary strings that
/// satisfy the BASInspectionFrame Body: Hashable
/// constraint (the underlying BASAnomalySignal +
/// BASInspectionCalibrationSummary types are not
/// Hashable,so they can't be directly embedded)。
///
/// HONEST scope:Body carries DERIVED summary strings
/// (input/output summaries + release decision + anomaly
/// count + calibration status) — full original bundle
/// can be retrieved via the source-of-truth BASInspection
/// Bundle if needed。 Adapter is for AUDIT EMISSION,
/// not for full reconstruction。
public struct BASInspectionBundleFrameBody:
    Equatable, Hashable, Codable, Sendable
{
    public let inputSummary: String
    public let outputSummary: String
    public let releaseDecisionSummary: String
    public let anomalyCount: Int
    public let calibrationStatus: String?
    public let replayAvailable: Bool

    public init(
        inputSummary: String,
        outputSummary: String,
        releaseDecisionSummary: String,
        anomalyCount: Int,
        calibrationStatus: String?,
        replayAvailable: Bool
    ) {
        self.inputSummary = inputSummary
        self.outputSummary = outputSummary
        self.releaseDecisionSummary =
            releaseDecisionSummary
        self.anomalyCount = anomalyCount
        self.calibrationStatus = calibrationStatus
        self.replayAvailable = replayAvailable
    }
}

/// Typed pure-function adapter producing the Tier C
/// frame form of an existing BASInspectionBundle。
public enum BASInspectionBundleFrameAdapter {

    /// Convert a BASInspectionBundle into a typed
    /// BASInspectionFrame<BASInspectionBundleFrameBody>。
    ///
    /// The frame's `inspectionID` is composed as
    /// "inspection@<generated-millis>" providing a
    /// stable per-inspection identifier。
    ///
    /// `diagnostics` is populated with anomaly-signal
    /// raw value codes for easy audit walker grep。
    public static func frame(
        from bundle: BASInspectionBundle,
        schemaVersion: String = "1.0.0",
        inspectionPolicy: String = "observability-core"
    ) -> BASInspectionFrame<
        BASInspectionBundleFrameBody>
    {
        let generatedAtMs = Int64(
            bundle.generatedAt.timeIntervalSince1970
            * 1000.0)
        let body = BASInspectionBundleFrameBody(
            inputSummary: bundle.trace.inputSummary,
            outputSummary: bundle.trace.outputSummary,
            releaseDecisionSummary:
                String(describing:
                    bundle.releaseDecision),
            anomalyCount:
                bundle.anomalySignals.count,
            calibrationStatus:
                bundle.calibration?.status,
            replayAvailable:
                bundle.replayDisposition.isAvailable)
        // Inspected refs = what the execution trace
        // touched (tools + memories)
        let inspectedRefs = bundle.trace.toolsCalled
            + bundle.trace.memoriesRecalled
        // Diagnostics:anomaly-signal codes for audit
        let diagnostics = bundle.anomalySignals
            .map { "anomaly:\(String(describing: $0))" }
        return BASInspectionFrame(
            inspectionID:
                "inspection@\(generatedAtMs)",
            schemaVersion: schemaVersion,
            inspectorRefs: ["substrate"],
            inspectedRefs: inspectedRefs,
            inspectionPolicy: inspectionPolicy,
            inspectedAtMs: generatedAtMs,
            body: body,
            diagnostics: diagnostics)
    }
}
