import Foundation

// 六十二.5 — typed canonical objects + bus payload mapping.
//
// ## Why this exists
//
// Manifesto v3 第三节.3 lists the typed objects each of the
// 8 buses carries. 第二节原则2 names 7 canonical cognitive
// objects ("不是一段段散乱自然语言... 必须靠统一的、可验证
// 的、可审计的类型化对象"). 五十五 ship 了 bus 名字 enum
// 但 **每根 bus 传什么对象**只在文档里。
//
// 六十二.5 ships the typed catalog of canonical objects + bus
// payload mapping.
//
// ## Properties
//
// - **Pure typed reference**.
// - **Every bus has ≥ 1 payload**.
// - **Every canonical object has ≥ 1 carrying bus**.
// - **7 cognitive objects from 二.原则2 all enumerated**.

public enum BASMotherboardCanonicalObject:
    String, Sendable, Equatable, Hashable, Codable,
    CaseIterable
{
    // ----- LeaseBus payloads -----
    case budgetFrame
    case runLease
    case brainState
    case thermalProtectionLevel
    case leaseExpirySignal

    // ----- WorldHostBus payloads -----
    case worldPriorSummary
    case hostConstitutionSummary
    case rhythmSummary
    case boundaryAndAuthorizationSummary

    // ----- SituationBus payloads -----
    case situationField
    case powerGradient
    case urgencyAuthenticity
    case consequenceHorizon
    case manipulationPrecursor

    // ----- CognitiveFrameBus payloads -----
    case canonicalCognitiveFrame
    case mirrorDraft
    case unknownsSet
    case contradictionLattice
    case pressureVector
    case boundaryContact

    // ----- MemoryBus payloads -----
    case memoryBundle
    case episodeArc
    case conflictCluster
    case continuityAnchor

    // ----- FrontierBus payloads -----
    case candidateFrontier
    case counterfactualBranch
    case consequenceProjection
    case opposingBriefing
    case evidenceDebt
    case guardianBranch

    // ----- RiskPermitBus payloads -----
    case riskField
    case actionPermit
    case delayReservation
    case protectiveSubstitute
    case sovereignEscalationHint

    // ----- VersionAuditBus payloads -----
    case updateTicket
    case ruleCandidate
    case hostChangeCandidate
    case versionDelta
    case rollbackWrit
    case sovereignLedgerEntry

    // ----- 二.原则2 7 canonical cognitive objects -----
    // (memoryAtom + sovereignWarrant; the other 5 already
    // appear above as bus payloads.)
    case memoryAtom
    case sovereignWarrant
}

public extension BASMotherboardBus {
    /// Canonical typed objects this bus carries. From
    /// doctrine 三.3.1-3.8.
    var canonicalPayload:
        Set<BASMotherboardCanonicalObject>
    {
        switch self {
        case .lease:
            return [
                .budgetFrame,
                .runLease,
                .brainState,
                .thermalProtectionLevel,
                .leaseExpirySignal,
            ]
        case .worldHost:
            return [
                .worldPriorSummary,
                .hostConstitutionSummary,
                .rhythmSummary,
                .boundaryAndAuthorizationSummary,
            ]
        case .situation:
            return [
                .situationField,
                .powerGradient,
                .urgencyAuthenticity,
                .consequenceHorizon,
                .manipulationPrecursor,
            ]
        case .cognitiveFrame:
            return [
                .canonicalCognitiveFrame,
                .mirrorDraft,
                .unknownsSet,
                .contradictionLattice,
                .pressureVector,
                .boundaryContact,
            ]
        case .memory:
            return [
                .memoryBundle,
                .episodeArc,
                .conflictCluster,
                .continuityAnchor,
                .memoryAtom,
            ]
        case .frontier:
            return [
                .candidateFrontier,
                .counterfactualBranch,
                .consequenceProjection,
                .opposingBriefing,
                .evidenceDebt,
                .guardianBranch,
            ]
        case .riskPermit:
            return [
                .riskField,
                .actionPermit,
                .delayReservation,
                .protectiveSubstitute,
                .sovereignEscalationHint,
                .sovereignWarrant,
            ]
        case .versionAudit:
            return [
                .updateTicket,
                .ruleCandidate,
                .hostChangeCandidate,
                .versionDelta,
                .rollbackWrit,
                .sovereignLedgerEntry,
            ]
        }
    }
}

public extension BASMotherboardCanonicalObject {
    /// Inverse: which bus carries this object. Each object
    /// has ≥ 1 carrying bus; first match returned for
    /// determinism.
    var carryingBus: BASMotherboardBus? {
        for bus in BASMotherboardBus.allCases
        where bus.canonicalPayload.contains(self)
        {
            return bus
        }
        return nil
    }
}

/// 7 canonical cognitive objects named explicitly in
/// 二.原则2 ("层与层之间不能靠'大段 prompt 续命'").
public enum BASMotherboardCognitiveObjectAxis {
    public static let theSeven:
        Set<BASMotherboardCanonicalObject> = [
            .situationField,
            .canonicalCognitiveFrame,
            .memoryAtom,
            .candidateFrontier,
            .actionPermit,
            .sovereignWarrant,
            .updateTicket,
        ]
}
