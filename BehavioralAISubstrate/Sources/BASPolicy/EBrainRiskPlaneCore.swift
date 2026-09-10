import Foundation
import BASRuntimeCore

private func riskUnit(_ value: Double) -> Double {
    min(max(value, 0), 1)
}

private func uniqueRiskStrings(_ values: [String]) -> [String] {
    var seen = Set<String>()
    return values.filter { !$0.isEmpty && seen.insert($0).inserted }
}

private func uniquePermitModes(
    _ modes: [BASActionPermitMode],
    excluding mode: BASActionPermitMode
) -> [BASActionPermitMode] {
    var seen = Set<BASActionPermitMode>()
    return modes.filter { $0 != mode && seen.insert($0).inserted }
}

private func trimmedOrNil(_ value: String?) -> String? {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed?.isEmpty == false ? trimmed : nil
}

public enum BASBrainRiskLevel: String, Codable, CaseIterable, Sendable, Comparable {
    case low
    case medium
    case high
    case extreme

    public static func < (lhs: BASBrainRiskLevel, rhs: BASBrainRiskLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        switch self {
        case .low:
            0
        case .medium:
            1
        case .high:
            2
        case .extreme:
            3
        }
    }
}

public enum BASActionPermitMode: String, Codable, CaseIterable, Sendable {
    case answer
    case mirror
    case compare
    case delay
    case draftOnly = "draft_only"
    case localOnly = "local_only"
    case block
    case replace
    case escalate

    /// audit blindspot-② HIGH — the canonical strictness ORDER of the permit modes (0 = least
    /// restrictive `.answer` … 8 = most restrictive `.escalate`). Single source of truth: the
    /// EBrainRuntimeCoordinator `permitStrictness` helper and `BASShadowResultPermitUpgrader` both
    /// derive their ranking from here so they can never diverge. Note this is NOT the CaseIterable
    /// declaration order (which lists block before replace) — it is the semantic restrictiveness rank.
    public var strictnessRank: Int {
        switch self {
        case .answer:    return 0
        case .mirror:    return 1
        case .compare:   return 2
        case .delay:     return 3
        case .draftOnly: return 4
        case .localOnly: return 5
        case .replace:   return 6
        case .block:     return 7
        case .escalate:  return 8
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case "answer":
            self = .answer
        case "mirror":
            self = .mirror
        case "compare":
            self = .compare
        case "delay":
            self = .delay
        case "draft_only", "draftOnly":
            self = .draftOnly
        case "local_only", "localOnly":
            self = .localOnly
        case "block":
            self = .block
        case "replace":
            self = .replace
        case "escalate":
            self = .escalate
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported action permit mode: \(rawValue)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct BASActionPermit: BASSchemaVersioned {
    public static let currentSchemaVersion = "2.0.0"

    public var schemaVersion: String
    public var mode: BASActionPermitMode
    public var stackedModes: [BASActionPermitMode]
    public var reasonCodes: [String]
    public var allowedDomains: [String]
    public var blockedDomains: [String]
    public var assertionCeiling: String
    public var toolScope: String
    public var memoryScope: String
    public var requireMirror: Bool
    public var requireCompare: Bool
    public var requireSecondCheck: Bool
    public var outputLengthCap: Int
    public var tonePolicy: String
    public var templatePolicy: String
    public var delayWindow: String?
    public var substituteRequired: Bool
    public var escalationHintRef: String?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case mode
        case stackedModes
        case reasonCodes
        case allowedDomains
        case blockedDomains
        case assertionCeiling
        case toolScope
        case memoryScope
        case requireMirror
        case requireCompare
        case requireSecondCheck
        case outputLengthCap
        case tonePolicy
        case templatePolicy
        case delayWindow
        case substituteRequired
        case escalationHintRef
    }

    public init(
        schemaVersion: String = BASActionPermit.currentSchemaVersion,
        mode: BASActionPermitMode,
        stackedModes: [BASActionPermitMode] = [],
        reasonCodes: [String] = [],
        allowedDomains: [String] = [],
        blockedDomains: [String] = [],
        assertionCeiling: String = "guarded",
        toolScope: String = "bounded",
        memoryScope: String = "standard",
        requireMirror: Bool = false,
        requireCompare: Bool = false,
        requireSecondCheck: Bool = false,
        outputLengthCap: Int = 240,
        tonePolicy: String = "grounded_clear",
        templatePolicy: String = "default",
        delayWindow: String? = nil,
        substituteRequired: Bool = false,
        escalationHintRef: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.mode = mode
        self.stackedModes = uniquePermitModes(stackedModes, excluding: mode)
        self.reasonCodes = uniqueRiskStrings(reasonCodes)
        self.allowedDomains = uniqueRiskStrings(allowedDomains)
        self.blockedDomains = uniqueRiskStrings(blockedDomains)
        self.assertionCeiling = assertionCeiling.trimmingCharacters(in: .whitespacesAndNewlines)
        self.toolScope = toolScope.trimmingCharacters(in: .whitespacesAndNewlines)
        self.memoryScope = memoryScope.trimmingCharacters(in: .whitespacesAndNewlines)
        self.requireMirror = requireMirror
        self.requireCompare = requireCompare
        self.requireSecondCheck = requireSecondCheck
        self.outputLengthCap = max(0, outputLengthCap)
        self.tonePolicy = tonePolicy
        self.templatePolicy = templatePolicy
        self.delayWindow = trimmedOrNil(delayWindow)
        self.substituteRequired = substituteRequired
        self.escalationHintRef = trimmedOrNil(escalationHintRef)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(String.self, forKey: .schemaVersion) ?? "1.0.0"
        mode = try container.decode(BASActionPermitMode.self, forKey: .mode)
        stackedModes = uniquePermitModes(
            try container.decodeIfPresent([BASActionPermitMode].self, forKey: .stackedModes) ?? [],
            excluding: mode
        )
        reasonCodes = uniqueRiskStrings(
            try container.decodeIfPresent([String].self, forKey: .reasonCodes) ?? []
        )
        allowedDomains = uniqueRiskStrings(
            try container.decodeIfPresent([String].self, forKey: .allowedDomains) ?? []
        )
        blockedDomains = uniqueRiskStrings(
            try container.decodeIfPresent([String].self, forKey: .blockedDomains) ?? []
        )
        assertionCeiling = try container.decodeIfPresent(String.self, forKey: .assertionCeiling) ?? "guarded"
        toolScope = try container.decodeIfPresent(String.self, forKey: .toolScope) ?? "bounded"
        memoryScope = try container.decodeIfPresent(String.self, forKey: .memoryScope) ?? "standard"
        requireMirror = try container.decodeIfPresent(Bool.self, forKey: .requireMirror) ?? false
        requireCompare = try container.decodeIfPresent(Bool.self, forKey: .requireCompare) ?? false
        requireSecondCheck = try container.decodeIfPresent(Bool.self, forKey: .requireSecondCheck) ?? false
        outputLengthCap = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .outputLengthCap) ?? 240
        )
        tonePolicy = try container.decodeIfPresent(String.self, forKey: .tonePolicy) ?? "grounded_clear"
        templatePolicy = try container.decodeIfPresent(String.self, forKey: .templatePolicy) ?? "default"
        delayWindow = trimmedOrNil(
            try container.decodeIfPresent(String.self, forKey: .delayWindow)
        )
        substituteRequired = try container.decodeIfPresent(Bool.self, forKey: .substituteRequired) ?? false
        escalationHintRef = trimmedOrNil(
            try container.decodeIfPresent(String.self, forKey: .escalationHintRef)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(mode, forKey: .mode)
        try container.encode(stackedModes, forKey: .stackedModes)
        try container.encode(reasonCodes, forKey: .reasonCodes)
        try container.encode(allowedDomains, forKey: .allowedDomains)
        try container.encode(blockedDomains, forKey: .blockedDomains)
        try container.encode(assertionCeiling, forKey: .assertionCeiling)
        try container.encode(toolScope, forKey: .toolScope)
        try container.encode(memoryScope, forKey: .memoryScope)
        try container.encode(requireMirror, forKey: .requireMirror)
        try container.encode(requireCompare, forKey: .requireCompare)
        try container.encode(requireSecondCheck, forKey: .requireSecondCheck)
        try container.encode(outputLengthCap, forKey: .outputLengthCap)
        try container.encode(tonePolicy, forKey: .tonePolicy)
        try container.encode(templatePolicy, forKey: .templatePolicy)
        try container.encodeIfPresent(delayWindow, forKey: .delayWindow)
        try container.encode(substituteRequired, forKey: .substituteRequired)
        try container.encodeIfPresent(escalationHintRef, forKey: .escalationHintRef)
    }

    public var allModes: [BASActionPermitMode] {
        [mode] + stackedModes.filter { $0 != mode }
    }
}

public extension BASActionPermit {
    static func protectiveBlock(reasonCodes: [String]) -> BASActionPermit {
        BASActionPermit(
            mode: .block,
            stackedModes: [.escalate],
            reasonCodes: reasonCodes,
            blockedDomains: ["tool_commit", "memory_commit", "host_commit", "high_consequence_decode"],
            assertionCeiling: "minimal",
            toolScope: "blocked",
            memoryScope: "blocked",
            requireMirror: true,
            requireCompare: true,
            requireSecondCheck: true,
            outputLengthCap: 120,
            tonePolicy: "clear_firm",
            templatePolicy: "protective_alternative",
            substituteRequired: true,
            escalationHintRef: "sovereign.l11.block"
        )
    }
}

public struct BASRiskCard: BASSchemaVersioned {
    public static let currentSchemaVersion = "2.0.0"

    public var schemaVersion: String
    public var totalRisk: Double
    public var riskLevel: BASBrainRiskLevel
    public var factors: [String]
    public var uncertainty: Double
    public var irreversibility: Double
    public var manipulationStrength: Double
    public var gsiScore: Double
    public var recommendedMode: BASActionPermitMode
    public var stackedModes: [BASActionPermitMode]
    public var assertionCeiling: String
    public var delayType: String?
    public var substituteType: String?
    public var sovereignHintLevel: String?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case totalRisk
        case riskLevel
        case factors
        case uncertainty
        case irreversibility
        case manipulationStrength
        case gsiScore
        case recommendedMode
        case stackedModes
        case assertionCeiling
        case delayType
        case substituteType
        case sovereignHintLevel
    }

    public init(
        schemaVersion: String = BASRiskCard.currentSchemaVersion,
        totalRisk: Double,
        riskLevel: BASBrainRiskLevel,
        factors: [String] = [],
        uncertainty: Double,
        irreversibility: Double,
        manipulationStrength: Double,
        gsiScore: Double,
        recommendedMode: BASActionPermitMode,
        stackedModes: [BASActionPermitMode] = [],
        assertionCeiling: String = "standard",
        delayType: String? = nil,
        substituteType: String? = nil,
        sovereignHintLevel: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.totalRisk = min(max(totalRisk, 0), 1)
        self.riskLevel = riskLevel
        self.factors = uniqueRiskStrings(factors)
        self.uncertainty = min(max(uncertainty, 0), 1)
        self.irreversibility = min(max(irreversibility, 0), 1)
        self.manipulationStrength = min(max(manipulationStrength, 0), 1)
        self.gsiScore = min(max(gsiScore, 0), 1)
        self.recommendedMode = recommendedMode
        self.stackedModes = uniquePermitModes(stackedModes, excluding: recommendedMode)
        self.assertionCeiling = assertionCeiling.trimmingCharacters(in: .whitespacesAndNewlines)
        self.delayType = trimmedOrNil(delayType)
        self.substituteType = trimmedOrNil(substituteType)
        self.sovereignHintLevel = trimmedOrNil(sovereignHintLevel)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(String.self, forKey: .schemaVersion) ?? "1.0.0"
        totalRisk = min(max(try container.decode(Double.self, forKey: .totalRisk), 0), 1)
        riskLevel = try container.decode(BASBrainRiskLevel.self, forKey: .riskLevel)
        factors = uniqueRiskStrings(
            try container.decodeIfPresent([String].self, forKey: .factors) ?? []
        )
        uncertainty = min(max(try container.decode(Double.self, forKey: .uncertainty), 0), 1)
        irreversibility = min(max(try container.decode(Double.self, forKey: .irreversibility), 0), 1)
        manipulationStrength = min(max(try container.decode(Double.self, forKey: .manipulationStrength), 0), 1)
        gsiScore = min(max(try container.decode(Double.self, forKey: .gsiScore), 0), 1)
        recommendedMode = try container.decode(BASActionPermitMode.self, forKey: .recommendedMode)
        stackedModes = uniquePermitModes(
            try container.decodeIfPresent([BASActionPermitMode].self, forKey: .stackedModes) ?? [],
            excluding: recommendedMode
        )
        assertionCeiling = try container.decodeIfPresent(String.self, forKey: .assertionCeiling) ?? "standard"
        delayType = trimmedOrNil(
            try container.decodeIfPresent(String.self, forKey: .delayType)
        )
        substituteType = trimmedOrNil(
            try container.decodeIfPresent(String.self, forKey: .substituteType)
        )
        sovereignHintLevel = trimmedOrNil(
            try container.decodeIfPresent(String.self, forKey: .sovereignHintLevel)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(totalRisk, forKey: .totalRisk)
        try container.encode(riskLevel, forKey: .riskLevel)
        try container.encode(factors, forKey: .factors)
        try container.encode(uncertainty, forKey: .uncertainty)
        try container.encode(irreversibility, forKey: .irreversibility)
        try container.encode(manipulationStrength, forKey: .manipulationStrength)
        try container.encode(gsiScore, forKey: .gsiScore)
        try container.encode(recommendedMode, forKey: .recommendedMode)
        try container.encode(stackedModes, forKey: .stackedModes)
        try container.encode(assertionCeiling, forKey: .assertionCeiling)
        try container.encodeIfPresent(delayType, forKey: .delayType)
        try container.encodeIfPresent(substituteType, forKey: .substituteType)
        try container.encodeIfPresent(sovereignHintLevel, forKey: .sovereignHintLevel)
    }
}

public struct BASHazardVector: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var harmSeverity: Double
    public var harmScope: Double
    public var irreversibility: Double
    public var uncertainty: Double
    public var evidenceDebt: Double
    public var manipulationIntensity: Double
    public var pressureAuthenticity: Double
    public var vulnerabilityCoupling: Double
    public var sideEffectScope: Double

    public init(
        schemaVersion: String = BASHazardVector.currentSchemaVersion,
        harmSeverity: Double,
        harmScope: Double,
        irreversibility: Double,
        uncertainty: Double,
        evidenceDebt: Double,
        manipulationIntensity: Double,
        pressureAuthenticity: Double,
        vulnerabilityCoupling: Double,
        sideEffectScope: Double
    ) {
        self.schemaVersion = schemaVersion
        self.harmSeverity = riskUnit(harmSeverity)
        self.harmScope = riskUnit(harmScope)
        self.irreversibility = riskUnit(irreversibility)
        self.uncertainty = riskUnit(uncertainty)
        self.evidenceDebt = riskUnit(evidenceDebt)
        self.manipulationIntensity = riskUnit(manipulationIntensity)
        self.pressureAuthenticity = riskUnit(pressureAuthenticity)
        self.vulnerabilityCoupling = riskUnit(vulnerabilityCoupling)
        self.sideEffectScope = riskUnit(sideEffectScope)
    }
}

public struct BASHarmRadiusMap: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var radiusID: String
    public var privateImpact: Double
    public var relationImpact: Double
    public var workflowImpact: Double
    public var publicImpact: Double
    public var longTermTrace: Double

    public init(
        schemaVersion: String = BASHarmRadiusMap.currentSchemaVersion,
        radiusID: String,
        privateImpact: Double,
        relationImpact: Double,
        workflowImpact: Double,
        publicImpact: Double,
        longTermTrace: Double
    ) {
        self.schemaVersion = schemaVersion
        self.radiusID = radiusID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.privateImpact = riskUnit(privateImpact)
        self.relationImpact = riskUnit(relationImpact)
        self.workflowImpact = riskUnit(workflowImpact)
        self.publicImpact = riskUnit(publicImpact)
        self.longTermTrace = riskUnit(longTermTrace)
    }
}

public struct BASReversibilityProfile: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var profileID: String
    public var reversible: Bool
    public var rollbackCost: Double
    public var confirmNodes: [String]
    public var draftSafe: Bool
    public var smallStepPossible: Bool

    public init(
        schemaVersion: String = BASReversibilityProfile.currentSchemaVersion,
        profileID: String,
        reversible: Bool,
        rollbackCost: Double,
        confirmNodes: [String] = [],
        draftSafe: Bool,
        smallStepPossible: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.profileID = profileID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.reversible = reversible
        self.rollbackCost = riskUnit(rollbackCost)
        self.confirmNodes = uniqueRiskStrings(confirmNodes)
        self.draftSafe = draftSafe
        self.smallStepPossible = smallStepPossible
    }
}

public struct BASEvidenceSufficiency: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var sufficiencyID: String
    public var supportLevel: Double
    public var missingEvidence: [String]
    public var allowedAssertionLevel: String
    public var allowedActionLevel: String

    public init(
        schemaVersion: String = BASEvidenceSufficiency.currentSchemaVersion,
        sufficiencyID: String,
        supportLevel: Double,
        missingEvidence: [String] = [],
        allowedAssertionLevel: String,
        allowedActionLevel: String
    ) {
        self.schemaVersion = schemaVersion
        self.sufficiencyID = sufficiencyID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.supportLevel = riskUnit(supportLevel)
        self.missingEvidence = uniqueRiskStrings(missingEvidence)
        self.allowedAssertionLevel = allowedAssertionLevel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.allowedActionLevel = allowedActionLevel.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct BASGSITrace: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var traceID: String
    public var gaslightSignals: [String]
    public var coerciveUrgency: Double
    public var shamePressure: Double
    public var authorityMask: Double
    public var relationLeverage: Double
    public var susceptibilityBand: String

    public init(
        schemaVersion: String = BASGSITrace.currentSchemaVersion,
        traceID: String,
        gaslightSignals: [String] = [],
        coerciveUrgency: Double,
        shamePressure: Double,
        authorityMask: Double,
        relationLeverage: Double,
        susceptibilityBand: String
    ) {
        self.schemaVersion = schemaVersion
        self.traceID = traceID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.gaslightSignals = uniqueRiskStrings(gaslightSignals)
        self.coerciveUrgency = riskUnit(coerciveUrgency)
        self.shamePressure = riskUnit(shamePressure)
        self.authorityMask = riskUnit(authorityMask)
        self.relationLeverage = riskUnit(relationLeverage)
        self.susceptibilityBand = susceptibilityBand.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct BASVulnerabilityCoupling: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var couplingID: String
    public var touchedBoundaries: [String]
    public var lowEnergyResonance: Double
    public var sensitivityWindow: Double
    public var protectionBias: Double

    public init(
        schemaVersion: String = BASVulnerabilityCoupling.currentSchemaVersion,
        couplingID: String,
        touchedBoundaries: [String] = [],
        lowEnergyResonance: Double,
        sensitivityWindow: Double,
        protectionBias: Double
    ) {
        self.schemaVersion = schemaVersion
        self.couplingID = couplingID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.touchedBoundaries = uniqueRiskStrings(touchedBoundaries)
        self.lowEnergyResonance = riskUnit(lowEnergyResonance)
        self.sensitivityWindow = riskUnit(sensitivityWindow)
        self.protectionBias = riskUnit(protectionBias)
    }
}

public struct BASActionModeDecision: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var decisionID: String
    public var primaryMode: BASActionPermitMode
    public var stackedModes: [BASActionPermitMode]
    public var reasonCodes: [String]
    public var confidence: Double

    public init(
        schemaVersion: String = BASActionModeDecision.currentSchemaVersion,
        decisionID: String,
        primaryMode: BASActionPermitMode,
        stackedModes: [BASActionPermitMode] = [],
        reasonCodes: [String] = [],
        confidence: Double
    ) {
        self.schemaVersion = schemaVersion
        self.decisionID = decisionID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.primaryMode = primaryMode
        self.stackedModes = uniquePermitModes(stackedModes, excluding: primaryMode)
        self.reasonCodes = uniqueRiskStrings(reasonCodes)
        self.confidence = riskUnit(confidence)
    }
}

public struct BASDelayReservation: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var reservationID: String
    public var delayType: String
    public var minDelay: Int
    public var maxDelay: Int
    public var allowedIntermediateActions: [String]

    public init(
        schemaVersion: String = BASDelayReservation.currentSchemaVersion,
        reservationID: String,
        delayType: String,
        minDelay: Int,
        maxDelay: Int,
        allowedIntermediateActions: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.reservationID = reservationID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.delayType = delayType.trimmingCharacters(in: .whitespacesAndNewlines)
        self.minDelay = max(0, minDelay)
        self.maxDelay = max(self.minDelay, maxDelay)
        self.allowedIntermediateActions = uniqueRiskStrings(allowedIntermediateActions)
    }
}

public struct BASProtectiveSubstitute: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var substituteID: String
    public var sourceCandidateRef: String
    public var substituteType: String
    public var description: String
    public var safetyGain: Double

    public init(
        schemaVersion: String = BASProtectiveSubstitute.currentSchemaVersion,
        substituteID: String,
        sourceCandidateRef: String,
        substituteType: String,
        description: String,
        safetyGain: Double
    ) {
        self.schemaVersion = schemaVersion
        self.substituteID = substituteID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceCandidateRef = sourceCandidateRef.trimmingCharacters(in: .whitespacesAndNewlines)
        self.substituteType = substituteType.trimmingCharacters(in: .whitespacesAndNewlines)
        self.description = description
        self.safetyGain = riskUnit(safetyGain)
    }
}

public struct BASSovereignEscalationHint: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var hintID: String
    public var sourceRefs: [String]
    public var reasonCodes: [String]
    public var urgency: String
    public var suggestedScope: String

    public init(
        schemaVersion: String = BASSovereignEscalationHint.currentSchemaVersion,
        hintID: String,
        sourceRefs: [String] = [],
        reasonCodes: [String] = [],
        urgency: String,
        suggestedScope: String
    ) {
        self.schemaVersion = schemaVersion
        self.hintID = hintID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceRefs = uniqueRiskStrings(sourceRefs)
        self.reasonCodes = uniqueRiskStrings(reasonCodes)
        self.urgency = urgency.trimmingCharacters(in: .whitespacesAndNewlines)
        self.suggestedScope = suggestedScope.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct BASRiskField: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var fieldID: String
    public var candidateRef: String
    public var hazardVector: BASHazardVector
    public var harmRadius: BASHarmRadiusMap
    public var reversibilityProfile: BASReversibilityProfile
    public var evidenceSufficiency: BASEvidenceSufficiency
    public var gsiTrace: BASGSITrace
    public var vulnerabilityCoupling: BASVulnerabilityCoupling
    public var confidenceBand: String

    public init(
        schemaVersion: String = BASRiskField.currentSchemaVersion,
        fieldID: String,
        candidateRef: String,
        hazardVector: BASHazardVector,
        harmRadius: BASHarmRadiusMap,
        reversibilityProfile: BASReversibilityProfile,
        evidenceSufficiency: BASEvidenceSufficiency,
        gsiTrace: BASGSITrace,
        vulnerabilityCoupling: BASVulnerabilityCoupling,
        confidenceBand: String
    ) {
        self.schemaVersion = schemaVersion
        self.fieldID = fieldID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.candidateRef = candidateRef.trimmingCharacters(in: .whitespacesAndNewlines)
        self.hazardVector = hazardVector
        self.harmRadius = harmRadius
        self.reversibilityProfile = reversibilityProfile
        self.evidenceSufficiency = evidenceSufficiency
        self.gsiTrace = gsiTrace
        self.vulnerabilityCoupling = vulnerabilityCoupling
        self.confidenceBand = confidenceBand.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct BASRiskDecisionPackage: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var packageID: String
    public var riskCard: BASRiskCard
    public var riskField: BASRiskField
    public var actionModeDecision: BASActionModeDecision
    public var actionPermit: BASActionPermit
    public var delayReservation: BASDelayReservation?
    public var protectiveSubstitute: BASProtectiveSubstitute?
    public var sovereignEscalationHint: BASSovereignEscalationHint?

    public init(
        schemaVersion: String = BASRiskDecisionPackage.currentSchemaVersion,
        packageID: String,
        riskCard: BASRiskCard,
        riskField: BASRiskField,
        actionModeDecision: BASActionModeDecision,
        actionPermit: BASActionPermit,
        delayReservation: BASDelayReservation? = nil,
        protectiveSubstitute: BASProtectiveSubstitute? = nil,
        sovereignEscalationHint: BASSovereignEscalationHint? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.packageID = packageID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.riskCard = riskCard
        self.riskField = riskField
        self.actionModeDecision = actionModeDecision
        self.actionPermit = actionPermit
        self.delayReservation = delayReservation
        self.protectiveSubstitute = protectiveSubstitute
        self.sovereignEscalationHint = sovereignEscalationHint
    }
}
