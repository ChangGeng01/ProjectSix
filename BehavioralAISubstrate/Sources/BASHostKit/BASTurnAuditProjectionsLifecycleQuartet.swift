// MARK: - BASTurnAuditProjectionsLifecycleQuartet
// chapter 四百八十八 / M1328 — V1 cluster B continuation

import Foundation
import BASMemory
import BASRuntimeCore

public struct BASTurnAuditProjectionsLifecycleQuartet: Sendable {
    public let synthesizedSeals: [BASSealEnvelope]
    public let sealAggregate:
        BASOldSealSealingProtocol.Aggregate?
    public let lifecycleSessions:
        [BASEvolutionLifecycleSession]
    public let lifecycleAggregate:
        BASEvolutionLifecycleSession.Aggregate?

    public static func compute(
        quarantineRecords: [BASQuarantineRecord],
        updateTickets: [BASUpdateTicket]
    ) -> BASTurnAuditProjectionsLifecycleQuartet {
        let seals = quarantineRecords.map { record in
            BASSealEnvelope(
                sealID: "seal.\(record.quarantineID)",
                targetRefs: [record.sourceRef],
                sealReason: record.reasonCodes
                    .joined(separator: ","),
                accessPolicy: .sovereignOnly,
                revealConditions: [],
                lineageCutRefs: [],
                auditRef: record.quarantineID)
        }
        let sealAgg = BASOldSealSealingProtocol
            .aggregate(seals)
        let sessions = updateTickets.map { t in
            BASEvolutionLifecycleSession(
                candidateID: t.ticketID,
                currentStage: .proposed,
                history: [])
        }
        let sessionAgg = BASEvolutionLifecycleSession
            .aggregate(sessions)
        return BASTurnAuditProjectionsLifecycleQuartet(
            synthesizedSeals: seals,
            sealAggregate: sealAgg,
            lifecycleSessions: sessions,
            lifecycleAggregate: sessionAgg)
    }
}
