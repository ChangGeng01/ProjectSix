// MARK: - BASEndOfTurnAuditEmissionRecord
// chapter 五百五 / M1397 — unified end-of-turn audit
// emission record composing 4 wire-in pipelines into
// a single Codable surface
//
// COMPOSITION across 7 chapters + 4 typed pipelines:
//
//   Pipeline 1 (cache report):
//     M1369 body → M1371 probe → M1386 bundle →
//     M1393 aggregator → M1374 report
//
//   Pipeline 2 (routing decisions):
//     M1377 classifier + M1378 policy →
//     M1389 observer → M1394 bundle (9th BASBundle)
//
//   Pipeline 3 (dispatch statistics):
//     M1375 attempt card → M1390 recorder →
//     M1373 statistics bundle (7th BASBundle)
//
//   Pipeline 4 (advisory ledger):
//     M1370 advisory → M1391 ledger →
//     M1395 bundle (10th BASBundle)
//
// HONEST SCOPE — chapter 五百五:
// =============================================================
// This record is a TYPED COMPOSITION SURFACE。 It does
// NOT auto-collect data — hosts (or the chapter 505
// M1398 emitter) explicitly construct it from observer
// snapshots。 V1 byte-equality preserved。
//
// ADR-014 OPT-IN — hosts that don't want unified audit
// emission can skip the record entirely。

import Foundation
import BASMetalSubstrate
import BASRuntimeCore

/// Typed Codable + Equatable + Hashable record carrying
/// the FOUR substrate observation pipelines for a single
/// turn。 Each field is optional — hosts may omit any
/// pipeline they don't use。
public struct BASEndOfTurnAuditEmissionRecord:
    Equatable, Codable, Sendable
{

    /// Stable correlation ID linking this audit record
    /// to the turn that produced it。
    public let turnID: String

    /// Pipeline 1 — chapter 504 M1374 cache report (via
    /// 5-stage typed composition from M1369 onwards)。
    public let cacheReport: BASMPSGraphCacheReportResult?

    /// Pipeline 2 — chapter 504 M1394 routing decisions
    /// (9th BASBundle adoption,via M1389 observer)。
    public let routingDecisions:
        BASKernelRoutingDecisionBundle?

    /// Pipeline 3 — chapter 499 M1373 dispatch statistics
    /// (7th BASBundle adoption,via M1390 recorder)。
    public let dispatchStatistics:
        BASKernelDispatchStatisticsBundle?

    /// Pipeline 4 — chapter 504 M1395 runtime-mode
    /// advisories (10th BASBundle adoption,via M1391
    /// ledger)。
    public let runtimeModeAdvisories:
        BASEBrainHostRuntimeModeAdvisoryBundle?

    /// Millis since epoch when this record was emitted。
    public let recordedAtMs: Int64

    public init(
        turnID: String,
        cacheReport:
            BASMPSGraphCacheReportResult? = nil,
        routingDecisions:
            BASKernelRoutingDecisionBundle? = nil,
        dispatchStatistics:
            BASKernelDispatchStatisticsBundle? = nil,
        runtimeModeAdvisories:
            BASEBrainHostRuntimeModeAdvisoryBundle? = nil,
        recordedAtMs: Int64
    ) {
        self.turnID = turnID
        self.cacheReport = cacheReport
        self.routingDecisions = routingDecisions
        self.dispatchStatistics = dispatchStatistics
        self.runtimeModeAdvisories =
            runtimeModeAdvisories
        self.recordedAtMs = recordedAtMs
    }

    // MARK: - Composition queries

    /// Count of pipelines (out of 4) that emitted data
    /// for this turn。 Useful for "did hosts wire all
    /// observation surfaces correctly?" audit checks。
    public var populatedPipelineCount: Int {
        var count = 0
        if cacheReport != nil { count += 1 }
        if routingDecisions != nil { count += 1 }
        if dispatchStatistics != nil { count += 1 }
        if runtimeModeAdvisories != nil { count += 1 }
        return count
    }

    /// `true` when all four pipelines are populated。
    /// Hosts running "fully observed" turns emit records
    /// with this property true。
    public var hasAllFourPipelines: Bool {
        populatedPipelineCount == 4
    }

    /// Total kernel dispatches observed by pipelines 1+3。
    /// Pipeline 1 reports total lookups (hit + miss);
    /// pipeline 3 reports total dispatches。 These need
    /// not match (cache lookups can happen without
    /// dispatch attempts and vice versa) — caller
    /// inspects both for cross-validation。
    public var totalLookupsAcrossPipelines: Int {
        let cacheLookups =
            cacheReport?.body.totalLookups ?? 0
        let dispatchAttempts =
            dispatchStatistics?.totalDispatches ?? 0
        return cacheLookups + dispatchAttempts
    }

    /// Cache hit ratio from pipeline 1。 Returns 0 if
    /// cacheReport is nil OR pipeline saw no lookups。
    public var cacheHitRatio: Double {
        cacheReport?.body.hitRatio ?? 0
    }

    /// Best-case routing match ratio from pipeline 2。
    /// Returns 0 if pipeline 2 is nil OR empty。
    public var routingBestCaseRatio: Double {
        routingDecisions?.bestCaseMatchRatio ?? 0
    }

    /// Dispatch success rate from pipeline 3。 Returns
    /// 0 if pipeline 3 is nil OR empty。
    public var dispatchSuccessRate: Double {
        dispatchStatistics?.successRate ?? 0
    }

    /// Advisory honored ratio from pipeline 4。 Returns
    /// 0 if pipeline 4 is nil OR empty。
    public var advisoryHonoredRatio: Double {
        runtimeModeAdvisories?.honoredRatio ?? 0
    }
}
