// MARK: - BASEndOfTurnAuditEmissionBundle
// chapter 五百五 / M1399 — 11th BASBundle<Item> adoption
//
// Wraps the M1397 BASEndOfTurnAuditEmissionRecord as a
// BASBundle Item so hosts replaying N turns get a typed
// Codable batch surface for audit walker consumption。
//
// HONEST SCOPE — chapter 五百五:
// =============================================================
// Pure-additive typed bundle adoption。 V1 byte-equality
// preserved。 ADR-014 OPT-IN — hosts construct the
// bundle explicitly from N emitted records。

import Foundation
import BASRuntimeCore

/// 11th REAL `BASBundle<Item>` typealias migration —
/// batch of N end-of-turn audit records for multi-turn
/// replay / inspection。
public typealias BASEndOfTurnAuditEmissionBundle =
    BASBundle<BASEndOfTurnAuditEmissionRecord>

extension BASBundle
    where Item == BASEndOfTurnAuditEmissionRecord
{

    /// Count of records where all 4 pipelines were
    /// populated。 Useful for "how many fully-observed
    /// turns?" replay audit。
    public var fullyObservedTurnCount: Int {
        items.filter(\.hasAllFourPipelines).count
    }

    /// Ratio of fully-observed turns in [0, 1]。 Zero
    /// when bundle empty。
    public var fullyObservedTurnRatio: Double {
        guard !items.isEmpty else { return 0 }
        return Double(fullyObservedTurnCount)
            / Double(items.count)
    }

    /// Cumulative populated-pipeline count across all
    /// records。 Useful for "did observers fire enough
    /// times during this replay?" audit。
    public var cumulativePopulatedPipelineCount: Int {
        items.reduce(0) {
            $0 + $1.populatedPipelineCount
        }
    }

    /// Distinct turn IDs in the bundle。 Hosts that
    /// emit one record per turn expect this to equal
    /// `items.count`;multiple-emission-per-turn hosts
    /// expect this to be lower。
    public var distinctTurnCount: Int {
        Set(items.map(\.turnID)).count
    }

    /// Mean cache hit ratio across records that had a
    /// non-nil cache report。 Returns 0 when no records
    /// had a cache report。
    public var meanCacheHitRatio: Double {
        let withCacheReport = items
            .compactMap { $0.cacheReport }
        guard !withCacheReport.isEmpty else { return 0 }
        let sum = withCacheReport.reduce(0.0) {
            $0 + $1.body.hitRatio
        }
        return sum / Double(withCacheReport.count)
    }

    /// Mean routing best-case ratio across records that
    /// had non-nil routing decisions。 Returns 0 when
    /// none did。
    public var meanRoutingBestCaseRatio: Double {
        let withRouting = items
            .compactMap { $0.routingDecisions }
        guard !withRouting.isEmpty else { return 0 }
        let sum = withRouting.reduce(0.0) {
            $0 + $1.bestCaseMatchRatio
        }
        return sum / Double(withRouting.count)
    }

    /// Mean dispatch success rate across records that
    /// had non-nil dispatch statistics。 Returns 0 when
    /// none did。
    public var meanDispatchSuccessRate: Double {
        let withDispatch = items
            .compactMap { $0.dispatchStatistics }
        guard !withDispatch.isEmpty else { return 0 }
        let sum = withDispatch.reduce(0.0) {
            $0 + $1.successRate
        }
        return sum / Double(withDispatch.count)
    }
}
