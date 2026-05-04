import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore
import BASWorldPrior

public struct BASEBrainTurnResult: Codable, Equatable, Sendable {
    public var deviceState: BASDeviceState
    public var budgetFrame: BASBudgetFrame
    public var wakeIntent: BASWakeIntent
    public var vitalState: BASVitalState
    public var runLease: BASRunLease?
    public var emergencyBrake: BASEmergencyBrake
    public var sovereignVerdict: BASSovereignVerdict?
    public var sovereignCommitTokens: [BASSovereignCommitToken]
    public var sovereignWarrants: [BASSovereignWarrant]
    public var sovereignLock: BASSovereignLock?
    public var quarantineRecords: [BASQuarantineRecord]
    public var sovereignAuditEntry: BASSovereignAuditEntry?
    public var sovereignActuationCommands: [BASSovereignActuationCommand]
    public var sovereignExecutionReceipts: [BASSovereignExecutionReceipt]
    public var policyLineage: BASRuntimePolicyLineage?
    public var recoveryDisposition: BASRecoveryDisposition?
    public var hostConstitution: BASHostConstitution?
    public var hostConstitutionVault: BASHostConstitutionVault?
    public var hostVersionTree: BASHostVersionTree?
    public var hostForgetRequest: BASForgetRequest?
    public var hostContext: BASHostProfile
    public var contextFrame: BASContextFrame
    public var decomposeFrame: BASDecomposeFrame
    public var memoryBundle: BASMemoryBundle
    public var thoughtFrame: BASThoughtFrame
    public var thoughtFold: BASThoughtFold
    public var triScores: [BASTriSelfScore]
    public var mergedChoice: BASMergedChoice
    public var riskCard: BASRiskCard
    public var actionPermit: BASActionPermit
    public var riskDecisionPackage: BASRiskDecisionPackage?
    public var hostGateValue: Double
    public var renderedOutput: BASRenderedOutput
    public var updateTickets: [BASUpdateTicket]
    public var experienceCandidates: [BASExperienceCandidate]
    public var workflowCandidates: [BASWorkflowCandidate]
    public var guardTemplateCandidates: [BASGuardTemplateCandidate]
    public var biasRecords: [BASBiasRecord]
    public var riskPatternCandidates: [BASRiskPatternCandidate]
    public var learningExportBundles: [BASLearningExportBundle]
    public var shadowTrialRecords: [BASShadowTrialRecord]
    public var versionDeltas: [BASVersionDelta]
    public var retractionOrders: [BASRetractionOrder]
    public var evolutionSeals: [BASEvolutionSeal]
    public var runtimeTrace: BASRuntimeTrace

    /// M578 (chapter 一百五十三 — 一次性解决掉) — 4 typed
    /// projection fields exposed directly on turn result for
    /// downstream observability (chapter 一百五十一 doctrine
    /// metrics + future analyses). Each field is independently
    /// `Codable` (all `BASSchemaVersioned`). Default `nil` for
    /// backward-compat.
    ///
    /// Why these 4 specifically (not the full
    /// `BASAuditObservationProjections` bag): the bag has 60+
    /// fields with ~20 non-`Codable` aggregate sub-types making
    /// full Codable refactor out-of-scope. These 4 cover the
    /// doctrine metrics that previously hit synthesis ceiling
    /// in chapter 一百五十二.
    public var kunlunAxisAlignment: BASAxisAlignment?
    public var humanAnchorSignal: BASHumanAnchorSignal?
    public var abyssalPressure: BASAbyssalPressure?
    public var unknownReserve: BASUnknownReserve?

    public init(
        deviceState: BASDeviceState,
        budgetFrame: BASBudgetFrame,
        wakeIntent: BASWakeIntent,
        vitalState: BASVitalState,
        runLease: BASRunLease? = nil,
        emergencyBrake: BASEmergencyBrake = BASEmergencyBrake(
            brakeLevel: .none,
            reasonCodes: []
        ),
        sovereignVerdict: BASSovereignVerdict? = nil,
        sovereignCommitTokens: [BASSovereignCommitToken] = [],
        sovereignWarrants: [BASSovereignWarrant] = [],
        sovereignLock: BASSovereignLock? = nil,
        quarantineRecords: [BASQuarantineRecord] = [],
        sovereignAuditEntry: BASSovereignAuditEntry? = nil,
        sovereignActuationCommands: [BASSovereignActuationCommand] = [],
        sovereignExecutionReceipts: [BASSovereignExecutionReceipt] = [],
        policyLineage: BASRuntimePolicyLineage? = nil,
        recoveryDisposition: BASRecoveryDisposition? = nil,
        hostConstitution: BASHostConstitution? = nil,
        hostConstitutionVault: BASHostConstitutionVault? = nil,
        hostVersionTree: BASHostVersionTree? = nil,
        hostForgetRequest: BASForgetRequest? = nil,
        hostContext: BASHostProfile,
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame,
        memoryBundle: BASMemoryBundle,
        thoughtFrame: BASThoughtFrame,
        thoughtFold: BASThoughtFold,
        triScores: [BASTriSelfScore],
        mergedChoice: BASMergedChoice,
        riskCard: BASRiskCard,
        actionPermit: BASActionPermit,
        riskDecisionPackage: BASRiskDecisionPackage? = nil,
        hostGateValue: Double,
        renderedOutput: BASRenderedOutput,
        updateTickets: [BASUpdateTicket],
        experienceCandidates: [BASExperienceCandidate] = [],
        workflowCandidates: [BASWorkflowCandidate] = [],
        guardTemplateCandidates: [BASGuardTemplateCandidate] = [],
        biasRecords: [BASBiasRecord] = [],
        riskPatternCandidates: [BASRiskPatternCandidate] = [],
        learningExportBundles: [BASLearningExportBundle] = [],
        shadowTrialRecords: [BASShadowTrialRecord] = [],
        versionDeltas: [BASVersionDelta] = [],
        retractionOrders: [BASRetractionOrder] = [],
        evolutionSeals: [BASEvolutionSeal] = [],
        runtimeTrace: BASRuntimeTrace,
        kunlunAxisAlignment: BASAxisAlignment? = nil,
        humanAnchorSignal: BASHumanAnchorSignal? = nil,
        abyssalPressure: BASAbyssalPressure? = nil,
        unknownReserve: BASUnknownReserve? = nil
    ) {
        self.deviceState = deviceState
        self.budgetFrame = budgetFrame
        self.wakeIntent = wakeIntent
        self.vitalState = vitalState
        self.runLease = runLease
        self.emergencyBrake = emergencyBrake
        self.sovereignVerdict = sovereignVerdict
        self.sovereignCommitTokens = sovereignCommitTokens
        self.sovereignWarrants = sovereignWarrants
        self.sovereignLock = sovereignLock
        self.quarantineRecords = quarantineRecords
        self.sovereignAuditEntry = sovereignAuditEntry
        self.sovereignActuationCommands = sovereignActuationCommands
        self.sovereignExecutionReceipts = sovereignExecutionReceipts
        self.policyLineage = policyLineage
        self.recoveryDisposition = recoveryDisposition
        self.hostConstitution = hostConstitution
        self.hostConstitutionVault = hostConstitutionVault
        self.hostVersionTree = hostVersionTree
        self.hostForgetRequest = hostForgetRequest
        self.hostContext = hostContext
        self.contextFrame = contextFrame
        self.decomposeFrame = decomposeFrame
        self.memoryBundle = memoryBundle
        self.thoughtFrame = thoughtFrame
        self.thoughtFold = thoughtFold
        self.triScores = triScores
        self.mergedChoice = mergedChoice
        self.riskCard = riskCard
        self.actionPermit = actionPermit
        self.riskDecisionPackage = riskDecisionPackage
        self.hostGateValue = hostGateValue
        self.renderedOutput = renderedOutput
        self.updateTickets = updateTickets
        self.experienceCandidates = experienceCandidates
        self.workflowCandidates = workflowCandidates
        self.guardTemplateCandidates = guardTemplateCandidates
        self.biasRecords = biasRecords
        self.riskPatternCandidates = riskPatternCandidates
        self.learningExportBundles = learningExportBundles
        self.shadowTrialRecords = shadowTrialRecords
        self.versionDeltas = versionDeltas
        self.retractionOrders = retractionOrders
        self.evolutionSeals = evolutionSeals
        self.runtimeTrace = runtimeTrace
        self.kunlunAxisAlignment = kunlunAxisAlignment
        self.humanAnchorSignal = humanAnchorSignal
        self.abyssalPressure = abyssalPressure
        self.unknownReserve = unknownReserve
    }

    private enum CodingKeys: String, CodingKey {
        case deviceState
        case budgetFrame
        case wakeIntent
        case vitalState
        case runLease
        case emergencyBrake
        case sovereignVerdict
        case sovereignCommitTokens
        case sovereignWarrants
        case sovereignLock
        case quarantineRecords
        case sovereignAuditEntry
        case sovereignActuationCommands
        case sovereignExecutionReceipts
        case policyLineage
        case recoveryDisposition
        case hostConstitution
        case hostConstitutionVault
        case hostVersionTree
        case hostForgetRequest
        case hostContext
        case contextFrame
        case decomposeFrame
        case memoryBundle
        case thoughtFrame
        case thoughtFold
        case triScores
        case mergedChoice
        case riskCard
        case actionPermit
        case riskDecisionPackage
        case hostGateValue
        case renderedOutput
        case updateTickets
        case experienceCandidates
        case workflowCandidates
        case guardTemplateCandidates
        case biasRecords
        case riskPatternCandidates
        case learningExportBundles
        case shadowTrialRecords
        case versionDeltas
        case retractionOrders
        case evolutionSeals
        case runtimeTrace
        case kunlunAxisAlignment
        case humanAnchorSignal
        case abyssalPressure
        case unknownReserve
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceState = try container.decode(BASDeviceState.self, forKey: .deviceState)
        budgetFrame = try container.decode(BASBudgetFrame.self, forKey: .budgetFrame)
        hostContext = try container.decode(BASHostProfile.self, forKey: .hostContext)
        contextFrame = try container.decode(BASContextFrame.self, forKey: .contextFrame)
        decomposeFrame = try container.decode(BASDecomposeFrame.self, forKey: .decomposeFrame)
        memoryBundle = try container.decode(BASMemoryBundle.self, forKey: .memoryBundle)
        thoughtFrame = try container.decode(BASThoughtFrame.self, forKey: .thoughtFrame)
        thoughtFold = try container.decode(BASThoughtFold.self, forKey: .thoughtFold)
        triScores = try container.decode([BASTriSelfScore].self, forKey: .triScores)
        mergedChoice = try container.decode(BASMergedChoice.self, forKey: .mergedChoice)
        riskCard = try container.decode(BASRiskCard.self, forKey: .riskCard)
        actionPermit = try container.decode(BASActionPermit.self, forKey: .actionPermit)
        riskDecisionPackage = try container.decodeIfPresent(
            BASRiskDecisionPackage.self,
            forKey: .riskDecisionPackage
        )
        hostGateValue = try container.decode(Double.self, forKey: .hostGateValue)
        renderedOutput = try container.decode(BASRenderedOutput.self, forKey: .renderedOutput)
        updateTickets = try container.decode([BASUpdateTicket].self, forKey: .updateTickets)
        experienceCandidates = try container.decodeIfPresent(
            [BASExperienceCandidate].self,
            forKey: .experienceCandidates
        ) ?? []
        workflowCandidates = try container.decodeIfPresent(
            [BASWorkflowCandidate].self,
            forKey: .workflowCandidates
        ) ?? []
        guardTemplateCandidates = try container.decodeIfPresent(
            [BASGuardTemplateCandidate].self,
            forKey: .guardTemplateCandidates
        ) ?? []
        biasRecords = try container.decodeIfPresent(
            [BASBiasRecord].self,
            forKey: .biasRecords
        ) ?? []
        riskPatternCandidates = try container.decodeIfPresent(
            [BASRiskPatternCandidate].self,
            forKey: .riskPatternCandidates
        ) ?? []
        learningExportBundles = try container.decodeIfPresent(
            [BASLearningExportBundle].self,
            forKey: .learningExportBundles
        ) ?? []
        shadowTrialRecords = try container.decodeIfPresent(
            [BASShadowTrialRecord].self,
            forKey: .shadowTrialRecords
        ) ?? []
        versionDeltas = try container.decodeIfPresent(
            [BASVersionDelta].self,
            forKey: .versionDeltas
        ) ?? []
        retractionOrders = try container.decodeIfPresent(
            [BASRetractionOrder].self,
            forKey: .retractionOrders
        ) ?? []
        evolutionSeals = try container.decodeIfPresent(
            [BASEvolutionSeal].self,
            forKey: .evolutionSeals
        ) ?? []
        runtimeTrace = try container.decode(BASRuntimeTrace.self, forKey: .runtimeTrace)
        kunlunAxisAlignment = try container.decodeIfPresent(
            BASAxisAlignment.self, forKey: .kunlunAxisAlignment)
        humanAnchorSignal = try container.decodeIfPresent(
            BASHumanAnchorSignal.self, forKey: .humanAnchorSignal)
        abyssalPressure = try container.decodeIfPresent(
            BASAbyssalPressure.self, forKey: .abyssalPressure)
        unknownReserve = try container.decodeIfPresent(
            BASUnknownReserve.self, forKey: .unknownReserve)
        wakeIntent = try container.decodeIfPresent(BASWakeIntent.self, forKey: .wakeIntent)
            ?? BASEBrainTurnResult.defaultWakeIntent(for: budgetFrame)
        vitalState = try container.decodeIfPresent(BASVitalState.self, forKey: .vitalState)
            ?? BASEBrainTurnResult.defaultVitalState(
                deviceState: deviceState,
                budgetFrame: budgetFrame
            )
        runLease = try container.decodeIfPresent(BASRunLease.self, forKey: .runLease)
        emergencyBrake = try container.decodeIfPresent(BASEmergencyBrake.self, forKey: .emergencyBrake)
            ?? BASEmergencyBrake(brakeLevel: .none, reasonCodes: [])
        sovereignVerdict = try container.decodeIfPresent(
            BASSovereignVerdict.self,
            forKey: .sovereignVerdict
        )
        sovereignCommitTokens = try container.decodeIfPresent(
            [BASSovereignCommitToken].self,
            forKey: .sovereignCommitTokens
        ) ?? []
        sovereignWarrants = try container.decodeIfPresent(
            [BASSovereignWarrant].self,
            forKey: .sovereignWarrants
        ) ?? []
        sovereignLock = try container.decodeIfPresent(
            BASSovereignLock.self,
            forKey: .sovereignLock
        )
        quarantineRecords = try container.decodeIfPresent(
            [BASQuarantineRecord].self,
            forKey: .quarantineRecords
        ) ?? []
        sovereignAuditEntry = try container.decodeIfPresent(
            BASSovereignAuditEntry.self,
            forKey: .sovereignAuditEntry
        )
        sovereignActuationCommands = try container.decodeIfPresent(
            [BASSovereignActuationCommand].self,
            forKey: .sovereignActuationCommands
        ) ?? []
        sovereignExecutionReceipts = try container.decodeIfPresent(
            [BASSovereignExecutionReceipt].self,
            forKey: .sovereignExecutionReceipts
        ) ?? []
        policyLineage = try container.decodeIfPresent(
            BASRuntimePolicyLineage.self,
            forKey: .policyLineage
        )
        recoveryDisposition = try container.decodeIfPresent(
            BASRecoveryDisposition.self,
            forKey: .recoveryDisposition
        )
        hostConstitution = try container.decodeIfPresent(
            BASHostConstitution.self,
            forKey: .hostConstitution
        )
        hostConstitutionVault = try container.decodeIfPresent(
            BASHostConstitutionVault.self,
            forKey: .hostConstitutionVault
        )
        hostVersionTree = try container.decodeIfPresent(
            BASHostVersionTree.self,
            forKey: .hostVersionTree
        )
        hostForgetRequest = try container.decodeIfPresent(
            BASForgetRequest.self,
            forKey: .hostForgetRequest
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(deviceState, forKey: .deviceState)
        try container.encode(budgetFrame, forKey: .budgetFrame)
        try container.encode(wakeIntent, forKey: .wakeIntent)
        try container.encode(vitalState, forKey: .vitalState)
        try container.encodeIfPresent(runLease, forKey: .runLease)
        try container.encode(emergencyBrake, forKey: .emergencyBrake)
        try container.encodeIfPresent(sovereignVerdict, forKey: .sovereignVerdict)
        try container.encode(sovereignCommitTokens, forKey: .sovereignCommitTokens)
        try container.encode(sovereignWarrants, forKey: .sovereignWarrants)
        try container.encodeIfPresent(sovereignLock, forKey: .sovereignLock)
        try container.encode(quarantineRecords, forKey: .quarantineRecords)
        try container.encodeIfPresent(sovereignAuditEntry, forKey: .sovereignAuditEntry)
        try container.encode(sovereignActuationCommands, forKey: .sovereignActuationCommands)
        try container.encode(sovereignExecutionReceipts, forKey: .sovereignExecutionReceipts)
        try container.encodeIfPresent(policyLineage, forKey: .policyLineage)
        try container.encodeIfPresent(recoveryDisposition, forKey: .recoveryDisposition)
        try container.encodeIfPresent(hostConstitution, forKey: .hostConstitution)
        try container.encodeIfPresent(hostConstitutionVault, forKey: .hostConstitutionVault)
        try container.encodeIfPresent(hostVersionTree, forKey: .hostVersionTree)
        try container.encodeIfPresent(hostForgetRequest, forKey: .hostForgetRequest)
        try container.encode(hostContext, forKey: .hostContext)
        try container.encode(contextFrame, forKey: .contextFrame)
        try container.encode(decomposeFrame, forKey: .decomposeFrame)
        try container.encode(memoryBundle, forKey: .memoryBundle)
        try container.encode(thoughtFrame, forKey: .thoughtFrame)
        try container.encode(thoughtFold, forKey: .thoughtFold)
        try container.encode(triScores, forKey: .triScores)
        try container.encode(mergedChoice, forKey: .mergedChoice)
        try container.encode(riskCard, forKey: .riskCard)
        try container.encode(actionPermit, forKey: .actionPermit)
        try container.encodeIfPresent(riskDecisionPackage, forKey: .riskDecisionPackage)
        try container.encode(hostGateValue, forKey: .hostGateValue)
        try container.encode(renderedOutput, forKey: .renderedOutput)
        try container.encode(updateTickets, forKey: .updateTickets)
        try container.encode(experienceCandidates, forKey: .experienceCandidates)
        try container.encode(workflowCandidates, forKey: .workflowCandidates)
        try container.encode(guardTemplateCandidates, forKey: .guardTemplateCandidates)
        try container.encode(biasRecords, forKey: .biasRecords)
        try container.encode(riskPatternCandidates, forKey: .riskPatternCandidates)
        try container.encode(learningExportBundles, forKey: .learningExportBundles)
        try container.encode(shadowTrialRecords, forKey: .shadowTrialRecords)
        try container.encode(versionDeltas, forKey: .versionDeltas)
        try container.encode(retractionOrders, forKey: .retractionOrders)
        try container.encode(evolutionSeals, forKey: .evolutionSeals)
        try container.encode(runtimeTrace, forKey: .runtimeTrace)
        try container.encodeIfPresent(
            kunlunAxisAlignment,
            forKey: .kunlunAxisAlignment)
        try container.encodeIfPresent(
            humanAnchorSignal, forKey: .humanAnchorSignal)
        try container.encodeIfPresent(
            abyssalPressure, forKey: .abyssalPressure)
        try container.encodeIfPresent(
            unknownReserve, forKey: .unknownReserve)
    }

    private static func defaultWakeIntent(for budgetFrame: BASBudgetFrame) -> BASWakeIntent {
        BASWakeIntent(
            intentLevel: wakeIntentLevel(for: budgetFrame.runMode),
            estimatedValue: 0.5,
            estimatedRisk: budgetFrame.runMode == .guard ? 0.9 : 0.5,
            estimatedCost: min(
                1,
                Double(budgetFrame.maxLoops + budgetFrame.maxCandidates) / 10
            ),
            preferredMode: budgetFrame.runMode
        )
    }

    private static func defaultVitalState(
        deviceState: BASDeviceState,
        budgetFrame: BASBudgetFrame
    ) -> BASVitalState {
        BASVitalState(
            wakeState: budgetFrame.runMode,
            survivalMargin: max(0.1, deviceState.batteryLevel),
            thermalMargin: thermalMargin(for: deviceState.thermalLevel),
            powerMargin: max(0.1, 1 - max(deviceState.cpuLoad, deviceState.gpuLoad)),
            continuityScore: budgetFrame.hasActiveLease() ? 0.82 : 0.58,
            stabilityScore: budgetFrame.thermalGuardLevel == .emergency ? 0.2 : 0.64
        )
    }

    private static func wakeIntentLevel(for runMode: BASEBrainRunMode) -> BASWakeIntentLevel {
        switch runMode {
        case .dormant:
            .dormant
        case .pulse:
            .pulse
        case .sentinel:
            .sentinel
        case .guard, .quarantine, .lockdown:
            .guard
        case .engage, .reflect, .deepLoop, .recovery:
            .engage
        }
    }

    private static func thermalMargin(for thermalLevel: BASThermalLevel) -> Double {
        switch thermalLevel {
        case .nominal:
            0.92
        case .warm:
            0.64
        case .hot:
            0.34
        case .critical:
            0.08
        }
    }
}
