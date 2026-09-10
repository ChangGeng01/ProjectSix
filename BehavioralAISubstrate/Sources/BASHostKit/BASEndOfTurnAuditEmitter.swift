// MARK: - BASEndOfTurnAuditEmitter
// chapter 五百五 / M1398 — actor that composes all 4
// observation pipelines into a unified emission record
//
// chapter 五百十三 / M1431 — 5th pipeline (projection
// blocks) added
//
// Hosts construct the emitter with optional observer +
// ledger references。 At end-of-turn,calling
// `emit(turnID:recordedAtMs:)` snapshots each connected
// pipeline and returns a typed BASEndOfTurnAudit
// EmissionRecord ready for audit emission。
//
// REAL CONSUMPTION across the 5 pipelines:
//   - probeBundle (M1386) → cacheReport via M1393
//   - routingObserver (M1389) → routingDecisions via
//     M1394 snapshotAsBundle()
//   - statisticsRecorder (M1390) → dispatchStatistics
//     via snapshot()
//   - advisoryLedger (M1391) → runtimeModeAdvisories
//     via M1395 snapshotAsBundle()
//   - projectionBlockObserver (M1426) →
//     projectionBlockObservations via M1427
//     snapshotAsBundle()  [chapter 513 M1431 addition]
//
// HONEST SCOPE — chapter 五百五 (chapter 五百十三 extends):
// =============================================================
// All connections are OPTIONAL — hosts may omit any
// observer they don't use。 The emitter passes through
// nil for omitted pipelines without auto-constructing
// empty bundles。 V1 byte-equality preserved (purely
// additive)。 ADR-014 OPT-IN — hosts opt-in by
// constructing the emitter。

import Foundation
import BASMetalSubstrate
import BASRuntimeCore

/// Actor-isolated emitter composing 4 substrate
/// observation pipelines into a typed unified audit
/// emission record。 Construction is dependency-
/// injection only:each observer is optional。
public actor BASEndOfTurnAuditEmitter {

    private let probeBundle:
        BASKernelEvaluateLatencyProbeBundle?
    private let routingObserver:
        BASKernelRoutingDecisionObserver?
    private let statisticsRecorder:
        BASKernelDispatchStatisticsRecorder?
    private let advisoryLedger:
        BASEBrainHostRuntimeModeAdvisoryLedger?
    private let projectionBlockObserver:
        BASAuditObservationProjectionsBundleObserver?

    public init(
        probeBundle:
            BASKernelEvaluateLatencyProbeBundle? = nil,
        routingObserver:
            BASKernelRoutingDecisionObserver? = nil,
        statisticsRecorder:
            BASKernelDispatchStatisticsRecorder? = nil,
        advisoryLedger:
            BASEBrainHostRuntimeModeAdvisoryLedger? = nil,
        projectionBlockObserver:
            BASAuditObservationProjectionsBundleObserver?
            = nil
    ) {
        self.probeBundle = probeBundle
        self.routingObserver = routingObserver
        self.statisticsRecorder = statisticsRecorder
        self.advisoryLedger = advisoryLedger
        self.projectionBlockObserver =
            projectionBlockObserver
    }

    /// Snapshot all connected pipelines and emit a
    /// unified audit record。 Read-only — does not
    /// mutate observer/ledger state。
    public func emit(
        turnID: String,
        recordedAtMs: Int64
    ) async -> BASEndOfTurnAuditEmissionRecord {
        // Pipeline 1: cache report via M1393 aggregator
        let cacheReport:
            BASMPSGraphCacheReportResult? = {
            guard let bundle = probeBundle
            else { return nil }
            return BASMPSGraphCacheReportAggregator
                .report(from: bundle)
        }()

        // Pipeline 2: routing decisions bundle
        let routingDecisions:
            BASKernelRoutingDecisionBundle?
        if let observer = routingObserver {
            routingDecisions = await observer
                .snapshotAsBundle(
                    bundleID:
                        "routing-\(turnID)",
                    recordedAtMs: recordedAtMs)
        } else {
            routingDecisions = nil
        }

        // Pipeline 3: dispatch statistics bundle
        let dispatchStatistics:
            BASKernelDispatchStatisticsBundle?
        if let recorder = statisticsRecorder {
            dispatchStatistics = await recorder
                .snapshot(
                    bundleID:
                        "dispatch-\(turnID)",
                    recordedAtMs: recordedAtMs)
        } else {
            dispatchStatistics = nil
        }

        // Pipeline 4: advisory bundle
        let runtimeModeAdvisories:
            BASEBrainHostRuntimeModeAdvisoryBundle?
        if let ledger = advisoryLedger {
            runtimeModeAdvisories = await ledger
                .snapshotAsBundle(
                    bundleID:
                        "advisory-\(turnID)",
                    recordedAtMs: recordedAtMs)
        } else {
            runtimeModeAdvisories = nil
        }

        // Pipeline 5: projection-block observations
        // bundle (chapter 513 M1431)
        let projectionBlockObservations:
            BASAuditObservationProjectionsBundle?
        if let observer = projectionBlockObserver {
            projectionBlockObservations = await observer
                .snapshotAsBundle()
        } else {
            projectionBlockObservations = nil
        }

        return BASEndOfTurnAuditEmissionRecord(
            turnID: turnID,
            cacheReport: cacheReport,
            routingDecisions: routingDecisions,
            dispatchStatistics: dispatchStatistics,
            runtimeModeAdvisories:
                runtimeModeAdvisories,
            projectionBlockObservations:
                projectionBlockObservations,
            recordedAtMs: recordedAtMs)
    }

    // MARK: - Connection accessors

    /// `true` when the emitter holds a probe bundle
    /// reference for pipeline 1。
    public nonisolated var hasProbeBundle: Bool {
        probeBundle != nil
    }

    /// `true` when the emitter holds a routing observer
    /// reference for pipeline 2。
    public nonisolated var hasRoutingObserver: Bool {
        routingObserver != nil
    }

    /// `true` when the emitter holds a statistics
    /// recorder reference for pipeline 3。
    public nonisolated var hasStatisticsRecorder: Bool {
        statisticsRecorder != nil
    }

    /// `true` when the emitter holds an advisory ledger
    /// reference for pipeline 4。
    public nonisolated var hasAdvisoryLedger: Bool {
        advisoryLedger != nil
    }

    /// `true` when the emitter holds a projection-block
    /// observer reference for pipeline 5 (chapter 513
    /// M1431)。
    public nonisolated var hasProjectionBlockObserver: Bool
    {
        projectionBlockObserver != nil
    }

    /// Count of connected pipelines (0-5)。 M1431 grows
    /// upper bound from 4 → 5。
    public nonisolated var connectedPipelineCount: Int {
        var count = 0
        if hasProbeBundle { count += 1 }
        if hasRoutingObserver { count += 1 }
        if hasStatisticsRecorder { count += 1 }
        if hasAdvisoryLedger { count += 1 }
        if hasProjectionBlockObserver { count += 1 }
        return count
    }
}
