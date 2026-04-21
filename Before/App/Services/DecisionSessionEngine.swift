import CryptoKit
import Foundation
import SQLite3
import BASHostKit

enum DecisionSessionLayerPlacement: String, Codable, Equatable, Sendable {
    case foldedLung = "L3.folded_lung"
}

enum DecisionSessionStatus: String, Codable, Equatable, Sendable {
    case active
    case paused
    case stalled
    case archived
    case broken
}

enum DecisionSessionBranchStatus: String, Codable, Equatable, Sendable {
    case active
    case merged
    case abandoned
}

enum DecisionSessionEventType: String, Codable, Equatable, Sendable {
    case userMessage = "user_message"
    case assistantMessage = "assistant_message"
    case correctionAdded = "correction_added"
    case branchMerged = "branch_merged"
    case toolCallStarted = "tool_call_started"
    case toolCallFinished = "tool_call_finished"
    case toolCallFailed = "tool_call_failed"
    case checkpointCreated = "checkpoint_created"
    case stepStarted = "step_started"
    case stepHeartbeat = "step_heartbeat"
    case stepStalled = "step_stalled"
    case stepRecovered = "step_recovered"
    case sessionPaused = "session_paused"
    case sessionResumed = "session_resumed"
    case sessionError = "session_error"
    case sessionRecovered = "session_recovered"
    case branchCreated = "branch_created"
}

enum DecisionSessionRuntimeMode: String, Codable, Equatable, Sendable {
    case chat
    case code
    case review
    case debug
}

enum DecisionSessionStepStatus: String, Codable, Equatable, Sendable {
    case planning
    case acting
    case waitingTool = "waiting_tool"
    case writing
    case stalled
    case failed
    case completed
}

struct DecisionSession: Codable, Equatable, Sendable {
    let id: String
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let status: DecisionSessionStatus
    let headBranchId: String
    let latestCheckpointId: String?
}

struct DecisionSessionBranch: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let sessionId: String
    let parentBranchId: String?
    let baseCheckpointId: String?
    let name: String
    let createdAt: Date
    let status: DecisionSessionBranchStatus
}

struct DecisionSessionEvent: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let sessionId: String
    let branchId: String
    let seq: Int
    let createdAt: Date
    let type: DecisionSessionEventType
    let parentEventId: String?
    let payloadRef: String?
    let payloadHash: String
    let recordHash: String
}

struct DecisionSessionCheckpointSummary: Codable, Equatable, Sendable {
    var goal: String
    var acceptedConstraints: [String]
    var confirmedFacts: [String]
    var openTasks: [String]
    var currentScope: [String]

    static let empty = DecisionSessionCheckpointSummary(
        goal: "",
        acceptedConstraints: [],
        confirmedFacts: [],
        openTasks: [],
        currentScope: []
    )
}

extension DecisionSessionCheckpointSummary {
    var eBrainBudgetLine: String? {
        DecisionEvolutionEBrainPresentationSupport.firstLine(
            withPrefix: DecisionEvolutionEBrainPresentationSupport.checkpointBudgetPrefix,
            in: acceptedConstraints
        )
    }

    var eBrainRouteLine: String? {
        DecisionEvolutionEBrainPresentationSupport.firstLine(
            withPrefix: DecisionEvolutionEBrainPresentationSupport.checkpointRoutePrefix,
            in: acceptedConstraints
        )
    }

    var eBrainDecisionLine: String? {
        DecisionEvolutionEBrainPresentationSupport.checkpointDecisionLine(
            from: confirmedFacts
        )
    }

    var eBrainTaskLine: String? {
        DecisionEvolutionEBrainPresentationSupport.firstLine(
            matching: DecisionEvolutionEBrainPresentationSupport.checkpointTaskPrefixes,
            in: openTasks
        )
    }

    var eBrainPressureLine: String? {
        DecisionEvolutionEBrainPresentationSupport.firstLine(
            withPrefix: DecisionEvolutionEBrainPresentationSupport.checkpointPressurePrefix,
            in: confirmedFacts
        )
    }

    var eBrainAuditLine: String? {
        DecisionEvolutionEBrainPresentationSupport.firstLine(
            withPrefix: DecisionEvolutionEBrainPresentationSupport.checkpointAuditPrefix,
            in: confirmedFacts
        )
    }

    var eBrainActiveKillSwitchesLine: String? {
        DecisionEvolutionEBrainPresentationSupport.firstLine(
            withPrefix: DecisionEvolutionEBrainPresentationSupport.checkpointActiveKillSwitchesPrefix,
            in: confirmedFacts
        )
    }

    var eBrainKillSwitchesLine: String? {
        DecisionEvolutionEBrainPresentationSupport.checkpointKillSwitchesLine(
            from: confirmedFacts
        )
    }

    var actionLine: String? {
        DecisionEvolutionEBrainPresentationSupport.firstLine(
            withPrefix: "action:",
            in: confirmedFacts
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

struct DecisionSessionCheckpointEBrainAnchor: Codable, Equatable, Sendable {
    var sessionID: String?
    var thoughtFoldChecksum: String?
    var riskLevel: String?
    var permitMode: String?
    var hostGatePercent: Int?
    var reviewDirectiveLine: String?
    var presenceLine: String?
    var riskFactorsLine: String?
    var reasonCodesLine: String?
    var courtLine: String?
    var versionTreeLine: String?
    var retractionLine: String?
    var stackedModes: [String]
    var assertionCeiling: String?
    var allowedDomains: [String]
    var blockedDomains: [String]
    var delayType: String?
    var substituteType: String?
    var sovereignHintLevel: String?
    var sovereignVerdictLine: String?
    var sovereignAuthorityLine: String?
    var sovereignAuditLine: String?
    var executionCapability: DecisionSessionCheckpointExecutionCapability?
    var morphGraph: BASMorphGraph?
    var hotColdMap: BASHotColdMap?
    var precisionProfile: BASPrecisionProfile?
    var lungState: BASLungState?
    var thermalExchange: BASThermalExchangeFrame?
    var breathScheduler: BASBreathSchedulerFrame?
    var integrityWeave: BASIntegrityWeaveFrame?
    var organPackages: [BASOrganPackage]
    var organDeltaPlan: BASOrganDeltaPlan?
    var resumeFrame: BASResumeFrame?
    var rollbackAnchor: BASRollbackAnchor?
    var sovereignBridgeResult: DecisionFoldedLungSovereignBridgeResult?

    private enum CodingKeys: String, CodingKey {
        case sessionID
        case thoughtFoldChecksum
        case riskLevel
        case permitMode
        case hostGatePercent
        case reviewDirectiveLine
        case presenceLine
        case riskFactorsLine
        case reasonCodesLine
        case courtLine
        case versionTreeLine
        case retractionLine
        case stackedModes
        case assertionCeiling
        case allowedDomains
        case blockedDomains
        case delayType
        case substituteType
        case sovereignHintLevel
        case sovereignVerdictLine
        case sovereignAuthorityLine
        case sovereignAuditLine
        case executionCapability
        case morphGraph
        case hotColdMap
        case precisionProfile
        case lungState
        case thermalExchange
        case breathScheduler
        case integrityWeave
        case organPackages
        case organDeltaPlan
        case resumeFrame
        case rollbackAnchor
        case sovereignBridgeResult
    }

    init(
        sessionID: String? = nil,
        thoughtFoldChecksum: String? = nil,
        riskLevel: String? = nil,
        permitMode: String? = nil,
        hostGatePercent: Int? = nil,
        reviewDirectiveLine: String? = nil,
        presenceLine: String? = nil,
        riskFactorsLine: String? = nil,
        reasonCodesLine: String? = nil,
        courtLine: String? = nil,
        versionTreeLine: String? = nil,
        retractionLine: String? = nil,
        stackedModes: [String] = [],
        assertionCeiling: String? = nil,
        allowedDomains: [String] = [],
        blockedDomains: [String] = [],
        delayType: String? = nil,
        substituteType: String? = nil,
        sovereignHintLevel: String? = nil,
        sovereignVerdictLine: String? = nil,
        sovereignAuthorityLine: String? = nil,
        sovereignAuditLine: String? = nil,
        executionCapability: DecisionSessionCheckpointExecutionCapability? = nil,
        morphGraph: BASMorphGraph? = nil,
        hotColdMap: BASHotColdMap? = nil,
        precisionProfile: BASPrecisionProfile? = nil,
        lungState: BASLungState? = nil,
        thermalExchange: BASThermalExchangeFrame? = nil,
        breathScheduler: BASBreathSchedulerFrame? = nil,
        integrityWeave: BASIntegrityWeaveFrame? = nil,
        organPackages: [BASOrganPackage] = [],
        organDeltaPlan: BASOrganDeltaPlan? = nil,
        resumeFrame: BASResumeFrame? = nil,
        rollbackAnchor: BASRollbackAnchor? = nil,
        sovereignBridgeResult: DecisionFoldedLungSovereignBridgeResult? = nil
    ) {
        self.sessionID = sessionID?.evolutionTrimmedNonEmpty
        self.thoughtFoldChecksum = thoughtFoldChecksum?.evolutionTrimmedNonEmpty
        self.riskLevel = riskLevel?.evolutionTrimmedNonEmpty
        self.permitMode = permitMode?.evolutionTrimmedNonEmpty
        self.hostGatePercent = hostGatePercent
        self.reviewDirectiveLine = reviewDirectiveLine?.evolutionTrimmedNonEmpty
        self.presenceLine = presenceLine?.evolutionTrimmedNonEmpty
        self.riskFactorsLine = riskFactorsLine?.evolutionTrimmedNonEmpty
        self.reasonCodesLine = reasonCodesLine?.evolutionTrimmedNonEmpty
        self.courtLine = courtLine?.evolutionTrimmedNonEmpty
        self.versionTreeLine = versionTreeLine?.evolutionTrimmedNonEmpty
        self.retractionLine = retractionLine?.evolutionTrimmedNonEmpty
        self.stackedModes = Self.orderedUniqueStrings(stackedModes)
        self.assertionCeiling = assertionCeiling?.evolutionTrimmedNonEmpty
        self.allowedDomains = Self.orderedUniqueStrings(allowedDomains)
        self.blockedDomains = Self.orderedUniqueStrings(blockedDomains)
        self.delayType = delayType?.evolutionTrimmedNonEmpty
        self.substituteType = substituteType?.evolutionTrimmedNonEmpty
        self.sovereignHintLevel = sovereignHintLevel?.evolutionTrimmedNonEmpty
        self.sovereignVerdictLine = sovereignVerdictLine?.evolutionTrimmedNonEmpty
        self.sovereignAuthorityLine = sovereignAuthorityLine?.evolutionTrimmedNonEmpty
        self.sovereignAuditLine = sovereignAuditLine?.evolutionTrimmedNonEmpty
        self.executionCapability = executionCapability?.normalized
        self.morphGraph = morphGraph
        self.hotColdMap = hotColdMap
        self.precisionProfile = precisionProfile
        self.lungState = lungState
        self.thermalExchange = thermalExchange
        self.breathScheduler = breathScheduler
        self.integrityWeave = integrityWeave
        self.organPackages = organPackages
        self.organDeltaPlan = organDeltaPlan
        self.resumeFrame = resumeFrame
        self.rollbackAnchor = rollbackAnchor
        self.sovereignBridgeResult = sovereignBridgeResult
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            sessionID: try container.decodeIfPresent(String.self, forKey: .sessionID),
            thoughtFoldChecksum: try container.decodeIfPresent(String.self, forKey: .thoughtFoldChecksum),
            riskLevel: try container.decodeIfPresent(String.self, forKey: .riskLevel),
            permitMode: try container.decodeIfPresent(String.self, forKey: .permitMode),
            hostGatePercent: try container.decodeIfPresent(Int.self, forKey: .hostGatePercent),
            reviewDirectiveLine: try container.decodeIfPresent(String.self, forKey: .reviewDirectiveLine),
            presenceLine: try container.decodeIfPresent(String.self, forKey: .presenceLine),
            riskFactorsLine: try container.decodeIfPresent(String.self, forKey: .riskFactorsLine),
            reasonCodesLine: try container.decodeIfPresent(String.self, forKey: .reasonCodesLine),
            courtLine: try container.decodeIfPresent(String.self, forKey: .courtLine),
            versionTreeLine: try container.decodeIfPresent(String.self, forKey: .versionTreeLine),
            retractionLine: try container.decodeIfPresent(String.self, forKey: .retractionLine),
            stackedModes: try container.decodeIfPresent([String].self, forKey: .stackedModes) ?? [],
            assertionCeiling: try container.decodeIfPresent(String.self, forKey: .assertionCeiling),
            allowedDomains: try container.decodeIfPresent([String].self, forKey: .allowedDomains) ?? [],
            blockedDomains: try container.decodeIfPresent([String].self, forKey: .blockedDomains) ?? [],
            delayType: try container.decodeIfPresent(String.self, forKey: .delayType),
            substituteType: try container.decodeIfPresent(String.self, forKey: .substituteType),
            sovereignHintLevel: try container.decodeIfPresent(String.self, forKey: .sovereignHintLevel),
            sovereignVerdictLine: try container.decodeIfPresent(String.self, forKey: .sovereignVerdictLine),
            sovereignAuthorityLine: try container.decodeIfPresent(String.self, forKey: .sovereignAuthorityLine),
            sovereignAuditLine: try container.decodeIfPresent(String.self, forKey: .sovereignAuditLine),
            executionCapability: try container.decodeIfPresent(DecisionSessionCheckpointExecutionCapability.self, forKey: .executionCapability),
            morphGraph: try container.decodeIfPresent(BASMorphGraph.self, forKey: .morphGraph),
            hotColdMap: try container.decodeIfPresent(BASHotColdMap.self, forKey: .hotColdMap),
            precisionProfile: try container.decodeIfPresent(BASPrecisionProfile.self, forKey: .precisionProfile),
            lungState: try container.decodeIfPresent(BASLungState.self, forKey: .lungState),
            thermalExchange: try container.decodeIfPresent(BASThermalExchangeFrame.self, forKey: .thermalExchange),
            breathScheduler: try container.decodeIfPresent(BASBreathSchedulerFrame.self, forKey: .breathScheduler),
            integrityWeave: try container.decodeIfPresent(BASIntegrityWeaveFrame.self, forKey: .integrityWeave),
            organPackages: try container.decodeIfPresent([BASOrganPackage].self, forKey: .organPackages) ?? [],
            organDeltaPlan: try container.decodeIfPresent(BASOrganDeltaPlan.self, forKey: .organDeltaPlan),
            resumeFrame: try container.decodeIfPresent(BASResumeFrame.self, forKey: .resumeFrame),
            rollbackAnchor: try container.decodeIfPresent(BASRollbackAnchor.self, forKey: .rollbackAnchor),
            sovereignBridgeResult: try container.decodeIfPresent(DecisionFoldedLungSovereignBridgeResult.self, forKey: .sovereignBridgeResult)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(sessionID, forKey: .sessionID)
        try container.encodeIfPresent(thoughtFoldChecksum, forKey: .thoughtFoldChecksum)
        try container.encodeIfPresent(riskLevel, forKey: .riskLevel)
        try container.encodeIfPresent(permitMode, forKey: .permitMode)
        try container.encodeIfPresent(hostGatePercent, forKey: .hostGatePercent)
        try container.encodeIfPresent(reviewDirectiveLine, forKey: .reviewDirectiveLine)
        try container.encodeIfPresent(presenceLine, forKey: .presenceLine)
        try container.encodeIfPresent(riskFactorsLine, forKey: .riskFactorsLine)
        try container.encodeIfPresent(reasonCodesLine, forKey: .reasonCodesLine)
        try container.encodeIfPresent(courtLine, forKey: .courtLine)
        try container.encodeIfPresent(versionTreeLine, forKey: .versionTreeLine)
        try container.encodeIfPresent(retractionLine, forKey: .retractionLine)
        try container.encode(stackedModes, forKey: .stackedModes)
        try container.encodeIfPresent(assertionCeiling, forKey: .assertionCeiling)
        try container.encode(allowedDomains, forKey: .allowedDomains)
        try container.encode(blockedDomains, forKey: .blockedDomains)
        try container.encodeIfPresent(delayType, forKey: .delayType)
        try container.encodeIfPresent(substituteType, forKey: .substituteType)
        try container.encodeIfPresent(sovereignHintLevel, forKey: .sovereignHintLevel)
        try container.encodeIfPresent(sovereignVerdictLine, forKey: .sovereignVerdictLine)
        try container.encodeIfPresent(sovereignAuthorityLine, forKey: .sovereignAuthorityLine)
        try container.encodeIfPresent(sovereignAuditLine, forKey: .sovereignAuditLine)
        try container.encodeIfPresent(executionCapability, forKey: .executionCapability)
        try container.encodeIfPresent(morphGraph, forKey: .morphGraph)
        try container.encodeIfPresent(hotColdMap, forKey: .hotColdMap)
        try container.encodeIfPresent(precisionProfile, forKey: .precisionProfile)
        try container.encodeIfPresent(lungState, forKey: .lungState)
        try container.encodeIfPresent(thermalExchange, forKey: .thermalExchange)
        try container.encodeIfPresent(breathScheduler, forKey: .breathScheduler)
        try container.encodeIfPresent(integrityWeave, forKey: .integrityWeave)
        try container.encode(organPackages, forKey: .organPackages)
        try container.encodeIfPresent(organDeltaPlan, forKey: .organDeltaPlan)
        try container.encodeIfPresent(resumeFrame, forKey: .resumeFrame)
        try container.encodeIfPresent(rollbackAnchor, forKey: .rollbackAnchor)
        try container.encodeIfPresent(sovereignBridgeResult, forKey: .sovereignBridgeResult)
    }

    private static func orderedUniqueStrings(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { uniqueValues, value in
            guard let trimmed = value.evolutionTrimmedNonEmpty else {
                return
            }
            guard uniqueValues.contains(trimmed) == false else {
                return
            }
            uniqueValues.append(trimmed)
        }
    }
}

struct DecisionSessionCheckpointExecutionCapability: Codable, Equatable, Sendable {
    let activeProviderID: String
    let preferredProviderID: String
    let fallbackProviderID: String?
    let providerTrackID: String
    let executionTierID: String
    let foundationTierID: String
    let reasonCodes: [String]
    let worldPriorContract: DecisionEBrainWorldPriorContract?
    let temporalKnowledgeContract: DecisionEBrainTemporalKnowledgeContract?
    let evidenceContract: DecisionEBrainEvidenceContract?

    private enum CodingKeys: String, CodingKey {
        case activeProviderID
        case preferredProviderID
        case fallbackProviderID
        case providerTrackID
        case executionTierID
        case foundationTierID
        case reasonCodes
        case worldPriorContract
        case temporalKnowledgeContract
        case evidenceContract
    }

    init(
        activeProviderID: String,
        preferredProviderID: String,
        fallbackProviderID: String? = nil,
        providerTrackID: String,
        executionTierID: String,
        foundationTierID: String,
        reasonCodes: [String] = [],
        worldPriorContract: DecisionEBrainWorldPriorContract? = nil,
        temporalKnowledgeContract: DecisionEBrainTemporalKnowledgeContract? = nil,
        evidenceContract: DecisionEBrainEvidenceContract? = nil
    ) {
        self.activeProviderID = activeProviderID
        self.preferredProviderID = preferredProviderID
        self.fallbackProviderID = fallbackProviderID?.evolutionTrimmedNonEmpty
        self.providerTrackID = providerTrackID
        self.executionTierID = executionTierID
        self.foundationTierID = foundationTierID
        self.reasonCodes = Self.orderedUnique(reasonCodes.compactMap(\.evolutionTrimmedNonEmpty))
        self.worldPriorContract = worldPriorContract
        self.temporalKnowledgeContract = temporalKnowledgeContract
        self.evidenceContract = evidenceContract
    }

    init(frame: DecisionEBrainExecutionCapabilityFrame) {
        self.init(
            activeProviderID: frame.activeProviderID,
            preferredProviderID: frame.preferredProviderID,
            fallbackProviderID: frame.fallbackProviderID,
            providerTrackID: frame.providerTrackID,
            executionTierID: frame.executionTierID,
            foundationTierID: frame.foundationTierID,
            reasonCodes: frame.reasonCodes,
            worldPriorContract: frame.worldPriorContract,
            temporalKnowledgeContract: frame.temporalKnowledgeContract,
            evidenceContract: frame.evidenceContract
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            activeProviderID: try container.decode(String.self, forKey: .activeProviderID),
            preferredProviderID: try container.decode(String.self, forKey: .preferredProviderID),
            fallbackProviderID: try container.decodeIfPresent(String.self, forKey: .fallbackProviderID),
            providerTrackID: try container.decode(String.self, forKey: .providerTrackID),
            executionTierID: try container.decode(String.self, forKey: .executionTierID),
            foundationTierID: try container.decode(String.self, forKey: .foundationTierID),
            reasonCodes: try container.decodeIfPresent([String].self, forKey: .reasonCodes) ?? [],
            worldPriorContract: try container.decodeIfPresent(DecisionEBrainWorldPriorContract.self, forKey: .worldPriorContract),
            temporalKnowledgeContract: try container.decodeIfPresent(DecisionEBrainTemporalKnowledgeContract.self, forKey: .temporalKnowledgeContract),
            evidenceContract: try container.decodeIfPresent(DecisionEBrainEvidenceContract.self, forKey: .evidenceContract)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(activeProviderID, forKey: .activeProviderID)
        try container.encode(preferredProviderID, forKey: .preferredProviderID)
        try container.encodeIfPresent(fallbackProviderID, forKey: .fallbackProviderID)
        try container.encode(providerTrackID, forKey: .providerTrackID)
        try container.encode(executionTierID, forKey: .executionTierID)
        try container.encode(foundationTierID, forKey: .foundationTierID)
        try container.encode(reasonCodes, forKey: .reasonCodes)
        try container.encodeIfPresent(worldPriorContract, forKey: .worldPriorContract)
        try container.encodeIfPresent(temporalKnowledgeContract, forKey: .temporalKnowledgeContract)
        try container.encodeIfPresent(evidenceContract, forKey: .evidenceContract)
    }

    var normalized: DecisionSessionCheckpointExecutionCapability {
        DecisionSessionCheckpointExecutionCapability(
            activeProviderID: activeProviderID,
            preferredProviderID: preferredProviderID,
            fallbackProviderID: fallbackProviderID,
            providerTrackID: providerTrackID,
            executionTierID: executionTierID,
            foundationTierID: foundationTierID,
            reasonCodes: reasonCodes,
            worldPriorContract: worldPriorContract,
            temporalKnowledgeContract: temporalKnowledgeContract,
            evidenceContract: evidenceContract
        )
    }

    var executionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame? {
        guard
            let activeProvider = DecisionModelProviderKind(rawValue: activeProviderID),
            let preferredProvider = DecisionModelProviderPreference(rawValue: preferredProviderID),
            let providerTrack = DecisionModelProviderTrack(rawValue: providerTrackID),
            let executionTier = DecisionIntelligenceExecutionTier(rawValue: executionTierID),
            let foundationTier = DecisionEBrainFoundationTier(rawValue: foundationTierID)
        else {
            return nil
        }

        return DecisionEBrainExecutionCapabilityFrame(
            activeProvider: activeProvider,
            preferredProvider: preferredProvider,
            fallbackProvider: fallbackProviderID.flatMap(DecisionModelProviderKind.init(rawValue:)),
            providerTrack: providerTrack,
            executionTier: executionTier,
            foundationTier: foundationTier,
            reasonCodes: Self.orderedUnique(reasonCodes.compactMap(\.evolutionTrimmedNonEmpty)),
            worldPriorContractOverride: worldPriorContract,
            temporalKnowledgeContractOverride: temporalKnowledgeContract,
            evidenceContractOverride: evidenceContract
        )
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { uniqueValues, value in
            guard !uniqueValues.contains(value) else { return }
            uniqueValues.append(value)
        }
    }
}

extension DecisionSessionCheckpointEBrainAnchor {
    var executionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame? {
        executionCapability?.executionCapabilityFrame
    }

    var foldedLungSnapshot: DecisionFoldedLungSnapshot? {
        DecisionFoldedLungCoordinator.snapshot(from: self)
    }

    var decisionLine: String? {
        guard let riskLevel = riskLevel?.evolutionTrimmedNonEmpty,
              let permitMode = permitMode?.evolutionTrimmedNonEmpty,
              let hostGatePercent,
              let thoughtFoldChecksum = thoughtFoldChecksum?.evolutionTrimmedNonEmpty else {
            return nil
        }

        return DecisionEvolutionNarrativeFormattingSupport.joined(
            DecisionEvolutionEBrainPresentationSupport.checkpointDecisionFactLines(
                riskLevel: riskLevel,
                permitMode: permitMode,
                hostGatePercent: hostGatePercent,
                foldChecksum: thoughtFoldChecksum
            )
        ).nilIfEmpty
    }

    var taskLine: String? {
        reviewDirectiveLine?.evolutionTrimmedNonEmpty
    }

    var resolvedPresenceLine: String? {
        presenceLine?.evolutionTrimmedNonEmpty
    }

    var windGateLine: String? {
        guard let permitMode = permitMode?.evolutionTrimmedNonEmpty else {
            return nil
        }

        return DecisionEvolutionNarrativeFormattingSupport.joined([
            "L11 wind gate",
            "primary \(permitMode)",
            stackedModes.isEmpty ? nil : "stacked \(Array(stackedModes.prefix(3)).joined(separator: ", "))",
            assertionCeiling?.evolutionTrimmedNonEmpty.map { "assert \($0)" },
            allowedDomains.isEmpty ? nil : "allow \(Array(allowedDomains.prefix(3)).joined(separator: ", "))",
            blockedDomains.isEmpty ? nil : "block \(Array(blockedDomains.prefix(3)).joined(separator: ", "))",
            delayType?.evolutionTrimmedNonEmpty.map { "delay \($0)" },
            substituteType?.evolutionTrimmedNonEmpty.map { "substitute \($0)" },
            sovereignHintLevel?.evolutionTrimmedNonEmpty.map { "sovereign \($0)" }
        ].compactMap { $0 }).nilIfEmpty
    }

    var resolvedRiskFactorsLine: String? {
        riskFactorsLine?.evolutionTrimmedNonEmpty
    }

    var resolvedReasonCodesLine: String? {
        reasonCodesLine?.evolutionTrimmedNonEmpty
            ?? DecisionEvolutionNarrativeFormattingSupport.labeledLine(
                prefix: "Reason codes",
                values: executionCapability?.reasonCodes ?? []
            )
    }

    var resolvedCourtLine: String? {
        courtLine?.evolutionTrimmedNonEmpty
    }

    var lungLine: String? {
        foldedLungSnapshot?.lungLine
    }

    var morphLine: String? {
        foldedLungSnapshot?.morphLine
    }

    var hotColdLine: String? {
        foldedLungSnapshot?.hotColdLine
    }

    var precisionLine: String? {
        foldedLungSnapshot?.precisionLine
    }

    var organPackageLine: String? {
        foldedLungSnapshot?.organPackageLine
    }

    var thermalExchangeLine: String? {
        foldedLungSnapshot?.thermalExchangeLine
    }

    var schedulerLine: String? {
        foldedLungSnapshot?.schedulerLine
    }

    var integrityWeaveLine: String? {
        foldedLungSnapshot?.integrityWeaveLine
    }

    var organDeltaLine: String? {
        foldedLungSnapshot?.organDeltaLine
    }

    var resumeLine: String? {
        foldedLungSnapshot?.resumeLine
    }

    var rollbackLine: String? {
        foldedLungSnapshot?.rollbackLine
    }

    var sovereignBridgeLine: String? {
        foldedLungSnapshot?.sovereignBridgeLine
    }

    var sovereignBridgeDetailLines: [String] {
        foldedLungSnapshot?.sovereignBridgeDetailLines ?? []
    }

    var sovereignBridgeSupplementalLines: [String] {
        foldedLungSnapshot?.sovereignBridgeSupplementalLines ?? []
    }

    func merged(with newer: DecisionSessionCheckpointEBrainAnchor) -> DecisionSessionCheckpointEBrainAnchor {
        DecisionSessionCheckpointEBrainAnchor(
            sessionID: newer.sessionID ?? sessionID,
            thoughtFoldChecksum: newer.thoughtFoldChecksum ?? thoughtFoldChecksum,
            riskLevel: newer.riskLevel ?? riskLevel,
            permitMode: newer.permitMode ?? permitMode,
            hostGatePercent: newer.hostGatePercent ?? hostGatePercent,
            reviewDirectiveLine: newer.reviewDirectiveLine ?? reviewDirectiveLine,
            presenceLine: newer.presenceLine ?? presenceLine,
            riskFactorsLine: newer.riskFactorsLine ?? riskFactorsLine,
            reasonCodesLine: newer.reasonCodesLine ?? reasonCodesLine,
            courtLine: newer.courtLine ?? courtLine,
            versionTreeLine: newer.versionTreeLine ?? versionTreeLine,
            retractionLine: newer.retractionLine ?? retractionLine,
            stackedModes: newer.stackedModes.isEmpty ? stackedModes : newer.stackedModes,
            assertionCeiling: newer.assertionCeiling ?? assertionCeiling,
            allowedDomains: newer.allowedDomains.isEmpty ? allowedDomains : newer.allowedDomains,
            blockedDomains: newer.blockedDomains.isEmpty ? blockedDomains : newer.blockedDomains,
            delayType: newer.delayType ?? delayType,
            substituteType: newer.substituteType ?? substituteType,
            sovereignHintLevel: newer.sovereignHintLevel ?? sovereignHintLevel,
            sovereignVerdictLine: newer.sovereignVerdictLine ?? sovereignVerdictLine,
            sovereignAuthorityLine: newer.sovereignAuthorityLine ?? sovereignAuthorityLine,
            sovereignAuditLine: newer.sovereignAuditLine ?? sovereignAuditLine,
            executionCapability: newer.executionCapability ?? executionCapability,
            morphGraph: newer.morphGraph ?? morphGraph,
            hotColdMap: newer.hotColdMap ?? hotColdMap,
            precisionProfile: newer.precisionProfile ?? precisionProfile,
            lungState: newer.lungState ?? lungState,
            thermalExchange: newer.thermalExchange ?? thermalExchange,
            breathScheduler: newer.breathScheduler ?? breathScheduler,
            integrityWeave: newer.integrityWeave ?? integrityWeave,
            organPackages: newer.organPackages.isEmpty ? organPackages : newer.organPackages,
            organDeltaPlan: newer.organDeltaPlan ?? organDeltaPlan,
            resumeFrame: newer.resumeFrame ?? resumeFrame,
            rollbackAnchor: newer.rollbackAnchor ?? rollbackAnchor,
            sovereignBridgeResult: newer.sovereignBridgeResult ?? sovereignBridgeResult
        )
    }
}

struct DecisionSessionCheckpointRuntimeState: Codable, Equatable, Sendable {
    var workspacePath: String?
    var branchName: String?
    var activeFiles: [String]
    var currentMode: DecisionSessionRuntimeMode
    var eBrainAnchor: DecisionSessionCheckpointEBrainAnchor?

    init(
        workspacePath: String? = nil,
        branchName: String? = nil,
        activeFiles: [String] = [],
        currentMode: DecisionSessionRuntimeMode = .chat,
        eBrainAnchor: DecisionSessionCheckpointEBrainAnchor? = nil
    ) {
        self.workspacePath = workspacePath
        self.branchName = branchName
        self.activeFiles = activeFiles
        self.currentMode = currentMode
        self.eBrainAnchor = eBrainAnchor
    }

    static let empty = DecisionSessionCheckpointRuntimeState(
        workspacePath: nil,
        branchName: nil,
        activeFiles: [],
        currentMode: .chat,
        eBrainAnchor: nil
    )
}

struct DecisionSessionCheckpointIntegrity: Codable, Equatable, Sendable {
    var eventHash: String
    var previousCheckpointHash: String?
}

struct DecisionSessionCheckpoint: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let sessionId: String
    let branchId: String
    let basedOnEventSeq: Int
    let createdAt: Date
    let summary: DecisionSessionCheckpointSummary
    let runtimeState: DecisionSessionCheckpointRuntimeState
    let integrity: DecisionSessionCheckpointIntegrity
    let previousCheckpointId: String?
    let checkpointHash: String
}

struct DecisionSessionStep: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let sessionId: String
    let branchId: String
    let startEventSeq: Int
    let status: DecisionSessionStepStatus
    let startedAt: Date
    let updatedAt: Date
    let ttlMs: Int
    let heartbeatAt: Date?
    let errorCode: String?
}

struct DecisionSessionTimelineItem: Equatable, Sendable, Identifiable {
    enum Kind: Equatable, Sendable {
        case checkpoint(DecisionSessionCheckpoint)
        case event(DecisionSessionEvent)
    }

    let id: String
    let createdAt: Date
    let branchId: String
    let title: String
    let detail: String
    let kind: Kind
}

struct DecisionSessionTimeline: Equatable, Sendable {
    let sessionId: String
    let branchId: String
    let checkpoint: DecisionSessionCheckpoint?
    let items: [DecisionSessionTimelineItem]
    let recoveryNotice: String?
    let mergeNotice: String?
}

struct DecisionSessionRecoveryResult: Equatable, Sendable {
    let session: DecisionSession
    let sourceBranch: DecisionSessionBranch
    let recoveredBranch: DecisionSessionBranch
    let checkpoint: DecisionSessionCheckpoint?
    let failedStepIds: [String]
    let replayedEvents: [DecisionSessionEvent]
}

struct DecisionSessionWatchdogAction: Equatable, Sendable {
    let stepId: String
    let sessionId: String
    let branchId: String
    let action: String
}

struct DecisionSessionCheckpointDraft: Equatable, Sendable {
    var summary: DecisionSessionCheckpointSummary
    var runtimeState: DecisionSessionCheckpointRuntimeState

    static let empty = DecisionSessionCheckpointDraft(
        summary: .empty,
        runtimeState: .empty
    )
}

struct DecisionSessionRuntimeSnapshot: Equatable, Sendable {
    let layerPlacement: DecisionSessionLayerPlacement
    let sessions: Int
    let activeSessions: Int
    let stalledSessions: Int
    let mergeReadySessions: Int
    let mergeableBranches: Int
    let branches: Int
    let checkpoints: Int
    let events: Int
    let steps: Int
    let recentSessions: [DecisionSessionRuntimeInspectionSession]

    init(
        layerPlacement: DecisionSessionLayerPlacement,
        sessions: Int,
        activeSessions: Int,
        stalledSessions: Int,
        mergeReadySessions: Int = 0,
        mergeableBranches: Int = 0,
        branches: Int,
        checkpoints: Int,
        events: Int,
        steps: Int,
        recentSessions: [DecisionSessionRuntimeInspectionSession] = []
    ) {
        self.layerPlacement = layerPlacement
        self.sessions = sessions
        self.activeSessions = activeSessions
        self.stalledSessions = stalledSessions
        self.mergeReadySessions = mergeReadySessions
        self.mergeableBranches = mergeableBranches
        self.branches = branches
        self.checkpoints = checkpoints
        self.events = events
        self.steps = steps
        self.recentSessions = recentSessions
    }
}

struct DecisionSessionRuntimeInspectionSession: Equatable, Sendable, Identifiable {
    let sessionID: String
    let title: String
    let status: DecisionSessionStatus
    let updatedAt: Date
    let headBranchID: String
    let latestCheckpointID: String?
    let latestCheckpointSeq: Int?
    let latestCheckpointGoal: String?
    let latestCheckpointBudgetLine: String?
    let latestCheckpointRouteLine: String?
    let latestCheckpointDecisionLine: String?
    let latestCheckpointTaskLine: String?
    let latestCheckpointPressureLine: String?
    let latestCheckpointAuditLine: String?
    let latestCheckpointActiveKillSwitchesLine: String?
    let latestCheckpointKillSwitchesLine: String?
    let latestCheckpointActionLine: String?
    let latestCheckpointEBrainAnchor: DecisionSessionCheckpointEBrainAnchor?
    let latestEventID: String?
    let latestEventSeq: Int?
    let latestEventType: DecisionSessionEventType?
    let latestEventDetail: String?
    let openStepCount: Int
    let openStepStatus: DecisionSessionStepStatus?
    let stalledStepCount: Int
    let branchCount: Int
    let mergeableBranchCount: Int
    let recoveryCount: Int
    let latestRecoveryAt: Date?
    let openStepID: String?
    let openStepHeartbeatAt: Date?
    let openStepUpdatedAt: Date?
    let openStepTTLms: Int?
    let openStepRemainingMs: Int?
    let openStepIsHeartbeatOverdue: Bool

    var id: String { sessionID }

    init(
        sessionID: String,
        title: String,
        status: DecisionSessionStatus,
        updatedAt: Date,
        headBranchID: String,
        latestCheckpointID: String?,
        latestCheckpointSeq: Int?,
        latestCheckpointGoal: String?,
        latestCheckpointBudgetLine: String? = nil,
        latestCheckpointRouteLine: String? = nil,
        latestCheckpointDecisionLine: String? = nil,
        latestCheckpointTaskLine: String? = nil,
        latestCheckpointPressureLine: String? = nil,
        latestCheckpointAuditLine: String? = nil,
        latestCheckpointActiveKillSwitchesLine: String? = nil,
        latestCheckpointKillSwitchesLine: String? = nil,
        latestCheckpointActionLine: String? = nil,
        latestCheckpointEBrainAnchor: DecisionSessionCheckpointEBrainAnchor? = nil,
        latestEventID: String?,
        latestEventSeq: Int?,
        latestEventType: DecisionSessionEventType?,
        latestEventDetail: String?,
        openStepCount: Int,
        openStepStatus: DecisionSessionStepStatus?,
        stalledStepCount: Int,
        branchCount: Int,
        mergeableBranchCount: Int = 0,
        recoveryCount: Int,
        latestRecoveryAt: Date?,
        openStepID: String? = nil,
        openStepHeartbeatAt: Date? = nil,
        openStepUpdatedAt: Date? = nil,
        openStepTTLms: Int? = nil,
        openStepRemainingMs: Int? = nil,
        openStepIsHeartbeatOverdue: Bool = false
    ) {
        self.sessionID = sessionID
        self.title = title
        self.status = status
        self.updatedAt = updatedAt
        self.headBranchID = headBranchID
        self.latestCheckpointID = latestCheckpointID
        self.latestCheckpointSeq = latestCheckpointSeq
        self.latestCheckpointGoal = latestCheckpointGoal
        self.latestCheckpointBudgetLine = latestCheckpointBudgetLine
        self.latestCheckpointRouteLine = latestCheckpointRouteLine
        self.latestCheckpointDecisionLine = latestCheckpointDecisionLine
        self.latestCheckpointTaskLine = latestCheckpointTaskLine
        self.latestCheckpointPressureLine = latestCheckpointPressureLine
        self.latestCheckpointAuditLine = latestCheckpointAuditLine
        self.latestCheckpointActiveKillSwitchesLine = latestCheckpointActiveKillSwitchesLine
        self.latestCheckpointKillSwitchesLine = latestCheckpointKillSwitchesLine
        self.latestCheckpointActionLine = latestCheckpointActionLine
        self.latestCheckpointEBrainAnchor = latestCheckpointEBrainAnchor
        self.latestEventID = latestEventID
        self.latestEventSeq = latestEventSeq
        self.latestEventType = latestEventType
        self.latestEventDetail = latestEventDetail
        self.openStepCount = openStepCount
        self.openStepStatus = openStepStatus
        self.stalledStepCount = stalledStepCount
        self.branchCount = branchCount
        self.mergeableBranchCount = mergeableBranchCount
        self.recoveryCount = recoveryCount
        self.latestRecoveryAt = latestRecoveryAt
        self.openStepID = openStepID
        self.openStepHeartbeatAt = openStepHeartbeatAt
        self.openStepUpdatedAt = openStepUpdatedAt
        self.openStepTTLms = openStepTTLms
        self.openStepRemainingMs = openStepRemainingMs
        self.openStepIsHeartbeatOverdue = openStepIsHeartbeatOverdue
    }

    var headline: String {
        DecisionSessionInspectionPresentationSupport.headline(
            title: title,
            status: status,
            latestEventType: latestEventType
        )
    }

    var openStepFreshnessLine: String? {
        guard openStepCount > 0 else { return nil }
        let statusDescriptor = openStepStatus?.rawValue.replacingOccurrences(of: "_", with: " ") ?? "active"
        let freshnessDescriptor: String
        if openStepIsHeartbeatOverdue {
            freshnessDescriptor = "watchdog overdue"
        } else if let openStepRemainingMs {
            let remainingSeconds = max(Int(ceil(Double(openStepRemainingMs) / 1000.0)), 0)
            freshnessDescriptor = "ttl \(remainingSeconds)s remaining"
        } else if openStepHeartbeatAt != nil {
            freshnessDescriptor = "heartbeat active"
        } else {
            freshnessDescriptor = "awaiting first heartbeat"
        }
        return "Step \(statusDescriptor) • \(freshnessDescriptor)"
    }

    var openStepAlertLine: String? {
        if openStepIsHeartbeatOverdue {
            return DecisionSessionRecoveryPresentationSupport.watchdogExpiredLine
        }
        if status == .stalled || stalledStepCount > 0 {
            return DecisionSessionRecoveryPresentationSupport.stalledRecoveryLine
        }
        return nil
    }

    var mergeReviewLine: String? {
        DecisionSessionReviewPresentationSupport.mergeReviewLine(
            mergeableBranchCount: mergeableBranchCount
        )
    }

    var checkpointPresentationFacts: DecisionSessionCheckpointPresentationFacts {
        DecisionSessionCheckpointPresentationFacts(
            budgetLine: latestCheckpointBudgetLine,
            routeLine: latestCheckpointRouteLine,
            decisionLine: latestCheckpointDecisionLine,
            taskLine: latestCheckpointTaskLine,
            pressureLine: latestCheckpointPressureLine,
            presenceLine: latestCheckpointEBrainAnchor?.resolvedPresenceLine,
            riskFactorsLine: latestCheckpointEBrainAnchor?.resolvedRiskFactorsLine,
            reasonCodesLine: latestCheckpointEBrainAnchor?.resolvedReasonCodesLine,
            courtLine: latestCheckpointEBrainAnchor?.resolvedCourtLine,
            auditLine: latestCheckpointAuditLine,
            activeKillSwitchesLine: latestCheckpointActiveKillSwitchesLine,
            killSwitchesLine: latestCheckpointKillSwitchesLine,
            actionLine: latestCheckpointActionLine,
            anchor: latestCheckpointEBrainAnchor
        )
    }

    var latestCheckpointRuntimeLine: String? {
        checkpointPresentationFacts.runtimeLine
    }

    var latestCheckpointAuditPressureLine: String? {
        checkpointPresentationFacts.auditPressureLine
    }

    var detailLine: String {
        DecisionSessionInspectionPresentationSupport.detailLine(
            checkpointID: latestCheckpointID,
            eventSeq: latestEventSeq,
            openStepCount: openStepCount,
            openStepStatus: openStepStatus,
            openStepFreshnessLine: openStepFreshnessLine,
            recoveryCount: recoveryCount
        )
    }
}

struct DecisionSessionCheckpointPresentationFacts: Equatable, Sendable {
    let budgetLine: String?
    let routeLine: String?
    let decisionLine: String?
    let taskLine: String?
    let pressureLine: String?
    let presenceLine: String?
    let riskFactorsLine: String?
    let reasonCodesLine: String?
    let courtLine: String?
    let auditLine: String?
    let activeKillSwitchesLine: String?
    let killSwitchesLine: String?
    let actionLine: String?
    let anchor: DecisionSessionCheckpointEBrainAnchor?

    private var effectiveDecisionLine: String? {
        decisionLine ?? anchor?.decisionLine
    }

    private var effectiveTaskLine: String? {
        taskLine ?? anchor?.taskLine
    }

    private var effectivePresenceLine: String? {
        presenceLine ?? anchor?.resolvedPresenceLine
    }

    private var effectiveCourtLine: String? {
        courtLine ?? anchor?.resolvedCourtLine
    }

    var resolvedDecisionLine: String? {
        effectiveDecisionLine
    }

    var resolvedTaskLine: String? {
        effectiveTaskLine
    }

    var resolvedPresenceLine: String? {
        effectivePresenceLine
    }

    var resolvedCourtLine: String? {
        effectiveCourtLine
    }

    var windGateLine: String? {
        anchor?.windGateLine
    }

    var runtimeLine: String? {
        DecisionEvolutionNarrativeFormattingSupport.joined(
            [budgetLine, routeLine].compactMap { $0 }
        ).nilIfEmpty
    }

    var auditPressureLine: String? {
        DecisionEvolutionNarrativeFormattingSupport.joined(
            [auditLine, killSwitchesLine].compactMap { $0 }
        ).nilIfEmpty
    }

    var lungLine: String? {
        anchor?.lungLine
    }

    var morphLine: String? {
        anchor?.morphLine
    }

    var hotColdLine: String? {
        anchor?.hotColdLine
    }

    var precisionLine: String? {
        anchor?.precisionLine
    }

    var organPackageLine: String? {
        anchor?.organPackageLine
    }

    var organDeltaLine: String? {
        anchor?.organDeltaLine
    }

    var thermalExchangeLine: String? {
        anchor?.thermalExchangeLine
    }

    var schedulerLine: String? {
        anchor?.schedulerLine
    }

    var integrityWeaveLine: String? {
        anchor?.integrityWeaveLine
    }

    var resumeLine: String? {
        anchor?.resumeLine
    }

    var rollbackLine: String? {
        anchor?.rollbackLine
    }

    var sovereignBridgeLine: String? {
        anchor?.sovereignBridgeLine
    }

    var sovereignBridgeDetailLines: [String] {
        anchor?.sovereignBridgeSupplementalLines ?? []
    }

    var sovereignVerdictLine: String? {
        anchor?.sovereignVerdictLine
    }

    var sovereignAuthorityLine: String? {
        anchor?.sovereignAuthorityLine
    }

    var sovereignAuditLine: String? {
        anchor?.sovereignAuditLine
    }

    var versionTreeLine: String? {
        anchor?.versionTreeLine
    }

    var retractionLine: String? {
        anchor?.retractionLine
    }

    var digestLines: [String] {
        var lines: [String] = []

        if let runtimeLine {
            lines.append(runtimeLine)
        }

        if let effectiveDecisionLine {
            let decisionSegments = [effectiveDecisionLine, effectiveTaskLine].compactMap { $0 }
            lines.append(
                DecisionEvolutionNarrativeFormattingSupport.joined(decisionSegments)
            )
        } else if let effectiveTaskLine {
            lines.append(effectiveTaskLine)
        }

        if let windGateLine {
            lines.append(windGateLine)
        }

        if let effectivePresenceLine {
            lines.append(effectivePresenceLine)
        }

        if let pressureLine {
            lines.append(pressureLine)
        }

        if let riskFactorsLine {
            lines.append(riskFactorsLine)
        }

        if let reasonCodesLine {
            lines.append(reasonCodesLine)
        }

        if let effectiveCourtLine {
            lines.append(effectiveCourtLine)
        }

        if let auditPressureLine {
            lines.append(auditPressureLine)
        }

        if let sovereignVerdictLine {
            lines.append(sovereignVerdictLine)
        }

        if let sovereignAuthorityLine {
            lines.append(sovereignAuthorityLine)
        }

        if let sovereignAuditLine {
            lines.append(sovereignAuditLine)
        }

        if let versionTreeLine {
            lines.append(versionTreeLine)
        }

        if let retractionLine {
            lines.append(retractionLine)
        }

        if let lungLine {
            lines.append(lungLine)
        }

        if let morphLine {
            lines.append(morphLine)
        }

        if let hotColdLine {
            lines.append(hotColdLine)
        }

        if let precisionLine {
            lines.append(precisionLine)
        }

        if let organPackageLine {
            lines.append(organPackageLine)
        }

        if let organDeltaLine {
            lines.append(organDeltaLine)
        }

        if let schedulerLine {
            lines.append(schedulerLine)
        }

        if let thermalExchangeLine {
            lines.append(thermalExchangeLine)
        }

        if let integrityWeaveLine {
            lines.append(integrityWeaveLine)
        }

        if let resumeLine {
            lines.append(resumeLine)
        }

        if let rollbackLine {
            lines.append(rollbackLine)
        }

        lines.append(contentsOf: anchor?.sovereignBridgeDetailLines ?? [])

        if let actionLine {
            lines.append(actionLine)
        }

        return lines
    }

    func combinedAuditLine(addition: String?) -> String? {
        DecisionEvolutionNarrativeFormattingSupport.joined(
            [auditLine, addition].compactMap { $0 }
        ).nilIfEmpty
    }
}

struct DecisionSessionExportCounts: Codable, Equatable, Sendable {
    let branches: Int
    let checkpoints: Int
    let events: Int
    let steps: Int
}

struct DecisionSessionExportManifest: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let exportedAt: Date
    let layerPlacement: DecisionSessionLayerPlacement
    let sourceSessionId: String
    let sourceHeadBranchId: String
    let sourceLatestCheckpointId: String?
    let sourceTitle: String
    let counts: DecisionSessionExportCounts
    let bundleFingerprint: String?
}

struct DecisionSessionExportEventRecord: Codable, Equatable, Sendable {
    let event: DecisionSessionEvent
    let payloadBase64: String?
}

struct DecisionSessionExportBundle: Codable, Equatable, Sendable {
    let manifest: DecisionSessionExportManifest
    let session: DecisionSession
    let branches: [DecisionSessionBranch]
    let checkpoints: [DecisionSessionCheckpoint]
    let events: [DecisionSessionExportEventRecord]
    let steps: [DecisionSessionStep]
}

struct DecisionSessionImportBundleBranchPreview: Equatable, Sendable, Identifiable {
    let id: String
    let name: String
    let statusLine: String
    let detailLine: String
    let isHead: Bool
}

struct DecisionSessionImportBundlePreview: Equatable, Sendable, Identifiable {
    let id: String
    let sourceSessionId: String
    let sourceTitle: String
    let importedTitle: String
    let exportedAt: Date
    let countsLine: String
    let integrityLine: String
    let checkpointLine: String
    let branchLine: String
    let unfinishedStepCount: Int
    let unfinishedStepsLine: String
    let headline: String
    let branchPreviews: [DecisionSessionImportBundleBranchPreview]
}

struct DecisionSessionPayloadUserMessage: Codable, Equatable, Sendable {
    let text: String
    let attachments: [String]
    let intent: String?
}

struct DecisionSessionPayloadAssistantMessage: Codable, Equatable, Sendable {
    let text: String
    let summary: String?
}

struct DecisionSessionPayloadCorrection: Codable, Equatable, Sendable {
    let targetEventId: String
    let mode: String
    let newText: String
    let reason: String
}

struct DecisionSessionPayloadToolCallStarted: Codable, Equatable, Sendable {
    let tool: String
    let argsPreview: [String: String]
}

struct DecisionSessionPayloadToolCallFinished: Codable, Equatable, Sendable {
    let tool: String
    let resultSummary: String
    let artifactRefs: [String]
}

struct DecisionSessionPayloadToolCallFailed: Codable, Equatable, Sendable {
    let tool: String
    let errorCode: String
    let recoverable: Bool
}

struct DecisionSessionPayloadCheckpointCreated: Codable, Equatable, Sendable {
    let checkpointId: String
    let basedOnEventSeq: Int
}

struct DecisionSessionPayloadStepStarted: Codable, Equatable, Sendable {
    let stepId: String
    let status: DecisionSessionStepStatus
    let ttlMs: Int
}

struct DecisionSessionPayloadHeartbeat: Codable, Equatable, Sendable {
    let stepId: String
    let progress: Double?
    let status: DecisionSessionStepStatus
}

struct DecisionSessionPayloadStepStalled: Codable, Equatable, Sendable {
    let stepId: String
    let errorCode: String?
}

struct DecisionSessionPayloadSessionError: Codable, Equatable, Sendable {
    let kind: String
    let stepId: String?
    let recoverable: Bool
}

struct DecisionSessionPayloadSessionRecovered: Codable, Equatable, Sendable {
    let sourceCheckpointId: String?
    let failedStepIds: [String]
    let sourceBranchId: String
}

struct DecisionSessionPayloadBranchCreated: Codable, Equatable, Sendable {
    let fromCheckpointId: String?
    let branchId: String
    let reason: String
}

struct DecisionSessionPayloadBranchMerged: Codable, Equatable, Sendable {
    let sourceBranchId: String
    let targetBranchId: String
    let reason: String
}

struct DecisionSessionEngineConfiguration: Equatable, Sendable {
    let baseDirectoryURL: URL?
    let defaultToolTTL: Int
    let defaultPlanningTTL: Int
    let defaultWritingTTL: Int
    let eventCompactionStride: Int

    init(
        baseDirectoryURL: URL? = nil,
        defaultToolTTL: Int = 20_000,
        defaultPlanningTTL: Int = 15_000,
        defaultWritingTTL: Int = 25_000,
        eventCompactionStride: Int = 8
    ) {
        self.baseDirectoryURL = baseDirectoryURL
        self.defaultToolTTL = defaultToolTTL
        self.defaultPlanningTTL = defaultPlanningTTL
        self.defaultWritingTTL = defaultWritingTTL
        self.eventCompactionStride = eventCompactionStride
    }
}

enum DecisionSessionEngineError: Error, LocalizedError {
    case sqlite(message: String)
    case sessionNotFound(String)
    case branchNotFound(String)
    case checkpointNotFound(String)
    case stepNotFound(String)
    case invalidState(String)
    case missingPath(String)

    var errorDescription: String? {
        switch self {
        case let .sqlite(message),
            let .sessionNotFound(message),
            let .branchNotFound(message),
            let .checkpointNotFound(message),
            let .stepNotFound(message),
            let .invalidState(message),
            let .missingPath(message):
            return message
        }
    }
}

actor DecisionSessionEngine {
    static let shared = try? DecisionSessionEngine()
    private static let exportSchemaVersion = 1

    private let configuration: DecisionSessionEngineConfiguration
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let databaseURL: URL
    private let blobsDirectoryURL: URL
    private let exportsDirectoryURL: URL
    private let logsDirectoryURL: URL
    private var db: OpaquePointer?

    init(configuration: DecisionSessionEngineConfiguration = .init()) throws {
        self.configuration = configuration
        let root = try Self.ensureBaseDirectory(baseDirectoryURL: configuration.baseDirectoryURL)
        self.databaseURL = root.appendingPathComponent("engine.db", isDirectory: false)
        self.blobsDirectoryURL = root.appendingPathComponent("blobs", isDirectory: true)
        self.exportsDirectoryURL = root.appendingPathComponent("exports", isDirectory: true)
        self.logsDirectoryURL = root.appendingPathComponent("logs", isDirectory: true)
        try Self.ensureDirectory(blobsDirectoryURL)
        try Self.ensureDirectory(exportsDirectoryURL)
        try Self.ensureDirectory(logsDirectoryURL)
        self.db = try Self.openDatabase(at: databaseURL)
        try Self.prepareSchema(on: db)
    }

    func createSession(title: String, now: Date = .now) throws -> DecisionSession {
        let sessionId = Self.makeIdentifier(prefix: "sess")
        let branchId = Self.makeIdentifier(prefix: "branch")
        try inTransaction {
            try execute(
                """
                INSERT INTO sessions (
                    id, title, created_at, updated_at, status, head_branch_id, latest_checkpoint_id
                ) VALUES (?, ?, ?, ?, ?, ?, NULL);
                """,
                bindings: [
                    .text(sessionId),
                    .text(title),
                    .double(now.timeIntervalSince1970),
                    .double(now.timeIntervalSince1970),
                    .text(DecisionSessionStatus.active.rawValue),
                    .text(branchId)
                ]
            )
            try execute(
                """
                INSERT INTO branches (
                    id, session_id, parent_branch_id, base_checkpoint_id, name, created_at, status
                ) VALUES (?, ?, NULL, NULL, ?, ?, ?);
                """,
                bindings: [
                    .text(branchId),
                    .text(sessionId),
                    .text("main"),
                    .double(now.timeIntervalSince1970),
                    .text(DecisionSessionBranchStatus.active.rawValue)
                ]
            )
        }
        return try getSession(sessionId)
    }

    func archiveSession(_ sessionId: String, now: Date = .now) throws -> DecisionSession {
        try updateSessionStatus(sessionId, status: .archived, eventType: nil, now: now)
    }

    func pauseSession(_ sessionId: String, now: Date = .now) throws -> DecisionSession {
        try updateSessionStatus(sessionId, status: .paused, eventType: .sessionPaused, now: now)
    }

    func resumeSession(_ sessionId: String, now: Date = .now) throws -> DecisionSession {
        try updateSessionStatus(sessionId, status: .active, eventType: .sessionResumed, now: now)
    }

    func getSession(_ sessionId: String) throws -> DecisionSession {
        let session = try querySingleValue(
            """
            SELECT id, title, created_at, updated_at, status, head_branch_id, latest_checkpoint_id
            FROM sessions
            WHERE id = ?;
            """,
            bindings: [.text(sessionId)],
            map: decodeSession(row:)
        )
        guard let session else {
            throw DecisionSessionEngineError.sessionNotFound("No session exists for \(sessionId).")
        }
        return session
    }

    func listSessions(limit: Int? = nil) throws -> [DecisionSession] {
        if let limit {
            return try queryRows(
                """
                SELECT id, title, created_at, updated_at, status, head_branch_id, latest_checkpoint_id
                FROM sessions
                ORDER BY updated_at DESC, id DESC
                LIMIT ?;
                """,
                bindings: [.int(limit)],
                map: decodeSession(row:)
            )
        }

        return try queryRows(
            """
            SELECT id, title, created_at, updated_at, status, head_branch_id, latest_checkpoint_id
            FROM sessions
            ORDER BY updated_at DESC, id DESC;
            """,
            bindings: [],
            map: decodeSession(row:)
        )
    }

    func listBranches(sessionId: String) throws -> [DecisionSessionBranch] {
        try queryRows(
            """
            SELECT id, session_id, parent_branch_id, base_checkpoint_id, name, created_at, status
            FROM branches
            WHERE session_id = ?
            ORDER BY created_at DESC, id DESC;
            """,
            bindings: [.text(sessionId)],
            map: decodeBranch(row:)
        )
    }

    func exportSession(_ sessionId: String, now: Date = .now) throws -> URL {
        let session = try getSession(sessionId)
        let branches = try listBranches(sessionId: sessionId)
        let checkpoints = try listCheckpoints(sessionId: sessionId)
        let events = try listAllEvents(sessionId: sessionId)
        let steps = try listAllSteps(sessionId: sessionId)
        let exportedEvents = try events.map { event in
            DecisionSessionExportEventRecord(
                event: event,
                payloadBase64: try loadPayloadData(for: event)?.base64EncodedString()
            )
        }
        let bundleFingerprint = Self.makeBundleFingerprint(
            session: session,
            branches: branches,
            checkpoints: checkpoints,
            events: exportedEvents,
            steps: steps
        )
        let bundle = DecisionSessionExportBundle(
            manifest: DecisionSessionExportManifest(
                schemaVersion: Self.exportSchemaVersion,
                exportedAt: now,
                layerPlacement: .foldedLung,
                sourceSessionId: session.id,
                sourceHeadBranchId: session.headBranchId,
                sourceLatestCheckpointId: session.latestCheckpointId,
                sourceTitle: session.title,
                counts: DecisionSessionExportCounts(
                    branches: branches.count,
                    checkpoints: checkpoints.count,
                    events: events.count,
                    steps: steps.count
                ),
                bundleFingerprint: bundleFingerprint
            ),
            session: session,
            branches: branches,
            checkpoints: checkpoints,
            events: exportedEvents,
            steps: steps
        )

        let exportEncoder = JSONEncoder()
        exportEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let fileName = "\(Self.safeFileComponent(session.title))-\(Self.fileTimestamp(now)).before-session.json"
        let url = exportsDirectoryURL.appendingPathComponent(fileName, isDirectory: false)
        let data = try exportEncoder.encode(bundle)
        try data.write(to: url, options: .atomic)
        return url
    }

    func importSession(from exportURL: URL, now: Date = .now) throws -> DecisionSession {
        let data = try Data(contentsOf: exportURL)
        let bundle = try decodeImportBundle(from: data)
        return try importSession(bundle, now: now)
    }

    func inspectImportBundle(from exportURL: URL) throws -> DecisionSessionImportBundlePreview {
        let data = try Data(contentsOf: exportURL)
        let bundle = try decodeImportBundle(from: data)
        return makeImportPreview(bundle)
    }

    func importSession(bundleData: Data, now: Date = .now) throws -> DecisionSession {
        let bundle = try decodeImportBundle(from: bundleData)
        return try importSession(bundle, now: now)
    }

    func inspectImportBundle(bundleData: Data) throws -> DecisionSessionImportBundlePreview {
        let bundle = try decodeImportBundle(from: bundleData)
        return makeImportPreview(bundle)
    }

    func createBranch(
        sessionId: String,
        fromCheckpointId: String?,
        name: String,
        reason: String = "manual branch",
        now: Date = .now
    ) throws -> DecisionSessionBranch {
        let session = try getSession(sessionId)
        let sourceBranch = try getBranch(session.headBranchId)
        let branchCheckpointDraft: DecisionSessionCheckpointDraft? = if let fromCheckpointId,
                                                                        let sourceCheckpoint = try? getCheckpoint(fromCheckpointId) {
            DecisionSessionCheckpointDraft(
                summary: sourceCheckpoint.summary,
                runtimeState: sourceCheckpoint.runtimeState
            )
        } else {
            latestCheckpointDraft(sessionId: sessionId, branchId: sourceBranch.id)
        }
        let branchId = Self.makeIdentifier(prefix: "branch")
        try inTransaction {
            try execute(
                """
                INSERT INTO branches (
                    id, session_id, parent_branch_id, base_checkpoint_id, name, created_at, status
                ) VALUES (?, ?, ?, ?, ?, ?, ?);
                """,
                bindings: [
                    .text(branchId),
                    .text(sessionId),
                    .text(sourceBranch.id),
                    .nullableText(fromCheckpointId),
                    .text(name),
                    .double(now.timeIntervalSince1970),
                    .text(DecisionSessionBranchStatus.active.rawValue)
                ]
            )
            try execute(
                """
                UPDATE sessions
                SET head_branch_id = ?, updated_at = ?
                WHERE id = ?;
                """,
                bindings: [
                    .text(branchId),
                    .double(now.timeIntervalSince1970),
                    .text(sessionId)
                ]
            )
        }
        let branch = try getBranch(branchId)
        _ = try appendEvent(
            sessionId: sessionId,
            branchId: branch.id,
            type: .branchCreated,
            parentEventId: nil,
            payload: DecisionSessionPayloadBranchCreated(
                fromCheckpointId: fromCheckpointId,
                branchId: branch.id,
                reason: reason
            ),
            now: now
        )
        try maybeAutoCheckpoint(
            sessionId: sessionId,
            branchId: branch.id,
            triggerEventType: .branchCreated,
            draft: branchCheckpointDraft,
            now: now
        )
        return branch
    }

    func switchBranch(sessionId: String, branchId: String, now: Date = .now) throws -> DecisionSession {
        _ = try getBranch(branchId)
        try execute(
            """
            UPDATE sessions
            SET head_branch_id = ?, updated_at = ?
            WHERE id = ?;
            """,
            bindings: [
                .text(branchId),
                .double(now.timeIntervalSince1970),
                .text(sessionId)
            ]
        )
        return try getSession(sessionId)
    }

    func mergeBranch(sourceBranchId: String, targetBranchId: String, now: Date = .now) throws -> DecisionSessionBranch {
        let source = try getBranch(sourceBranchId)
        let target = try getBranch(targetBranchId)
        guard source.sessionId == target.sessionId else {
            throw DecisionSessionEngineError.invalidState("Branches can only merge within the same session.")
        }
        guard source.id != target.id else {
            throw DecisionSessionEngineError.invalidState("A branch cannot merge into itself.")
        }
        guard source.status == .active else {
            throw DecisionSessionEngineError.invalidState("Only active branches can be merged.")
        }
        guard target.status == .active else {
            throw DecisionSessionEngineError.invalidState("Target branch must stay active during merge.")
        }
        try execute(
            """
            UPDATE branches
            SET status = ?
            WHERE id = ?;
            """,
            bindings: [
                .text(DecisionSessionBranchStatus.merged.rawValue),
                .text(sourceBranchId)
            ]
        )
        _ = try appendEvent(
            sessionId: source.sessionId,
            branchId: target.id,
            type: .branchMerged,
            parentEventId: try latestEvent(sessionId: source.sessionId, branchId: target.id)?.id,
            payload: DecisionSessionPayloadBranchMerged(
                sourceBranchId: source.id,
                targetBranchId: target.id,
                reason: "merged into active branch"
            ),
            now: now
        )
        return try getBranch(source.id)
    }

    func abandonBranch(_ branchId: String, now: Date = .now) throws -> DecisionSessionBranch {
        _ = now
        try execute(
            """
            UPDATE branches
            SET status = ?
            WHERE id = ?;
            """,
            bindings: [
                .text(DecisionSessionBranchStatus.abandoned.rawValue),
                .text(branchId)
            ]
        )
        return try getBranch(branchId)
    }

    @discardableResult
    func appendUserMessage(
        sessionId: String,
        text: String,
        attachments: [String] = [],
        intent: String? = nil,
        branchId: String? = nil,
        checkpointDraft: DecisionSessionCheckpointDraft? = nil,
        now: Date = .now
    ) throws -> DecisionSessionEvent {
        try appendBranchEvent(
            sessionId: sessionId,
            branchId: branchId,
            type: .userMessage,
            payload: DecisionSessionPayloadUserMessage(
                text: text,
                attachments: attachments,
                intent: intent
            ),
            checkpointDraft: checkpointDraft,
            now: now
        )
    }

    @discardableResult
    func appendAssistantMessage(
        sessionId: String,
        text: String,
        summary: String? = nil,
        branchId: String? = nil,
        checkpointDraft: DecisionSessionCheckpointDraft? = nil,
        now: Date = .now
    ) throws -> DecisionSessionEvent {
        try appendBranchEvent(
            sessionId: sessionId,
            branchId: branchId,
            type: .assistantMessage,
            payload: DecisionSessionPayloadAssistantMessage(
                text: text,
                summary: summary
            ),
            checkpointDraft: checkpointDraft,
            now: now
        )
    }

    func appendCorrection(
        sessionId: String,
        targetEventId: String,
        newText: String,
        reason: String = "user corrected prior requirement",
        checkpointDraft: DecisionSessionCheckpointDraft? = nil,
        now: Date = .now
    ) throws -> (branch: DecisionSessionBranch, checkpoint: DecisionSessionCheckpoint?, correction: DecisionSessionEvent) {
        let session = try getSession(sessionId)
        let sourceBranch = try getBranch(session.headBranchId)
        let sourceCheckpoint = try createCheckpoint(
            sessionId: sessionId,
            branchId: sourceBranch.id,
            draft: checkpointDraft ?? latestCheckpointDraft(sessionId: sessionId, branchId: sourceBranch.id),
            now: now
        )
        let correctionBranch = try createBranch(
            sessionId: sessionId,
            fromCheckpointId: sourceCheckpoint.id,
            name: "correction-\(sourceCheckpoint.basedOnEventSeq)",
            reason: "correction branch",
            now: now
        )
        let correction = try appendEvent(
            sessionId: sessionId,
            branchId: correctionBranch.id,
            type: .correctionAdded,
            parentEventId: nil,
            payload: DecisionSessionPayloadCorrection(
                targetEventId: targetEventId,
                mode: "supersede",
                newText: newText,
                reason: reason
            ),
            now: now
        )
        return (correctionBranch, sourceCheckpoint, correction)
    }

    @discardableResult
    func appendToolCallStarted(
        sessionId: String,
        tool: String,
        argsPreview: [String: String],
        branchId: String? = nil,
        now: Date = .now
    ) throws -> DecisionSessionEvent {
        try appendBranchEvent(
            sessionId: sessionId,
            branchId: branchId,
            type: .toolCallStarted,
            payload: DecisionSessionPayloadToolCallStarted(tool: tool, argsPreview: argsPreview),
            checkpointDraft: nil,
            now: now
        )
    }

    @discardableResult
    func appendToolCallFinished(
        sessionId: String,
        tool: String,
        resultSummary: String,
        artifactRefs: [String] = [],
        branchId: String? = nil,
        checkpointDraft: DecisionSessionCheckpointDraft? = nil,
        now: Date = .now
    ) throws -> DecisionSessionEvent {
        try appendBranchEvent(
            sessionId: sessionId,
            branchId: branchId,
            type: .toolCallFinished,
            payload: DecisionSessionPayloadToolCallFinished(
                tool: tool,
                resultSummary: resultSummary,
                artifactRefs: artifactRefs
            ),
            checkpointDraft: checkpointDraft,
            now: now
        )
    }

    @discardableResult
    func appendToolCallFailed(
        sessionId: String,
        tool: String,
        errorCode: String,
        recoverable: Bool,
        branchId: String? = nil,
        now: Date = .now
    ) throws -> DecisionSessionEvent {
        try appendBranchEvent(
            sessionId: sessionId,
            branchId: branchId,
            type: .toolCallFailed,
            payload: DecisionSessionPayloadToolCallFailed(
                tool: tool,
                errorCode: errorCode,
                recoverable: recoverable
            ),
            checkpointDraft: nil,
            now: now
        )
    }

    func listEvents(
        sessionId: String,
        branchId: String,
        fromSeq: Int = 1,
        toSeq: Int? = nil
    ) throws -> [DecisionSessionEvent] {
        if let toSeq {
            return try queryRows(
                """
                SELECT id, session_id, branch_id, seq, created_at, type, parent_event_id, payload_ref, payload_hash, record_hash
                FROM events
                WHERE session_id = ? AND branch_id = ? AND seq BETWEEN ? AND ?
                ORDER BY seq ASC;
                """,
                bindings: [.text(sessionId), .text(branchId), .int(fromSeq), .int(toSeq)],
                map: decodeEvent(row:)
            )
        }
        return try queryRows(
            """
            SELECT id, session_id, branch_id, seq, created_at, type, parent_event_id, payload_ref, payload_hash, record_hash
            FROM events
            WHERE session_id = ? AND branch_id = ? AND seq >= ?
            ORDER BY seq ASC;
            """,
            bindings: [.text(sessionId), .text(branchId), .int(fromSeq)],
            map: decodeEvent(row:)
        )
    }

    func listCheckpoints(sessionId: String) throws -> [DecisionSessionCheckpoint] {
        try queryRows(
            """
            SELECT id, session_id, branch_id, based_on_event_seq, created_at, summary_json,
                   runtime_state_json, event_hash, previous_checkpoint_hash, previous_checkpoint_id, checkpoint_hash
            FROM checkpoints
            WHERE session_id = ?
            ORDER BY created_at ASC, id ASC;
            """,
            bindings: [.text(sessionId)],
            map: decodeCheckpoint(row:)
        )
    }

    func listAllEvents(sessionId: String) throws -> [DecisionSessionEvent] {
        try queryRows(
            """
            SELECT id, session_id, branch_id, seq, created_at, type, parent_event_id, payload_ref, payload_hash, record_hash
            FROM events
            WHERE session_id = ?
            ORDER BY branch_id ASC, seq ASC, id ASC;
            """,
            bindings: [.text(sessionId)],
            map: decodeEvent(row:)
        )
    }

    func listAllSteps(sessionId: String) throws -> [DecisionSessionStep] {
        try queryRows(
            """
            SELECT id, session_id, branch_id, start_event_seq, status, started_at, updated_at, ttl_ms, heartbeat_at, error_code
            FROM steps
            WHERE session_id = ?
            ORDER BY started_at ASC, id ASC;
            """,
            bindings: [.text(sessionId)],
            map: decodeStep(row:)
        )
    }

    func createCheckpoint(
        sessionId: String,
        branchId: String? = nil,
        draft: DecisionSessionCheckpointDraft = .empty,
        now: Date = .now
    ) throws -> DecisionSessionCheckpoint {
        let session = try getSession(sessionId)
        let resolvedBranchId = branchId ?? session.headBranchId
        _ = try getBranch(resolvedBranchId)
        let latestEvent = try latestEvent(sessionId: sessionId, branchId: resolvedBranchId)
        let previous = try getLatestCheckpoint(sessionId: sessionId, branchId: resolvedBranchId)
        let checkpointId = Self.makeIdentifier(prefix: "ckpt")
        let basedOnEventSeq = latestEvent?.seq ?? 0
        let eventHash = latestEvent?.recordHash ?? Self.sha256("empty-events")
        let previousCheckpointHash = previous?.checkpointHash
        let summaryJSON = try encodeJSONString(draft.summary)
        let runtimeStateJSON = try encodeJSONString(draft.runtimeState)
        let checkpointHash = Self.sha256(
            [
                checkpointId,
                sessionId,
                resolvedBranchId,
                "\(basedOnEventSeq)",
                eventHash,
                previousCheckpointHash ?? "none",
                summaryJSON,
                runtimeStateJSON
            ].joined(separator: "|")
        )

        try inTransaction {
            try execute(
                """
                INSERT INTO checkpoints (
                    id, session_id, branch_id, based_on_event_seq, created_at, summary_json,
                    runtime_state_json, event_hash, previous_checkpoint_hash, previous_checkpoint_id, checkpoint_hash
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """,
                bindings: [
                    .text(checkpointId),
                    .text(sessionId),
                    .text(resolvedBranchId),
                    .int(basedOnEventSeq),
                    .double(now.timeIntervalSince1970),
                    .text(summaryJSON),
                    .text(runtimeStateJSON),
                    .text(eventHash),
                    .nullableText(previousCheckpointHash),
                    .nullableText(previous?.id),
                    .text(checkpointHash)
                ]
            )
            try execute(
                """
                UPDATE sessions
                SET latest_checkpoint_id = ?, updated_at = ?
                WHERE id = ?;
                """,
                bindings: [
                    .text(checkpointId),
                    .double(now.timeIntervalSince1970),
                    .text(sessionId)
                ]
            )
        }
        _ = try appendEvent(
            sessionId: sessionId,
            branchId: resolvedBranchId,
            type: .checkpointCreated,
            parentEventId: latestEvent?.id,
            payload: DecisionSessionPayloadCheckpointCreated(
                checkpointId: checkpointId,
                basedOnEventSeq: basedOnEventSeq
            ),
            now: now
        )
        return try getCheckpoint(checkpointId)
    }

    func getLatestCheckpoint(sessionId: String, branchId: String) throws -> DecisionSessionCheckpoint? {
        try queryOptionalCheckpoint(
            """
            SELECT id, session_id, branch_id, based_on_event_seq, created_at, summary_json, runtime_state_json,
                   event_hash, previous_checkpoint_hash, previous_checkpoint_id, checkpoint_hash
            FROM checkpoints
            WHERE session_id = ? AND branch_id = ?
            ORDER BY created_at DESC, id DESC
            LIMIT 1;
            """,
            bindings: [.text(sessionId), .text(branchId)]
        )
    }

    func restoreFromCheckpoint(_ checkpointId: String, now: Date = .now) throws -> DecisionSessionRecoveryResult {
        let checkpoint = try getCheckpoint(checkpointId)
        return try recoverSession(
            checkpoint.sessionId,
            branchId: checkpoint.branchId,
            preferredCheckpointId: checkpoint.id,
            now: now
        )
    }

    func getCheckpointForHost(_ checkpointId: String) throws -> DecisionSessionCheckpoint {
        try getCheckpoint(checkpointId)
    }

    func startStep(
        sessionId: String,
        branchId: String? = nil,
        status: DecisionSessionStepStatus = .planning,
        ttlMs: Int? = nil,
        now: Date = .now
    ) throws -> DecisionSessionStep {
        let session = try getSession(sessionId)
        let resolvedBranchId = branchId ?? session.headBranchId
        let stepId = Self.makeIdentifier(prefix: "step")
        let latestEvent = try latestEvent(sessionId: sessionId, branchId: resolvedBranchId)
        let resolvedTTL = ttlMs ?? defaultTTL(for: status)

        try execute(
            """
            INSERT INTO steps (
                id, session_id, branch_id, start_event_seq, status, started_at, updated_at, ttl_ms, heartbeat_at, error_code
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL);
            """,
            bindings: [
                .text(stepId),
                .text(sessionId),
                .text(resolvedBranchId),
                .int(latestEvent?.seq ?? 0),
                .text(status.rawValue),
                .double(now.timeIntervalSince1970),
                .double(now.timeIntervalSince1970),
                .int(resolvedTTL)
            ]
        )

        _ = try appendEvent(
            sessionId: sessionId,
            branchId: resolvedBranchId,
            type: .stepStarted,
            parentEventId: latestEvent?.id,
            payload: DecisionSessionPayloadStepStarted(stepId: stepId, status: status, ttlMs: resolvedTTL),
            now: now
        )
        return try getStep(stepId)
    }

    func heartbeat(
        stepId: String,
        progress: Double? = nil,
        status: DecisionSessionStepStatus? = nil,
        now: Date = .now
    ) throws -> DecisionSessionStep {
        let step = try getStep(stepId)
        let updatedStatus = status ?? step.status
        try execute(
            """
            UPDATE steps
            SET status = ?, updated_at = ?, heartbeat_at = ?
            WHERE id = ?;
            """,
            bindings: [
                .text(updatedStatus.rawValue),
                .double(now.timeIntervalSince1970),
                .double(now.timeIntervalSince1970),
                .text(stepId)
            ]
        )
        _ = try appendEvent(
            sessionId: step.sessionId,
            branchId: step.branchId,
            type: .stepHeartbeat,
            parentEventId: try latestEvent(sessionId: step.sessionId, branchId: step.branchId)?.id,
            payload: DecisionSessionPayloadHeartbeat(
                stepId: stepId,
                progress: progress,
                status: updatedStatus
            ),
            now: now
        )
        return try getStep(stepId)
    }

    func completeStep(stepId: String, now: Date = .now) throws -> DecisionSessionStep {
        try updateStep(stepId: stepId, status: .completed, errorCode: nil, now: now)
    }

    func markStepStalled(stepId: String, errorCode: String? = nil, now: Date = .now) throws -> DecisionSessionStep {
        let step = try updateStep(stepId: stepId, status: .stalled, errorCode: errorCode, now: now)
        _ = try appendEvent(
            sessionId: step.sessionId,
            branchId: step.branchId,
            type: .stepStalled,
            parentEventId: try latestEvent(sessionId: step.sessionId, branchId: step.branchId)?.id,
            payload: DecisionSessionPayloadStepStalled(stepId: stepId, errorCode: errorCode),
            now: now
        )
        _ = try appendEvent(
            sessionId: step.sessionId,
            branchId: step.branchId,
            type: .sessionError,
            parentEventId: try latestEvent(sessionId: step.sessionId, branchId: step.branchId)?.id,
            payload: DecisionSessionPayloadSessionError(
                kind: "stalled_step",
                stepId: step.id,
                recoverable: true
            ),
            now: now
        )
        _ = try updateSessionStatus(step.sessionId, status: .stalled, eventType: nil, now: now)
        return step
    }

    func recoverSession(
        _ sessionId: String,
        branchId: String? = nil,
        preferredCheckpointId: String? = nil,
        now: Date = .now
    ) throws -> DecisionSessionRecoveryResult {
        let session = try getSession(sessionId)
        let sourceBranch = try getBranch(branchId ?? session.headBranchId)
        let checkpoint = if let preferredCheckpointId {
            try getCheckpoint(preferredCheckpointId)
        } else {
            try getLatestCheckpoint(sessionId: sessionId, branchId: sourceBranch.id)
        }
        let replayEvents = try listEvents(
            sessionId: sessionId,
            branchId: sourceBranch.id,
            fromSeq: (checkpoint?.basedOnEventSeq ?? 0) + 1
        )
        let openSteps = try openSteps(sessionId: sessionId, branchId: sourceBranch.id)
        let failedSteps = try openSteps.map {
            try updateStep(stepId: $0.id, status: .failed, errorCode: "recovered_from_checkpoint", now: now)
        }
        let recoveryBranch = try createBranch(
            sessionId: sessionId,
            fromCheckpointId: checkpoint?.id,
            name: "recovery-\(sourceBranch.id.suffix(6))",
            reason: "watchdog recovery",
            now: now
        )
        _ = try appendEvent(
            sessionId: sessionId,
            branchId: recoveryBranch.id,
            type: .sessionRecovered,
            parentEventId: nil,
            payload: DecisionSessionPayloadSessionRecovered(
                sourceCheckpointId: checkpoint?.id,
                failedStepIds: failedSteps.map(\.id),
                sourceBranchId: sourceBranch.id
            ),
            now: now
        )
        for step in failedSteps {
            _ = try appendEvent(
                sessionId: sessionId,
                branchId: recoveryBranch.id,
                type: .stepRecovered,
                parentEventId: nil,
                payload: DecisionSessionPayloadStepStalled(stepId: step.id, errorCode: step.errorCode),
                now: now
            )
        }
        _ = try updateSessionStatus(sessionId, status: .active, eventType: nil, now: now)
        return DecisionSessionRecoveryResult(
            session: try getSession(sessionId),
            sourceBranch: sourceBranch,
            recoveredBranch: recoveryBranch,
            checkpoint: checkpoint,
            failedStepIds: failedSteps.map(\.id),
            replayedEvents: replayEvents
        )
    }

    func rebuildTimeline(sessionId: String, branchId: String? = nil) throws -> DecisionSessionTimeline {
        let session = try getSession(sessionId)
        let resolvedBranchId = branchId ?? session.headBranchId
        let checkpoint = try getLatestCheckpoint(sessionId: sessionId, branchId: resolvedBranchId)
        let events = try listEvents(
            sessionId: sessionId,
            branchId: resolvedBranchId,
            fromSeq: (checkpoint?.basedOnEventSeq ?? 0) + 1
        )
        let visibleMergeEvents = events.filter { $0.type == .branchMerged }
        let foldedMergeEvents = try mergedEventsFoldedIntoCheckpoint(
            sessionId: sessionId,
            branchId: resolvedBranchId,
            checkpoint: checkpoint
        )

        var items: [DecisionSessionTimelineItem] = []
        if let checkpoint {
            items.append(
                DecisionSessionTimelineItem(
                    id: "checkpoint-\(checkpoint.id)",
                    createdAt: checkpoint.createdAt,
                    branchId: checkpoint.branchId,
                    title: "Checkpoint \(checkpoint.id)",
                    detail: DecisionEvolutionCheckpointRecoverySupport.timelineCheckpointDetail(
                        goal: checkpoint.summary.goal,
                        basedOnEventSeq: checkpoint.basedOnEventSeq
                    ),
                    kind: .checkpoint(checkpoint)
                )
            )
        }

        items += events.map { event in
            DecisionSessionTimelineItem(
                id: "event-\(event.id)",
                createdAt: event.createdAt,
                branchId: event.branchId,
                title: event.type.rawValue,
                detail: (try? timelineDetail(for: event)) ?? "Event \(event.id)",
                kind: .event(event)
            )
        }

        let recoveryNotice = events.contains(where: { $0.type == .sessionRecovered })
            ? DecisionEvolutionCheckpointRecoverySupport.timelineRecoveryNotice
            : nil
        let mergeNotice = try timelineMergeNotice(
            sessionId: sessionId,
            targetBranchId: resolvedBranchId,
            foldedMergeEvents: foldedMergeEvents,
            visibleMergeEvents: visibleMergeEvents
        )

        return DecisionSessionTimeline(
            sessionId: sessionId,
            branchId: resolvedBranchId,
            checkpoint: checkpoint,
            items: items.sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.id < rhs.id
            },
            recoveryNotice: recoveryNotice,
            mergeNotice: mergeNotice
        )
    }

    func sweepWatchdog(now: Date = .now) throws -> [DecisionSessionWatchdogAction] {
        let openSteps = try queryRows(
            """
            SELECT id, session_id, branch_id, start_event_seq, status, started_at, updated_at, ttl_ms, heartbeat_at, error_code
            FROM steps
            WHERE status IN (?, ?, ?, ?);
            """,
            bindings: [
                .text(DecisionSessionStepStatus.planning.rawValue),
                .text(DecisionSessionStepStatus.acting.rawValue),
                .text(DecisionSessionStepStatus.waitingTool.rawValue),
                .text(DecisionSessionStepStatus.writing.rawValue)
            ],
            map: decodeStep(row:)
        )
        var actions: [DecisionSessionWatchdogAction] = []
        for step in openSteps {
            let referenceDate = step.heartbeatAt ?? step.updatedAt
            let elapsedMs = Int(now.timeIntervalSince(referenceDate) * 1000)
            guard elapsedMs > step.ttlMs else { continue }
            _ = try markStepStalled(stepId: step.id, errorCode: "watchdog_timeout", now: now)
            _ = try recoverSession(step.sessionId, branchId: step.branchId, now: now)
            actions.append(
                DecisionSessionWatchdogAction(
                    stepId: step.id,
                    sessionId: step.sessionId,
                    branchId: step.branchId,
                    action: "stalled_and_recovered"
                )
            )
        }
        return actions
    }

    func resetForTesting() throws {
        try execute(
            """
            DELETE FROM steps;
            DELETE FROM checkpoints;
            DELETE FROM events;
            DELETE FROM branches;
            DELETE FROM sessions;
            """,
            bindings: []
        )
        try clearDirectoryContents(at: blobsDirectoryURL)
        try clearDirectoryContents(at: exportsDirectoryURL)
        try clearDirectoryContents(at: logsDirectoryURL)
    }

    func snapshot(now: Date = .now) throws -> DecisionSessionRuntimeSnapshot {
        DecisionSessionRuntimeSnapshot(
            layerPlacement: .foldedLung,
            sessions: try count("sessions"),
            activeSessions: try count("sessions", whereClause: "status = '\(DecisionSessionStatus.active.rawValue)'"),
            stalledSessions: try count("sessions", whereClause: "status = '\(DecisionSessionStatus.stalled.rawValue)'"),
            mergeReadySessions: try countRows(
                """
                SELECT COUNT(DISTINCT b.session_id) AS count_value
                FROM branches b
                JOIN sessions s ON s.id = b.session_id
                WHERE b.id != s.head_branch_id AND b.status = ?;
                """,
                bindings: [.text(DecisionSessionBranchStatus.active.rawValue)]
            ),
            mergeableBranches: try countRows(
                """
                SELECT COUNT(*) AS count_value
                FROM branches b
                JOIN sessions s ON s.id = b.session_id
                WHERE b.id != s.head_branch_id AND b.status = ?;
                """,
                bindings: [.text(DecisionSessionBranchStatus.active.rawValue)]
            ),
            branches: try count("branches"),
            checkpoints: try count("checkpoints"),
            events: try count("events"),
            steps: try count("steps"),
            recentSessions: try listSessions(limit: 3).map { try runtimeInspection(for: $0, now: now) }
        )
    }

    private func importSession(
        _ bundle: DecisionSessionExportBundle,
        now: Date
    ) throws -> DecisionSession {
        let importedSessionId = Self.makeIdentifier(prefix: "sess")
        let importedTitle = Self.importedSessionTitle(bundle.session.title)

        let branchMap = Dictionary(
            uniqueKeysWithValues: bundle.branches.map { ($0.id, Self.makeIdentifier(prefix: "branch")) }
        )
        let checkpointMap = Dictionary(
            uniqueKeysWithValues: bundle.checkpoints.map { ($0.id, Self.makeIdentifier(prefix: "ckpt")) }
        )
        let eventMap = Dictionary(
            uniqueKeysWithValues: bundle.events.map { ($0.event.id, Self.makeIdentifier(prefix: "evt")) }
        )
        let stepMap = Dictionary(
            uniqueKeysWithValues: bundle.steps.map { ($0.id, Self.makeIdentifier(prefix: "step")) }
        )

        let importedStatus: DecisionSessionStatus = switch bundle.session.status {
        case .archived:
            .archived
        case .broken:
            .broken
        case .active, .paused, .stalled:
            .paused
        }

        try inTransaction {
            for branch in bundle.branches.sorted(by: Self.branchSort(lhs:rhs:)) {
                try execute(
                    """
                    INSERT INTO branches (
                        id, session_id, parent_branch_id, base_checkpoint_id, name, created_at, status
                    ) VALUES (?, ?, ?, ?, ?, ?, ?);
                    """,
                    bindings: [
                        .text(branchMap[branch.id] ?? branch.id),
                        .text(importedSessionId),
                        .nullableText(branch.parentBranchId.flatMap { branchMap[$0] }),
                        .nullableText(branch.baseCheckpointId.flatMap { checkpointMap[$0] }),
                        .text(branch.name),
                        .double(branch.createdAt.timeIntervalSince1970),
                        .text(branch.status.rawValue)
                    ]
                )
            }

            try execute(
                """
                INSERT INTO sessions (
                    id, title, created_at, updated_at, status, head_branch_id, latest_checkpoint_id
                ) VALUES (?, ?, ?, ?, ?, ?, ?);
                """,
                bindings: [
                    .text(importedSessionId),
                    .text(importedTitle),
                    .double(now.timeIntervalSince1970),
                    .double(now.timeIntervalSince1970),
                    .text(importedStatus.rawValue),
                    .text(branchMap[bundle.session.headBranchId] ?? bundle.session.headBranchId),
                    .null
                ]
            )

            var latestRecordHashByBranch: [String: String] = [:]
            let sortedEvents = bundle.events.sorted { lhs, rhs in
                if lhs.event.branchId != rhs.event.branchId {
                    return lhs.event.branchId < rhs.event.branchId
                }
                if lhs.event.seq != rhs.event.seq {
                    return lhs.event.seq < rhs.event.seq
                }
                return lhs.event.id < rhs.event.id
            }

            for exportedEvent in sortedEvents {
                let event = exportedEvent.event
                let importedBranchId = branchMap[event.branchId] ?? event.branchId
                let remappedPayloadData = try remappedPayloadData(
                    for: exportedEvent,
                    branchMap: branchMap,
                    checkpointMap: checkpointMap,
                    eventMap: eventMap,
                    stepMap: stepMap
                )
                let payloadHash = remappedPayloadData.map(Self.sha256(_:)) ?? event.payloadHash
                let payloadRef = try remappedPayloadData.map { try persistPayload(data: $0, hash: payloadHash) }
                let importedEventId = eventMap[event.id] ?? event.id
                let importedParentEventId = event.parentEventId.flatMap { eventMap[$0] }
                let previousRecordHash = latestRecordHashByBranch[importedBranchId] ?? "root"
                let recordHash = Self.sha256(
                    [
                        previousRecordHash,
                        importedEventId,
                        importedSessionId,
                        importedBranchId,
                        "\(event.seq)",
                        event.type.rawValue,
                        importedParentEventId ?? "root",
                        payloadHash
                    ].joined(separator: "|")
                )

                try execute(
                    """
                    INSERT INTO events (
                        id, session_id, branch_id, seq, created_at, type, parent_event_id,
                        payload_ref, payload_hash, record_hash
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                    """,
                    bindings: [
                        .text(importedEventId),
                        .text(importedSessionId),
                        .text(importedBranchId),
                        .int(event.seq),
                        .double(event.createdAt.timeIntervalSince1970),
                        .text(event.type.rawValue),
                        .nullableText(importedParentEventId),
                        .nullableText(payloadRef),
                        .text(payloadHash),
                        .text(recordHash)
                    ]
                )
                latestRecordHashByBranch[importedBranchId] = recordHash
            }

            var checkpointHashMap: [String: String] = [:]
            for checkpoint in bundle.checkpoints.sorted(by: Self.checkpointSort(lhs:rhs:)) {
                let importedCheckpointId = checkpointMap[checkpoint.id] ?? checkpoint.id
                let importedBranchId = branchMap[checkpoint.branchId] ?? checkpoint.branchId
                let previousCheckpointId = checkpoint.previousCheckpointId.flatMap { checkpointMap[$0] }
                let previousCheckpointHash = checkpoint.previousCheckpointId.flatMap { checkpointHashMap[$0] }
                let eventHash = try importedEventHash(
                    sessionId: importedSessionId,
                    branchId: importedBranchId,
                    basedOnEventSeq: checkpoint.basedOnEventSeq
                )
                let summaryJSON = try encodeJSONString(checkpoint.summary)
                let runtimeStateJSON = try encodeJSONString(checkpoint.runtimeState)
                let checkpointHash = Self.sha256(
                    [
                        importedCheckpointId,
                        importedSessionId,
                        importedBranchId,
                        "\(checkpoint.basedOnEventSeq)",
                        eventHash,
                        previousCheckpointHash ?? "none",
                        summaryJSON,
                        runtimeStateJSON
                    ].joined(separator: "|")
                )

                try execute(
                    """
                    INSERT INTO checkpoints (
                        id, session_id, branch_id, based_on_event_seq, created_at, summary_json,
                        runtime_state_json, event_hash, previous_checkpoint_hash, previous_checkpoint_id, checkpoint_hash
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                    """,
                    bindings: [
                        .text(importedCheckpointId),
                        .text(importedSessionId),
                        .text(importedBranchId),
                        .int(checkpoint.basedOnEventSeq),
                        .double(checkpoint.createdAt.timeIntervalSince1970),
                        .text(summaryJSON),
                        .text(runtimeStateJSON),
                        .text(eventHash),
                        .nullableText(previousCheckpointHash),
                        .nullableText(previousCheckpointId),
                        .text(checkpointHash)
                    ]
                )
                checkpointHashMap[checkpoint.id] = checkpointHash
            }

            for step in bundle.steps.sorted(by: Self.stepSort(lhs:rhs:)) {
                let importedStepId = stepMap[step.id] ?? step.id
                let importedBranchId = branchMap[step.branchId] ?? step.branchId
                let importedStepStatus: DecisionSessionStepStatus = switch step.status {
                case .planning, .acting, .waitingTool, .writing, .stalled:
                    .failed
                case .failed, .completed:
                    step.status
                }
                let importedErrorCode: String? = switch step.status {
                case .planning, .acting, .waitingTool, .writing, .stalled:
                    "imported_unfinished_step"
                case .failed, .completed:
                    step.errorCode
                }

                try execute(
                    """
                    INSERT INTO steps (
                        id, session_id, branch_id, start_event_seq, status, started_at, updated_at, ttl_ms, heartbeat_at, error_code
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                    """,
                    bindings: [
                        .text(importedStepId),
                        .text(importedSessionId),
                        .text(importedBranchId),
                        .int(step.startEventSeq),
                        .text(importedStepStatus.rawValue),
                        .double(step.startedAt.timeIntervalSince1970),
                        .double(step.updatedAt.timeIntervalSince1970),
                        .int(step.ttlMs),
                        step.heartbeatAt.map { .double($0.timeIntervalSince1970) } ?? .null,
                        .nullableText(importedErrorCode)
                    ]
                )
            }

            try execute(
                """
                UPDATE sessions
                SET latest_checkpoint_id = ?, updated_at = ?
                WHERE id = ?;
                """,
                bindings: [
                    .nullableText(bundle.session.latestCheckpointId.flatMap { checkpointMap[$0] }),
                    .double(now.timeIntervalSince1970),
                    .text(importedSessionId)
                ]
            )
        }

        return try getSession(importedSessionId)
    }

    private func makeImportPreview(
        _ bundle: DecisionSessionExportBundle
    ) -> DecisionSessionImportBundlePreview {
        let importedTitle = Self.importedSessionTitle(bundle.session.title)
        let headBranchID = bundle.manifest.sourceHeadBranchId
        let sortedBranches = bundle.branches.sorted(by: Self.branchSort(lhs:rhs:))
        let branchPreviews = sortedBranches.map { branch in
            let isHead = branch.id == headBranchID
            let detailLine = DecisionSessionBranchPresentationSupport.detailLine(
                originLine: nil,
                parentBranchID: branch.parentBranchId,
                baseCheckpointID: branch.baseCheckpointId,
                createdAt: branch.createdAt
            )

            return DecisionSessionImportBundleBranchPreview(
                id: branch.id,
                name: branch.name,
                statusLine: DecisionSessionReviewPresentationSupport.importBranchStatusLine(
                    status: branch.status,
                    isHead: isHead
                ),
                detailLine: detailLine,
                isHead: isHead
            )
        }

        let latestCheckpointGoal = bundle.checkpoints.first(where: { $0.id == bundle.manifest.sourceLatestCheckpointId })?.summary.goal
        let checkpointLine = DecisionSessionReviewPresentationSupport.latestCheckpointLine(
            latestCheckpointID: bundle.manifest.sourceLatestCheckpointId,
            goal: latestCheckpointGoal
        )

        let unfinishedSteps = bundle.steps.filter {
            switch $0.status {
            case .planning, .acting, .waitingTool, .writing, .stalled:
                return true
            case .failed, .completed:
                return false
            }
        }

        let unfinishedStepCount = unfinishedSteps.count
        let unfinishedStepsLine = DecisionSessionStepPresentationSupport.importUnfinishedStepsLine(
            unfinishedStepCount: unfinishedStepCount
        )

        let headBranchName = sortedBranches.first(where: { $0.id == headBranchID })?.name ?? headBranchID

        let integrityLine: String
        if let bundleFingerprint = bundle.manifest.bundleFingerprint {
            integrityLine = "Validated schema v\(bundle.manifest.schemaVersion) • fingerprint \(bundleFingerprint.prefix(12))"
        } else {
            integrityLine = "Validated legacy schema v\(bundle.manifest.schemaVersion) • fingerprint unavailable"
        }

        return DecisionSessionImportBundlePreview(
            id: "\(bundle.manifest.sourceSessionId)|\(bundle.manifest.exportedAt.timeIntervalSince1970)",
            sourceSessionId: bundle.manifest.sourceSessionId,
            sourceTitle: bundle.manifest.sourceTitle,
            importedTitle: importedTitle,
            exportedAt: bundle.manifest.exportedAt,
            countsLine: DecisionSessionReviewPresentationSupport.importCountsLine(
                branches: bundle.manifest.counts.branches,
                checkpoints: bundle.manifest.counts.checkpoints,
                events: bundle.manifest.counts.events,
                steps: bundle.manifest.counts.steps
            ),
            integrityLine: integrityLine,
            checkpointLine: checkpointLine,
            branchLine: DecisionSessionReviewPresentationSupport.importBranchLine(
                headBranchName: headBranchName,
                layerPlacement: bundle.manifest.layerPlacement
            ),
            unfinishedStepCount: unfinishedStepCount,
            unfinishedStepsLine: unfinishedStepsLine,
            headline: DecisionSessionReviewPresentationSupport.importPreviewHeadline,
            branchPreviews: branchPreviews
        )
    }

    private func validateImportBundle(
        _ bundle: DecisionSessionExportBundle
    ) throws {
        guard bundle.manifest.schemaVersion == Self.exportSchemaVersion else {
            throw DecisionSessionEngineError.invalidState(
                "Unsupported Session Engine bundle schema v\(bundle.manifest.schemaVersion)."
            )
        }
        guard bundle.manifest.layerPlacement == .foldedLung else {
            throw DecisionSessionEngineError.invalidState("Unsupported Session Engine layer placement.")
        }
        guard bundle.session.id == bundle.manifest.sourceSessionId else {
            throw DecisionSessionEngineError.invalidState("Session Engine bundle session id does not match the manifest.")
        }
        guard bundle.session.headBranchId == bundle.manifest.sourceHeadBranchId else {
            throw DecisionSessionEngineError.invalidState("Session Engine bundle head branch does not match the manifest.")
        }
        guard bundle.session.latestCheckpointId == bundle.manifest.sourceLatestCheckpointId else {
            throw DecisionSessionEngineError.invalidState("Session Engine bundle latest checkpoint does not match the manifest.")
        }
        guard bundle.branches.count == bundle.manifest.counts.branches,
              bundle.checkpoints.count == bundle.manifest.counts.checkpoints,
              bundle.events.count == bundle.manifest.counts.events,
              bundle.steps.count == bundle.manifest.counts.steps else {
            throw DecisionSessionEngineError.invalidState("Session Engine bundle counts do not match the manifest.")
        }

        let branchIDs = Set(bundle.branches.map(\.id))
        let checkpointIDs = Set(bundle.checkpoints.map(\.id))

        guard branchIDs.contains(bundle.manifest.sourceHeadBranchId) else {
            throw DecisionSessionEngineError.invalidState("Session Engine bundle is missing the manifest head branch.")
        }
        if let latestCheckpointID = bundle.manifest.sourceLatestCheckpointId,
           checkpointIDs.contains(latestCheckpointID) == false {
            throw DecisionSessionEngineError.invalidState("Session Engine bundle is missing the manifest latest checkpoint.")
        }

        guard bundle.branches.allSatisfy({ $0.sessionId == bundle.session.id }) else {
            throw DecisionSessionEngineError.invalidState("Session Engine bundle contains a branch that belongs to another session.")
        }
        guard bundle.checkpoints.allSatisfy({
            $0.sessionId == bundle.session.id && branchIDs.contains($0.branchId)
        }) else {
            throw DecisionSessionEngineError.invalidState("Session Engine bundle contains a checkpoint with an invalid branch reference.")
        }
        guard bundle.events.allSatisfy({
            $0.event.sessionId == bundle.session.id && branchIDs.contains($0.event.branchId)
        }) else {
            throw DecisionSessionEngineError.invalidState("Session Engine bundle contains an event with an invalid branch reference.")
        }
        guard bundle.steps.allSatisfy({
            $0.sessionId == bundle.session.id && branchIDs.contains($0.branchId)
        }) else {
            throw DecisionSessionEngineError.invalidState("Session Engine bundle contains a step with an invalid branch reference.")
        }

        let eventsByBranch = Dictionary(grouping: bundle.events.map(\.event), by: \.branchId)
        for events in eventsByBranch.values {
            let sorted = events.sorted {
                if $0.seq != $1.seq {
                    return $0.seq < $1.seq
                }
                return $0.id < $1.id
            }
            for (lhs, rhs) in zip(sorted, sorted.dropFirst()) {
                guard rhs.seq > lhs.seq else {
                    throw DecisionSessionEngineError.invalidState("Session Engine bundle event sequences are not strictly increasing within a branch.")
                }
            }
        }

        if let bundleFingerprint = bundle.manifest.bundleFingerprint {
            let expectedFingerprint = Self.makeBundleFingerprint(
                session: bundle.session,
                branches: bundle.branches,
                checkpoints: bundle.checkpoints,
                events: bundle.events,
                steps: bundle.steps
            )
            guard expectedFingerprint == bundleFingerprint else {
                throw DecisionSessionEngineError.invalidState("Session Engine bundle fingerprint validation failed.")
            }
        }
    }

    private func decodeImportBundle(from data: Data) throws -> DecisionSessionExportBundle {
        let bundle = try decoder.decode(DecisionSessionExportBundle.self, from: data)
        try validateImportBundle(bundle)
        return bundle
    }

    private static func makeBundleFingerprint(
        session: DecisionSession,
        branches: [DecisionSessionBranch],
        checkpoints: [DecisionSessionCheckpoint],
        events: [DecisionSessionExportEventRecord],
        steps: [DecisionSessionStep]
    ) -> String {
        let branchDigest = branches
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.id < rhs.id
            }
            .map {
                [
                    $0.id,
                    $0.sessionId,
                    $0.parentBranchId ?? "nil",
                    $0.baseCheckpointId ?? "nil",
                    $0.name,
                    $0.status.rawValue,
                    String($0.createdAt.timeIntervalSince1970)
                ].joined(separator: "|")
            }
            .joined(separator: "||")

        let checkpointDigest = checkpoints
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.id < rhs.id
            }
            .map {
                [
                    $0.id,
                    $0.sessionId,
                    $0.branchId,
                    String($0.basedOnEventSeq),
                    $0.previousCheckpointId ?? "nil",
                    $0.checkpointHash
                ].joined(separator: "|")
            }
            .joined(separator: "||")

        let eventDigest = events
            .sorted { lhs, rhs in
                if lhs.event.branchId != rhs.event.branchId {
                    return lhs.event.branchId < rhs.event.branchId
                }
                if lhs.event.seq != rhs.event.seq {
                    return lhs.event.seq < rhs.event.seq
                }
                return lhs.event.id < rhs.event.id
            }
            .map {
                [
                    $0.event.id,
                    $0.event.sessionId,
                    $0.event.branchId,
                    String($0.event.seq),
                    $0.event.type.rawValue,
                    $0.event.parentEventId ?? "nil",
                    $0.event.payloadHash,
                    $0.event.recordHash,
                    $0.payloadBase64.map(Self.sha256(_:)) ?? "nil"
                ].joined(separator: "|")
            }
            .joined(separator: "||")

        let stepDigest = steps
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt {
                    return lhs.startedAt < rhs.startedAt
                }
                return lhs.id < rhs.id
            }
            .map {
                [
                    $0.id,
                    $0.sessionId,
                    $0.branchId,
                    String($0.startEventSeq),
                    $0.status.rawValue,
                    String($0.startedAt.timeIntervalSince1970),
                    String($0.updatedAt.timeIntervalSince1970),
                    String($0.ttlMs),
                    $0.heartbeatAt.map { String($0.timeIntervalSince1970) } ?? "nil",
                    $0.errorCode ?? "nil"
                ].joined(separator: "|")
            }
            .joined(separator: "||")

        return sha256(
            [
                session.id,
                session.title,
                session.status.rawValue,
                session.headBranchId,
                session.latestCheckpointId ?? "nil",
                branchDigest,
                checkpointDigest,
                eventDigest,
                stepDigest
            ].joined(separator: "###")
        )
    }

    func loadPayloadData(for event: DecisionSessionEvent) throws -> Data? {
        guard let payloadRef = event.payloadRef else { return nil }
        let url = blobsDirectoryURL.appendingPathComponent(payloadRef, isDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func shutdown() {
        guard let db else { return }
        sqlite3_close(db)
        self.db = nil
    }

    private func appendBranchEvent<Payload: Encodable>(
        sessionId: String,
        branchId: String?,
        type: DecisionSessionEventType,
        payload: Payload,
        checkpointDraft: DecisionSessionCheckpointDraft?,
        now: Date
    ) throws -> DecisionSessionEvent {
        let session = try getSession(sessionId)
        let resolvedBranchId = branchId ?? session.headBranchId
        let event = try appendEvent(
            sessionId: sessionId,
            branchId: resolvedBranchId,
            type: type,
            parentEventId: try latestEvent(sessionId: sessionId, branchId: resolvedBranchId)?.id,
            payload: payload,
            now: now
        )
        try maybeAutoCheckpoint(
            sessionId: sessionId,
            branchId: resolvedBranchId,
            triggerEventType: type,
            draft: checkpointDraft,
            now: now
        )
        return event
    }

    @discardableResult
    private func appendEvent<Payload: Encodable>(
        sessionId: String,
        branchId: String,
        type: DecisionSessionEventType,
        parentEventId: String?,
        payload: Payload,
        now: Date
    ) throws -> DecisionSessionEvent {
        let payloadData = try encoder.encode(payload)
        let payloadHash = Self.sha256(payloadData)
        let payloadRef = try persistPayload(data: payloadData, hash: payloadHash)
        let latest = try latestEvent(sessionId: sessionId, branchId: branchId)
        let nextSeq = (latest?.seq ?? 0) + 1
        let eventId = Self.makeIdentifier(prefix: "evt")
        let recordHash = Self.sha256(
            [
                latest?.recordHash ?? "root",
                eventId,
                sessionId,
                branchId,
                "\(nextSeq)",
                type.rawValue,
                parentEventId ?? "root",
                payloadHash
            ].joined(separator: "|")
        )
        try execute(
            """
            INSERT INTO events (
                id, session_id, branch_id, seq, created_at, type, parent_event_id,
                payload_ref, payload_hash, record_hash
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            bindings: [
                .text(eventId),
                .text(sessionId),
                .text(branchId),
                .int(nextSeq),
                .double(now.timeIntervalSince1970),
                .text(type.rawValue),
                .nullableText(parentEventId),
                .nullableText(payloadRef),
                .text(payloadHash),
                .text(recordHash)
            ]
        )
        try execute(
            """
            UPDATE sessions
            SET updated_at = ?, head_branch_id = ?
            WHERE id = ?;
            """,
            bindings: [
                .double(now.timeIntervalSince1970),
                .text(branchId),
                .text(sessionId)
            ]
        )
        return DecisionSessionEvent(
            id: eventId,
            sessionId: sessionId,
            branchId: branchId,
            seq: nextSeq,
            createdAt: now,
            type: type,
            parentEventId: parentEventId,
            payloadRef: payloadRef,
            payloadHash: payloadHash,
            recordHash: recordHash
        )
    }

    private func maybeAutoCheckpoint(
        sessionId: String,
        branchId: String,
        triggerEventType: DecisionSessionEventType,
        draft: DecisionSessionCheckpointDraft?,
        now: Date
    ) throws {
        let latest = try latestEvent(sessionId: sessionId, branchId: branchId)
        guard let latest else { return }
        let checkpointDraft = draft ?? latestCheckpointDraft(sessionId: sessionId, branchId: branchId)
        let shouldCheckpoint: Bool = switch triggerEventType {
        case .assistantMessage, .toolCallFinished, .branchCreated:
            true
        case .userMessage, .toolCallStarted, .toolCallFailed, .sessionPaused, .sessionResumed,
                .stepStarted, .stepHeartbeat, .stepStalled, .stepRecovered, .sessionError,
                .sessionRecovered, .correctionAdded, .checkpointCreated:
            latest.seq % configuration.eventCompactionStride == 0
        case .branchMerged:
            false
        }
        guard shouldCheckpoint else { return }
        _ = try createCheckpoint(
            sessionId: sessionId,
            branchId: branchId,
            draft: checkpointDraft,
            now: now
        )
    }

    private func latestCheckpointDraft(sessionId: String, branchId: String) -> DecisionSessionCheckpointDraft {
        guard let resolved = try? getLatestCheckpoint(sessionId: sessionId, branchId: branchId) else {
            return .empty
        }
        return DecisionSessionCheckpointDraft(summary: resolved.summary, runtimeState: resolved.runtimeState)
    }

    private func openSteps(sessionId: String, branchId: String) throws -> [DecisionSessionStep] {
        try queryRows(
            """
            SELECT id, session_id, branch_id, start_event_seq, status, started_at, updated_at, ttl_ms, heartbeat_at, error_code
            FROM steps
            WHERE session_id = ? AND branch_id = ? AND status IN (?, ?, ?, ?, ?)
            ORDER BY started_at ASC;
            """,
            bindings: [
                .text(sessionId),
                .text(branchId),
                .text(DecisionSessionStepStatus.planning.rawValue),
                .text(DecisionSessionStepStatus.acting.rawValue),
                .text(DecisionSessionStepStatus.waitingTool.rawValue),
                .text(DecisionSessionStepStatus.writing.rawValue),
                .text(DecisionSessionStepStatus.stalled.rawValue)
            ],
            map: decodeStep(row:)
        )
    }

    private func updateStep(
        stepId: String,
        status: DecisionSessionStepStatus,
        errorCode: String?,
        now: Date
    ) throws -> DecisionSessionStep {
        try execute(
            """
            UPDATE steps
            SET status = ?, updated_at = ?, error_code = ?
            WHERE id = ?;
            """,
            bindings: [
                .text(status.rawValue),
                .double(now.timeIntervalSince1970),
                .nullableText(errorCode),
                .text(stepId)
            ]
        )
        return try getStep(stepId)
    }

    private func runtimeInspection(for session: DecisionSession, now: Date = .now) throws -> DecisionSessionRuntimeInspectionSession {
        let latestCheckpoint = try session.latestCheckpointId.map(getCheckpoint(_:))
            ?? getLatestCheckpoint(sessionId: session.id, branchId: session.headBranchId)
        let latestHeadEvent = try latestEvent(sessionId: session.id, branchId: session.headBranchId)
        let latestHeadEventDetail = try latestHeadEvent.flatMap { try timelineDetail(for: $0) }
        let openHeadSteps = try openSteps(sessionId: session.id, branchId: session.headBranchId)
        let representativeOpenStep = openHeadSteps.max { lhs, rhs in
            let lhsReferenceDate = lhs.heartbeatAt ?? lhs.updatedAt
            let rhsReferenceDate = rhs.heartbeatAt ?? rhs.updatedAt
            if lhsReferenceDate != rhsReferenceDate {
                return lhsReferenceDate < rhsReferenceDate
            }
            return lhs.updatedAt < rhs.updatedAt
        }
        let openStepReferenceDate = representativeOpenStep.map { $0.heartbeatAt ?? $0.updatedAt }
        let openStepRemainingMs: Int? = if let representativeOpenStep, let openStepReferenceDate {
            representativeOpenStep.ttlMs - Int(now.timeIntervalSince(openStepReferenceDate) * 1000)
        } else {
            nil
        }
        let latestCheckpointGoal = latestCheckpoint?.summary.goal.isEmpty == false ? latestCheckpoint?.summary.goal : nil
        let latestCheckpointEBrainAnchor = latestCheckpoint?.runtimeState.eBrainAnchor
        let latestCheckpointBudgetLine = latestCheckpoint?.summary.eBrainBudgetLine
        let latestCheckpointRouteLine = latestCheckpoint?.summary.eBrainRouteLine
        let latestCheckpointDecisionLine = latestCheckpoint?.summary.eBrainDecisionLine
            ?? latestCheckpointEBrainAnchor?.decisionLine
        let latestCheckpointTaskLine = latestCheckpoint?.summary.eBrainTaskLine
            ?? latestCheckpointEBrainAnchor?.taskLine
        let latestCheckpointPressureLine = latestCheckpoint?.summary.eBrainPressureLine
        let latestCheckpointAuditLine = latestCheckpoint?.summary.eBrainAuditLine
        let latestCheckpointActiveKillSwitchesLine = latestCheckpoint?.summary.eBrainActiveKillSwitchesLine
        let latestCheckpointKillSwitchesLine = latestCheckpoint?.summary.eBrainKillSwitchesLine
        let latestCheckpointActionLine = latestCheckpoint?.summary.actionLine
        let branchCount = try countRows(
            """
            SELECT COUNT(*) AS count_value
            FROM branches
            WHERE session_id = ?;
            """,
            bindings: [.text(session.id)]
        )
        let mergeableBranchCount = try countRows(
            """
            SELECT COUNT(*) AS count_value
            FROM branches
            WHERE session_id = ? AND id != ? AND status = ?;
            """,
            bindings: [
                .text(session.id),
                .text(session.headBranchId),
                .text(DecisionSessionBranchStatus.active.rawValue)
            ]
        )
        let recoveryCount = try countRows(
            """
            SELECT COUNT(*) AS count_value
            FROM events
            WHERE session_id = ? AND type = ?;
            """,
            bindings: [.text(session.id), .text(DecisionSessionEventType.sessionRecovered.rawValue)]
        )
        let latestRecoveryAt = try querySingleValue(
            """
            SELECT created_at
            FROM events
            WHERE session_id = ? AND type = ?
            ORDER BY created_at DESC, id DESC
            LIMIT 1;
            """,
            bindings: [.text(session.id), .text(DecisionSessionEventType.sessionRecovered.rawValue)],
            map: { row in
                Date(timeIntervalSince1970: try row.double(named: "created_at"))
            }
        )

        return DecisionSessionRuntimeInspectionSession(
            sessionID: session.id,
            title: session.title,
            status: session.status,
            updatedAt: session.updatedAt,
            headBranchID: session.headBranchId,
            latestCheckpointID: latestCheckpoint?.id,
            latestCheckpointSeq: latestCheckpoint?.basedOnEventSeq,
            latestCheckpointGoal: latestCheckpointGoal,
            latestCheckpointBudgetLine: latestCheckpointBudgetLine,
            latestCheckpointRouteLine: latestCheckpointRouteLine,
            latestCheckpointDecisionLine: latestCheckpointDecisionLine,
            latestCheckpointTaskLine: latestCheckpointTaskLine,
            latestCheckpointPressureLine: latestCheckpointPressureLine,
            latestCheckpointAuditLine: latestCheckpointAuditLine,
            latestCheckpointActiveKillSwitchesLine: latestCheckpointActiveKillSwitchesLine,
            latestCheckpointKillSwitchesLine: latestCheckpointKillSwitchesLine,
            latestCheckpointActionLine: latestCheckpointActionLine,
            latestCheckpointEBrainAnchor: latestCheckpointEBrainAnchor,
            latestEventID: latestHeadEvent?.id,
            latestEventSeq: latestHeadEvent?.seq,
            latestEventType: latestHeadEvent?.type,
            latestEventDetail: latestHeadEventDetail,
            openStepCount: openHeadSteps.count,
            openStepStatus: representativeOpenStep?.status,
            stalledStepCount: openHeadSteps.filter { $0.status == .stalled }.count,
            branchCount: branchCount,
            mergeableBranchCount: mergeableBranchCount,
            recoveryCount: recoveryCount,
            latestRecoveryAt: latestRecoveryAt,
            openStepID: representativeOpenStep?.id,
            openStepHeartbeatAt: representativeOpenStep?.heartbeatAt,
            openStepUpdatedAt: representativeOpenStep?.updatedAt,
            openStepTTLms: representativeOpenStep?.ttlMs,
            openStepRemainingMs: openStepRemainingMs,
            openStepIsHeartbeatOverdue: (openStepRemainingMs ?? 0) < 0
        )
    }

    @discardableResult
    private func updateSessionStatus(
        _ sessionId: String,
        status: DecisionSessionStatus,
        eventType: DecisionSessionEventType?,
        now: Date
    ) throws -> DecisionSession {
        let session = try getSession(sessionId)
        try execute(
            """
            UPDATE sessions
            SET status = ?, updated_at = ?
            WHERE id = ?;
            """,
            bindings: [
                .text(status.rawValue),
                .double(now.timeIntervalSince1970),
                .text(sessionId)
            ]
        )
        if let eventType {
            _ = try appendEvent(
                sessionId: sessionId,
                branchId: session.headBranchId,
                type: eventType,
                parentEventId: try latestEvent(sessionId: sessionId, branchId: session.headBranchId)?.id,
                payload: DecisionSessionPayloadSessionError(
                    kind: eventType.rawValue,
                    stepId: nil,
                    recoverable: true
                ),
                now: now
            )
        }
        return try getSession(sessionId)
    }

    private func timelineDetail(for event: DecisionSessionEvent) throws -> String {
        guard let data = try loadPayloadData(for: event) else {
            return event.type.rawValue
        }
        switch event.type {
        case .userMessage:
            let payload = try decoder.decode(DecisionSessionPayloadUserMessage.self, from: data)
            return payload.text
        case .assistantMessage:
            let payload = try decoder.decode(DecisionSessionPayloadAssistantMessage.self, from: data)
            return payload.summary ?? payload.text
        case .correctionAdded:
            let payload = try decoder.decode(DecisionSessionPayloadCorrection.self, from: data)
            return "Correction: \(payload.newText)"
        case .branchMerged:
            let payload = try decoder.decode(DecisionSessionPayloadBranchMerged.self, from: data)
            return DecisionSessionTimelinePresentationSupport.branchMergedDetail(
                sourceBranchID: payload.sourceBranchId,
                targetBranchID: payload.targetBranchId
            )
        case .toolCallStarted:
            let payload = try decoder.decode(DecisionSessionPayloadToolCallStarted.self, from: data)
            return DecisionSessionTimelinePresentationSupport.toolStartedDetail(
                tool: payload.tool
            )
        case .toolCallFinished:
            let payload = try decoder.decode(DecisionSessionPayloadToolCallFinished.self, from: data)
            return DecisionSessionTimelinePresentationSupport.toolFinishedDetail(
                resultSummary: payload.resultSummary
            )
        case .toolCallFailed:
            let payload = try decoder.decode(DecisionSessionPayloadToolCallFailed.self, from: data)
            return DecisionSessionTimelinePresentationSupport.toolFailedDetail(
                tool: payload.tool,
                errorCode: payload.errorCode
            )
        case .checkpointCreated:
            let payload = try decoder.decode(DecisionSessionPayloadCheckpointCreated.self, from: data)
            return DecisionSessionTimelinePresentationSupport.checkpointCreatedDetail(
                basedOnEventSeq: payload.basedOnEventSeq
            )
        case .stepStarted:
            let payload = try decoder.decode(DecisionSessionPayloadStepStarted.self, from: data)
            return DecisionSessionTimelinePresentationSupport.stepStartedDetail(
                stepID: payload.stepId
            )
        case .stepHeartbeat:
            let payload = try decoder.decode(DecisionSessionPayloadHeartbeat.self, from: data)
            return DecisionSessionTimelinePresentationSupport.heartbeatDetail(
                stepID: payload.stepId,
                progress: payload.progress
            )
        case .stepStalled:
            let payload = try decoder.decode(DecisionSessionPayloadStepStalled.self, from: data)
            return DecisionSessionTimelinePresentationSupport.stepStalledDetail(
                stepID: payload.stepId
            )
        case .stepRecovered:
            let payload = try decoder.decode(DecisionSessionPayloadStepStalled.self, from: data)
            return DecisionSessionTimelinePresentationSupport.stepRecoveredDetail(
                stepID: payload.stepId
            )
        case .sessionPaused:
            return DecisionSessionTimelinePresentationSupport.sessionPausedDetail
        case .sessionResumed:
            return DecisionSessionTimelinePresentationSupport.sessionResumedDetail
        case .sessionError:
            let payload = try decoder.decode(DecisionSessionPayloadSessionError.self, from: data)
            return DecisionSessionTimelinePresentationSupport.sessionErrorDetail(
                kind: payload.kind
            )
        case .sessionRecovered:
            let payload = try decoder.decode(DecisionSessionPayloadSessionRecovered.self, from: data)
            return DecisionSessionRecoveryPresentationSupport.checkpointEventDetail(
                sourceCheckpointID: payload.sourceCheckpointId
            )
        case .branchCreated:
            let payload = try decoder.decode(DecisionSessionPayloadBranchCreated.self, from: data)
            return DecisionSessionTimelinePresentationSupport.branchCreatedDetail(
                fromCheckpointID: payload.fromCheckpointId
            )
        }
    }

    private func mergedEventsFoldedIntoCheckpoint(
        sessionId: String,
        branchId: String,
        checkpoint: DecisionSessionCheckpoint?
    ) throws -> [DecisionSessionEvent] {
        guard let checkpoint, checkpoint.basedOnEventSeq > 0 else { return [] }
        let lowerBound: Int
        if let previousCheckpointId = checkpoint.previousCheckpointId,
           let previousCheckpoint = try? getCheckpoint(previousCheckpointId) {
            lowerBound = previousCheckpoint.basedOnEventSeq + 1
        } else {
            lowerBound = 1
        }
        guard checkpoint.basedOnEventSeq >= lowerBound else { return [] }
        return try listEvents(
            sessionId: sessionId,
            branchId: branchId,
            fromSeq: lowerBound,
            toSeq: checkpoint.basedOnEventSeq
        ).filter { $0.type == .branchMerged }
    }

    private func timelineMergeNotice(
        sessionId: String,
        targetBranchId: String,
        foldedMergeEvents: [DecisionSessionEvent],
        visibleMergeEvents: [DecisionSessionEvent]
    ) throws -> String? {
        let foldedSources = try mergeSourceBranchNames(
            sessionId: sessionId,
            mergeEvents: foldedMergeEvents
        )
        let visibleSources = try mergeSourceBranchNames(
            sessionId: sessionId,
            mergeEvents: visibleMergeEvents
        )

        guard foldedSources.isEmpty == false || visibleSources.isEmpty == false else {
            return nil
        }

        let branchDescriptor = try getBranch(targetBranchId).name
        if foldedSources.isEmpty == false {
            return DecisionSessionTimelinePresentationSupport.foldedMergeNotice(
                branchName: branchDescriptor,
                foldedSources: formatMergeSourceList(foldedSources),
                visibleSources: visibleSources.isEmpty ? nil : formatMergeSourceList(visibleSources)
            )
        }
        return DecisionSessionTimelinePresentationSupport.visibleMergeNotice(
            visibleSources: formatMergeSourceList(visibleSources)
        )
    }

    private func mergeSourceBranchNames(
        sessionId: String,
        mergeEvents: [DecisionSessionEvent]
    ) throws -> [String] {
        let names = try mergeEvents.compactMap { event -> String? in
            guard let data = try loadPayloadData(for: event) else { return nil }
            let payload = try decoder.decode(DecisionSessionPayloadBranchMerged.self, from: data)
            if let branch = try? getBranch(payload.sourceBranchId), branch.sessionId == sessionId {
                return branch.name
            }
            return payload.sourceBranchId
        }
        return Array(NSOrderedSet(array: names)) as? [String] ?? names
    }

    private func formatMergeSourceList(_ sources: [String]) -> String {
        switch sources.count {
        case 0:
            return "unknown branches"
        case 1:
            return sources[0]
        case 2:
            return "\(sources[0]) and \(sources[1])"
        default:
            let preview = sources.prefix(2).joined(separator: ", ")
            return "\(preview), and \(sources.count - 2) more branches"
        }
    }

    private func remappedPayloadData(
        for exportedEvent: DecisionSessionExportEventRecord,
        branchMap: [String: String],
        checkpointMap: [String: String],
        eventMap: [String: String],
        stepMap: [String: String]
    ) throws -> Data? {
        guard let payloadBase64 = exportedEvent.payloadBase64,
              let payloadData = Data(base64Encoded: payloadBase64) else {
            return nil
        }

        switch exportedEvent.event.type {
        case .userMessage,
             .assistantMessage,
             .toolCallStarted,
             .toolCallFinished,
             .toolCallFailed,
             .sessionPaused,
             .sessionResumed:
            return payloadData
        case .correctionAdded:
            var payload = try decoder.decode(DecisionSessionPayloadCorrection.self, from: payloadData)
            payload = DecisionSessionPayloadCorrection(
                targetEventId: eventMap[payload.targetEventId] ?? payload.targetEventId,
                mode: payload.mode,
                newText: payload.newText,
                reason: payload.reason
            )
            return try encoder.encode(payload)
        case .branchMerged:
            var payload = try decoder.decode(DecisionSessionPayloadBranchMerged.self, from: payloadData)
            payload = DecisionSessionPayloadBranchMerged(
                sourceBranchId: branchMap[payload.sourceBranchId] ?? payload.sourceBranchId,
                targetBranchId: branchMap[payload.targetBranchId] ?? payload.targetBranchId,
                reason: payload.reason
            )
            return try encoder.encode(payload)
        case .checkpointCreated:
            var payload = try decoder.decode(DecisionSessionPayloadCheckpointCreated.self, from: payloadData)
            payload = DecisionSessionPayloadCheckpointCreated(
                checkpointId: checkpointMap[payload.checkpointId] ?? payload.checkpointId,
                basedOnEventSeq: payload.basedOnEventSeq
            )
            return try encoder.encode(payload)
        case .stepStarted:
            var payload = try decoder.decode(DecisionSessionPayloadStepStarted.self, from: payloadData)
            payload = DecisionSessionPayloadStepStarted(
                stepId: stepMap[payload.stepId] ?? payload.stepId,
                status: payload.status,
                ttlMs: payload.ttlMs
            )
            return try encoder.encode(payload)
        case .stepHeartbeat:
            var payload = try decoder.decode(DecisionSessionPayloadHeartbeat.self, from: payloadData)
            payload = DecisionSessionPayloadHeartbeat(
                stepId: stepMap[payload.stepId] ?? payload.stepId,
                progress: payload.progress,
                status: payload.status
            )
            return try encoder.encode(payload)
        case .stepStalled, .stepRecovered:
            var payload = try decoder.decode(DecisionSessionPayloadStepStalled.self, from: payloadData)
            payload = DecisionSessionPayloadStepStalled(
                stepId: stepMap[payload.stepId] ?? payload.stepId,
                errorCode: payload.errorCode
            )
            return try encoder.encode(payload)
        case .sessionError:
            var payload = try decoder.decode(DecisionSessionPayloadSessionError.self, from: payloadData)
            payload = DecisionSessionPayloadSessionError(
                kind: payload.kind,
                stepId: payload.stepId.flatMap { stepMap[$0] } ?? payload.stepId,
                recoverable: payload.recoverable
            )
            return try encoder.encode(payload)
        case .sessionRecovered:
            var payload = try decoder.decode(DecisionSessionPayloadSessionRecovered.self, from: payloadData)
            payload = DecisionSessionPayloadSessionRecovered(
                sourceCheckpointId: payload.sourceCheckpointId.flatMap { checkpointMap[$0] } ?? payload.sourceCheckpointId,
                failedStepIds: payload.failedStepIds.map { stepMap[$0] ?? $0 },
                sourceBranchId: branchMap[payload.sourceBranchId] ?? payload.sourceBranchId
            )
            return try encoder.encode(payload)
        case .branchCreated:
            var payload = try decoder.decode(DecisionSessionPayloadBranchCreated.self, from: payloadData)
            payload = DecisionSessionPayloadBranchCreated(
                fromCheckpointId: payload.fromCheckpointId.flatMap { checkpointMap[$0] } ?? payload.fromCheckpointId,
                branchId: branchMap[payload.branchId] ?? payload.branchId,
                reason: payload.reason
            )
            return try encoder.encode(payload)
        }
    }

    private func importedEventHash(
        sessionId: String,
        branchId: String,
        basedOnEventSeq: Int
    ) throws -> String {
        let latestHash = try querySingleValue(
            """
            SELECT record_hash
            FROM events
            WHERE session_id = ? AND branch_id = ? AND seq <= ?
            ORDER BY seq DESC, id DESC
            LIMIT 1;
            """,
            bindings: [
                .text(sessionId),
                .text(branchId),
                .int(basedOnEventSeq)
            ],
            map: { try $0.text(named: "record_hash") }
        )
        return latestHash ?? Self.sha256("empty-events")
    }

    private func getBranch(_ branchId: String) throws -> DecisionSessionBranch {
        let branch = try querySingleValue(
            """
            SELECT id, session_id, parent_branch_id, base_checkpoint_id, name, created_at, status
            FROM branches
            WHERE id = ?;
            """,
            bindings: [.text(branchId)],
            map: decodeBranch(row:)
        )
        guard let branch else {
            throw DecisionSessionEngineError.branchNotFound("No branch exists for \(branchId).")
        }
        return branch
    }

    private func getCheckpoint(_ checkpointId: String) throws -> DecisionSessionCheckpoint {
        let checkpoint = try queryOptionalCheckpoint(
            """
            SELECT id, session_id, branch_id, based_on_event_seq, created_at, summary_json, runtime_state_json,
                   event_hash, previous_checkpoint_hash, previous_checkpoint_id, checkpoint_hash
            FROM checkpoints
            WHERE id = ?;
            """,
            bindings: [.text(checkpointId)]
        )
        guard let checkpoint else {
            throw DecisionSessionEngineError.checkpointNotFound("No checkpoint exists for \(checkpointId).")
        }
        return checkpoint
    }

    private func getStep(_ stepId: String) throws -> DecisionSessionStep {
        let step = try querySingleValue(
            """
            SELECT id, session_id, branch_id, start_event_seq, status, started_at, updated_at, ttl_ms, heartbeat_at, error_code
            FROM steps
            WHERE id = ?;
            """,
            bindings: [.text(stepId)],
            map: decodeStep(row:)
        )
        guard let step else {
            throw DecisionSessionEngineError.stepNotFound("No step exists for \(stepId).")
        }
        return step
    }

    private func latestEvent(sessionId: String, branchId: String) throws -> DecisionSessionEvent? {
        try querySingleValue(
            """
            SELECT id, session_id, branch_id, seq, created_at, type, parent_event_id, payload_ref, payload_hash, record_hash
            FROM events
            WHERE session_id = ? AND branch_id = ?
            ORDER BY seq DESC
            LIMIT 1;
            """,
            bindings: [.text(sessionId), .text(branchId)],
            map: decodeEvent(row:)
        )
    }

    private func persistPayload(data: Data, hash: String) throws -> String {
        let fileName = "\(hash).json"
        let url = blobsDirectoryURL.appendingPathComponent(fileName, isDirectory: false)
        if !FileManager.default.fileExists(atPath: url.path) {
            try data.write(to: url, options: .atomic)
        }
        return fileName
    }

    private func defaultTTL(for status: DecisionSessionStepStatus) -> Int {
        switch status {
        case .planning:
            configuration.defaultPlanningTTL
        case .acting, .waitingTool:
            configuration.defaultToolTTL
        case .writing:
            configuration.defaultWritingTTL
        case .stalled, .failed, .completed:
            configuration.defaultToolTTL
        }
    }

    private func count(_ table: String, whereClause: String? = nil) throws -> Int {
        let sql = if let whereClause {
            "SELECT COUNT(*) AS count_value FROM \(table) WHERE \(whereClause);"
        } else {
            "SELECT COUNT(*) AS count_value FROM \(table);"
        }
        let value = try querySingleValue(
            sql,
            bindings: [],
            map: { try Int($0.int64(named: "count_value")) }
        )
        return value ?? 0
    }

    private func countRows(_ sql: String, bindings: [SQLiteBinding]) throws -> Int {
        let value = try querySingleValue(
            sql,
            bindings: bindings,
            map: { try Int($0.int64(named: "count_value")) }
        )
        return value ?? 0
    }

    private static func openDatabase(at databaseURL: URL) throws -> OpaquePointer? {
        var connection: OpaquePointer?
        let result = sqlite3_open_v2(
            databaseURL.path,
            &connection,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard result == SQLITE_OK, let connection else {
            throw DecisionSessionEngineError.sqlite(message: "Unable to open session engine database at \(databaseURL.path).")
        }
        try exec("PRAGMA journal_mode=WAL;", on: connection)
        try exec("PRAGMA synchronous=NORMAL;", on: connection)
        try exec("PRAGMA foreign_keys=ON;", on: connection)
        return connection
    }

    private static func prepareSchema(on db: OpaquePointer?) throws {
        try exec(
            """
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL,
                status TEXT NOT NULL,
                head_branch_id TEXT NOT NULL,
                latest_checkpoint_id TEXT
            );
            """,
            on: db
        )
        try exec(
            """
            CREATE TABLE IF NOT EXISTS branches (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                parent_branch_id TEXT,
                base_checkpoint_id TEXT,
                name TEXT NOT NULL,
                created_at REAL NOT NULL,
                status TEXT NOT NULL
            );
            """,
            on: db
        )
        try exec(
            """
            CREATE TABLE IF NOT EXISTS events (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                branch_id TEXT NOT NULL,
                seq INTEGER NOT NULL,
                created_at REAL NOT NULL,
                type TEXT NOT NULL,
                parent_event_id TEXT,
                payload_ref TEXT,
                payload_hash TEXT NOT NULL,
                record_hash TEXT NOT NULL,
                UNIQUE(branch_id, seq)
            );
            """,
            on: db
        )
        try exec(
            """
            CREATE TABLE IF NOT EXISTS checkpoints (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                branch_id TEXT NOT NULL,
                based_on_event_seq INTEGER NOT NULL,
                created_at REAL NOT NULL,
                summary_json TEXT NOT NULL,
                runtime_state_json TEXT NOT NULL,
                event_hash TEXT NOT NULL,
                previous_checkpoint_hash TEXT,
                previous_checkpoint_id TEXT,
                checkpoint_hash TEXT NOT NULL
            );
            """,
            on: db
        )
        try exec(
            """
            CREATE TABLE IF NOT EXISTS steps (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                branch_id TEXT NOT NULL,
                start_event_seq INTEGER NOT NULL,
                status TEXT NOT NULL,
                started_at REAL NOT NULL,
                updated_at REAL NOT NULL,
                ttl_ms INTEGER NOT NULL,
                heartbeat_at REAL,
                error_code TEXT
            );
            """,
            on: db
        )
        try exec("CREATE INDEX IF NOT EXISTS idx_events_session_branch_seq ON events(session_id, branch_id, seq);", on: db)
        try exec("CREATE INDEX IF NOT EXISTS idx_checkpoints_session_branch_created ON checkpoints(session_id, branch_id, created_at);", on: db)
        try exec("CREATE INDEX IF NOT EXISTS idx_steps_session_branch_status ON steps(session_id, branch_id, status);", on: db)
    }

    private static func exec(_ sql: String, on db: OpaquePointer?) throws {
        guard let db else {
            throw DecisionSessionEngineError.sqlite(message: "Session engine database is not open.")
        }
        let result = sqlite3_exec(db, sql, nil, nil, nil)
        guard result == SQLITE_OK else {
            let description = String(cString: sqlite3_errmsg(db))
            throw DecisionSessionEngineError.sqlite(message: "\(sql) (\(description))")
        }
    }

    private func inTransaction<T>(_ body: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE TRANSACTION;", bindings: [])
        do {
            let value = try body()
            try execute("COMMIT TRANSACTION;", bindings: [])
            return value
        } catch {
            try? execute("ROLLBACK TRANSACTION;", bindings: [])
            throw error
        }
    }

    private func execute(_ sql: String, bindings: [SQLiteBinding]) throws {
        guard let db else {
            throw DecisionSessionEngineError.sqlite(message: "Session engine database is not open.")
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw sqliteError(message: sql)
        }
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)
        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE || result == SQLITE_ROW else {
            throw sqliteError(message: sql)
        }
    }

    private func querySingleValue<T>(
        _ sql: String,
        bindings: [SQLiteBinding],
        map: (SQLiteRow) throws -> T
    ) throws -> T? {
        let rows = try queryRows(sql, bindings: bindings, map: map)
        return rows.first
    }

    private func queryOptionalCheckpoint(_ sql: String, bindings: [SQLiteBinding]) throws -> DecisionSessionCheckpoint? {
        try querySingleValue(sql, bindings: bindings, map: decodeCheckpoint(row:))
    }

    private func queryRows<T>(
        _ sql: String,
        bindings: [SQLiteBinding],
        map: (SQLiteRow) throws -> T
    ) throws -> [T] {
        guard let db else {
            throw DecisionSessionEngineError.sqlite(message: "Session engine database is not open.")
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw sqliteError(message: sql)
        }
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)
        var rows: [T] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_ROW {
                let row = SQLiteRow(statement: statement)
                rows.append(try map(row))
            } else if result == SQLITE_DONE {
                break
            } else {
                throw sqliteError(message: sql)
            }
        }
        return rows
    }

    private func bind(_ bindings: [SQLiteBinding], to statement: OpaquePointer?) throws {
        for (index, binding) in bindings.enumerated() {
            let parameterIndex = Int32(index + 1)
            let result: Int32
            switch binding {
            case let .text(value):
                result = sqlite3_bind_text(statement, parameterIndex, value, -1, Self.sqliteTransient)
            case let .int(value):
                result = sqlite3_bind_int64(statement, parameterIndex, Int64(value))
            case let .double(value):
                result = sqlite3_bind_double(statement, parameterIndex, value)
            case .null:
                result = sqlite3_bind_null(statement, parameterIndex)
            }
            guard result == SQLITE_OK else {
                throw sqliteError(message: "Failed to bind parameter \(index) for session engine statement.")
            }
        }
    }

    private func decodeSession(row: SQLiteRow) throws -> DecisionSession {
        let statusRaw = try row.text(named: "status")
        guard let status = DecisionSessionStatus(rawValue: statusRaw) else {
            throw DecisionSessionEngineError.invalidState("Invalid session status.")
        }
        return DecisionSession(
            id: try row.text(named: "id"),
            title: try row.text(named: "title"),
            createdAt: Date(timeIntervalSince1970: try row.double(named: "created_at")),
            updatedAt: Date(timeIntervalSince1970: try row.double(named: "updated_at")),
            status: status,
            headBranchId: try row.text(named: "head_branch_id"),
            latestCheckpointId: row.optionalText(named: "latest_checkpoint_id")
        )
    }

    private func decodeBranch(row: SQLiteRow) throws -> DecisionSessionBranch {
        let statusRaw = try row.text(named: "status")
        guard let status = DecisionSessionBranchStatus(rawValue: statusRaw) else {
            throw DecisionSessionEngineError.invalidState("Invalid branch status.")
        }
        return DecisionSessionBranch(
            id: try row.text(named: "id"),
            sessionId: try row.text(named: "session_id"),
            parentBranchId: row.optionalText(named: "parent_branch_id"),
            baseCheckpointId: row.optionalText(named: "base_checkpoint_id"),
            name: try row.text(named: "name"),
            createdAt: Date(timeIntervalSince1970: try row.double(named: "created_at")),
            status: status
        )
    }

    private func decodeEvent(row: SQLiteRow) throws -> DecisionSessionEvent {
        let typeRaw = try row.text(named: "type")
        guard let type = DecisionSessionEventType(rawValue: typeRaw) else {
            throw DecisionSessionEngineError.invalidState("Invalid event type.")
        }
        return DecisionSessionEvent(
            id: try row.text(named: "id"),
            sessionId: try row.text(named: "session_id"),
            branchId: try row.text(named: "branch_id"),
            seq: Int(try row.int64(named: "seq")),
            createdAt: Date(timeIntervalSince1970: try row.double(named: "created_at")),
            type: type,
            parentEventId: row.optionalText(named: "parent_event_id"),
            payloadRef: row.optionalText(named: "payload_ref"),
            payloadHash: try row.text(named: "payload_hash"),
            recordHash: try row.text(named: "record_hash")
        )
    }

    private func decodeCheckpoint(row: SQLiteRow) throws -> DecisionSessionCheckpoint {
        let summary = try decoder.decode(
            DecisionSessionCheckpointSummary.self,
            from: Data((try row.text(named: "summary_json")).utf8)
        )
        let runtimeState = try decoder.decode(
            DecisionSessionCheckpointRuntimeState.self,
            from: Data((try row.text(named: "runtime_state_json")).utf8)
        )
        return DecisionSessionCheckpoint(
            id: try row.text(named: "id"),
            sessionId: try row.text(named: "session_id"),
            branchId: try row.text(named: "branch_id"),
            basedOnEventSeq: Int(try row.int64(named: "based_on_event_seq")),
            createdAt: Date(timeIntervalSince1970: try row.double(named: "created_at")),
            summary: summary,
            runtimeState: runtimeState,
            integrity: DecisionSessionCheckpointIntegrity(
                eventHash: try row.text(named: "event_hash"),
                previousCheckpointHash: row.optionalText(named: "previous_checkpoint_hash")
            ),
            previousCheckpointId: row.optionalText(named: "previous_checkpoint_id"),
            checkpointHash: try row.text(named: "checkpoint_hash")
        )
    }

    private func decodeStep(row: SQLiteRow) throws -> DecisionSessionStep {
        let statusRaw = try row.text(named: "status")
        guard let status = DecisionSessionStepStatus(rawValue: statusRaw) else {
            throw DecisionSessionEngineError.invalidState("Invalid step status.")
        }
        return DecisionSessionStep(
            id: try row.text(named: "id"),
            sessionId: try row.text(named: "session_id"),
            branchId: try row.text(named: "branch_id"),
            startEventSeq: Int(try row.int64(named: "start_event_seq")),
            status: status,
            startedAt: Date(timeIntervalSince1970: try row.double(named: "started_at")),
            updatedAt: Date(timeIntervalSince1970: try row.double(named: "updated_at")),
            ttlMs: Int(try row.int64(named: "ttl_ms")),
            heartbeatAt: row.optionalDouble(named: "heartbeat_at").map(Date.init(timeIntervalSince1970:)),
            errorCode: row.optionalText(named: "error_code")
        )
    }

    private func encodeJSONString<Value: Encodable>(_ value: Value) throws -> String {
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw DecisionSessionEngineError.invalidState("Unable to encode session engine JSON payload.")
        }
        return string
    }

    private func sqliteError(message: String) -> DecisionSessionEngineError {
        let description = if let db {
            String(cString: sqlite3_errmsg(db))
        } else {
            "Unknown SQLite error."
        }
        return .sqlite(message: "\(message) (\(description))")
    }

    private static func ensureBaseDirectory(baseDirectoryURL: URL?) throws -> URL {
        let baseDirectory: URL
        if let baseDirectoryURL {
            baseDirectory = baseDirectoryURL
        } else if let containerURL = SharedContainer.containerURL {
            baseDirectory = containerURL
        } else {
            baseDirectory = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("Before", isDirectory: true)
        }

        let root = baseDirectory.appendingPathComponent("session_engine", isDirectory: true)
        try ensureDirectory(root)
        return root
    }

    private static func ensureDirectory(_ url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
    }

    private func clearDirectoryContents(at url: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return }

        for entry in try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil
        ) {
            try fileManager.removeItem(at: entry)
        }
    }

    private static func makeIdentifier(prefix: String) -> String {
        "\(prefix)_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())"
    }

    private static func safeFileComponent(_ value: String) -> String {
        let cleaned = value
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return cleaned.isEmpty ? "session" : cleaned
    }

    private static func fileTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    private static func importedSessionTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return "Imported Session" }
        if trimmed.hasSuffix("(Imported)") {
            return trimmed
        }
        return "\(trimmed) (Imported)"
    }

    private static func branchSort(lhs: DecisionSessionBranch, rhs: DecisionSessionBranch) -> Bool {
        let lhsIsRoot = lhs.parentBranchId == nil
        let rhsIsRoot = rhs.parentBranchId == nil
        if lhsIsRoot != rhsIsRoot {
            return lhsIsRoot && !rhsIsRoot
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        return lhs.id < rhs.id
    }

    private static func checkpointSort(lhs: DecisionSessionCheckpoint, rhs: DecisionSessionCheckpoint) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        if lhs.basedOnEventSeq != rhs.basedOnEventSeq {
            return lhs.basedOnEventSeq < rhs.basedOnEventSeq
        }
        return lhs.id < rhs.id
    }

    private static func stepSort(lhs: DecisionSessionStep, rhs: DecisionSessionStep) -> Bool {
        if lhs.startedAt != rhs.startedAt {
            return lhs.startedAt < rhs.startedAt
        }
        if lhs.startEventSeq != rhs.startEventSeq {
            return lhs.startEventSeq < rhs.startEventSeq
        }
        return lhs.id < rhs.id
    }

    private static func sha256(_ value: String) -> String {
        sha256(Data(value.utf8))
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}

private enum SQLiteBinding {
    case text(String)
    case int(Int)
    case double(Double)
    case null

    static func nullableText(_ value: String?) -> SQLiteBinding {
        guard let value else { return .null }
        return .text(value)
    }
}

private struct SQLiteRow {
    let statement: OpaquePointer?

    func text(named name: String) throws -> String {
        guard let value = optionalText(named: name) else {
            throw DecisionSessionEngineError.invalidState("Missing text column \(name).")
        }
        return value
    }

    func optionalText(named name: String) -> String? {
        let index = columnIndex(named: name)
        guard index >= 0, let value = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: value)
    }

    func int64(named name: String) throws -> Int64 {
        let index = columnIndex(named: name)
        guard index >= 0 else {
            throw DecisionSessionEngineError.invalidState("Missing int column \(name).")
        }
        return sqlite3_column_int64(statement, index)
    }

    func double(named name: String) throws -> Double {
        let index = columnIndex(named: name)
        guard index >= 0 else {
            throw DecisionSessionEngineError.invalidState("Missing double column \(name).")
        }
        return sqlite3_column_double(statement, index)
    }

    func optionalDouble(named name: String) -> Double? {
        let index = columnIndex(named: name)
        guard index >= 0, sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return sqlite3_column_double(statement, index)
    }

    private func columnIndex(named name: String) -> Int32 {
        let count = sqlite3_column_count(statement)
        for index in 0..<count {
            guard let rawName = sqlite3_column_name(statement, index) else { continue }
            if String(cString: rawName) == name {
                return index
            }
        }
        return -1
    }
}
