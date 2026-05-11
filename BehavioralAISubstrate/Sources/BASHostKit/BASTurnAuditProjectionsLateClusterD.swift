// MARK: - BASTurnAuditProjectionsLateClusterD
// chapter 四百九十一 / M1340 — V1 cluster B near-finish

import Foundation
import BASMemory
import BASRuntimeCore
import BASWorldPrior

public struct BASTurnAuditProjectionsLateClusterD: Sendable {
    public let unknownReserve: BASUnknownReserve
    public let forbiddenCandidates:
        [BASForbiddenKnowledgeCandidate]
    public let forbiddenAggregate:
        BASForbiddenKnowledgeCandidate.Aggregate?

    public static func compute(
        sessionID: String,
        confidenceFloor: Double,
        quarantineRecords: [BASQuarantineRecord]
    ) -> BASTurnAuditProjectionsLateClusterD {
        let reserve = BASUnknownReserve.derive(
            reserveID:
                "unknown-reserve-\(sessionID)",
            confidenceFloor: confidenceFloor)
        let candidates = quarantineRecords.map {
            BASForbiddenKnowledgeCandidate.derive(
                from: $0)
        }
        let agg = BASForbiddenKnowledgeCandidate
            .aggregate(candidates)
        return BASTurnAuditProjectionsLateClusterD(
            unknownReserve: reserve,
            forbiddenCandidates: candidates,
            forbiddenAggregate: agg)
    }
}
